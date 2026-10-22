import Foundation

/// In-app UI language, independent of the device language. English is the default.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case portuguese = "pt"

    static let storageKey = "app.language"

    var id: String { rawValue }

    /// Shown in its own language so it's recognisable from either UI.
    var displayName: String {
        switch self {
        case .english: return "English"
        case .portuguese: return "Português"
        }
    }

    static var current: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .english
    }
}

/// Pick the string for the current app language. Each view that shows text
/// declares `@AppStorage(AppLanguage.storageKey)` so it re-renders on change.
func L(_ en: String, _ pt: String) -> String {
    AppLanguage.current == .portuguese ? pt : en
}
