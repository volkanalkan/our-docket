import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var currentNonce: String = ""

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 24) {
                #if DEBUG
                Button("Debug: Anonymous Sign-In") {
                    Task { await authViewModel.signInAnonymouslyForDebug() }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 20)
                #endif

                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "scale.3d")
                        .font(.system(size: 56))
                        .foregroundStyle(Theme.gold)

                    Text("Our Docket")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(Theme.navy)

                    Text("The official record of your relationship")
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
                        if authViewModel.errorMessage != nil {
                            HapticFeedback.error()
                        }
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
                        .transition(.opacity)
                }
            }
            .animation(.default, value: authViewModel.errorMessage)
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthViewModel())
}
