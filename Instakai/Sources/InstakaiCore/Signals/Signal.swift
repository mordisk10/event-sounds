import Foundation

/// A single normalised measurement coming out of the face tracker.
///
/// Every signal is normalised to a well defined range so that rules written
/// against them stay valid across devices and calibration profiles:
///
/// - Blend-shape style signals (`tongueOut`, `jawOpen`, `eyeBlinkLeft`, …) are
///   in `0...1`, where `0` is neutral and `1` is fully expressed.
/// - Directional signals (`tongueDown`, `headYaw`, `gazeX`, …) are in `0...1`
///   as *magnitudes in that direction*; the opposite direction has its own
///   signal. This keeps rule authoring simple ("tongueDown > 0.55") instead of
///   forcing users to reason about signed axes.
/// - `faceVisible` is a boolean encoded as `0` or `1`.
public enum Signal: String, Codable, CaseIterable, Sendable {

    // MARK: Tongue

    /// How far the tongue is protruding, regardless of direction.
    case tongueOut
    /// Tongue protruding and pointing up, relative to the face (roll corrected).
    case tongueUp
    /// Tongue protruding and pointing down — the primary "scroll" gesture.
    case tongueDown
    /// Tongue protruding and pointing towards the user's own left.
    case tongueLeft
    /// Tongue protruding and pointing towards the user's own right.
    case tongueRight

    // MARK: Mouth / jaw

    case jawOpen
    case mouthPucker
    case mouthFunnel
    case mouthSmileLeft
    case mouthSmileRight
    case cheekPuff

    // MARK: Eyes / brows

    case eyeBlinkLeft
    case eyeBlinkRight
    case eyeSquintLeft
    case eyeSquintRight
    case browInnerUp
    case browDownLeft
    case browDownRight

    // MARK: Head pose (magnitudes per direction)

    case headYawLeft
    case headYawRight
    case headPitchUp
    case headPitchDown
    case headRollLeft
    case headRollRight

    // MARK: Gaze

    case gazeLeft
    case gazeRight
    case gazeUp
    case gazeDown

    // MARK: Meta

    /// `1` when a face is currently tracked, `0` otherwise.
    case faceVisible
    /// Confidence of the tongue direction estimate, `0...1`.
    case tongueConfidence

    /// Human readable label used by the rule editor.
    public var displayName: String {
        switch self {
        case .tongueOut: return "Dil dışarı"
        case .tongueUp: return "Dil yukarı"
        case .tongueDown: return "Dil aşağı"
        case .tongueLeft: return "Dil sola"
        case .tongueRight: return "Dil sağa"
        case .jawOpen: return "Ağız açık"
        case .mouthPucker: return "Dudak büzme"
        case .mouthFunnel: return "Dudak hunisi"
        case .mouthSmileLeft: return "Gülümseme (sol)"
        case .mouthSmileRight: return "Gülümseme (sağ)"
        case .cheekPuff: return "Yanak şişirme"
        case .eyeBlinkLeft: return "Göz kırpma (sol)"
        case .eyeBlinkRight: return "Göz kırpma (sağ)"
        case .eyeSquintLeft: return "Göz kısma (sol)"
        case .eyeSquintRight: return "Göz kısma (sağ)"
        case .browInnerUp: return "Kaş kaldırma"
        case .browDownLeft: return "Kaş indirme (sol)"
        case .browDownRight: return "Kaş indirme (sağ)"
        case .headYawLeft: return "Baş sola dönük"
        case .headYawRight: return "Baş sağa dönük"
        case .headPitchUp: return "Baş yukarı"
        case .headPitchDown: return "Baş aşağı"
        case .headRollLeft: return "Baş sola yatık"
        case .headRollRight: return "Baş sağa yatık"
        case .gazeLeft: return "Bakış sola"
        case .gazeRight: return "Bakış sağa"
        case .gazeUp: return "Bakış yukarı"
        case .gazeDown: return "Bakış aşağı"
        case .faceVisible: return "Yüz görünür"
        case .tongueConfidence: return "Dil güveni"
        }
    }

    /// Signals grouped for the picker UI.
    public static let groups: [(title: String, signals: [Signal])] = [
        ("Dil", [.tongueOut, .tongueUp, .tongueDown, .tongueLeft, .tongueRight, .tongueConfidence]),
        ("Ağız", [.jawOpen, .mouthPucker, .mouthFunnel, .mouthSmileLeft, .mouthSmileRight, .cheekPuff]),
        ("Göz & kaş", [.eyeBlinkLeft, .eyeBlinkRight, .eyeSquintLeft, .eyeSquintRight,
                       .browInnerUp, .browDownLeft, .browDownRight]),
        ("Baş", [.headYawLeft, .headYawRight, .headPitchUp, .headPitchDown, .headRollLeft, .headRollRight]),
        ("Bakış", [.gazeLeft, .gazeRight, .gazeUp, .gazeDown]),
        ("Durum", [.faceVisible])
    ]

    /// Signals that only make sense while the tongue is actually out. The
    /// engine gates these so a noisy direction estimate on a closed mouth can
    /// never fire a rule.
    public var requiresTongueOut: Bool {
        switch self {
        case .tongueUp, .tongueDown, .tongueLeft, .tongueRight: return true
        default: return false
        }
    }
}
