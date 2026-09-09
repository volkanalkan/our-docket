import SwiftUI

struct PairingView: View {
    private enum Mode {
        case choose
        case showCode
        case enterCode
    }

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var mode: Mode = .choose
    @State private var generatedCode: String?
    @State private var enteredCode = ""
    @State private var isBusy = false

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Pairing")
                    .font(.system(.title, design: .serif, weight: .bold))
                    .foregroundStyle(Theme.navy)

                Group {
                    switch mode {
                    case .choose:
                        chooseView
                    case .showCode:
                        showCodeView
                    case .enterCode:
                        enterCodeView
                    }
                }
                .animation(.default, value: mode)

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button("Sign Out", role: .destructive) {
                    HapticFeedback.tap()
                    authViewModel.signOut()
                }
                .buttonStyle(.plain)
                .font(.footnote)
            }
            .padding()
        }
    }

    private var chooseView: some View {
        VStack(spacing: 16) {
            Button {
                HapticFeedback.tap()
                Task {
                    isBusy = true
                    generatedCode = await authViewModel.generateInviteCode()
                    isBusy = false
                    if generatedCode != nil {
                        HapticFeedback.success()
                        withAnimation { mode = .showCode }
                    } else {
                        HapticFeedback.error()
                    }
                }
            } label: {
                Label("Create Invite Code", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.ourDocketPrimary)

            Button {
                HapticFeedback.tap()
                authViewModel.errorMessage = nil
                withAnimation { mode = .enterCode }
            } label: {
                Label("Enter Invite Code", systemImage: "number")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.ourDocketSecondary)
        }
        .disabled(isBusy)
    }

    private var showCodeView: some View {
        VStack(spacing: 12) {
            Text("Send this code to your partner:")
                .foregroundStyle(.secondary)

            Text(generatedCode ?? "")
                .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.navy)
                .textSelection(.enabled)

            Text("The code is valid for 24 hours.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Back") { HapticFeedback.tap(); withAnimation { mode = .choose } }
                .buttonStyle(.plain)
                .font(.footnote)
                .padding(.top, 8)
        }
    }

    private var enterCodeView: some View {
        VStack(spacing: 12) {
            TextField("6-digit code", text: $enteredCode)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .font(.title2)
                .frame(maxWidth: 200)
                .onChange(of: enteredCode) { _, newValue in
                    enteredCode = String(newValue.filter(\.isNumber).prefix(6))
                }

            Button {
                HapticFeedback.tap()
                Task {
                    isBusy = true
                    await authViewModel.redeemInviteCode(enteredCode)
                    isBusy = false
                    if authViewModel.errorMessage != nil {
                        HapticFeedback.error()
                    } else {
                        HapticFeedback.success()
                    }
                }
            } label: {
                Text("Pair")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.ourDocketPrimary)
            .disabled(enteredCode.count != 6 || isBusy)

            Button("Back") { HapticFeedback.tap(); withAnimation { mode = .choose } }
                .buttonStyle(.plain)
                .font(.footnote)
        }
    }
}

#Preview {
    PairingView()
        .environmentObject(AuthViewModel())
}
