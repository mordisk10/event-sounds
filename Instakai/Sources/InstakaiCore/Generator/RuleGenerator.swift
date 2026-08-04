import Foundation

/// Compiles high-level `RuleBlueprint` values into executable `Rule` values.
///
/// Everything tuning-related lives here in one table. When a gesture feels wrong
/// on real hardware, this is the single file to adjust — no rule that a user has
/// already saved needs to change, because saved rules are blueprints.
public enum RuleGenerator {

    /// Base tuning per gesture preset, before sensitivity scaling.
    struct Tuning {
        var threshold: Double
        var release: Double
        var minimumHold: TimeInterval
        var maximumHold: TimeInterval?
        var repeatCount: Int
        var repeatWindow: TimeInterval
        var fireMode: FireMode
        var cooldown: TimeInterval
    }

    static func tuning(for preset: GesturePreset) -> Tuning {
        switch preset {
        // Directional tongue gestures auto-repeat: holding the tongue down keeps
        // scrolling, which is far less tiring than one gesture per scroll.
        case .tongueDown, .tongueUp, .tongueLeft, .tongueRight:
            return Tuning(threshold: 0.45, release: 0.28, minimumHold: 0.16,
                          maximumHold: nil, repeatCount: 1, repeatWindow: 0.8,
                          fireMode: .repeating(interval: 0.55), cooldown: 0.25)

        case .tongueOutShort:
            return Tuning(threshold: 0.5, release: 0.3, minimumHold: 0.10,
                          maximumHold: 0.55, repeatCount: 1, repeatWindow: 0.8,
                          fireMode: .release, cooldown: 0.4)

        case .tongueOutLong:
            return Tuning(threshold: 0.5, release: 0.3, minimumHold: 0.9,
                          maximumHold: nil, repeatCount: 1, repeatWindow: 0.8,
                          fireMode: .edge, cooldown: 1.0)

        case .tongueOutDouble:
            return Tuning(threshold: 0.5, release: 0.28, minimumHold: 0.07,
                          maximumHold: 0.45, repeatCount: 2, repeatWindow: 1.0,
                          fireMode: .release, cooldown: 0.7)

        case .jawOpen:
            return Tuning(threshold: 0.55, release: 0.32, minimumHold: 0.25,
                          maximumHold: nil, repeatCount: 1, repeatWindow: 0.8,
                          fireMode: .edge, cooldown: 0.6)

        // Blinks need a double to avoid firing on natural blinking.
        case .blinkLeftDouble, .blinkRightDouble:
            return Tuning(threshold: 0.62, release: 0.3, minimumHold: 0.05,
                          maximumHold: 0.35, repeatCount: 2, repeatWindow: 0.85,
                          fireMode: .release, cooldown: 0.8)

        case .browRaise:
            return Tuning(threshold: 0.5, release: 0.3, minimumHold: 0.22,
                          maximumHold: nil, repeatCount: 1, repeatWindow: 0.8,
                          fireMode: .edge, cooldown: 0.7)

        case .smile:
            return Tuning(threshold: 0.55, release: 0.33, minimumHold: 0.3,
                          maximumHold: nil, repeatCount: 1, repeatWindow: 0.8,
                          fireMode: .edge, cooldown: 1.2)

        case .cheekPuff:
            return Tuning(threshold: 0.5, release: 0.3, minimumHold: 0.25,
                          maximumHold: nil, repeatCount: 1, repeatWindow: 0.8,
                          fireMode: .edge, cooldown: 0.8)

        case .headNodDown, .headTurnLeft, .headTurnRight:
            return Tuning(threshold: 0.42, release: 0.24, minimumHold: 0.3,
                          maximumHold: nil, repeatCount: 1, repeatWindow: 0.8,
                          fireMode: .edge, cooldown: 0.8)
        }
    }

    /// Builds the trigger for a blueprint.
    public static func makeTrigger(for blueprint: RuleBlueprint) -> GestureTrigger {
        let base = tuning(for: blueprint.gesture)
        let scale = blueprint.sensitivity.thresholdScale
        let threshold = min(max(base.threshold * scale, 0.1), 0.95)
        // Keep the hysteresis gap proportional so a high threshold does not end
        // up with a release point above it.
        let gap = (base.threshold - base.release) * scale
        let release = min(max(threshold - max(gap, 0.06), 0.05), threshold - 0.03)

        return GestureTrigger(signal: blueprint.gesture.signal,
                              threshold: threshold,
                              releaseThreshold: release,
                              minimumHold: base.minimumHold * blueprint.sensitivity.holdScale,
                              maximumHold: base.maximumHold,
                              repeatCount: base.repeatCount,
                              repeatWindow: base.repeatWindow,
                              fireMode: base.fireMode)
    }

    /// Builds the full condition tree: surface restriction AND extra clauses.
    public static func makeCondition(for blueprint: RuleBlueprint) -> Condition {
        var clauses: [Condition] = []
        if let surface = blueprint.surface {
            clauses.append(.surface(surface))
        }
        clauses.append(contentsOf: blueprint.extraConditions)

        switch clauses.count {
        case 0: return .always
        case 1: return clauses[0]
        default: return .all(clauses)
        }
    }

    /// Compiles a blueprint into a rule. The rule reuses the blueprint's `id`,
    /// so regenerating after an edit preserves engine state for that rule.
    public static func makeRule(from blueprint: RuleBlueprint) -> Rule {
        let base = tuning(for: blueprint.gesture)
        return Rule(id: blueprint.id,
                    name: blueprint.name,
                    isEnabled: blueprint.isEnabled,
                    trigger: makeTrigger(for: blueprint),
                    condition: makeCondition(for: blueprint),
                    actions: blueprint.actions,
                    cooldown: max(base.cooldown * blueprint.cooldownScale, 0.05),
                    priority: blueprint.priority,
                    isExclusive: blueprint.isExclusive,
                    notes: blueprint.notes)
    }

    public static func makeRules(from blueprints: [RuleBlueprint]) -> [Rule] {
        blueprints.map(makeRule(from:))
    }

    // MARK: - Validation

    public struct Warning: Identifiable, Hashable, Sendable {
        public var id = UUID()
        public var blueprintID: UUID?
        public var message: String
    }

    /// Static checks the editor shows before a profile goes live. These catch
    /// the mistakes that are otherwise only discoverable by pointing a camera at
    /// your face and getting confused.
    public static func validate(blueprints: [RuleBlueprint],
                                macros: [Macro]) -> [Warning] {
        var warnings: [Warning] = []
        let macroIndex = Dictionary(uniqueKeysWithValues: macros.map { ($0.id, $0) })

        for blueprint in blueprints {
            if blueprint.actions.isEmpty {
                warnings.append(Warning(blueprintID: blueprint.id,
                                        message: "“\(blueprint.name)” kuralının hiç eylemi yok."))
            }

            for action in blueprint.actions {
                if case .runMacro(let id) = action, macroIndex[id] == nil {
                    warnings.append(Warning(blueprintID: blueprint.id,
                                            message: "“\(blueprint.name)” eksik makroya işaret ediyor: \(id)"))
                }
            }

            // Recursion check per blueprint, using the real expander.
            do {
                _ = try MacroExpander.expand(blueprint.actions, macros: macroIndex)
            } catch {
                warnings.append(Warning(blueprintID: blueprint.id,
                                        message: "“\(blueprint.name)”: \(error)"))
            }
        }

        // Overlapping gestures with identical scoping will race each other.
        let enabled = blueprints.filter(\.isEnabled)
        for index in enabled.indices {
            for other in enabled[(index + 1)...] {
                let lhs = enabled[index]
                guard lhs.gesture == other.gesture,
                      lhs.surface == other.surface,
                      lhs.priority == other.priority,
                      !lhs.isExclusive, !other.isExclusive else { continue }
                warnings.append(Warning(
                    blueprintID: lhs.id,
                    message: "“\(lhs.name)” ve “\(other.name)” aynı hareketi aynı ekranda paylaşıyor; " +
                             "birine öncelik verin ya da “yalnızca bu” işaretleyin."))
            }
        }

        return warnings
    }
}
