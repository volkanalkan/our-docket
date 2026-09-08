import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Çıkış Yap", role: .destructive) {
                        HapticFeedback.tap()
                        authViewModel.signOut()
                        dismiss()
                    }
                }

                Section {
                    Button("Hesabı Sil", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                    .disabled(isDeleting)
                } footer: {
                    Text("Hesabını sildiğinde giriş bilgilerin kalıcı olarak kaldırılır. Paylaştığın anılar, notlar ve kararlar partnerinin hesabında kalmaya devam eder.")
                }

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
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
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
