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
                Text("Eşleşme")
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

                Button("Çıkış Yap", role: .destructive) {
                    authViewModel.signOut()
                }
                .font(.footnote)
            }
            .padding()
        }
    }

    private var chooseView: some View {
        VStack(spacing: 16) {
            Button {
                Task {
                    isBusy = true
                    generatedCode = await authViewModel.generateInviteCode()
                    isBusy = false
                    if generatedCode != nil { mode = .showCode }
                }
            } label: {
                Label("Davet Kodu Oluştur", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.navy)

            Button {
                authViewModel.errorMessage = nil
                mode = .enterCode
            } label: {
                Label("Davet Kodu Gir", systemImage: "number")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Theme.navy)
        }
        .disabled(isBusy)
    }

    private var showCodeView: some View {
        VStack(spacing: 12) {
            Text("Partnerine bu kodu gönder:")
                .foregroundStyle(.secondary)

            Text(generatedCode ?? "")
                .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.navy)
                .textSelection(.enabled)

            Text("Kod 24 saat geçerlidir.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Geri") { mode = .choose }
                .font(.footnote)
                .padding(.top, 8)
        }
    }

    private var enterCodeView: some View {
        VStack(spacing: 12) {
            TextField("6 haneli kod", text: $enteredCode)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .font(.title2)
                .frame(maxWidth: 200)
                .onChange(of: enteredCode) { _, newValue in
                    enteredCode = String(newValue.filter(\.isNumber).prefix(6))
                }

            Button {
                Task {
                    isBusy = true
                    await authViewModel.redeemInviteCode(enteredCode)
                    isBusy = false
                }
            } label: {
                Text("Eşleş")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.navy)
            .disabled(enteredCode.count != 6 || isBusy)

            Button("Geri") { mode = .choose }
                .font(.footnote)
        }
    }
}

#Preview {
    PairingView()
        .environmentObject(AuthViewModel())
}
