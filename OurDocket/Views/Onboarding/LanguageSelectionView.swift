import SwiftUI

struct LanguageSelectionView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.gold)

                    // No language is chosen yet, so both prompts are shown
                    // verbatim rather than localized.
                    Text(verbatim: "Choose your language")
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .foregroundStyle(Theme.navy)
                    Text(verbatim: "Dilini seç")
                        .font(.system(.title3, design: .serif, weight: .semibold))
                        .foregroundStyle(Theme.navy.opacity(0.65))
                }

                VStack(spacing: 14) {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            HapticFeedback.tap()
                            Task { await authViewModel.setPreferredLanguage(language) }
                        } label: {
                            Text(verbatim: language.nativeName)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.ourDocketPrimary)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
                Spacer()
            }
        }
    }
}

#Preview {
    LanguageSelectionView()
        .environmentObject(AuthViewModel())
}
