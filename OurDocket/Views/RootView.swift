import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var languageStore: LanguageStore

    var body: some View {
        Group {
            switch authViewModel.state {
            case .loading:
                ProgressView()
            case .signedOut:
                SignInView()
            case _ where languageStore.selection == nil:
                LanguageSelectionView()
            case .needsPairing:
                PairingView()
            case .needsStartDate(let coupleId):
                StartDateView(coupleId: coupleId)
            case .ready(let coupleId):
                HomeView(coupleId: coupleId)
            }
        }
        .animation(.default, value: authViewModel.state)
        .animation(.default, value: languageStore.selection)
    }
}

#Preview {
    RootView()
        .environmentObject(AuthViewModel())
        .environmentObject(LanguageStore.shared)
}
