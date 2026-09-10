import SwiftUI
import QuartzCore

enum WalkerID: Hashable {
    case own
    case partner
}

struct Walker: Identifiable {
    enum AirActivity: Equatable {
        case balloon(until: TimeInterval)
        case jetpack(until: TimeInterval)
    }

    enum Activity: Equatable {
        case walking
        case idle(until: TimeInterval)
        case waving(until: TimeInterval)
        case meeting(until: TimeInterval)
        case awaitingBalloon
        case ballooning(until: TimeInterval)
        case jetpack(until: TimeInterval, targetAltitude: CGFloat, targetX: CGFloat, retarget: TimeInterval)
        case hovering(until: TimeInterval, resume: AirActivity)
        case hopping
        case falling
        case landing
        case dragging
        case thrown(hard: Bool, bounces: Int)
        case landed(until: TimeInterval)
        case angry(until: TimeInterval)
    }

    let id: WalkerID
    /// Horizontal position in layer points; `y` is altitude above the
    /// ground line (0 = standing), positive upward.
    var x: CGFloat
    var y: CGFloat = 0
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    /// 1 faces right, -1 faces left (rendered as a horizontal flip).
    var facing: CGFloat
    var speed: CGFloat
    var activity: Activity = .walking
    var nextDecision: TimeInterval
    var bob: CGFloat = 0
    var spin: CGFloat = 0
    var squash: CGFloat = 0
    var lean: CGFloat = 0

    var isWaving: Bool {
        if case .waving = activity { return true }
        return false
    }

    var isAngry: Bool {
        if case .angry = activity { return true }
        return false
    }

    var hasJetpack: Bool {
        switch activity {
        case .jetpack, .hovering(_, .jetpack), .landing: return true
        default: return false
        }
    }

    var isAirborne: Bool { y > 0.5 }

    var canMeetInAir: Bool {
        switch activity {
        case .ballooning, .jetpack: return true
        default: return false
        }
    }
}

struct Balloon: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    var target: WalkerID
    var holder: WalkerID?
    var poppedAt: TimeInterval?
    let phase: Double
}

struct HeartMoment {
    let x: CGFloat
    let y: CGFloat
    let startedAt: TimeInterval
}

/// Purely local, purely cosmetic: each device simulates both characters on
/// its own. Only their appearance comes from Firestore — positions and
/// events are never synced, so the two phones each get their own little
/// improvised show.
@MainActor
final class AmbientCharactersModel: ObservableObject {
    @Published private(set) var walkers: [Walker] = []
    @Published private(set) var balloons: [Balloon] = []
    @Published private(set) var heart: HeartMoment?
    @Published private(set) var now: TimeInterval = CACurrentMediaTime()

    static let heartDuration: TimeInterval = 1.8
    static let popDuration: TimeInterval = 0.35

    private(set) var characterHeight: CGFloat = 44
    private var minX: CGFloat = 24
    private var maxX: CGFloat = 300
    private var ceiling: CGFloat = 200
    private var lastTick = CACurrentMediaTime()
    private var meetCooldownUntil: TimeInterval = 0
    private var nextEventAt: TimeInterval = CACurrentMediaTime() + 8
    private var loop: Task<Void, Never>?

    private static let balloonColors: [Color] = [
        Color(hex: "E8646B"), Color(hex: "F2B544"), Color(hex: "5FA8D3"),
        Color(hex: "8BC48A"), Color(hex: "B48CD9"), Color(hex: "F08AB0")
    ]

    // MARK: - Configuration

    func configure(width: CGFloat, height: CGFloat, characterHeight: CGFloat) {
        guard width > 0, height > 0 else { return }
        self.characterHeight = characterHeight
        minX = 24
        maxX = max(minX + 1, width - 24)
        // Flights top out around mid-screen — high enough to feel free,
        // low enough not to hover over the header all the time.
        ceiling = max(80, min(height * 0.5, height - characterHeight - 24))
        for index in walkers.indices {
            walkers[index].x = min(max(walkers[index].x, minX), maxX)
        }
    }

    func setPresence(own: Bool, partner: Bool) {
        sync(.own, present: own)
        sync(.partner, present: partner)
    }

    func start() {
        guard loop == nil else { return }
        lastTick = CACurrentMediaTime()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.step()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    // MARK: - Interaction

    func tap(_ id: WalkerID) {
        guard let index = walkers.firstIndex(where: { $0.id == id }) else { return }
        switch walkers[index].activity {
        case .walking, .idle, .landed:
            walkers[index].activity = .waving(until: now + 1.3)
            HapticFeedback.selection()
        default:
            break
        }
    }

    func drag(_ id: WalkerID, toX x: CGFloat, altitude: CGFloat) {
        guard let index = walkers.firstIndex(where: { $0.id == id }) else { return }
        if walkers[index].activity != .dragging {
            releaseBalloon(heldBy: id)
            walkers[index].activity = .dragging
            walkers[index].vx = 0
            walkers[index].vy = 0
            walkers[index].lean = 0
            walkers[index].spin = 0
        }
        walkers[index].x = min(max(x, minX), maxX)
        walkers[index].y = min(max(altitude, 0), ceiling + 40)
    }

    func release(_ id: WalkerID, velocity: CGSize) {
        guard let index = walkers.firstIndex(where: { $0.id == id }),
              walkers[index].activity == .dragging else { return }
        let vx = min(max(velocity.width * 0.85, -1300), 1300)
        let vy = min(max(-velocity.height * 0.85, -1400), 1400)
        let hard = hypot(vx, vy) > 950
        walkers[index].vx = vx
        walkers[index].vy = vy
        walkers[index].facing = vx >= 0 ? 1 : -1
        walkers[index].activity = .thrown(hard: hard, bounces: 0)
        if hard { HapticFeedback.tap() }
    }

    // MARK: - Simulation

    private func sync(_ id: WalkerID, present: Bool) {
        let index = walkers.firstIndex { $0.id == id }
        if present, index == nil {
            walkers.append(Walker(
                id: id,
                x: .random(in: minX...maxX),
                facing: Bool.random() ? 1 : -1,
                speed: .random(in: 20...32),
                nextDecision: now + .random(in: 1.5...4)
            ))
        } else if !present, let index {
            releaseBalloon(heldBy: id)
            walkers.remove(at: index)
        }
    }

    private func step() {
        let time = CACurrentMediaTime()
        let dt = min(time - lastTick, 0.05)
        lastTick = time
        now = time

        for index in walkers.indices {
            advance(&walkers[index], dt: dt, time: time)
        }
        advanceBalloons(dt: dt, time: time)
        checkGroundMeeting(time: time)
        checkAirMeeting(time: time)
        maybeStartEvent(time: time)

        if let heart, time - heart.startedAt > Self.heartDuration {
            self.heart = nil
        }
    }

    private func advance(_ w: inout Walker, dt: TimeInterval, time: TimeInterval) {
        w.squash = max(0, w.squash - CGFloat(dt) * 3)

        switch w.activity {
        case .walking:
            w.x += w.facing * w.speed * dt
            if w.x <= minX { w.x = minX; w.facing = 1 } else if w.x >= maxX { w.x = maxX; w.facing = -1 }
            w.bob = abs(sin(time * 9)) * 2.5
            w.lean = 0
            if time >= w.nextDecision { decide(&w, time: time) }

        case .idle(let until):
            w.bob = 0
            if time >= until { w.activity = .walking; w.nextDecision = time + .random(in: 2...5) }

        case .waving(let until):
            w.bob = abs(sin(time * 14)) * 1.5
            if time >= until { w.activity = .walking; w.nextDecision = time + .random(in: 1.5...4) }

        case .meeting(let until):
            w.bob = 0
            if time >= until { resumeWalking(&w, time: time) }

        case .awaitingBalloon:
            w.bob = abs(sin(time * 4)) * 1
            if !balloons.contains(where: { $0.target == w.id && $0.poppedAt == nil }) {
                w.activity = .walking
            }

        case .ballooning(let until):
            let targetVy: CGFloat = w.y < ceiling ? 26 : 0
            w.vy += (targetVy - w.vy) * CGFloat(min(1, dt * 2))
            w.y = min(w.y + w.vy * dt, ceiling + 6)
            w.x += sin(time * 1.3 + Double(w.id == .own ? 0 : 2)) * 16 * dt
            w.x = min(max(w.x, minX), maxX)
            w.bob = sin(time * 3) * 1.5
            w.lean = sin(time * 1.3) * 4
            if time >= until {
                releaseBalloon(heldBy: w.id, pop: true)
                w.activity = .falling
                w.vy = 0
            }

        case .jetpack(let until, let targetAltitude, let targetX, let retarget):
            w.vy += ((targetAltitude - w.y) * 3 - w.vy * 2.2) * dt
            w.y = min(max(w.y + w.vy * dt, 0), ceiling + 10)
            let desiredVx = min(max((targetX - w.x) * 1.4, -70), 70)
            w.vx += (desiredVx - w.vx) * CGFloat(min(1, dt * 3))
            w.x = min(max(w.x + w.vx * dt, minX), maxX)
            if abs(w.vx) > 6 { w.facing = w.vx > 0 ? 1 : -1 }
            w.lean = min(max(w.vx / 5, -16), 16)
            w.bob = sin(time * 6) * 1.2
            if time >= until {
                w.activity = .landing
            } else if time >= retarget {
                w.activity = .jetpack(
                    until: until,
                    targetAltitude: .random(in: 60...ceiling),
                    targetX: .random(in: minX...maxX),
                    retarget: time + .random(in: 1.5...2.8)
                )
            }

        case .hovering(let until, let resume):
            w.vy *= 0.9
            w.vx *= 0.9
            w.bob = sin(time * 3) * 1.5
            if time >= until {
                switch resume {
                case .balloon(let end): w.activity = .ballooning(until: end)
                case .jetpack(let end):
                    w.activity = .jetpack(until: end, targetAltitude: .random(in: 60...ceiling), targetX: .random(in: minX...maxX), retarget: time + 2)
                }
            }

        case .hopping, .falling:
            w.vy -= 1100 * dt
            w.y += w.vy * dt
            w.x = min(max(w.x + w.vx * dt, minX), maxX)
            w.lean = 0
            if w.y <= 0 {
                w.y = 0
                w.vy = 0
                w.vx = 0
                w.squash = 1
                w.activity = .landed(until: time + 0.35)
            }

        case .landing:
            w.vy += (-75 - w.vy) * CGFloat(min(1, dt * 3))
            w.vx *= 0.96
            w.y += w.vy * dt
            w.x = min(max(w.x + w.vx * dt, minX), maxX)
            w.lean *= 0.95
            w.bob = sin(time * 6) * 1
            if w.y <= 0 {
                w.y = 0
                w.vy = 0
                w.vx = 0
                w.lean = 0
                w.squash = 0.6
                w.activity = .landed(until: time + 0.4)
            }

        case .dragging:
            w.bob = 0
            w.lean = sin(time * 5) * 6

        case .thrown(let hard, let bounces):
            w.vy -= 1500 * dt
            w.x += w.vx * dt
            w.y += w.vy * dt
            w.spin += w.vx * 0.5 * dt
            if w.x <= minX { w.x = minX; w.vx = -w.vx * 0.55 }
            if w.x >= maxX { w.x = maxX; w.vx = -w.vx * 0.55 }
            if w.y >= ceiling + 40 { w.y = ceiling + 40; w.vy = -abs(w.vy) * 0.4 }
            if w.y <= 0 {
                w.y = 0
                if abs(w.vy) > 220, bounces < 2 {
                    w.vy = -w.vy * 0.42
                    w.vx *= 0.7
                    w.squash = 0.5
                    w.activity = .thrown(hard: hard, bounces: bounces + 1)
                } else {
                    w.vx = 0
                    w.vy = 0
                    w.spin = 0
                    w.squash = 1
                    w.activity = hard ? .angry(until: time + 2.4) : .landed(until: time + 0.35)
                    if hard { HapticFeedback.error() }
                }
            }

        case .landed(let until):
            w.bob = 0
            w.spin *= 0.7
            if time >= until { resumeWalking(&w, time: time) }

        case .angry(let until):
            w.bob = abs(sin(time * 22)) * 3
            w.spin = 0
            if time >= until { resumeWalking(&w, time: time) }
        }
    }

    private func resumeWalking(_ w: inout Walker, time: TimeInterval) {
        w.activity = .walking
        w.facing = Bool.random() ? 1 : -1
        w.speed = .random(in: 20...32)
        w.nextDecision = time + .random(in: 2...4)
    }

    private func decide(_ w: inout Walker, time: TimeInterval) {
        let roll = Double.random(in: 0..<1)
        if roll < 0.18 {
            w.activity = .idle(until: time + .random(in: 1...2.5))
        } else if roll < 0.28 {
            w.activity = .hopping
            w.vy = .random(in: 220...300)
            w.vx = w.facing * w.speed
        } else if roll < 0.5 {
            w.facing *= -1
        }
        w.speed = .random(in: 20...32)
        w.nextDecision = time + .random(in: 1.5...4)
    }

    // MARK: - Events

    private func maybeStartEvent(time: TimeInterval) {
        guard time >= nextEventAt else { return }
        let candidates = walkers.indices.filter { walkers[$0].activity == .walking }
        guard let index = candidates.randomElement() else {
            nextEventAt = time + 3
            return
        }
        nextEventAt = time + .random(in: 14...30)

        if Bool.random() {
            walkers[index].activity = .awaitingBalloon
            balloons.append(Balloon(
                x: walkers[index].x + .random(in: -30...30),
                y: ceiling + 60,
                color: Self.balloonColors.randomElement()!,
                target: walkers[index].id,
                phase: .random(in: 0...(2 * .pi))
            ))
        } else {
            walkers[index].activity = .jetpack(
                until: time + .random(in: 5...8),
                targetAltitude: .random(in: 60...ceiling),
                targetX: .random(in: minX...maxX),
                retarget: time + .random(in: 1.5...2.5)
            )
            walkers[index].vy = 90
        }
    }

    private func advanceBalloons(dt: TimeInterval, time: TimeInterval) {
        for index in balloons.indices.reversed() {
            var balloon = balloons[index]
            if let poppedAt = balloon.poppedAt {
                if time - poppedAt > Self.popDuration { balloons.remove(at: index) }
                continue
            }

            if let holder = balloon.holder, let w = walkers.first(where: { $0.id == holder }) {
                balloon.x = w.x + w.facing * 6 + sin(time * 1.6 + balloon.phase) * 3
                balloon.y = w.y + characterHeight + 20
            } else if let w = walkers.first(where: { $0.id == balloon.target }), w.activity == .awaitingBalloon {
                let handY = w.y + characterHeight * 0.85 + 14
                balloon.y -= 48 * dt
                balloon.x += ((w.x + w.facing * 6) - balloon.x) * CGFloat(min(1, dt * 1.5)) + sin(time * 2 + balloon.phase) * 10 * dt
                if balloon.y <= handY {
                    balloon.holder = w.id
                    if let wi = walkers.firstIndex(where: { $0.id == w.id }) {
                        walkers[wi].activity = .ballooning(until: time + .random(in: 5...8))
                        walkers[wi].vy = 0
                    }
                }
            } else {
                balloon.poppedAt = time
            }
            balloons[index] = balloon
        }
    }

    private func releaseBalloon(heldBy id: WalkerID, pop: Bool = true) {
        for index in balloons.indices where balloons[index].holder == id || balloons[index].target == id {
            if balloons[index].poppedAt == nil {
                balloons[index].holder = nil
                balloons[index].poppedAt = now
            }
        }
    }

    // MARK: - Meetings

    private func checkGroundMeeting(time: TimeInterval) {
        guard walkers.count == 2,
              time >= meetCooldownUntil,
              walkers.allSatisfy({ $0.activity == .walking }),
              abs(walkers[0].x - walkers[1].x) < 26 else { return }

        faceEachOther()
        for index in walkers.indices {
            walkers[index].activity = .meeting(until: time + Self.heartDuration)
        }
        heart = HeartMoment(x: (walkers[0].x + walkers[1].x) / 2, y: characterHeight + 6, startedAt: time)
        meetCooldownUntil = time + 12
        HapticFeedback.selection()
    }

    private func checkAirMeeting(time: TimeInterval) {
        guard walkers.count == 2,
              time >= meetCooldownUntil,
              walkers.allSatisfy(\.canMeetInAir),
              abs(walkers[0].x - walkers[1].x) < 44,
              abs(walkers[0].y - walkers[1].y) < 36 else { return }

        faceEachOther()
        for index in walkers.indices {
            let resume: Walker.AirActivity
            switch walkers[index].activity {
            case .ballooning(let until): resume = .balloon(until: until + Self.heartDuration)
            case .jetpack(let until, _, _, _): resume = .jetpack(until: until + Self.heartDuration)
            default: continue
            }
            walkers[index].activity = .hovering(until: time + Self.heartDuration, resume: resume)
        }
        heart = HeartMoment(
            x: (walkers[0].x + walkers[1].x) / 2,
            y: (walkers[0].y + walkers[1].y) / 2 + characterHeight + 6,
            startedAt: time
        )
        meetCooldownUntil = time + 12
        HapticFeedback.selection()
    }

    private func faceEachOther() {
        let left = walkers[0].x <= walkers[1].x ? 0 : 1
        walkers[left].facing = 1
        walkers[1 - left].facing = -1
    }
}
