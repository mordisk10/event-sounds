import SwiftUI

/// The single source of truth for colour, spacing, radius and shadow.
///
/// The palette is built around two decisions the product owner made: a light,
/// white-iPhone surface and an orange accent. Everything else is derived from
/// those — greys are warm-neutral so they sit next to the orange without
/// clashing, and no second accent hue is introduced.
enum Theme {

    // MARK: - Colour

    enum Palette {
        /// Primary accent. Used for the mic button, active tabs, primary CTAs.
        static let accent = Color(hex: 0xFF6A1A)
        /// Pressed / darker accent, for the push effect and gradients.
        static let accentDeep = Color(hex: 0xE0530B)
        /// Tinted background behind accent content (chips, selected rows).
        static let accentWash = Color(hex: 0xFFF1E8)

        /// App background. Slightly off-white so white cards read as raised.
        static let background = Color(hex: 0xF7F7F9)
        /// Card and sheet surfaces.
        static let surface = Color.white
        /// Recessed areas inside a card (code blocks, inputs).
        static let surfaceSunken = Color(hex: 0xF2F2F5)

        static let textPrimary = Color(hex: 0x101014)
        static let textSecondary = Color(hex: 0x6B6B76)
        /// For hints and disabled text — deliberately light, used sparingly.
        static let textTertiary = Color(hex: 0x9A9AA5)

        static let separator = Color(hex: 0xE6E6EC)

        static let success = Color(hex: 0x1EA95C)
        static let warning = Color(hex: 0xE0A100)
        static let danger = Color(hex: 0xE0322D)

        /// Particle colours for the celebration burst. Kept inside the accent
        /// family plus one warm highlight so it reads as "Instakai", not as
        /// generic party confetti.
        static let celebration: [Color] = [
            Color(hex: 0xFF6A1A), Color(hex: 0xFF9A4D),
            Color(hex: 0xFFC46B), Color(hex: 0xE0530B)
        ]
    }

    // MARK: - Metrics

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 14
        static let l: CGFloat = 20
        static let xl: CGFloat = 28
        static let xxl: CGFloat = 40
        /// Standard screen side inset.
        static let screen: CGFloat = 20
        /// Bottom padding every scrolling screen needs so its last row clears
        /// the floating tab bar. The bar overlays the content rather than
        /// insetting it, so nothing reserves this space automatically.
        static let tabBarClearance: CGFloat = 96
    }

    enum Radius {
        static let control: CGFloat = 14
        static let card: CGFloat = 22
        static let sheet: CGFloat = 28
        /// Panorama cards are rounder so the 3D rotation reads as a curved wall.
        static let panorama: CGFloat = 26
    }

    // MARK: - Motion

    enum Motion {
        /// The default spring. Every press, expand and slide uses this so the
        /// whole app moves with one personality.
        static let standard = Animation.spring(response: 0.34, dampingFraction: 0.74)
        /// Snappier, for the press-down half of the push effect.
        static let press = Animation.spring(response: 0.2, dampingFraction: 0.6)
        /// Slower, for the island expansion and celebration.
        static let showcase = Animation.spring(response: 0.5, dampingFraction: 0.68)
    }
}

// MARK: - Typography

extension Font {
    /// Screen titles.
    static let iaTitle = Font.system(size: 30, weight: .bold, design: .rounded)
    /// Section headers inside a screen.
    static let iaHeadline = Font.system(size: 19, weight: .semibold, design: .rounded)
    /// Card titles.
    static let iaCardTitle = Font.system(size: 16, weight: .semibold, design: .rounded)
    /// Body copy.
    static let iaBody = Font.system(size: 15, weight: .regular)
    /// Supporting copy under a title.
    static let iaCaption = Font.system(size: 13, weight: .regular)
    /// Chips, tags, tab labels.
    static let iaMicro = Font.system(size: 11, weight: .semibold, design: .rounded)
    /// Numbers that must not jitter while animating.
    static let iaNumeric = Font.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit()
}

// MARK: - Helpers

extension Color {
    /// Builds a colour from a hex literal, e.g. `Color(hex: 0xFF6A1A)`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
