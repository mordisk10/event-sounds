import Foundation

/// Ready-made profiles. New installs start on `handsFreeBrowsing`; the others
/// exist so users have working examples to copy and modify.
public enum PresetLibrary {

    /// The profile the app ships with.
    ///
    /// Core binding, and the one the project was built around: tongue down
    /// scrolls. In Reels that means a full-screen jump to the next clip; in the
    /// feed it is a softer partial scroll so text posts stay readable.
    public static func handsFreeBrowsing() -> Profile {
        Profile(
            name: "Eller serbest gezinme",
            notes: "Dil aşağı kaydırır, dil yukarı geri alır, çift dil beğenir.",
            blueprints: [
                RuleBlueprint(
                    name: "Dil aşağı → Reels'te sonraki",
                    gesture: .tongueDown,
                    sensitivity: .medium,
                    surface: .reels,
                    actions: [.runMacro(id: "scroll-next")],
                    priority: 10,
                    notes: "Reels tam ekran olduğu için tam bir ekran kaydırır."),

                RuleBlueprint(
                    name: "Dil aşağı → akışta kaydır",
                    gesture: .tongueDown,
                    sensitivity: .medium,
                    surface: .feed,
                    actions: [.runMacro(id: "nudge-down")],
                    notes: "Akışta okumayı bölmemek için kısmi kaydırma."),

                RuleBlueprint(
                    name: "Dil aşağı → diğer ekranlarda kaydır",
                    gesture: .tongueDown,
                    sensitivity: .medium,
                    extraConditions: [
                        .not(.any([.surface(.reels), .surface(.feed), .surface(.directMessages)]))
                    ],
                    actions: [.scroll(direction: .down, amount: .screens(0.7), animated: true)],
                    priority: -10,
                    notes: "Mesajlarda kapalı: yanlışlıkla sohbet kaydırmayı önler."),

                RuleBlueprint(
                    name: "Dil yukarı → geri kaydır",
                    gesture: .tongueUp,
                    sensitivity: .medium,
                    actions: [.runMacro(id: "scroll-previous")]),

                RuleBlueprint(
                    name: "Dili iki kez çıkar → beğen",
                    gesture: .tongueOutDouble,
                    sensitivity: .medium,
                    extraConditions: [.any([.surface(.reels), .surface(.feed), .surface(.postDetail)])],
                    actions: [.like, .haptic(.success)],
                    priority: 20,
                    isExclusive: true,
                    notes: "Öncelik yüksek ve “yalnızca bu”: tek dil kurallarını bastırır."),

                RuleBlueprint(
                    name: "Kaş kaldır → sesi aç/kapat",
                    gesture: .browRaise,
                    sensitivity: .medium,
                    actions: [.runMacro(id: "toggle-sound")]),

                RuleBlueprint(
                    name: "Dil sağa → gezinme modu",
                    gesture: .tongueRight,
                    sensitivity: .low,
                    actions: [.runMacro(id: "toggle-navigation-mode")],
                    priority: 30,
                    isExclusive: true),

                RuleBlueprint(
                    name: "Gezinme modu: dil aşağı → Reels'e git",
                    gesture: .tongueDown,
                    sensitivity: .low,
                    extraConditions: [.flag(name: "gezinme", equals: true)],
                    actions: [
                        .runMacro(id: "open-reels"),
                        .setFlag(name: "gezinme", value: false)
                    ],
                    priority: 40,
                    isExclusive: true,
                    notes: "Katmanlı kısayol örneği: bayrak açıkken aynı hareket başka iş yapar.")
            ],
            modes: ["varsayilan", "sadece-izleme"],
            defaultMode: "varsayilan",
            flags: ["gezinme": false])
    }

    /// Minimal, deliberately hard to trigger by accident. A good starting point
    /// for users who need reliability over speed.
    public static func minimalAccessibility() -> Profile {
        Profile(
            name: "Sade erişilebilirlik",
            notes: "Yalnızca iki hareket, düşük hassasiyet, uzun bekleme süreleri.",
            blueprints: [
                RuleBlueprint(name: "Dil aşağı → kaydır",
                              gesture: .tongueDown,
                              sensitivity: .low,
                              actions: [.runMacro(id: "scroll-next")],
                              cooldownScale: 1.6),
                RuleBlueprint(name: "Dil yukarı → geri",
                              gesture: .tongueUp,
                              sensitivity: .low,
                              actions: [.runMacro(id: "scroll-previous")],
                              cooldownScale: 1.6)
            ])
    }

    /// Everything wired up, for users who want density.
    public static func powerUser() -> Profile {
        Profile(
            name: "Gelişmiş",
            notes: "Dil, kaş, yanak ve baş hareketlerinin tamamı bağlı.",
            blueprints: [
                RuleBlueprint(name: "Dil aşağı → sonraki",
                              gesture: .tongueDown, sensitivity: .high,
                              actions: [.runMacro(id: "scroll-next")]),
                RuleBlueprint(name: "Dil yukarı → önceki",
                              gesture: .tongueUp, sensitivity: .high,
                              actions: [.runMacro(id: "scroll-previous")]),
                RuleBlueprint(name: "Dil sola → yorumlar",
                              gesture: .tongueLeft, sensitivity: .medium,
                              actions: [.openComments]),
                RuleBlueprint(name: "Dil sağa → kapat",
                              gesture: .tongueRight, sensitivity: .medium,
                              actions: [.closeOverlay]),
                RuleBlueprint(name: "Çift dil → beğen ve geç",
                              gesture: .tongueOutDouble, sensitivity: .medium,
                              actions: [.runMacro(id: "like-and-next")],
                              priority: 20, isExclusive: true),
                RuleBlueprint(name: "Uzun dil → kaydet ve geç",
                              gesture: .tongueOutLong, sensitivity: .medium,
                              actions: [.runMacro(id: "save-and-next")],
                              priority: 15, isExclusive: true),
                RuleBlueprint(name: "Yanak şişir → sesi aç/kapat",
                              gesture: .cheekPuff, sensitivity: .medium,
                              actions: [.runMacro(id: "toggle-sound")]),
                RuleBlueprint(name: "Kaş kaldır → oynat/duraklat",
                              gesture: .browRaise, sensitivity: .medium,
                              actions: [.playPause, .haptic(.selection)]),
                RuleBlueprint(name: "Baş sola → geri",
                              gesture: .headTurnLeft, sensitivity: .low,
                              actions: [.runMacro(id: "go-back")])
            ])
    }

    public static let all: [Profile] = [
        handsFreeBrowsing(), minimalAccessibility(), powerUser()
    ]

    /// Named entries for the preset picker.
    public static var catalogue: [(name: String, notes: String, make: () -> Profile)] {
        [
            ("Eller serbest gezinme", "Önerilen başlangıç", handsFreeBrowsing),
            ("Sade erişilebilirlik", "İki hareket, çok düşük yanlış tetikleme", minimalAccessibility),
            ("Gelişmiş", "Tüm hareketler bağlı", powerUser)
        ]
    }
}
