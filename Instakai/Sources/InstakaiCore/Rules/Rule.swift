import Foundation

/// One "eğer bu hareket ve şu koşul, o zaman şu makro" binding.
public struct Rule: Identifiable, Codable, Hashable, Sendable {

    public var id: UUID
    public var name: String
    public var isEnabled: Bool

    /// The gesture that starts this rule.
    public var trigger: GestureTrigger
    /// The "eğer" gate. `.always` means the gesture alone is enough.
    public var condition: Condition
    /// What to run. `runMacro` entries are expanded before dispatch.
    public var actions: [MacroAction]

    /// Minimum seconds between two firings of this rule. Guards against a
    /// gesture that hovers near the threshold spamming Instagram.
    public var cooldown: TimeInterval

    /// Higher priority wins when several rules fire on the same frame.
    public var priority: Int

    /// When true, firing this rule suppresses every lower-priority rule on the
    /// same frame. Use it for "dil aşağı + ağız açık" style combos that would
    /// otherwise also match the plain "dil aşağı" rule.
    public var isExclusive: Bool

    public var notes: String

    public init(id: UUID = UUID(),
                name: String,
                isEnabled: Bool = true,
                trigger: GestureTrigger,
                condition: Condition = .always,
                actions: [MacroAction],
                cooldown: TimeInterval = 0.35,
                priority: Int = 0,
                isExclusive: Bool = false,
                notes: String = "") {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.trigger = trigger
        self.condition = condition
        self.actions = actions
        self.cooldown = cooldown
        self.priority = priority
        self.isExclusive = isExclusive
        self.notes = notes
    }

    /// One-line description for the rule list: "Dil aşağı → Kaydır aşağı".
    public var summary: String {
        let actionSummary = actions.first?.displayName ?? "eylem yok"
        let suffix = actions.count > 1 ? " +\(actions.count - 1)" : ""
        return "\(trigger.signal.displayName) → \(actionSummary)\(suffix)"
    }
}

/// A rule that matched on a given frame, with its actions already flattened.
public struct RuleFiring: Identifiable, Hashable, Sendable {
    public var id: UUID { ruleID }
    public var ruleID: UUID
    public var ruleName: String
    public var schedule: [ScheduledAction]
    public var timestamp: TimeInterval

    public init(ruleID: UUID, ruleName: String, schedule: [ScheduledAction], timestamp: TimeInterval) {
        self.ruleID = ruleID
        self.ruleName = ruleName
        self.schedule = schedule
        self.timestamp = timestamp
    }
}
