import SwiftUI
import FirebaseCore

@main
struct OurDocketApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                // The brand palette (navy/gold/cream) is fixed regardless of
                // the system appearance — this isn't a themeable app, so we
                // opt entirely out of the system light/dark mechanism rather
                // than half-adapting to it.
                .preferredColorScheme(.light)
        }
    }
}
