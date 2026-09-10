import SwiftUI

/// A single overlay across the whole main screen where both partners'
/// characters live: they walk along the tab bar's top edge and now and
/// then float off on a balloon, take a jetpack lap, or get flung by a
/// finger. Mounted once at the root so tab switches never reset them;
/// only the characters themselves are hit-testable, so everything
/// underneath stays tappable.
struct AmbientCharactersLayer: View {
    let own: CharacterAppearance?
    let partner: CharacterAppearance?
    /// Global y of the tab bar's top edge.
    let tabBarTop: CGFloat

    @StateObject private var model = AmbientCharactersModel()
    @Environment(\.scenePhase) private var scenePhase

    private let characterHeight: CGFloat = 44

    var body: some View {
        GeometryReader { geometry in
            // Until the bar has reported its edge, assume it sits at the
            // bottom of this layer so the characters never start off-screen.
            let ground = tabBarTop > 0 ? tabBarTop - geometry.frame(in: .global).minY : geometry.size.height - 60

            ZStack(alignment: .topLeading) {
                strings(ground: ground)

                ForEach(model.balloons) { balloon in
                    BalloonView(balloon: balloon, now: model.now)
                        .position(x: balloon.x, y: ground - balloon.y)
                }

                ForEach(model.walkers) { walker in
                    if let appearance = appearance(for: walker.id) {
                        WalkerView(walker: walker, appearance: appearance, height: characterHeight, now: model.now)
                            .position(x: walker.x + shake(for: walker), y: ground - walker.y - characterHeight / 2 - walker.bob)
                            .gesture(
                                DragGesture(minimumDistance: 4, coordinateSpace: .named("ambient"))
                                    .onChanged { value in
                                        model.drag(walker.id, toX: value.location.x, altitude: ground - value.location.y - characterHeight / 2)
                                    }
                                    .onEnded { value in
                                        model.release(walker.id, velocity: value.velocity)
                                    }
                            )
                            .onTapGesture { model.tap(walker.id) }
                    }
                }

                if let heart = model.heart {
                    HeartView(progress: (model.now - heart.startedAt) / AmbientCharactersModel.heartDuration)
                        .position(x: heart.x, y: ground - heart.y)
                }
            }
            .coordinateSpace(name: "ambient")
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .onAppear {
                model.configure(width: geometry.size.width, height: max(ground, 1), characterHeight: characterHeight)
                model.setPresence(own: own != nil, partner: partner != nil)
                model.start()
            }
            .onChange(of: geometry.size) { _, _ in
                model.configure(width: geometry.size.width, height: max(ground, 1), characterHeight: characterHeight)
            }
            .onChange(of: tabBarTop) { _, _ in
                model.configure(width: geometry.size.width, height: max(ground, 1), characterHeight: characterHeight)
            }
        }
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

    private func shake(for walker: Walker) -> CGFloat {
        walker.isAngry ? CGFloat(sin(model.now * 40)) * 1.6 : 0
    }

    /// Balloon strings, from the knot down to the holder's raised hand.
    private func strings(ground: CGFloat) -> some View {
        Path { path in
            for balloon in model.balloons where balloon.poppedAt == nil {
                guard let holder = balloon.holder, let walker = model.walkers.first(where: { $0.id == holder }) else { continue }
                let top = CGPoint(x: balloon.x, y: ground - balloon.y + 15)
                let hand = CGPoint(x: walker.x + walker.facing * 8, y: ground - walker.y - characterHeight * 0.55)
                path.move(to: top)
                path.addQuadCurve(to: hand, control: CGPoint(x: (top.x + hand.x) / 2 + walker.facing * 4, y: (top.y + hand.y) / 2))
            }
        }
        .stroke(Color(hex: "2B2118").opacity(0.55), lineWidth: 1)
    }
}

private struct WalkerView: View {
    let walker: Walker
    let appearance: CharacterAppearance
    let height: CGFloat
    let now: TimeInterval

    var body: some View {
        CharacterView(appearance: appearance)
            .frame(height: height)
            .background(alignment: .center) {
                if walker.hasJetpack {
                    JetpackView(now: now)
                        .offset(x: -10, y: 2)
                }
            }
            .scaleEffect(x: walker.facing, y: 1)
            .scaleEffect(x: 1 + walker.squash * 0.22, y: 1 - walker.squash * 0.22, anchor: .bottom)
            .rotationEffect(.degrees(walker.lean + walker.spin))
            .overlay(alignment: .top) {
                if walker.isWaving {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.gold)
                        .offset(x: 16, y: -8)
                        .transition(.scale.combined(with: .opacity))
                }
                if walker.isAngry {
                    AngerMark()
                        .offset(x: 14, y: -6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.snappy, value: walker.isWaving)
            .animation(.snappy, value: walker.isAngry)
            .padding(6)
            .contentShape(Rectangle())
    }
}

private struct JetpackView: View {
    let now: TimeInterval

    var body: some View {
        let flicker = 0.75 + 0.25 * abs(sin(now * 28))
        VStack(spacing: -2) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: "8A8F98"))
                .frame(width: 10, height: 16)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(hex: "2B2118").opacity(0.7), lineWidth: 1))
            Ellipse()
                .fill(LinearGradient(colors: [Color(hex: "FFD166"), Color(hex: "F3722C").opacity(0.9), .clear], startPoint: .top, endPoint: .bottom))
                .frame(width: 8, height: 16 * flicker)
        }
        .offset(y: 4)
    }
}

/// The classic cartoon "anger vein": four short strokes around a point.
private struct AngerMark: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for angle in stride(from: 45.0, to: 360.0, by: 90.0) {
                let radians = angle * .pi / 180
                var path = Path()
                path.move(to: CGPoint(x: center.x + 3 * cos(radians), y: center.y + 3 * sin(radians)))
                path.addLine(to: CGPoint(x: center.x + 7 * cos(radians), y: center.y + 7 * sin(radians)))
                context.stroke(path, with: .color(Color(hex: "D7263D")), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            }
        }
        .frame(width: 16, height: 16)
    }
}

private struct BalloonView: View {
    let balloon: Balloon
    let now: TimeInterval

    var body: some View {
        let popProgress = balloon.poppedAt.map { min(1, (now - $0) / AmbientCharactersModel.popDuration) } ?? 0
        ZStack {
            Ellipse()
                .fill(balloon.color)
                .frame(width: 22, height: 28)
                .overlay(Ellipse().stroke(Color(hex: "2B2118").opacity(0.7), lineWidth: 1))
            Ellipse()
                .fill(.white.opacity(0.45))
                .frame(width: 6, height: 9)
                .offset(x: -5, y: -7)
            Triangle()
                .fill(balloon.color)
                .frame(width: 6, height: 5)
                .offset(y: 16)
        }
        .rotationEffect(.degrees(sin(now * 1.6 + balloon.phase) * 5))
        .scaleEffect(1 + popProgress * 0.6)
        .opacity(1 - popProgress)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
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
