import SwiftUI

/// The narrow "sidewalk" between the tab content and the tab bar where
/// both partners' characters wander. Mounted once at the app root (inside
/// MainTabView's bottom inset) so switching tabs never resets them, and
/// kept out of the content area so it can't cover anything tappable.
struct AmbientCharactersStrip: View {
    let own: CharacterAppearance?
    let partner: CharacterAppearance?

    @StateObject private var model = AmbientCharactersModel()
    @Environment(\.scenePhase) private var scenePhase

    private let stripHeight: CGFloat = 60
    private let characterHeight: CGFloat = 50

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(model.walkers) { walker in
                    if let appearance = appearance(for: walker.id) {
                        WalkerView(walker: walker, appearance: appearance, height: characterHeight) {
                            model.tap(walker.id)
                        }
                        .position(x: walker.x, y: stripHeight - characterHeight / 2 - walker.bob)
                    }
                }

                if let heart = model.heart {
                    HeartView(progress: (model.now - heart.startedAt) / AmbientCharactersModel.heartDuration)
                        .position(x: heart.x, y: stripHeight - characterHeight - 4)
                }
            }
            .frame(width: geometry.size.width, height: stripHeight)
            .onAppear {
                model.configure(width: geometry.size.width)
                model.setPresence(own: own != nil, partner: partner != nil)
                model.start()
            }
            .onChange(of: geometry.size.width) { _, width in
                model.configure(width: width)
            }
        }
        .frame(height: stripHeight)
        .onChange(of: own == nil || partner == nil) {
            model.setPresence(own: own != nil, partner: partner != nil)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.start() } else { model.stop() }
        }
        .onDisappear { model.stop() }
    }

    private func appearance(for id: WalkerID) -> CharacterAppearance? {
        switch id {
        case .own: own
        case .partner: partner
        }
    }
}

private struct WalkerView: View {
    let walker: Walker
    let appearance: CharacterAppearance
    let height: CGFloat
    let onTap: () -> Void

    var body: some View {
        CharacterView(appearance: appearance)
            .frame(height: height)
            .scaleEffect(x: walker.facing, y: 1)
            .overlay(alignment: .topTrailing) {
                if walker.isWaving {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.gold)
                        .offset(x: 12, y: -10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.snappy, value: walker.isWaving)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
    }
}

private struct HeartView: View {
    let progress: Double

    var body: some View {
        let clamped = min(max(progress, 0), 1)
        let pop = 0.6 + 0.4 * min(clamped * 4, 1)
        let pulse = 1 + 0.12 * sin(clamped * .pi * 6)

        Image(systemName: "heart.fill")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color(hex: "E0607E"))
            .scaleEffect(pop * pulse)
            .offset(y: -14 * clamped)
            .opacity(clamped < 0.75 ? 1 : (1 - clamped) / 0.25)
    }
}

#Preview {
    VStack {
        Spacer()
        AmbientCharactersStrip(own: .defaults(for: .female), partner: .defaults(for: .male))
        BottomTabBar(selection: .constant(.home))
    }
    .background(Theme.cream)
}
