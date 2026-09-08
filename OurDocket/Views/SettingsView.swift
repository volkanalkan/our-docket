import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar(title: "Ayarlar", showBack: false) {
                    HeaderIconButton(systemImage: "xmark") { dismiss() }
                }

                VStack(spacing: 20) {
                    Button("Çıkış Yap") {
                        HapticFeedback.tap()
                        authViewModel.signOut()
                        dismiss()
                    }
                    .buttonStyle(.ourDocketSecondary)

                    VStack(spacing: 8) {
                        Button("Hesabı Sil") {
                            showingDeleteConfirmation = true
                        }
                        .buttonStyle(.ourDocketDestructive)
                        .disabled(isDeleting)

                        Text("Hesabını sildiğinde giriş bilgilerin kalıcı olarak kaldırılır. Paylaştığın anılar, notlar ve kararlar partnerinin hesabında kalmaya devam eder.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }

                    Spacer()
                }
                .padding()
            }
        }
        .confirmationDialog(
            "Hesabını silmek istediğine emin misin?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Hesabı Sil", role: .destructive) {
                Task {
                    isDeleting = true
                    await authViewModel.deleteAccount()
                    isDeleting = false
                    if authViewModel.errorMessage == nil {
                        HapticFeedback.success()
                    }
                }
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Bu işlem geri alınamaz.")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
