#if canImport(UIKit)
import UIKit
import AVFoundation
import InstakaiCore

/// Performs the scheduled actions a rule firing produced.
///
/// Actions are dispatched on the main queue at their scheduled offsets. Nothing
/// blocks: a macro with a 400ms gap schedules its second half rather than
/// sleeping, so the tracker keeps running at full rate throughout.
@MainActor
final class MacroDispatcher: ObservableObject {

    /// Actions performed recently, newest first — the session screen's activity log.
    @Published private(set) var log: [Entry] = []
    /// Set to false by the panic switch; every dispatch becomes a no-op.
    @Published var isArmed = true

    struct Entry: Identifiable {
        let id = UUID()
        let ruleName: String
        let detail: String
        let date: Date
    }

    private let surface: InstagramSurfaceController
    private let haptics = HapticsService()
    private let speech = AVSpeechSynthesizer()

    /// Work items for actions not yet performed, so a panic stop can cancel
    /// everything still queued.
    private var pending: [DispatchWorkItem] = []

    init(surface: InstagramSurfaceController) {
        self.surface = surface
    }

    func dispatch(_ firing: RuleFiring) {
        guard isArmed else { return }

        for scheduled in firing.schedule {
            guard scheduled.offset > 0.001 else {
                perform(scheduled.action, ruleName: firing.ruleName)
                continue
            }
            let item = DispatchWorkItem { [weak self] in
                self?.perform(scheduled.action, ruleName: firing.ruleName)
            }
            pending.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + scheduled.offset, execute: item)
        }

        pending.removeAll { $0.isCancelled }
    }

    /// Cancels everything queued and disarms. Bound to the big stop button.
    func panicStop() {
        pending.forEach { $0.cancel() }
        pending.removeAll()
        isArmed = false
        append(ruleName: "—", detail: "Acil durdurma: kuyruk temizlendi")
    }

    private func perform(_ action: MacroAction, ruleName: String) {
        guard isArmed else { return }

        switch action {
        case .haptic(let style):
            haptics.play(style)
        case .speak(let text):
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "tr-TR")
            speech.speak(utterance)
        case .delay, .runMacro, .setFlag, .toggleFlag:
            // Delays are folded into offsets, macros are expanded and flags are
            // applied inside the engine — none of these reach the dispatcher.
            return
        default:
            surface.perform(action)
        }

        append(ruleName: ruleName, detail: action.displayName)
    }

    private func append(ruleName: String, detail: String) {
        log.insert(Entry(ruleName: ruleName, detail: detail, date: Date()), at: 0)
        if log.count > 60 { log.removeLast(log.count - 60) }
    }
}

/// Thin wrapper over the feedback generators, kept in one place so haptics can
/// be muted globally from Settings.
final class HapticsService {

    var isEnabled = true

    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    func play(_ style: HapticStyle) {
        guard isEnabled else { return }
        switch style {
        case .light:     UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:     UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .success:   notification.notificationOccurred(.success)
        case .warning:   notification.notificationOccurred(.warning)
        case .error:     notification.notificationOccurred(.error)
        case .selection: selection.selectionChanged()
        }
    }
}
#endif
