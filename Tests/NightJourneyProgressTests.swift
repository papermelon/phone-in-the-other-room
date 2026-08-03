import XCTest

final class NightJourneyProgressTests: XCTestCase {
    func testProgressUsesWallClockAndClampsAtCompletion() {
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

        let midway = NightJourneyProgress.resolve(plan: plan, at: plan.intendedBedtime.addingTimeInterval(4 * 60 * 60))
        let finished = NightJourneyProgress.resolve(plan: plan, at: plan.protectedUntil.addingTimeInterval(60))

        XCTAssertEqual(midway.fraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(midway.segment, .mountain)
        XCTAssertEqual(finished.fraction, 1, accuracy: 0.001)
        XCTAssertEqual(finished.segment, .sunrise)
        XCTAssertEqual(finished.illustratedMiles, NightJourneyProgress.illustratedTrailMiles, accuracy: 0.001)
    }

    func testAdditionalQuietStartsAtItsOwnInterval() {
        let start = Date(timeIntervalSince1970: 1_000)
        let plan = NightWatchPlan.additionalQuiet(start: start, end: start.addingTimeInterval(60 * 60))
        let progress = NightJourneyProgress.resolve(plan: plan, at: start.addingTimeInterval(30 * 60))
        XCTAssertEqual(progress.fraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(progress.illustratedMiles, NightJourneyProgress.illustratedTrailMiles / 2, accuracy: 0.001)
    }

    func testMalformedZeroDurationPlanDoesNotProduceNaN() {
        let instant = Date(timeIntervalSince1970: 1_000)
        let plan = NightWatchPlan.additionalQuiet(start: instant, end: instant)
        let progress = NightJourneyProgress.resolve(plan: plan, at: instant)

        XCTAssertTrue(progress.fraction.isFinite)
        XCTAssertEqual(progress.fraction, 0, accuracy: 0.001)
    }
}
