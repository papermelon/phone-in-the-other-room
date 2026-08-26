import XCTest

final class NightJourneyProgressTests: XCTestCase {
    func testPrimaryProgressTracksOverallAndCurrentPhase() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let bedtime = start.addingTimeInterval(30 * 60)
        let plan = NightWatchPlan(
            intendedBedtime: bedtime,
            wakeTime: bedtime.addingTimeInterval(8 * 60 * 60),
            protectedUntil: bedtime.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        let run = FocusRun(plannedDurationSeconds: 9 * 60 * 60, startedAt: start, state: .running, nightWatchPlan: plan)

        let windDown = try XCTUnwrap(NightJourneyProgress.resolve(run: run, at: start.addingTimeInterval(15 * 60)))
        XCTAssertEqual(windDown.phaseFraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(windDown.segment, .mountain)
        XCTAssertEqual(windDown.nextTransition, bedtime)

        let overnight = try XCTUnwrap(NightJourneyProgress.resolve(run: run, at: bedtime.addingTimeInterval(4 * 60 * 60)))
        XCTAssertEqual(overnight.phase, .overnight)
        XCTAssertEqual(overnight.phaseFraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(overnight.segment, .moonlit)

        let completed = try XCTUnwrap(NightJourneyProgress.resolve(run: run, at: plan.protectedUntil.addingTimeInterval(1)))
        XCTAssertEqual(completed.overallFraction, 1)
        XCTAssertEqual(completed.phase, .complete)
    }

    func testLateStartBecomesPhaseStart() throws {
        let bedtime = Date(timeIntervalSince1970: 20_000)
        let plan = NightWatchPlan(
            intendedBedtime: bedtime,
            wakeTime: bedtime.addingTimeInterval(8 * 60 * 60),
            protectedUntil: bedtime.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        let lateStart = bedtime.addingTimeInterval(-10 * 60)
        let run = FocusRun(plannedDurationSeconds: 60, startedAt: lateStart, state: .running, nightWatchPlan: plan)
        let progress = try XCTUnwrap(NightJourneyProgress.resolve(run: run, at: lateStart))
        XCTAssertEqual(progress.phaseFraction, 0)
    }

    func testAdditionalQuietCountsToProtectedUntil() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let plan = NightWatchPlan.additionalQuiet(start: start, end: start.addingTimeInterval(60 * 60))
        let run = FocusRun(plannedDurationSeconds: 60 * 60, startedAt: start, state: .running, nightWatchPlan: plan)
        let progress = try XCTUnwrap(NightJourneyProgress.resolve(run: run, at: start.addingTimeInterval(30 * 60)))

        XCTAssertEqual(progress.overallFraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(progress.nextTransition, plan.protectedUntil)
        XCTAssertEqual(plan.nextTransition(after: start), plan.protectedUntil)
    }

    func testMalformedIntervalStaysFinite() throws {
        let instant = Date(timeIntervalSince1970: 1_000)
        let plan = NightWatchPlan.additionalQuiet(start: instant, end: instant)
        let run = FocusRun(plannedDurationSeconds: 0, startedAt: instant, state: .running, nightWatchPlan: plan)
        let progress = try XCTUnwrap(NightJourneyProgress.resolve(run: run, at: instant))
        XCTAssertTrue(progress.overallFraction.isFinite)
        XCTAssertTrue(progress.phaseFraction.isFinite)
    }

    func testTerrainIsPeriodicAndBounded() {
        for segment in NightJourneySegment.allCases {
            let profile = NightJourneyTerrainProfile.profile(for: segment)
            XCTAssertEqual(profile.normalizedHeight(at: 0), profile.normalizedHeight(at: 1), accuracy: 0.000_001)
            XCTAssertEqual(profile.normalizedSlope(at: 0), profile.normalizedSlope(at: 1), accuracy: 0.000_001)
            for sample in 0...100 {
                let height = profile.normalizedHeight(at: Double(sample) / 100)
                XCTAssertTrue((0.64...0.88).contains(height))
            }
        }
    }

    func testGaitWrapsAcrossSixFrames() {
        let firstCycleDistance = NightJourneyGait.distancePerFrame * Double(NightJourneyGait.frameCount)

        XCTAssertEqual(NightJourneyGait.frame(forForegroundDistance: 0), 0)
        XCTAssertEqual(NightJourneyGait.frame(forForegroundDistance: NightJourneyGait.distancePerFrame), 1)
        XCTAssertEqual(NightJourneyGait.frame(forForegroundDistance: firstCycleDistance), 0)
        XCTAssertEqual(NightJourneyGait.frame(forForegroundDistance: firstCycleDistance + NightJourneyGait.distancePerFrame * 2), 2)
    }

    func testGaitCadenceUsesCalmTwoSecondStride() {
        let elapsedForOneFrame = NightJourneyGait.distancePerFrame / NightJourneyGait.foregroundSpeed
        let distanceAfterOneSecond = NightJourneyGait.foregroundDistance(elapsedSinceStart: 1)

        XCTAssertEqual(elapsedForOneFrame, 1.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(distanceAfterOneSecond, NightJourneyGait.distancePerFrame * 3, accuracy: 0.000_001)
        XCTAssertEqual(NightJourneyGait.frame(forForegroundDistance: distanceAfterOneSecond), 3)
    }

    func testGaitRemainsFiniteAfterLongElapsedIntervals() {
        let elapsed = 10 * 365.25 * 24 * 60 * 60
        let distance = NightJourneyGait.foregroundDistance(elapsedSinceStart: elapsed)
        let frame = NightJourneyGait.frame(forForegroundDistance: distance)

        XCTAssertTrue(distance.isFinite)
        XCTAssertTrue((0..<NightJourneyGait.frameCount).contains(frame))
        XCTAssertEqual(NightJourneyGait.foregroundDistance(elapsedSinceStart: -1), 0)
    }

    func testGaitReduceMotionKeepsOllieOnTheFirstFrame() {
        XCTAssertEqual(
            NightJourneyGait.frame(forForegroundDistance: 10_000, reduceMotion: true),
            0
        )
    }
}
