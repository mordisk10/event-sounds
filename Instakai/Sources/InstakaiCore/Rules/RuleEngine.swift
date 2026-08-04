import Foundation

/// Evaluates every enabled rule against each incoming frame and decides which
/// ones actually fire.
///
/// Per frame the engine:
/// 1. advances each rule's `TriggerStateMachine`,
/// 2. drops rules whose `condition` does not hold,
/// 3. drops rules still inside their cooldown (or the global cooldown),
/// 4. sorts survivors by priority and applies exclusivity,
/// 5. applies flag mutations, then expands the remaining actions into schedules.
///
/// The engine never touches UIKit or WebKit — it returns `RuleFiring` values and
/// something else decides how to perform them.
public final class RuleEngine {

    public struct Options: Codable, Hashable, Sendable {
        /// Minimum seconds between *any* two firings, across all rules. Acts as
        /// a global rate limit so a badly tuned profile cannot flood the surface.
        public var globalCooldown: TimeInterval
        /// Maximum rules allowed to fire on a single frame.
        public var maximumConcurrentFirings: Int
        /// When false, the engine evaluates but reports firings without marking
        /// cooldowns — used by the "test mode" in the rule editor.
        public var commitsCooldowns: Bool

        public init(globalCooldown: TimeInterval = 0.12,
                    maximumConcurrentFirings: Int = 2,
                    commitsCooldowns: Bool = true) {
            self.globalCooldown = globalCooldown
            self.maximumConcurrentFirings = maximumConcurrentFirings
            self.commitsCooldowns = commitsCooldowns
        }

        public static let `default` = Options()
    }

    public private(set) var rules: [Rule]
    public private(set) var macros: [String: Macro]
    public var options: Options

    /// One state machine per rule id, kept across frames.
    private var machines: [UUID: TriggerStateMachine] = [:]
    /// Last fire timestamp per rule id.
    private var lastFired: [UUID: TimeInterval] = [:]
    private var lastGlobalFire: TimeInterval = -.greatestFiniteMagnitude

    /// Errors raised while expanding macros, surfaced to the UI rather than
    /// thrown out of the hot path.
    public private(set) var lastExpansionError: String?

    public init(rules: [Rule] = [],
                macros: [Macro] = [],
                options: Options = .default) {
        self.rules = rules
        self.macros = Dictionary(uniqueKeysWithValues: macros.map { ($0.id, $0) })
        self.options = options
    }

    // MARK: - Configuration

    /// Swaps the rule set in without losing in-flight gesture state for rules
    /// that survived the edit. This matters because the editor writes on every
    /// keystroke while the camera is live.
    public func replace(rules newRules: [Rule]) {
        rules = newRules
        let liveIDs = Set(newRules.map(\.id))
        machines = machines.filter { liveIDs.contains($0.key) }
        lastFired = lastFired.filter { liveIDs.contains($0.key) }
    }

    public func replace(macros newMacros: [Macro]) {
        macros = Dictionary(uniqueKeysWithValues: newMacros.map { ($0.id, $0) })
    }

    /// Clears all gesture and cooldown state.
    public func reset() {
        machines.values.forEach { $0.reset() }
        lastFired.removeAll()
        lastGlobalFire = -.greatestFiniteMagnitude
        lastExpansionError = nil
    }

    // MARK: - Evaluation

    public func update(frame: SignalFrame, context: EvaluationContext) -> [RuleFiring] {
        let now = frame.timestamp

        // Step 1 + 2: advance triggers, keep only rules whose condition holds.
        var candidates: [Rule] = []
        for rule in rules {
            let machine = machines[rule.id] ?? {
                let created = TriggerStateMachine()
                machines[rule.id] = created
                return created
            }()

            guard rule.isEnabled else {
                machine.reset()
                continue
            }

            let didFire = machine.update(trigger: rule.trigger, frame: frame)
            guard didFire else { continue }
            guard rule.condition.evaluate(frame: frame, context: context) else { continue }
            candidates.append(rule)
        }

        guard !candidates.isEmpty else { return [] }

        // Step 3: cooldowns.
        guard now - lastGlobalFire >= options.globalCooldown else { return [] }
        candidates = candidates.filter { rule in
            guard let previous = lastFired[rule.id] else { return true }
            return now - previous >= rule.cooldown
        }
        guard !candidates.isEmpty else { return [] }

        // Step 4: priority ordering, then exclusivity.
        candidates.sort { lhs, rhs in
            lhs.priority == rhs.priority ? lhs.name < rhs.name : lhs.priority > rhs.priority
        }
        // Candidates are sorted by descending priority, so everything after the
        // first exclusive rule is by definition lower priority and gets dropped.
        if let exclusiveIndex = candidates.firstIndex(where: \.isExclusive) {
            candidates = Array(candidates.prefix(through: exclusiveIndex))
        }
        candidates = Array(candidates.prefix(max(options.maximumConcurrentFirings, 1)))

        // Step 5: apply flag writes, expand the rest.
        var firings: [RuleFiring] = []
        for rule in candidates {
            let dispatchable = applyFlagMutations(in: rule.actions, context: context)
            let schedule: [ScheduledAction]
            do {
                schedule = try MacroExpander.expand(dispatchable, macros: macros)
            } catch {
                lastExpansionError = "\(rule.name): \(error)"
                continue
            }

            if options.commitsCooldowns {
                lastFired[rule.id] = now
                lastGlobalFire = now
            }
            firings.append(RuleFiring(ruleID: rule.id,
                                      ruleName: rule.name,
                                      schedule: schedule,
                                      timestamp: now))
        }
        return firings
    }

    /// Executes flag actions immediately and returns the remaining actions.
    ///
    /// Flags are applied here, not by the dispatcher, so that a rule later in
    /// the same frame already sees the new value.
    private func applyFlagMutations(in actions: [MacroAction],
                                    context: EvaluationContext) -> [MacroAction] {
        actions.filter { action in
            switch action {
            case .setFlag(let name, let value):
                context.flags.set(name, to: value)
                return false
            case .toggleFlag(let name):
                context.flags.toggle(name)
                return false
            default:
                return true
            }
        }
    }

    // MARK: - Introspection

    /// Current phase of a rule's trigger, for the live debug view.
    public func phase(of ruleID: UUID) -> TriggerStateMachine.Phase {
        machines[ruleID]?.phase ?? .idle
    }

    /// Seconds remaining on a rule's cooldown at `now`.
    public func cooldownRemaining(for rule: Rule, now: TimeInterval) -> TimeInterval {
        guard let previous = lastFired[rule.id] else { return 0 }
        return max(0, rule.cooldown - (now - previous))
    }
}
