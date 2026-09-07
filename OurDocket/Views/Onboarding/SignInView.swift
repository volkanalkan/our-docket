import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var currentNonce: String = ""

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "scale.3d")
                        .font(.system(size: 56))
                        .foregroundStyle(Theme.gold)

                    Text("Our Docket")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(Theme.navy)

                    Text("İlişkinizin resmi dosyası")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                SignInWithAppleButton(.signIn) { request in
                    let nonce = AuthService.randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName]
                    request.nonce = AuthService.sha256(nonce)
                } onCompletion: { result in
                    Task {
                        await authViewModel.handleSignInWithApple(result: result, rawNonce: currentNonce)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .padding(.horizontal, 32)

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthViewModel())
}
