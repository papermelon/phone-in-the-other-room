import XCTest

final class QuietPeriodSchedulingTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testNextQuarterHourRoundsForwardFromFiveOhSeven() throws {
        let now = try date(2026, 8, 9, 5, 7)

        XCTAssertEqual(
            QuietPeriodScheduling.nextLocalQuarterHour(after: now, calendar: utc),
            try date(2026, 8, 9, 5, 15)
        )
    }

    func testExactQuarterHourBoundaryIsValid() throws {
        let now = try date(2026, 8, 9, 5, 15)

        XCTAssertEqual(
            QuietPeriodScheduling.nextLocalQuarterHour(after: now, calendar: utc),
            now
        )
    }

    func testQuarterHourWithSecondsRoundsToTheFollowingBoundary() throws {
        let now = try date(2026, 8, 9, 5, 15, second: 1)

        XCTAssertEqual(
            QuietPeriodScheduling.nextLocalQuarterHour(after: now, calendar: utc),
            try date(2026, 8, 9, 5, 30)
        )
    }

    func testLateNightQuarterHourCrossesIntoTheNextLocalDay() throws {
        let now = try date(2026, 8, 9, 23, 58)

        XCTAssertEqual(
            QuietPeriodScheduling.nextLocalQuarterHour(after: now, calendar: utc),
            try date(2026, 8, 10, 0, 0)
        )
    }

    func testGeneralDefaultIsThirtyMinutesAndPracticePresetStartsNowForFiveMinutes() throws {
        let now = try date(2026, 8, 9, 5, 7, second: 12)
        let general = QuietPeriodScheduling.defaultWindow(now: now, calendar: utc)
        let practice = QuietPeriodScheduling.defaultWindow(
            now: now,
            calendar: utc,
            preset: .startNowPractice
        )

        XCTAssertEqual(general.start, try date(2026, 8, 9, 5, 15))
        XCTAssertEqual(general.duration, 30 * 60, accuracy: 0.1)
        XCTAssertEqual(practice.start, now)
        XCTAssertEqual(practice.duration, 5 * 60, accuracy: 0.1)
    }

    func testNowStartIsNormalizedToTheConfirmationTime() throws {
        let now = try date(2026, 8, 9, 5, 15, second: 4)
        let interval = try QuietPeriodScheduling.normalizedInterval(
            requestedStart: now,
            end: now.addingTimeInterval(5 * 60),
            now: now
        )

        XCTAssertEqual(interval.start, now)
    }

    func testPastStartWithFutureEndUsesOnlyTheRemainingWindow() throws {
        let now = try date(2026, 8, 9, 5, 15)
        let requestedStart = now.addingTimeInterval(-10 * 60)
        let end = now.addingTimeInterval(5 * 60)

        let interval = try QuietPeriodScheduling.normalizedInterval(
            requestedStart: requestedStart,
            end: end,
            now: now
        )
        let plan = NightWatchPlan.additionalQuiet(start: interval.start, end: interval.end)

        XCTAssertEqual(interval.start, now)
        XCTAssertEqual(plan.creditedQuietMinutes(startedAt: now, through: end), 5)
    }

    func testExpiredEndIsRejected() throws {
        let now = try date(2026, 8, 9, 5, 15)

        XCTAssertThrowsError(try QuietPeriodScheduling.normalizedInterval(
            requestedStart: now.addingTimeInterval(-10 * 60),
            end: now,
            now: now
        )) { error in
            XCTAssertEqual(error as? QuietPeriodSchedulingError, .expired)
        }
    }

    func testLessThanMeaningfulRemainingDurationAndInvalidIntervalsAreRejected() throws {
        let now = try date(2026, 8, 9, 5, 15)

        XCTAssertThrowsError(try QuietPeriodScheduling.normalizedInterval(
            requestedStart: now.addingTimeInterval(-2 * 60),
            end: now.addingTimeInterval(30),
            now: now
        )) { error in
            XCTAssertEqual(error as? QuietPeriodSchedulingError, .insufficientRemainingDuration)
        }
        XCTAssertThrowsError(try QuietPeriodScheduling.normalizedInterval(
            requestedStart: now.addingTimeInterval(60),
            end: now,
            now: now
        )) { error in
            XCTAssertEqual(error as? QuietPeriodSchedulingError, .invalidInterval)
        }
    }

    func testOverlapIsRejectedButAdjacentWindowsAreAllowed() throws {
        let now = try date(2026, 8, 9, 5, 15)
        let candidate = DateInterval(start: now, end: now.addingTimeInterval(5 * 60))
        let overlap = DateInterval(start: now.addingTimeInterval(4 * 60), end: now.addingTimeInterval(9 * 60))
        let adjacent = DateInterval(start: candidate.end, end: candidate.end.addingTimeInterval(5 * 60))

        do {
            try QuietPeriodScheduling.validateNoOverlap(candidate, with: [overlap])
            XCTFail("An overlapping quiet window should be rejected.")
        } catch {
            XCTAssertEqual(error as? QuietPeriodSchedulingError, .invalidInterval)
        }
        do {
            try QuietPeriodScheduling.validateNoOverlap(candidate, with: [adjacent])
        } catch {
            XCTFail("Adjacent quiet windows should be allowed.")
        }
    }

    func testSpringDSTUsesTheNextValidLocalQuarterHour() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        let now = try XCTUnwrap(newYork.date(from: DateComponents(
            timeZone: newYork.timeZone,
            year: 2026,
            month: 3,
            day: 8,
            hour: 1,
            minute: 58
        )))

        let window = QuietPeriodScheduling.defaultWindow(now: now, calendar: newYork)
        let start = newYork.dateComponents([.year, .month, .day, .hour, .minute], from: window.start)

        XCTAssertEqual(start.year, 2026)
        XCTAssertEqual(start.month, 3)
        XCTAssertEqual(start.day, 8)
        XCTAssertEqual(start.hour, 3)
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(window.duration, 30 * 60, accuracy: 0.1)
    }

    func testActiveSavedWindowIsEligibleAndFiveMinuteAdditionalQuietStaysOutsideProtectedNightProgress() throws {
        let now = try date(2026, 8, 9, 5, 15)
        let period = WindDownOneTimePeriod(
            title: "Practice",
            interval: DateInterval(start: now.addingTimeInterval(-60), end: now.addingTimeInterval(5 * 60))
        )
        let state = WindDownScheduleState(oneTimePeriods: [period])
        let eligible = WindDownScheduleEngine.eligibleOccurrence(in: state, at: now, calendar: utc)
        let plan = NightWatchPlan.additionalQuiet(start: now, end: period.interval.end)
        let run = FocusRun(
            plannedDurationSeconds: 5 * 60,
            startedAt: now,
            state: .completed,
            guardKind: .honorTimer,
            nightWatchPlan: plan
        )

        XCTAssertEqual(eligible?.id, period.id)
        XCTAssertTrue(period.isEligible(at: now))
        XCTAssertEqual(plan.creditedQuietMinutes(startedAt: now, through: period.interval.end), 5)
        XCTAssertFalse(run.isProgressionEligibleNightWatch)
        XCTAssertNil(RewardEngine().generateReward(for: run, progress: .empty))
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        second: Int = 0
    ) throws -> Date {
        try XCTUnwrap(utc.date(from: DateComponents(
            timeZone: utc.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )))
    }
}
