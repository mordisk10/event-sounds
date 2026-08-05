import SwiftUI

/// The app-wide "push" response: everything tappable dips under the finger and
/// springs back on release, with a haptic tick at the moment of contact.
///
/// One style, applied everywhere, is what makes the interaction feel like a
/// single product rather than a set of screens. Intensity is tuned per size —
/// a small chip that scaled as much as a full-width button would look broken.
struct PushButtonStyle: ButtonStyle {

    enum Intensity {
        /// Chips, icon buttons, table rows.
        case subtle
        /// Standard buttons and cards.
        case standard
        /// The microphone button — the one control that should feel physical.
        case pronounced

        var scale: CGFloat {
            switch self {
            case .subtle: return 0.97
            case .standard: return 0.955
            case .pronounced: return 0.92
            }
        }

        var brightness: Double {
            switch self {
            case .subtle: return -0.02
            case .standard: return -0.04
            case .pronounced: return -0.06
            }
        }

        var haptic: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .subtle: return .light
            case .standard: return .medium
            case .pronounced: return .heavy
            }
        }
    }

    var intensity: Intensity = .standard
    /// Set false inside lists where the row already provides its own feedback.
    var hapticsEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? intensity.scale : 1)
            .brightness(configuration.isPressed ? intensity.brightness : 0)
            .animation(configuration.isPressed ? Theme.Motion.press : Theme.Motion.standard,
                       value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed, hapticsEnabled, Haptics.isEnabled else { return }
                Haptics.impact(intensity.haptic)
            }
    }
}

extension ButtonStyle where Self == PushButtonStyle {
    static var push: PushButtonStyle { PushButtonStyle() }
    static var pushSubtle: PushButtonStyle { PushButtonStyle(intensity: .subtle) }
    static var pushPronounced: PushButtonStyle { PushButtonStyle(intensity: .pronounced) }
}

/// Applies the same dip to a non-button view that handles its own gesture —
/// the microphone, mainly, which cannot be a plain `Button` because push-to-talk
/// needs the press and release separately.
struct PushEffect: ViewModifier {
    let isPressed: Bool
    var intensity: PushButtonStyle.Intensity = .standard

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? intensity.scale : 1)
            .brightness(isPressed ? intensity.brightness : 0)
            .animation(isPressed ? Theme.Motion.press : Theme.Motion.standard, value: isPressed)
    }
}

extension View {
    func pushEffect(isPressed: Bool,
                    intensity: PushButtonStyle.Intensity = .standard) -> some View {
        modifier(PushEffect(isPressed: isPressed, intensity: intensity))
    }
}

/// Central haptics, so the Settings toggle silences every call site at once.
enum Haptics {

    /// Mirrors the Settings switch. Read by `PushButtonStyle` on every press.
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "app.haptics") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "app.haptics") }
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
