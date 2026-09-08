import SwiftUI

struct ShortcutCard: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let systemImage: String
}

struct ShortcutCardsView: View {
    let coupleId: String

    private let cards: [ShortcutCard] = [
        ShortcutCard(title: "Anı Dosyaları", systemImage: "folder.fill"),
        ShortcutCard(title: "Notlar", systemImage: "checklist"),
        ShortcutCard(title: "Kararlar", systemImage: "seal.fill")
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
            }
        }
        .navigationDestination(for: ShortcutCard.self) { card in
            switch card.title {
            case "Anı Dosyaları":
                CaseFilesListView(coupleId: coupleId)
            case "Notlar":
                NotesView(coupleId: coupleId)
            case "Kararlar":
                DecisionsListView(coupleId: coupleId)
            default:
                ComingSoonView(title: card.title)
            }
        }
    }
}

struct ComingSoonView: View {
    let title: String

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "hourglass")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.gold)
                Text(title)
                    .font(.system(.title2, design: .serif, weight: .bold))
                    .foregroundStyle(Theme.navy)
                Text("Yakında burada olacak.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ShortcutCardsView(coupleId: "preview").padding()
    }
}
