import Foundation

/// A local play round sampled from elapsed time, independent of rendering cadence.
struct PastureFetchRound {
    enum Phase { case flying, chasing, pickup, returning, delivery, ready }
    struct Frame {
        let phase: Phase
        let ollie: PastureScenePoint
        let ball: PastureScenePoint
        let lift: Double
        let facesLeft: Bool
        let carryFraction: Double
        var isRunning: Bool { phase == .flying || phase == .chasing || phase == .returning }
    }

    let origin: PastureScenePoint
    let target: PastureScenePoint
    let ollieStart: PastureScenePoint
    let returnPoint: PastureScenePoint
    let flightDuration: Double
    let arrivalTime: Double
    let returnTime: Double
    var duration: Double { returnTime + 0.45 }

    init(origin: PastureScenePoint, target: PastureScenePoint, ollieStart: PastureScenePoint) {
        self.origin = origin
        self.target = Self.boundedTarget(target)
        self.ollieStart = ollieStart
        returnPoint = PastureSceneLayout.clamped(.init(x: origin.x + 0.11, y: origin.y - 0.07), footprint: .ollie)
        flightDuration = 0.65 + origin.distance(to: self.target) * 0.8
        arrivalTime = max(flightDuration + 0.3, 0.15 + ollieStart.distance(to: self.target) / 0.25)
        returnTime = arrivalTime + 0.4 + max(0.1, self.target.distance(to: returnPoint) / 0.25)
    }

    static func boundedTarget(_ point: PastureScenePoint) -> PastureScenePoint {
        guard point.x.isFinite, point.y.isFinite else { return .init(x: 0.3, y: 0.6) }
        return PastureSceneLayout.clamped(point, footprint: .ollie)
    }

    /// The release point aims the throw; a faster flick adds travel in that direction.
    static func throwTarget(release: PastureScenePoint, predicted: PastureScenePoint) -> PastureScenePoint {
        guard predicted.x.isFinite, predicted.y.isFinite else { return boundedTarget(release) }
        return boundedTarget(.init(x: release.x + (predicted.x - release.x) * 0.35,
                                   y: release.y + (predicted.y - release.y) * 0.35))
    }

    func frame(at elapsed: Double, reduceMotion: Bool = false) -> Frame {
        let t = elapsed.isFinite ? max(0, elapsed) : 0
        let returnStart = arrivalTime + 0.4
        let outbound = min(1, max(0, (t - 0.15) / (arrivalTime - 0.15)))
        let inbound = min(1, max(0, (t - returnStart) / (returnTime - returnStart)))
        let dog = t < returnStart ? Self.mix(ollieStart, target, outbound) : Self.mix(target, returnPoint, inbound)
        let left = t < arrivalTime ? target.x < ollieStart.x : returnPoint.x < target.x
        let phase: Phase
        let ball: PastureScenePoint
        var lift = 0.0
        if t < flightDuration {
            phase = .flying
            let progress = t / flightDuration
            ball = Self.mix(origin, target, progress)
            lift = 0.20 * 4 * progress * (1 - progress)
        } else if t < arrivalTime {
            phase = .chasing
            ball = target
            let bounce = min(1, (t - flightDuration) / 0.3)
            lift = sin(bounce * .pi) * 0.035
        } else if t < returnStart {
            phase = .pickup
            ball = target
        } else if t < returnTime {
            phase = .returning
            ball = dog
        } else {
            phase = t < duration ? .delivery : .ready
            ball = Self.mix(returnPoint, origin, min(1, (t - returnTime) / 0.45))
        }
        let carry = t < arrivalTime ? 0 : t < returnStart ? (t - arrivalTime) / 0.4
            : t < returnTime ? 1 : max(0, 1 - (t - returnTime) / 0.45)
        return Frame(phase: phase, ollie: dog, ball: ball, lift: reduceMotion ? 0 : lift,
                     facesLeft: left, carryFraction: carry)
    }

    static func mix(_ a: PastureScenePoint, _ b: PastureScenePoint, _ fraction: Double) -> PastureScenePoint {
        if fraction <= 0 { return a }
        if fraction >= 1 { return b }
        return .init(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction)
    }

    /// Sheep anticipate the next part of Ollie's route and walk aside at a capped speed.
    static func sheepStep(from point: PastureScenePoint, ollie: PastureScenePoint,
                          ahead: PastureScenePoint, neighbours: [PastureScenePoint], delta: Double) -> PastureScenePoint {
        guard delta.isFinite, delta > 0 else { return point }
        let vx = ahead.x - ollie.x, vy = ahead.y - ollie.y
        let lengthSquared = vx * vx + vy * vy
        let fraction = lengthSquared > 0.000001
            ? min(1, max(0, ((point.x - ollie.x) * vx + (point.y - ollie.y) * vy) / lengthSquared)) : 0
        let nearest = mix(ollie, ahead, fraction)
        guard point.distance(to: nearest) < 0.18 else { return point }
        let dx = point.x - nearest.x, dy = point.y - nearest.y
        let distance = hypot(dx, dy)
        let direction = distance > 0.001 ? atan2(dy, dx) : atan2(vy, vx) + .pi / 2
        var goal = PastureSceneLayout.clamped(.init(x: nearest.x + cos(direction) * 0.21,
                                                    y: nearest.y + sin(direction) * 0.21), footprint: .sheep)
        // At the pasture edge, the opposite side can offer more room.
        if goal.distance(to: nearest) < 0.15 {
            goal = PastureSceneLayout.clamped(.init(x: nearest.x - cos(direction) * 0.21,
                                                    y: nearest.y - sin(direction) * 0.21), footprint: .sheep)
        }
        for neighbour in neighbours where goal.distance(to: neighbour) < 0.15 {
            let angle = atan2(goal.y - neighbour.y, goal.x - neighbour.x)
            goal = PastureSceneLayout.clamped(.init(x: neighbour.x + cos(angle) * 0.16,
                                                    y: neighbour.y + sin(angle) * 0.16), footprint: .sheep)
        }
        let travel = point.distance(to: goal)
        return mix(point, goal, min(1, min(delta, 0.05) * 0.28 / max(travel, 0.00001)))
    }
}
