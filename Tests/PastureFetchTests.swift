import XCTest

final class PastureFetchTests: XCTestCase {
    private let origin = PastureScenePoint(x: 0.5, y: 0.86)
    private let start = PastureScenePoint(x: 0.75, y: 0.75)

    func testRestingPosesRiseBeforeBecomingReady() {
        for pose in 5...11 {
            let asset = String(format: "dog/dog_ollie_motion_pose_%02d", pose)
            let frames = PastureFetchWakeUp.frames(from: asset)
            XCTAssertEqual(frames.first?.assetName, asset)
            XCTAssertEqual(frames.last?.assetName, NightJourneyAssets.ollieHomeIdleFrames[0])
            XCTAssertTrue(frames.allSatisfy { $0.duration > 0 && OllieGarmentFit.forAsset($0.assetName) != nil })
            XCTAssertTrue(frames.dropFirst().allSatisfy { $0.poseIdentifier >= 10 })
        }
        XCTAssertTrue(PastureFetchWakeUp.frames(from: nil).isEmpty)
        XCTAssertTrue(PastureFetchWakeUp.frames(from: NightJourneyAssets.ollieHomeIdleFrames[0]).isEmpty)
        XCTAssertTrue(PastureFetchWakeUp.frames(from: "unknown_asset").isEmpty)
    }

    func testReleaseDirectionAndFlickSpeedControlThrow() {
        let release = PastureScenePoint(x: 0.4, y: 0.7)
        let tap = PastureFetchRound.throwTarget(release: release, predicted: release)
        let flick = PastureFetchRound.throwTarget(release: release, predicted: .init(x: 0.1, y: 0.4))
        XCTAssertEqual(tap, release)
        XCTAssertLessThan(flick.x, tap.x)
        XCTAssertLessThan(flick.y, tap.y)
        XCTAssertGreaterThan(origin.distance(to: flick), origin.distance(to: tap))
    }

    func testTargetsStayInsideReachableGroundIncludingInvalidInput() {
        for point in [PastureScenePoint(x: -10, y: -10), .init(x: 10, y: 10), .init(x: .nan, y: .infinity)] {
            let bounded = PastureFetchRound.boundedTarget(point)
            XCTAssertEqual(bounded, PastureSceneLayout.clamped(bounded, footprint: .ollie))
            XCTAssertTrue(bounded.x.isFinite && bounded.y.isFinite)
        }
    }

    func testOllieCannotPickUpUntilBallHasLandedAndHeHasArrived() {
        let round = PastureFetchRound(origin: origin, target: .init(x: 0.15, y: 0.57), ollieStart: start)
        XCTAssertGreaterThanOrEqual(round.arrivalTime, round.flightDuration + 0.3)
        XCTAssertEqual(round.frame(at: 0).ollie, start)
        XCTAssertEqual(round.frame(at: round.arrivalTime).phase, .pickup)
        XCTAssertEqual(round.frame(at: round.arrivalTime).ollie, round.target)
        XCTAssertEqual(round.frame(at: round.arrivalTime).ball, round.target)
        let returning = round.frame(at: round.arrivalTime + 0.5)
        XCTAssertEqual(returning.phase, .returning)
        XCTAssertEqual(returning.ball, returning.ollie)
        XCTAssertEqual(returning.carryFraction, 1)
        XCTAssertEqual(round.frame(at: round.duration).phase, .ready)
        XCTAssertEqual(round.frame(at: round.duration).ball, origin)
        XCTAssertEqual(round.frame(at: round.duration).ollie, round.returnPoint)
    }

    func testEveryPhaseBoundaryHasContinuousDogBallAndPickupMotion() {
        let round = PastureFetchRound(origin: origin, target: .init(x: 0.2, y: 0.6), ollieStart: start)
        for time in [round.flightDuration, round.arrivalTime, round.arrivalTime + 0.4, round.returnTime, round.duration] {
            let before = round.frame(at: time - 0.00001), after = round.frame(at: time + 0.00001)
            XCTAssertLessThan(before.ollie.distance(to: after.ollie), 0.0001)
            XCTAssertLessThan(before.ball.distance(to: after.ball), 0.0001)
            XCTAssertEqual(before.carryFraction, after.carryFraction, accuracy: 0.0001)
        }
        for tick in 1...Int(round.duration * 60) {
            let prior = round.frame(at: Double(tick - 1) / 60)
            let current = round.frame(at: Double(tick) / 60)
            XCTAssertLessThanOrEqual(prior.ollie.distance(to: current.ollie), 0.25 / 60 + 0.00001)
        }
    }

    func testReduceMotionKeepsTravelAndTimingWithoutArc() {
        let round = PastureFetchRound(origin: origin, target: .init(x: 0.2, y: 0.6), ollieStart: start)
        let normal = round.frame(at: 0.4), reduced = round.frame(at: 0.4, reduceMotion: true)
        XCTAssertGreaterThan(normal.lift, 0)
        XCTAssertEqual(reduced.lift, 0)
        XCTAssertEqual(normal.ball, reduced.ball)
        XCTAssertEqual(normal.ollie, reduced.ollie)
        XCTAssertEqual(round.frame(at: .nan).ollie, start)
    }

    func testSheepAnticipatesRouteWithBoundedWalkingSpeed() {
        let dog = PastureScenePoint(x: 0.3, y: 0.65), ahead = PastureScenePoint(x: 0.55, y: 0.65)
        var sheep = PastureScenePoint(x: 0.5, y: 0.65)
        let original = sheep
        for _ in 0..<60 {
            let next = PastureFetchRound.sheepStep(from: sheep, ollie: dog, ahead: ahead, neighbours: [], delta: 1.0 / 60)
            XCTAssertLessThanOrEqual(sheep.distance(to: next), 0.28 / 60 + 0.00001)
            XCTAssertEqual(next, PastureSceneLayout.clamped(next, footprint: .sheep))
            sheep = next
        }
        XCTAssertGreaterThan(sheep.distance(to: original), 0.15)
        let distant = PastureScenePoint(x: 0.85, y: 0.8)
        XCTAssertEqual(PastureFetchRound.sheepStep(from: distant, ollie: dog, ahead: ahead, neighbours: [], delta: 1), distant)
    }
}
