import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        Group {
            switch authViewModel.state {
            case .loading:
                ProgressView()
            case .signedOut:
                SignInView()
            case .needsPairing:
                PairingView()
            case .needsStartDate(let coupleId):
                StartDateView(coupleId: coupleId)
            case .ready(let coupleId):
                HomeView(coupleId: coupleId)
            }
        }
        .animation(.default, value: authViewModel.state)
    }
}

#Preview {
    RootView()
        .environmentObject(AuthViewModel())
}
