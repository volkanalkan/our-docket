import SwiftUI

struct ShortcutCardsView: View {
    @Binding var selectedTab: AppTab

    private let shortcuts: [AppTab] = [.archive, .notes, .milestones]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(shortcuts) { tab in
                Button {
                    HapticFeedback.tap()
                    selectedTab = tab
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: tab.systemImage)
                            .font(.title2)
                        Text(tab.title)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Theme.navy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.navy.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    ShortcutCardsView(selectedTab: .constant(.home)).padding()
}
