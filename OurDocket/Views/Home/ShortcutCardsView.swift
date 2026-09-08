import SwiftUI

struct ShortcutCard: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let systemImage: String
}

struct ShortcutCardsView: View {
    let coupleId: String

    private let cards: [ShortcutCard] = [
        ShortcutCard(title: "Arşiv", systemImage: "folder.fill"),
        ShortcutCard(title: "Notlar", systemImage: "checklist"),
        ShortcutCard(title: "Dönüm Noktaları", systemImage: "seal.fill")
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(cards) { card in
                NavigationLink(value: card) {
                    VStack(spacing: 8) {
                        Image(systemName: card.systemImage)
                            .font(.title2)
                        Text(card.title)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Theme.navy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.navy.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .simultaneousGesture(TapGesture().onEnded { HapticFeedback.tap() })
            }
        }
        .navigationDestination(for: ShortcutCard.self) { card in
            switch card.title {
            case "Arşiv":
                CaseFilesListView(coupleId: coupleId)
            case "Notlar":
                NotesView(coupleId: coupleId)
            case "Dönüm Noktaları":
                DecisionsListView(coupleId: coupleId)
            default:
                EmptyView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ShortcutCardsView(coupleId: "preview").padding()
    }
}
