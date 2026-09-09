import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case turkish = "tr"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    /// Each language's own name for itself — deliberately never translated,
    /// so the picker reads naturally to someone who hasn't chosen yet.
    var nativeName: String {
        switch self {
        case .english: "English"
        case .turkish: "Türkçe"
        }
    }

    /// The compiled .lproj for this language inside the running bundle
    /// (app or widget extension — each carries its own catalog).
    var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }

    static var systemDefault: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("tr") == true ? .turkish : .english
    }

    /// The user's explicit in-app choice if they've made one, else the
    /// system language. Safe from any thread and from the widget process.
    static var current: AppLanguage { LanguageStorage.load() ?? systemDefault }

    /// For strings built outside SwiftUI (notifications, error messages,
    /// persisted defaults). SwiftUI `Text` doesn't need this — it follows
    /// the `\.locale` environment the app root sets from the same choice.
    static func localized(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: current.bundle)
    }
}

/// The app's language choice must be independent of the phone's Settings
/// language, so it's stored explicitly (in the App Group, so the widget
/// sees it too) and mirrored to Firestore by the app for cross-device use.
@MainActor
final class LanguageStore: ObservableObject {
    static let shared = LanguageStore()

    /// nil until the user has explicitly chosen — that's what gates the
    /// language step of onboarding.
    @Published private(set) var selection: AppLanguage?

    var effective: AppLanguage { selection ?? .systemDefault }

    private init() {
        selection = LanguageStorage.load()
    }

    func select(_ language: AppLanguage) {
        guard language != selection else { return }
        selection = language
        LanguageStorage.save(language)
    }
}

private enum LanguageStorage {
    private static let key = "preferredLanguage"

    static func load() -> AppLanguage? {
        UserDefaults(suiteName: SharedRelationshipStore.appGroupId)?
            .string(forKey: key)
            .flatMap(AppLanguage.init(rawValue:))
    }

    static func save(_ language: AppLanguage) {
        UserDefaults(suiteName: SharedRelationshipStore.appGroupId)?.set(language.rawValue, forKey: key)
    }
}

extension Date {
    /// Date-only formatting in the app's chosen language rather than the
    /// device locale (`formatted(date:time:)` would otherwise ignore the
    /// in-app choice).
    func formatted(appStyle style: Date.FormatStyle.DateStyle) -> String {
        formatted(Date.FormatStyle(date: style, time: .omitted, locale: AppLanguage.current.locale))
    }
}
