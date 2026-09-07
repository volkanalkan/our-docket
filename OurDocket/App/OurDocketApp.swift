import SwiftUI
import FirebaseCore

@main
struct OurDocketApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
