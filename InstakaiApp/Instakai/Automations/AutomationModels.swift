import SwiftUI

/// What starts an automation.
enum AutomationTrigger: String, CaseIterable, Identifiable, Codable {
    case tongueDown, tongueUp, tongueLeft, tongueRight
    case doubleBlink, browRaise, jawOpen, cheekPuff
    case voiceCommand

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .tongueDown: return "arrow.down.circle.fill"
        case .tongueUp: return "arrow.up.circle.fill"
        case .tongueLeft: return "arrow.left.circle.fill"
        case .tongueRight: return "arrow.right.circle.fill"
        case .doubleBlink: return "eye.fill"
        case .browRaise: return "arrow.up.and.down.circle"
        case .jawOpen: return "mouth.fill"
        case .cheekPuff: return "wind"
        case .voiceCommand: return "waveform"
        }
    }

    func name(_ lang: LanguageManager) -> String {
        let tr: String, en: String
        switch self {
        case .tongueDown: (tr, en) = ("Dili aşağı uzat", "Point tongue down")
        case .tongueUp: (tr, en) = ("Dili yukarı uzat", "Point tongue up")
        case .tongueLeft: (tr, en) = ("Dili sola uzat", "Point tongue left")
        case .tongueRight: (tr, en) = ("Dili sağa uzat", "Point tongue right")
        case .doubleBlink: (tr, en) = ("Çift göz kırp", "Double blink")
        case .browRaise: (tr, en) = ("Kaşları kaldır", "Raise brows")
        case .jawOpen: (tr, en) = ("Ağzı aç", "Open jaw")
        case .cheekPuff: (tr, en) = ("Yanakları şişir", "Puff cheeks")
        case .voiceCommand: (tr, en) = ("Ses komutu", "Voice command")
        }
        return lang.language == .turkish ? tr : en
    }
}

/// The extra requirement layered on top of a trigger.
enum AutomationCondition: String, CaseIterable, Identifiable, Codable {
    case always, inReels, inFeed, inStories, inMessages, sessionOnly

    var id: String { rawValue }

    func name(_ lang: LanguageManager) -> String {
        let tr: String, en: String
        switch self {
        case .always: (tr, en) = ("Her zaman", "Always")
        case .inReels: (tr, en) = ("Yalnızca Reels'te", "Only in Reels")
        case .inFeed: (tr, en) = ("Yalnızca akışta", "Only in feed")
        case .inStories: (tr, en) = ("Yalnızca hikâyelerde", "Only in stories")
        case .inMessages: (tr, en) = ("Yalnızca mesajlarda", "Only in messages")
        case .sessionOnly: (tr, en) = ("Oturum açıkken", "While session is on")
        }
        return lang.language == .turkish ? tr : en
    }
}

/// What the automation does.
enum AutomationAction: String, CaseIterable, Identifiable, Codable {
    case scrollNext, scrollPrevious, like, save, openComments
    case mute, playPause, goBack, openReels

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .scrollNext: return "chevron.down"
        case .scrollPrevious: return "chevron.up"
        case .like: return "heart.fill"
        case .save: return "bookmark.fill"
        case .openComments: return "bubble.left.fill"
        case .mute: return "speaker.slash.fill"
        case .playPause: return "playpause.fill"
        case .goBack: return "arrow.uturn.backward"
        case .openReels: return "play.rectangle.fill"
        }
    }

    func name(_ lang: LanguageManager) -> String {
        let tr: String, en: String
        switch self {
        case .scrollNext: (tr, en) = ("Sonrakine geç", "Go to next")
        case .scrollPrevious: (tr, en) = ("Öncekine dön", "Go to previous")
        case .like: (tr, en) = ("Beğen", "Like")
        case .save: (tr, en) = ("Kaydet", "Save")
        case .openComments: (tr, en) = ("Yorumları aç", "Open comments")
        case .mute: (tr, en) = ("Sesi aç/kapat", "Toggle sound")
        case .playPause: (tr, en) = ("Oynat/duraklat", "Play/pause")
        case .goBack: (tr, en) = ("Geri dön", "Go back")
        case .openReels: (tr, en) = ("Reels'i aç", "Open Reels")
        }
        return lang.language == .turkish ? tr : en
    }
}

struct Automation: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var isEnabled: Bool = true
    var trigger: AutomationTrigger
    var condition: AutomationCondition = .always
    var actions: [AutomationAction]

    // Technical settings. Hidden behind a disclosure by default — most people
    // never touch them, and every one has an info tip next to it.
    var priority: Int = 0
    var cooldown: Double = 0.4
    var isExclusive: Bool = false

    var runCount: Int = 0
    var lastRun: Date?
}

/// Stores automations and produces suggestions from plain-language input.
@MainActor
final class AutomationStore: ObservableObject {

    @Published var automations: [Automation] = []
    /// The suggestion awaiting accept/discard, if any.
    @Published var suggestion: Automation?
    @Published var isGenerating = false

    private let storageKey = "app.automations"

    init() {
        load()
        if automations.isEmpty { automations = Self.starterSet }
    }

    // MARK: - CRUD

    func upsert(_ automation: Automation) {
        if let index = automations.firstIndex(where: { $0.id == automation.id }) {
            automations[index] = automation
        } else {
            automations.append(automation)
        }
        save()
    }

    func delete(_ automation: Automation) {
        automations.removeAll { $0.id == automation.id }
        save()
    }

    func duplicate(_ automation: Automation) {
        var copy = automation
        copy.id = UUID()
        copy.name += " ✦"
        copy.runCount = 0
        copy.lastRun = nil
        automations.append(copy)
        save()
    }

    func setEnabled(_ id: UUID, _ isEnabled: Bool) {
        guard let index = automations.firstIndex(where: { $0.id == id }) else { return }
        automations[index].isEnabled = isEnabled
        save()
    }

    // MARK: - AI composition

    /// Turns a sentence into a proposed automation.
    ///
    /// Today this is keyword matching, on purpose: it keeps the accept/refine/
    /// discard flow honest while the model is not wired up. When a real model
    /// lands it replaces the body of this method and nothing in the UI changes.
    func generate(from prompt: String, lang: LanguageManager) async {
        isGenerating = true
        defer { isGenerating = false }

        try? await Task.sleep(for: .milliseconds(900))

        let text = prompt.lowercased()

        let trigger: AutomationTrigger
        if text.contains("aşağı") || text.contains("down") {
            trigger = .tongueDown
        } else if text.contains("yukarı") || text.contains("up") {
            trigger = .tongueUp
        } else if text.contains("göz") || text.contains("blink") {
            trigger = .doubleBlink
        } else if text.contains("kaş") || text.contains("brow") {
            trigger = .browRaise
        } else if text.contains("sol") || text.contains("left") {
            trigger = .tongueLeft
        } else if text.contains("sağ") || text.contains("right") {
            trigger = .tongueRight
        } else {
            trigger = .voiceCommand
        }

        var actions: [AutomationAction] = []
        if text.contains("beğen") || text.contains("like") { actions.append(.like) }
        if text.contains("kaydet") || text.contains("save") { actions.append(.save) }
        if text.contains("yorum") || text.contains("comment") { actions.append(.openComments) }
        if text.contains("ses") || text.contains("mute") || text.contains("sound") {
            actions.append(.mute)
        }
        if text.contains("geri") || text.contains("previous") || text.contains("back") {
            actions.append(.scrollPrevious)
        }
        if actions.isEmpty { actions = [.scrollNext] }

        let condition: AutomationCondition
        if text.contains("reels") {
            condition = .inReels
        } else if text.contains("akış") || text.contains("feed") {
            condition = .inFeed
        } else {
            condition = .always
        }

        suggestion = Automation(
            name: prompt.count > 34 ? String(prompt.prefix(34)) + "…" : prompt,
            trigger: trigger,
            condition: condition,
            actions: actions
        )
        Haptics.success()
    }

    func acceptSuggestion() {
        guard let suggestion else { return }
        automations.append(suggestion)
        self.suggestion = nil
        save()
        Haptics.success()
    }

    func discardSuggestion() {
        suggestion = nil
        Haptics.impact(.light)
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(automations) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Automation].self, from: data) else { return }
        automations = decoded
    }

    /// What a new install starts with, so the list is never empty on first open.
    static let starterSet: [Automation] = [
        Automation(name: "Dil aşağı → sonraki",
                   trigger: .tongueDown, condition: .always, actions: [.scrollNext],
                   runCount: 128, lastRun: Date().addingTimeInterval(-320)),
        Automation(name: "Dil yukarı → önceki",
                   trigger: .tongueUp, condition: .always, actions: [.scrollPrevious],
                   runCount: 41, lastRun: Date().addingTimeInterval(-900)),
        Automation(name: "Çift göz kırpma → beğen",
                   trigger: .doubleBlink, condition: .inReels, actions: [.like],
                   priority: 10, isExclusive: true,
                   runCount: 12, lastRun: Date().addingTimeInterval(-4200))
    ]
}
