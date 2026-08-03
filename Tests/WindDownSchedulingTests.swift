import XCTest

final class WindDownSchedulingTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testPrimaryRoutineMigratesVisibleStartFromLegacyPreferences() {
        let preferences = NightWatchPreferences(
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            windDownMinutes: 90,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains,
            guardKind: .honorTimer,
            isConfigured: true
        )

        let routine = WindDownRoutine.primary(from: preferences)

        XCTAssertEqual(routine.role, .primarySleepBookend)
        XCTAssertEqual(routine.start, WindDownClockTime(hour: 21, minute: 30))
        XCTAssertEqual(routine.end, WindDownClockTime(hour: 7, minute: 0))
        XCTAssertTrue(routine.automaticStartEnabled)
    }

    func testRoutineCrossesMidnightUsingLocalCalendar() throws {
        let day = try date(2026, 8, 3, 12, 0)
        let routine = WindDownRoutine(
            title: "Morning quiet",
            role: .additionalQuiet,
            start: WindDownClockTime(hour: 23, minute: 30),
            end: WindDownClockTime(hour: 0, minute: 15)
        )

        let interval = try XCTUnwrap(routine.interval(on: day, calendar: calendar))

        XCTAssertEqual(interval.start, try date(2026, 8, 3, 23, 30))
        XCTAssertEqual(interval.end, try date(2026, 8, 4, 0, 15))
    }

    func testNextWindDownOverrideIsConsumedOnceAndExpires() throws {
        let start = try date(2026, 8, 3, 21, 0)
        let end = try date(2026, 8, 3, 22, 0)
        var override = NextWindDownOverride(
            routineID: UUID(),
            role: .additionalQuiet,
            interval: DateInterval(start: start, end: end),
            createdAt: try date(2026, 8, 3, 12, 0),
            expiresAt: try date(2026, 8, 4, 0, 0)
        )

        XCTAssertTrue(override.isAvailable(at: try date(2026, 8, 3, 20, 0)))
        XCTAssertTrue(override.consume(at: start))
        XCTAssertFalse(override.consume(at: start.addingTimeInterval(60)))
        XCTAssertFalse(override.isAvailable(at: try date(2026, 8, 3, 23, 0)))
    }

    func testScheduleEngineRejectsOverlappingOccurrences() throws {
        let day = try date(2026, 8, 3, 12, 0)
        let first = WindDownOccurrence(
            routineID: UUID(),
            role: .additionalQuiet,
            interval: DateInterval(
                start: try date(2026, 8, 3, 20, 0),
                end: try date(2026, 8, 3, 21, 0)
            )
        )
        let second = WindDownOccurrence(
            routineID: UUID(),
            role: .additionalQuiet,
            interval: DateInterval(
                start: try date(2026, 8, 3, 20, 30),
                end: try date(2026, 8, 3, 21, 30)
            )
        )
        XCTAssertNotNil(day)

        XCTAssertThrowsError(try WindDownScheduleEngine.validateNoOverlaps([first, second])) { error in
            guard case let WindDownScheduleError.overlappingOccurrences(firstID, secondID) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(firstID, first.id)
            XCTAssertEqual(secondID, second.id)
        }
    }

    func testHistoryAggregatesMultipleOccurrencesOnOneReportingDay() throws {
        let firstStart = try date(2026, 8, 3, 20, 0)
        let firstPlan = makePlan(startedAt: firstStart, bedtime: firstStart.addingTimeInterval(30 * 60))
        let first = NightWatchRecord(
            id: UUID(),
            plan: firstPlan,
            startedAt: firstStart,
            endedAt: firstPlan.protectedUntil,
            startMethod: .honorTimer,
            outcome: .completed,
            creditedWindDownMinutes: 30,
            creditedMorningQuietMinutes: 30,
            role: .primarySleepBookend,
            updatedAt: firstPlan.protectedUntil
        )

        let secondStart = try date(2026, 8, 3, 12, 0)
        let secondPlan = makePlan(startedAt: secondStart, bedtime: secondStart.addingTimeInterval(30 * 60))
        let second = NightWatchRecord(
            id: UUID(),
            plan: secondPlan,
            startedAt: secondStart,
            endedAt: secondStart.addingTimeInterval(30 * 60),
            startMethod: .honorTimer,
            outcome: .completed,
            creditedWindDownMinutes: 30,
            creditedMorningQuietMinutes: 0,
            role: .additionalQuiet,
            updatedAt: secondStart.addingTimeInterval(30 * 60)
        )

        let summaries = WindDownHistoryAggregator.daySummaries(
            from: [first, second],
            calendar: calendar
        )

        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries[0].occurrenceCount, 2)
        XCTAssertEqual(summaries[0].completedOccurrenceCount, 2)
        XCTAssertEqual(summaries[0].quietMinutes, 90)
        XCTAssertEqual(summaries[0].protectedNightCount, 1)
    }

    func testLegacyNightWatchRecordDefaultsToPrimaryRole() throws {
        let start = try date(2026, 8, 3, 20, 0)
        let record = NightWatchRecord(
            id: UUID(),
            plan: makePlan(startedAt: start, bedtime: start.addingTimeInterval(30 * 60)),
            startedAt: start,
            startMethod: .honorTimer
        )
        let encoded = try JSONEncoder().encode(record)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "role")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(NightWatchRecord.self, from: legacyData)

        XCTAssertEqual(decoded.role, .primarySleepBookend)
    }

    func testAdditionalQuietPlanCreditsOnlyItsOwnIntervalAndCannotProgress() throws {
        let start = try date(2026, 8, 3, 12, 0)
        let end = start.addingTimeInterval(45 * 60)
        let plan = NightWatchPlan.additionalQuiet(start: start, end: end)
        let run = FocusRun(
            plannedDurationSeconds: 45 * 60,
            startedAt: start,
            state: .completed,
            guardKind: .honorTimer,
            nightWatchPlan: plan
        )

        XCTAssertEqual(plan.role, .additionalQuiet)
        XCTAssertEqual(plan.creditedQuietMinutes(startedAt: start, through: end), 45)
        XCTAssertEqual(plan.creditedMorningQuietMinutes(startedAt: start, through: end), 0)
        XCTAssertFalse(run.isProgressionEligibleNightWatch)
        XCTAssertNil(RewardEngine().generateReward(for: run, progress: .empty))
    }

    private func makePlan(startedAt: Date, bedtime: Date) -> NightWatchPlan {
        NightWatchPlan(
            intendedBedtime: bedtime,
            wakeTime: bedtime.addingTimeInterval(8 * 60 * 60),
            protectedUntil: bedtime.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )))
    }
}
