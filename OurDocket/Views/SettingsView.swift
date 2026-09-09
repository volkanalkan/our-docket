import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var languageStore: LanguageStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar(title: "Settings", showBack: false) {
                    HeaderIconButton(systemImage: "xmark") { dismiss() }
                }

                VStack(spacing: 20) {
                    languagePicker

                    Button("Sign Out") {
                        HapticFeedback.tap()
                        authViewModel.signOut()
                        dismiss()
                    }
                    .buttonStyle(.ourDocketSecondary)

                    VStack(spacing: 8) {
                        Button("Delete Account") {
                            showingDeleteConfirmation = true
                        }
                        .buttonStyle(.ourDocketDestructive)
                        .disabled(isDeleting)

                        Text("Deleting your account permanently removes your sign-in credentials. The memories, notes and milestones you shared stay in your partner's account.")
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
            "Are you sure you want to delete your account?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task {
                    isDeleting = true
                    await authViewModel.deleteAccount()
                    isDeleting = false
                    if authViewModel.errorMessage == nil {
                        HapticFeedback.success()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Language")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(AppLanguage.allCases) { language in
                    let isSelected = languageStore.effective == language
                    Button {
                        HapticFeedback.selection()
                        Task { await authViewModel.setPreferredLanguage(language) }
                    } label: {
                        Text(verbatim: language.nativeName)
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Theme.navy : Theme.navy.opacity(0.08))
                            .foregroundStyle(isSelected ? .white : Theme.navy)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
        .environmentObject(LanguageStore.shared)
}
