import SwiftUI

/// Holds the selected language and hands out translated strings.
///
/// The picker in Settings is authoritative, not the system locale — the app is
/// explicitly two-language and the user chooses. On first launch we seed from
/// the device locale so a Turkish phone opens in Turkish.
final class LanguageManager: ObservableObject {

    @AppStorage("app.language") private var storedLanguage: String = ""

    @Published var language: AppLanguage {
        didSet { storedLanguage = language.rawValue }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: "app.language") ?? ""
        if let known = AppLanguage(rawValue: stored) {
            language = known
        } else {
            let preferred = Locale.preferredLanguages.first ?? "en"
            language = preferred.hasPrefix("tr") ? .turkish : .english
        }
    }

    /// Translated string for a key. Short name because it appears everywhere:
    /// `Text(lang.t(.homeGreeting))`.
    func t(_ key: S) -> String {
        key.value(for: language)
    }

    /// Convenience for interpolating a count, e.g. "12 runs".
    func t(_ key: S, count: Int) -> String {
        "\(count) \(key.value(for: language))"
    }
}

/// Lets any view read the manager without threading it through initialisers.
private struct LanguageManagerKey: EnvironmentKey {
    static let defaultValue = LanguageManager()
}

extension EnvironmentValues {
    var lang: LanguageManager {
        get { self[LanguageManagerKey.self] }
        set { self[LanguageManagerKey.self] = newValue }
    }
}
