import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var languageStore: LanguageStore

    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar(title: "Profile", showBack: false) {
                    HeaderIconButton(systemImage: "pencil") { showingEditor = true }
                }

                ScrollView {
                    VStack(spacing: 28) {
                        identityCard

                        languagePicker

                        if let startDate = authViewModel.couple?.relationshipStartDate?.dateValue() {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Relationship start")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                Text(startDate.formatted(appStyle: .long))
                                    .font(.system(.body, design: .serif, weight: .semibold))
                                    .foregroundStyle(Theme.navy)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        VStack(spacing: 20) {
                            Button("Sign Out") {
                                HapticFeedback.tap()
                                authViewModel.signOut()
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
                        }
                        .padding(.top, 12)

                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingEditor) {
            IdentitySetupView(mode: .edit)
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

    /// Initials stand in until the character (8c) replaces them.
    private var identityCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.navy)
                    .frame(width: 88, height: 88)
                Text(initials)
                    .font(.system(.title, design: .serif, weight: .bold))
                    .foregroundStyle(Theme.cream)
            }

            Text(authViewModel.user?.displayName ?? "")
                .font(.system(.title2, design: .serif, weight: .bold))
                .foregroundStyle(Theme.navy)

            if let username = authViewModel.user?.username {
                Text(verbatim: "@\(username)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var initials: String {
        let words = (authViewModel.user?.displayName ?? "").split(separator: " ").prefix(2)
        return words.compactMap { $0.first.map(String.init) }.joined().uppercased()
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
    ProfileView()
        .environmentObject(AuthViewModel())
        .environmentObject(LanguageStore.shared)
}
