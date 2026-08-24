import XCTest

final class ScreenFreeMorningPresentationTests: XCTestCase {
    func testWatchDoesNotLetFutureMorningMaskActiveWindDown() {
        let now = Date(timeIntervalSince1970: 2_000)
        var run = FocusRun(plannedDurationSeconds: 60 * 60, startedAt: now)
        let scheduled = ScreenFreeMorningPresentation(occurrence: MorningQuietOccurrence(
            scheduledStart: now.addingTimeInterval(60 * 60), scheduledEnd: now.addingTimeInterval(90 * 60), outcome: .scheduled
        ), at: now)
        XCTAssertNil(ScreenFreeMorningWatchPresentationPolicy.preferred(morning: scheduled, run: run))
        run.state = .completed
        XCTAssertEqual(ScreenFreeMorningWatchPresentationPolicy.preferred(morning: scheduled, run: run), scheduled)
    }
    func testActiveOccurrenceWinsOverDeferredAndContainsNoRewardSurface() throws {
        let now = Date(timeIntervalSince1970: 2_000)
        let deferred = MorningQuietOccurrence(
            scheduledStart: now.addingTimeInterval(60 * 60), scheduledEnd: now.addingTimeInterval(90 * 60), outcome: .scheduled
        )
        let active = MorningQuietOccurrence(
            scheduledStart: now.addingTimeInterval(-10 * 60), scheduledEnd: now.addingTimeInterval(20 * 60), actualStart: now.addingTimeInterval(-10 * 60), outcome: .active
        )
        let value = try XCTUnwrap(ScreenFreeMorningPresentationRouting.current(occurrences: [deferred, active], at: now))
        XCTAssertEqual(value.occurrenceID, active.id)
        XCTAssertEqual(value.status, .active)
        XCTAssertEqual(value.actualEligibleMinutes, 10)
        XCTAssertFalse(String(describing: value).localizedCaseInsensitiveContains("sheep"))
        XCTAssertFalse(String(describing: value).localizedCaseInsensitiveContains("reward"))
    }

    func testFinishedAndSkippedPresentationRemainFactual() {
        let now = Date(timeIntervalSince1970: 2_000)
        let skipped = MorningQuietOccurrence(
            scheduledStart: now, scheduledEnd: now.addingTimeInterval(30 * 60), endedAt: now, outcome: .skipped
        )
        XCTAssertEqual(ScreenFreeMorningPresentation(occurrence: skipped, at: now).status, .skipped)
        XCTAssertEqual(ScreenFreeMorningPresentation(occurrence: skipped, at: now).actualEligibleMinutes, 0)
    }
}
