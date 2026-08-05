import Foundation

/// The macros every profile can reference without defining them first.
public enum MacroLibrary {

    public static let scrollNext = Macro(
        id: "scroll-next",
        name: "Sonraki içerik",
        notes: "Akışta bir ekran aşağı kaydırır. Reels'te bir sonraki klibe geçer.",
        actions: [
            .scroll(direction: .down, amount: .screens(1.0), animated: true),
            .haptic(.light)
        ],
        isBuiltIn: true)

    public static let scrollPrevious = Macro(
        id: "scroll-previous",
        name: "Önceki içerik",
        actions: [
            .scroll(direction: .up, amount: .screens(1.0), animated: true),
            .haptic(.light)
        ],
        isBuiltIn: true)

    public static let nudgeDown = Macro(
        id: "nudge-down",
        name: "Biraz aşağı",
        notes: "Akışta yumuşak, kısmi kaydırma — okurken kullanışlı.",
        actions: [.scroll(direction: .down, amount: .screens(0.45), animated: true)],
        isBuiltIn: true)

    public static let likeAndNext = Macro(
        id: "like-and-next",
        name: "Beğen ve geç",
        actions: [
            .like,
            .haptic(.success),
            .delay(seconds: 0.35),
            .scroll(direction: .down, amount: .screens(1.0), animated: true)
        ],
        isBuiltIn: true)

    public static let saveAndNext = Macro(
        id: "save-and-next",
        name: "Kaydet ve geç",
        actions: [
            .savePost,
            .haptic(.medium),
            .delay(seconds: 0.35),
            .runMacro(id: "scroll-next")
        ],
        isBuiltIn: true)

    public static let openReels = Macro(
        id: "open-reels",
        name: "Reels'i aç",
        actions: [.navigate(.reels), .haptic(.selection)],
        isBuiltIn: true)

    public static let goBack = Macro(
        id: "go-back",
        name: "Geri dön",
        actions: [.closeOverlay, .delay(seconds: 0.2), .navigate(.back)],
        isBuiltIn: true)

    public static let toggleSound = Macro(
        id: "toggle-sound",
        name: "Sesi aç/kapat",
        actions: [.toggleMute, .haptic(.selection)],
        isBuiltIn: true)

    /// Flips the `gezinme` flag. Rules gated on `.flag("gezinme", equals: true)`
    /// only respond while navigation mode is on — this is how a user builds a
    /// "gesture layer" without any new engine concepts.
    public static let toggleNavigationMode = Macro(
        id: "toggle-navigation-mode",
        name: "Gezinme modunu aç/kapat",
        notes: "Bayrağı çevirir; gezinme kuralları yalnızca bayrak açıkken çalışır.",
        actions: [
            .toggleFlag(name: "gezinme"),
            .haptic(.warning)
        ],
        isBuiltIn: true)

    public static let builtIns: [Macro] = [
        scrollNext, scrollPrevious, nudgeDown, likeAndNext, saveAndNext,
        openReels, goBack, toggleSound, toggleNavigationMode
    ]
}
