import SwiftUI

/// Name + unique @username. Shown as an onboarding gate the first time
/// (and for existing accounts that predate usernames), and again from the
/// Profile tab as an editor.
struct IdentitySetupView: View {
    enum Mode {
        case onboarding
        case edit
    }

    var mode: Mode = .onboarding

    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var username = ""
    @State private var isSaving = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && IdentityService.isValidUsername(username)
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                if mode == .edit {
                    HeaderBar(title: "Edit Profile", showBack: false) {
                        HeaderIconButton(systemImage: "xmark") { dismiss() }
                    }
                }

                ScrollView {
                    VStack(spacing: 24) {
                        if mode == .onboarding {
                            VStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .font(.system(size: 48))
                                    .foregroundStyle(Theme.gold)
                                Text("Introduce Yourself")
                                    .font(.system(.title2, design: .serif, weight: .bold))
                                    .foregroundStyle(Theme.navy)
                                Text("Your partner will see you by this name.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 40)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            TextField("e.g. Volkan", text: $name)
                                .padding(12)
                                .background(.white.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text(verbatim: "@")
                                    .foregroundStyle(.secondary)
                                TextField("username", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.asciiCapable)
                                    .onChange(of: username) { _, newValue in
                                        let sanitized = IdentityService.sanitize(newValue)
                                        if sanitized != newValue { username = sanitized }
                                    }
                            }
                            .padding(12)
                            .background(.white.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text("3–20 characters: letters, numbers, dots and underscores.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button(mode == .onboarding ? "Continue" : "Save") {
                            HapticFeedback.tap()
                            Task { await save() }
                        }
                        .buttonStyle(.ourDocketPrimary)
                        .disabled(!isValid || isSaving)

                        if mode == .onboarding {
                            Button("Sign Out", role: .destructive) {
                                HapticFeedback.tap()
                                authViewModel.signOut()
                            }
                            .buttonStyle(.plain)
                            .font(.footnote)
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onAppear(perform: prefill)
    }

    private func prefill() {
        guard name.isEmpty, username.isEmpty, let user = authViewModel.user else { return }
        name = user.displayName
        username = user.username ?? ""
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        if await authViewModel.saveIdentity(name: name, username: username) {
            HapticFeedback.success()
            if mode == .edit { dismiss() }
        } else {
            HapticFeedback.error()
        }
    }
}

#Preview {
    IdentitySetupView()
        .environmentObject(AuthViewModel())
}
