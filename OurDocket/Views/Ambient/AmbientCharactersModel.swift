import Foundation
import QuartzCore

enum WalkerID: Hashable {
    case own
    case partner
}

struct Walker: Identifiable {
    enum Activity: Equatable {
        case walking
        case idle(until: TimeInterval)
        case meeting(until: TimeInterval)
        case waving(until: TimeInterval)
    }

    let id: WalkerID
    var x: CGFloat
    /// 1 faces right, -1 faces left (rendered as a horizontal flip).
    var facing: CGFloat
    var speed: CGFloat
    var activity: Activity = .walking
    var nextDecision: TimeInterval
    var bob: CGFloat = 0

    var isWaving: Bool {
        if case .waving = activity { return true }
        return false
    }
}

struct HeartMoment {
    let x: CGFloat
    let startedAt: TimeInterval
}

/// Purely local, purely cosmetic: each device simulates both characters on
/// its own. Only their appearance comes from Firestore — positions are
/// never synced, so the two phones don't have to agree on where anyone is.
@MainActor
final class AmbientCharactersModel: ObservableObject {
    @Published private(set) var walkers: [Walker] = []
    @Published private(set) var heart: HeartMoment?
    @Published private(set) var now: TimeInterval = CACurrentMediaTime()

    static let heartDuration: TimeInterval = 1.8

    private var minX: CGFloat = 24
    private var maxX: CGFloat = 300
    private var lastTick = CACurrentMediaTime()
    private var meetCooldownUntil: TimeInterval = 0
    private var loop: Task<Void, Never>?

    func configure(width: CGFloat) {
        guard width > 0 else { return }
        minX = 24
        maxX = max(minX + 1, width - 24)
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
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    /// A tap interrupts whatever the character was doing for a quick wave,
    /// except mid-meeting — that moment belongs to the two of them.
    func tap(_ id: WalkerID) {
        guard let index = walkers.firstIndex(where: { $0.id == id }) else { return }
        if case .meeting = walkers[index].activity { return }
        walkers[index].activity = .waving(until: now + 1.3)
        HapticFeedback.selection()
    }

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
            walkers.remove(at: index)
        }
    }

    private func step() {
        let time = CACurrentMediaTime()
        let dt = min(time - lastTick, 0.1)
        lastTick = time
        now = time

        for index in walkers.indices {
            advance(&walkers[index], dt: dt, time: time)
        }
        checkMeeting(time: time)
        if let heart, time - heart.startedAt > Self.heartDuration {
            self.heart = nil
        }
    }

    private func advance(_ walker: inout Walker, dt: TimeInterval, time: TimeInterval) {
        switch walker.activity {
        case .walking:
            walker.x += walker.facing * walker.speed * dt
            if walker.x <= minX {
                walker.x = minX
                walker.facing = 1
            } else if walker.x >= maxX {
                walker.x = maxX
                walker.facing = -1
            }
            walker.bob = abs(sin(time * 9)) * 2.5
            if time >= walker.nextDecision {
                decide(&walker, time: time)
            }
        case .idle(let until):
            walker.bob = 0
            if time >= until {
                walker.activity = .walking
                walker.nextDecision = time + .random(in: 2...5)
            }
        case .meeting(let until):
            walker.bob = 0
            if time >= until {
                walker.activity = .walking
                walker.facing = Bool.random() ? 1 : -1
                walker.speed = .random(in: 20...32)
                walker.nextDecision = time + .random(in: 2...4)
            }
        case .waving(let until):
            walker.bob = abs(sin(time * 14)) * 1.5
            if time >= until {
                walker.activity = .walking
                walker.nextDecision = time + .random(in: 1.5...4)
            }
        }
    }

    private func decide(_ walker: inout Walker, time: TimeInterval) {
        let roll = Double.random(in: 0..<1)
        if roll < 0.2 {
            walker.activity = .idle(until: time + .random(in: 1...2.5))
        } else if roll < 0.45 {
            walker.facing *= -1
        }
        walker.speed = .random(in: 20...32)
        walker.nextDecision = time + .random(in: 1.5...4)
    }

    private func checkMeeting(time: TimeInterval) {
        guard walkers.count == 2,
              time >= meetCooldownUntil,
              walkers.allSatisfy({ $0.activity == .walking }),
              abs(walkers[0].x - walkers[1].x) < 26 else { return }

        let left = walkers[0].x <= walkers[1].x ? 0 : 1
        walkers[left].facing = 1
        walkers[1 - left].facing = -1
        for index in walkers.indices {
            walkers[index].activity = .meeting(until: time + Self.heartDuration)
        }
        heart = HeartMoment(x: (walkers[0].x + walkers[1].x) / 2, startedAt: time)
        // Long enough that they wander apart before they can meet again.
        meetCooldownUntil = time + 10
        HapticFeedback.selection()
    }
}
