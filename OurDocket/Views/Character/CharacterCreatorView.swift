import SwiftUI

/// Full-screen character customization. Gates onboarding after the
/// identity step, and reopens from the Profile tab as an editor.
struct CharacterCreatorView: View {
    enum Mode {
        case onboarding
        case edit
    }

    var mode: Mode = .onboarding

    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var appearance = CharacterAppearance.defaults(for: .female)
    @State private var isSaving = false
    @State private var didLoad = false

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                if mode == .edit {
                    HeaderBar(title: "Edit Character", showBack: false) {
                        HeaderIconButton(systemImage: "xmark") { dismiss() }
                    }
                }

                ScrollView {
                    VStack(spacing: 24) {
                        if mode == .onboarding {
                            Text("Create Your Character")
                                .font(.system(.title2, design: .serif, weight: .bold))
                                .foregroundStyle(Theme.navy)
                                .padding(.top, 24)
                        }

                        preview

                        genderPicker

                        optionSection(title: "Hair") {
                            ForEach(CharacterCatalog.hairStyles(for: appearance.gender)) { hair in
                                optionButton(isSelected: appearance.hairId == hair.id) {
                                    appearance.hairId = hair.id
                                } label: {
                                    CharacterView(appearance: variant(hairId: hair.id), crop: .head)
                                        .frame(width: 64, height: 64)
                                        .background(Theme.navy.opacity(0.06))
                                        .clipShape(Circle())
                                }
                            }
                        }

                        optionSection(title: "Skin Tone") {
                            ForEach(CharacterCatalog.skinTones) { tone in
                                optionButton(isSelected: appearance.skinToneId == tone.id) {
                                    appearance.skinToneId = tone.id
                                } label: {
                                    Circle()
                                        .fill(tone.color)
                                        .frame(width: 44, height: 44)
                                }
                            }
                        }

                        optionSection(title: "Outfit") {
                            ForEach(CharacterCatalog.outfits(for: appearance.gender)) { outfit in
                                optionButton(isSelected: appearance.outfitId == outfit.id, cornerRadius: 14) {
                                    appearance.outfitId = outfit.id
                                } label: {
                                    CharacterView(appearance: variant(outfitId: outfit.id))
                                        .frame(width: 60, height: 100)
                                        .padding(6)
                                        .background(Theme.navy.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            }
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
                        .disabled(isSaving)
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .onAppear(perform: load)
        .onChange(of: appearance.gender) { _, gender in
            // The other gender's hair/outfit ids aren't in this pool, so
            // fall back to its first options rather than keep stale ids.
            appearance = .defaults(for: gender)
        }
    }

    private var preview: some View {
        ZStack(alignment: .bottomTrailing) {
            CharacterView(appearance: appearance)
                .frame(height: 280)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.white.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.navy.opacity(0.08)))
                .animation(.snappy, value: appearance)

            Button {
                HapticFeedback.selection()
                withAnimation(.snappy) {
                    appearance = .random(for: appearance.gender)
                }
            } label: {
                Label("Random", systemImage: "shuffle")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Theme.navy, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .padding(.horizontal)
    }

    private var genderPicker: some View {
        Picker("Gender", selection: $appearance.gender) {
            ForEach(CharacterGender.allCases) { gender in
                Text(gender.title).tag(gender)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private func optionSection<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    content()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }

    private func optionButton<Label: View>(isSelected: Bool, cornerRadius: CGFloat = 999, action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View {
        Button {
            HapticFeedback.selection()
            withAnimation(.snappy) { action() }
        } label: {
            label()
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Theme.gold, lineWidth: 3)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func variant(hairId: String? = nil, outfitId: String? = nil) -> CharacterAppearance {
        var copy = appearance
        if let hairId { copy.hairId = hairId }
        if let outfitId { copy.outfitId = outfitId }
        return copy
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let existing = authViewModel.user?.character {
            appearance = existing
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        if await authViewModel.saveCharacter(appearance) {
            HapticFeedback.success()
            if mode == .edit { dismiss() }
        } else {
            HapticFeedback.error()
        }
    }
}

#Preview {
    CharacterCreatorView()
        .environmentObject(AuthViewModel())
}
