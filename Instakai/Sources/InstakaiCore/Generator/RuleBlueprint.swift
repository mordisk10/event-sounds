import Foundation

/// Named gesture shapes the generator knows how to turn into a tuned trigger.
///
/// A preset carries the *intent* ("dil aşağı kaydır") while the generator owns
/// the numbers. That split is the point of the generator: the user picks a
/// gesture and a sensitivity in the UI, and never has to reason about hysteresis
/// or hold windows unless they open the advanced editor.
public enum GesturePreset: String, Codable, CaseIterable, Sendable {
    case tongueDown
    case tongueUp
    case tongueLeft
    case tongueRight
    case tongueOutShort
    case tongueOutLong
    case tongueOutDouble
    case jawOpen
    case blinkLeftDouble
    case blinkRightDouble
    case browRaise
    case smile
    case cheekPuff
    case headNodDown
    case headTurnLeft
    case headTurnRight

    public var displayName: String {
        switch self {
        case .tongueDown: return "Dili aşağı uzat"
        case .tongueUp: return "Dili yukarı uzat"
        case .tongueLeft: return "Dili sola uzat"
        case .tongueRight: return "Dili sağa uzat"
        case .tongueOutShort: return "Dili kısa çıkar"
        case .tongueOutLong: return "Dili uzun süre çıkar"
        case .tongueOutDouble: return "Dili iki kez çıkar"
        case .jawOpen: return "Ağzı aç"
        case .blinkLeftDouble: return "Sol gözü iki kez kırp"
        case .blinkRightDouble: return "Sağ gözü iki kez kırp"
        case .browRaise: return "Kaşları kaldır"
        case .smile: return "Gülümse"
        case .cheekPuff: return "Yanakları şişir"
        case .headNodDown: return "Başı aşağı eğ"
        case .headTurnLeft: return "Başı sola çevir"
        case .headTurnRight: return "Başı sağa çevir"
        }
    }

    /// The signal this preset watches.
    public var signal: Signal {
        switch self {
        case .tongueDown: return .tongueDown
        case .tongueUp: return .tongueUp
        case .tongueLeft: return .tongueLeft
        case .tongueRight: return .tongueRight
        case .tongueOutShort, .tongueOutLong, .tongueOutDouble: return .tongueOut
        case .jawOpen: return .jawOpen
        case .blinkLeftDouble: return .eyeBlinkLeft
        case .blinkRightDouble: return .eyeBlinkRight
        case .browRaise: return .browInnerUp
        case .smile: return .mouthSmileLeft
        case .cheekPuff: return .cheekPuff
        case .headNodDown: return .headPitchDown
        case .headTurnLeft: return .headYawLeft
        case .headTurnRight: return .headYawRight
        }
    }

    /// Presets grouped for the picker.
    public static let groups: [(title: String, presets: [GesturePreset])] = [
        ("Dil", [.tongueDown, .tongueUp, .tongueLeft, .tongueRight,
                 .tongueOutShort, .tongueOutLong, .tongueOutDouble]),
        ("Yüz", [.jawOpen, .browRaise, .smile, .cheekPuff,
                 .blinkLeftDouble, .blinkRightDouble]),
        ("Baş", [.headNodDown, .headTurnLeft, .headTurnRight])
    ]
}

/// How eagerly a gesture should fire.
public enum Sensitivity: String, Codable, CaseIterable, Sendable {
    case low, medium, high

    public var displayName: String {
        switch self {
        case .low: return "Düşük (zor tetiklenir)"
        case .medium: return "Orta"
        case .high: return "Yüksek (kolay tetiklenir)"
        }
    }

    /// Multiplier applied to the preset's base threshold.
    var thresholdScale: Double {
        switch self {
        case .low: return 1.25
        case .medium: return 1.0
        case .high: return 0.78
        }
    }

    /// Multiplier applied to the preset's base hold time.
    var holdScale: Double {
        switch self {
        case .low: return 1.4
        case .medium: return 1.0
        case .high: return 0.7
        }
    }
}

/// The form-shaped description of a rule, as edited in the UI.
///
/// A blueprint is what gets saved when a user builds a rule with the simple
/// editor; `RuleGenerator` compiles it into a full `Rule`. Blueprints are also
/// what presets and shared "recipe" JSON files contain, so a rule set stays
/// portable across app versions even if the tuning constants change.
public struct RuleBlueprint: Identifiable, Codable, Hashable, Sendable {

    public var id: UUID
    public var name: String
    public var gesture: GesturePreset
    public var sensitivity: Sensitivity
    /// Restrict to one Instagram surface. `nil` means "any surface".
    public var surface: Surface?
    /// Extra "eğer" clauses ANDed on top of the surface restriction.
    public var extraConditions: [Condition]
    public var actions: [MacroAction]
    /// Scales the generated cooldown; `1` keeps the preset default.
    public var cooldownScale: Double
    public var isEnabled: Bool
    public var priority: Int
    public var isExclusive: Bool
    public var notes: String

    public init(id: UUID = UUID(),
                name: String,
                gesture: GesturePreset,
                sensitivity: Sensitivity = .medium,
                surface: Surface? = nil,
                extraConditions: [Condition] = [],
                actions: [MacroAction],
                cooldownScale: Double = 1,
                isEnabled: Bool = true,
                priority: Int = 0,
                isExclusive: Bool = false,
                notes: String = "") {
        self.id = id
        self.name = name
        self.gesture = gesture
        self.sensitivity = sensitivity
        self.surface = surface
        self.extraConditions = extraConditions
        self.actions = actions
        self.cooldownScale = cooldownScale
        self.isEnabled = isEnabled
        self.priority = priority
        self.isExclusive = isExclusive
        self.notes = notes
    }
}
