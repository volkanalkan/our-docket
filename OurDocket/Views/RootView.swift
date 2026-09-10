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
            case _ where authViewModel.user?.username == nil:
                IdentitySetupView()
            case _ where authViewModel.user?.character == nil:
                CharacterCreatorView()
            case .needsPairing:
                PairingView()
            case .needsStartDate(let coupleId):
                StartDateView(coupleId: coupleId)
            case .ready(let coupleId):
                MainTabView(coupleId: coupleId)
            }
        }
        .animation(.default, value: authViewModel.state)
        .animation(.default, value: languageStore.selection)
        .animation(.default, value: authViewModel.user?.username)
        .animation(.default, value: authViewModel.user?.character)
    }
}

#Preview {
    RootView()
        .environmentObject(AuthViewModel())
        .environmentObject(LanguageStore.shared)
}
