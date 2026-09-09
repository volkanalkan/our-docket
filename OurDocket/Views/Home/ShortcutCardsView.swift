import SwiftUI

enum ShortcutDestination: CaseIterable, Hashable {
    case archive
    case notes
    case milestones

    var title: LocalizedStringKey {
        switch self {
        case .archive: "Archive"
        case .notes: "Notes"
        case .milestones: "Milestones"
        }
    }

    var systemImage: String {
        switch self {
        case .archive: "folder.fill"
        case .notes: "checklist"
        case .milestones: "seal.fill"
        }
    }
}

struct ShortcutCardsView: View {
    let coupleId: String

    var body: some View {
        HStack(spacing: 12) {
            ForEach(ShortcutDestination.allCases, id: \.self) { destination in
                NavigationLink(value: destination) {
                    VStack(spacing: 8) {
                        Image(systemName: destination.systemImage)
                            .font(.title2)
                        Text(destination.title)
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
                .simultaneousGesture(TapGesture().onEnded { HapticFeedback.tap() })
            }
        }
        .navigationDestination(for: ShortcutDestination.self) { destination in
            switch destination {
            case .archive:
                CaseFilesListView(coupleId: coupleId)
            case .notes:
                NotesView(coupleId: coupleId)
            case .milestones:
                DecisionsListView(coupleId: coupleId)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ShortcutCardsView(coupleId: "preview").padding()
    }
}
