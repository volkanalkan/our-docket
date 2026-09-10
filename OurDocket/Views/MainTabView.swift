import SwiftUI

enum AppTab: CaseIterable, Identifiable {
    case home
    case archive
    case notes
    case milestones
    case profile

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .archive: "Archive"
        case .notes: "Notes"
        case .milestones: "Milestones"
        case .profile: "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .archive: "folder.fill"
        case .notes: "checklist"
        case .milestones: "seal.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}

/// All five tabs stay alive side by side (rather than a system `TabView`)
/// so each one's navigation stack and scroll position survive switching,
/// and so nothing system-drawn sits at the bottom — the bar is ours, in the
/// same custom-chrome spirit as `HeaderBar`.
struct MainTabView: View {
    let coupleId: String

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selection: AppTab = .home

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    content(for: tab)
                }
                .opacity(selection == tab ? 1 : 0)
                .allowsHitTesting(selection == tab)
                .accessibilityHidden(selection != tab)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                AmbientCharactersStrip(
                    own: authViewModel.user?.character,
                    partner: authViewModel.partner?.character
                )
                BottomTabBar(selection: $selection)
            }
        }
    }

    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            HomeView(coupleId: coupleId, selectedTab: $selection)
        case .archive:
            CaseFilesListView(coupleId: coupleId)
        case .notes:
            NotesView(coupleId: coupleId)
        case .milestones:
            DecisionsListView(coupleId: coupleId)
        case .profile:
            ProfileView()
        }
    }
}

struct BottomTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let isSelected = selection == tab
                Button {
                    HapticFeedback.selection()
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                        Text(tab.title)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isSelected ? Theme.navy : Theme.navy.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .background(Theme.cream)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.navy.opacity(0.08))
                .frame(height: 1)
        }
    }
}

#Preview {
    MainTabView(coupleId: "preview")
        .environmentObject(AuthViewModel())
        .environmentObject(LanguageStore.shared)
}
