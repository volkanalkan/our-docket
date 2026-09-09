import SwiftUI
import FirebaseCore

@main
struct OurDocketApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @ObservedObject private var languageStore = LanguageStore.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .environmentObject(languageStore)
                // Every SwiftUI `Text` resolves its localization from this
                // locale, so the in-app language choice applies everywhere
                // regardless of the phone's Settings language.
                .environment(\.locale, languageStore.effective.locale)
                // The brand palette (navy/gold/cream) is fixed regardless of
                // the system appearance — this isn't a themeable app, so we
                // opt entirely out of the system light/dark mechanism rather
                // than half-adapting to it.
                .preferredColorScheme(.light)
        }
    }
}
