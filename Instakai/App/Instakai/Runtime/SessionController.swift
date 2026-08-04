#if canImport(UIKit) && canImport(ARKit)
import SwiftUI
import Combine
import InstakaiCore

/// Wires the tracker, the rule engine, the surface and the dispatcher together,
/// and owns the profile that configures all four.
///
/// This is the only object that knows about every layer; everything else stays
/// unaware of the rest of the app.
@MainActor
final class SessionController: ObservableObject {

    // MARK: Published state

    @Published private(set) var profile: Profile {
        didSet { applyProfile() }
    }
    @Published private(set) var profiles: [Profile] = []
    @Published var mode: String
    @Published private(set) var isRunning = false
    /// Most recent processed frame, for the live meters.
    @Published private(set) var frame: SignalFrame = SignalFrame.lost(at: 0)
    @Published private(set) var storeError: String?

    // MARK: Collaborators

    let tracking = FaceTrackingService()
    let surface = InstagramSurfaceController()
    let dispatcher: MacroDispatcher

    private let engine = RuleEngine()
    private let flags = FlagRegistry()
    private var store: ProfileStore?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let seed = PresetLibrary.handsFreeBrowsing()
        profile = seed
        mode = seed.defaultMode
        dispatcher = MacroDispatcher(surface: surface)

        loadStore()
        applyProfile()
        observeTracking()
        forwardChildUpdates()
    }

    /// Re-publishes changes from the nested observable objects.
    ///
    /// SwiftUI only observes the object a view declares. Without this, the
    /// surface chip and the activity log would go stale because views watch
    /// `SessionController` while the values live on its children.
    private func forwardChildUpdates() {
        for publisher in [surface.objectWillChange.eraseToAnyPublisher(),
                          dispatcher.objectWillChange.eraseToAnyPublisher(),
                          tracking.objectWillChange.eraseToAnyPublisher()] {
            publisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
    }

    // MARK: - Profile lifecycle

    private func loadStore() {
        do {
            let store = try ProfileStore.makeDefault()
            self.store = store
            let loaded = try store.loadOrSeed()
            profiles = loaded
            if let first = loaded.first { profile = first }
        } catch {
            storeError = "Profiller yüklenemedi: \(error.localizedDescription)"
        }
    }

    /// Pushes the current profile into every component that depends on it.
    /// Called on every edit, including while the camera is live.
    private func applyProfile() {
        engine.replace(macros: profile.resolvedMacros())
        engine.replace(rules: profile.compiledRules)
        engine.options = profile.engineOptions
        tracking.apply(tuning: profile.signalTuning)
        tracking.apply(calibration: profile.calibration)
        flags.replaceAll(with: profile.flags)
        if !profile.modes.contains(mode) {
            mode = profile.defaultMode
        }
    }

    func select(profile newProfile: Profile) {
        profile = newProfile
        mode = newProfile.defaultMode
    }

    /// Mutates and persists the active profile. Every editor goes through here
    /// so saving and re-applying can never be forgotten at a call site.
    func updateProfile(_ mutate: (inout Profile) -> Void) {
        var copy = profile
        mutate(&copy)
        profile = copy
        persist(copy)
    }

    private func persist(_ profile: Profile) {
        guard let store else { return }
        do {
            try store.save(profile)
            if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[index] = profile
            } else {
                profiles.append(profile)
            }
        } catch {
            storeError = "Profil kaydedilemedi: \(error.localizedDescription)"
        }
    }

    func duplicateActiveProfile() {
        var copy = profile
        copy.id = UUID()
        copy.name += " kopyası"
        persist(copy)
        profile = copy
    }

    func deleteActiveProfile() {
        guard profiles.count > 1, let store else { return }
        try? store.delete(profile)
        profiles.removeAll { $0.id == profile.id }
        if let next = profiles.first { profile = next }
    }

    func exportActiveProfile() -> String {
        (try? store?.exportJSON(profile)) ?? ""
    }

    func importProfile(json: String) {
        guard let store else { return }
        do {
            let imported = try store.importJSON(json)
            profiles.append(imported)
            profile = imported
        } catch {
            storeError = "İçe aktarma başarısız: \(error.localizedDescription)"
        }
    }

    // MARK: - Blueprint editing

    func upsert(blueprint: RuleBlueprint) {
        updateProfile { profile in
            if let index = profile.blueprints.firstIndex(where: { $0.id == blueprint.id }) {
                profile.blueprints[index] = blueprint
            } else {
                profile.blueprints.append(blueprint)
            }
        }
    }

    func deleteBlueprints(at offsets: IndexSet) {
        updateProfile { $0.blueprints.remove(atOffsets: offsets) }
    }

    func moveBlueprints(from offsets: IndexSet, to destination: Int) {
        updateProfile { $0.blueprints.move(fromOffsets: offsets, toOffset: destination) }
    }

    func setBlueprint(_ id: UUID, enabled: Bool) {
        updateProfile { profile in
            guard let index = profile.blueprints.firstIndex(where: { $0.id == id }) else { return }
            profile.blueprints[index].isEnabled = enabled
        }
    }

    func upsert(macro: Macro) {
        updateProfile { profile in
            if let index = profile.macros.firstIndex(where: { $0.id == macro.id }) {
                profile.macros[index] = macro
            } else {
                profile.macros.append(macro)
            }
        }
    }

    // MARK: - Run loop

    private func observeTracking() {
        // Engine evaluation happens on the tracker's queue, off the main thread,
        // so a busy UI cannot add latency to a gesture.
        tracking.frames
            .sink { [weak self] frame in self?.handle(frame: frame) }
            .store(in: &cancellables)

        tracking.$latestFrame
            .receive(on: DispatchQueue.main)
            .assign(to: &$frame)
    }

    private nonisolated func handle(frame: SignalFrame) {
        Task { @MainActor [weak self] in
            guard let self, self.isRunning else { return }
            let context = EvaluationContext.current(surface: self.surface.currentSurface,
                                                    mode: self.mode,
                                                    flags: self.flags)
            for firing in self.engine.update(frame: frame, context: context) {
                self.dispatcher.dispatch(firing)
            }
        }
    }

    func start() {
        engine.reset()
        flags.replaceAll(with: profile.flags)
        dispatcher.isArmed = true
        tracking.start()
        isRunning = true
    }

    func stop() {
        tracking.stop()
        engine.reset()
        isRunning = false
    }

    func panicStop() {
        dispatcher.panicStop()
        stop()
    }

    // MARK: - Introspection for the UI

    var warnings: [RuleGenerator.Warning] { profile.warnings }

    func flagValue(_ name: String) -> Bool { flags.value(for: name) }

    var flagSnapshot: [String: Bool] { flags.snapshot }
}
#endif
