import XCTest

final class NightsHistorySummaryTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        self.calendar = calendar
    }

    func testPrimaryNightUsesWakeDayAcrossMidnight() throws {
        let record = try primaryRecord(
            bedtime: date(2026, 8, 10, 22, 30),
            wake: date(2026, 8, 11, 7, 0),
            protectedUntil: date(2026, 8, 11, 7, 45)
        )

        XCTAssertEqual(
            NightsHistoryAggregator.displayDay(for: record, calendar: calendar),
            date(2026, 8, 11)
        )
    }

    func testAdditionalQuietUsesItsActualStartDayAcrossMidnight() throws {
        let record = additionalRecord(
            start: date(2026, 8, 10, 23, 45),
            end: date(2026, 8, 11, 0, 15)
        )

        XCTAssertEqual(
            NightsHistoryAggregator.displayDay(for: record, calendar: calendar),
            date(2026, 8, 10)
        )
    }

    func testMixedDayKeepsPrimaryAndAdditionalStateIndependent() throws {
        let primary = try primaryRecord(
            bedtime: date(2026, 8, 10, 22, 0),
            wake: date(2026, 8, 11, 7, 0),
            protectedUntil: date(2026, 8, 11, 7, 45),
            windDownMinutes: 60,
            morningMinutes: 45
        )
        let additional = additionalRecord(
            start: date(2026, 8, 11, 18, 0),
            end: date(2026, 8, 11, 18, 20)
        )

        let summary = NightsHistoryAggregator.summary(
            for: date(2026, 8, 11),
            from: [primary, additional],
            calendar: calendar
        )

        XCTAssertEqual(summary.primaryOutcome, .protected)
        XCTAssertEqual(summary.primaryAttemptCount, 1)
        XCTAssertEqual(summary.protectedNightCount, 1)
        XCTAssertEqual(summary.protectedWindDownMinutes, 60)
        XCTAssertEqual(summary.protectedMorningQuietMinutes, 45)
        XCTAssertEqual(summary.additionalCount, 1)
        XCTAssertEqual(summary.additionalQuietMinutes, 20)
        XCTAssertEqual(summary.totalOccurrenceCount, 2)
        XCTAssertEqual(summary.primaryRecordIDs, [primary.id])
        XCTAssertEqual(summary.additionalRecordIDs, [additional.id])
    }

    func testMultipleEarlyEndedPrimaryAttemptsRemainCounted() throws {
        let first = try primaryRecord(
            bedtime: date(2026, 8, 10, 22, 0),
            wake: date(2026, 8, 11, 7, 0),
            protectedUntil: date(2026, 8, 11, 7, 30),
            outcome: .endedEarly,
            endedAt: date(2026, 8, 10, 21, 35),
            windDownMinutes: 0,
            morningMinutes: 0
        )
        let second = try primaryRecord(
            bedtime: date(2026, 8, 10, 22, 0),
            wake: date(2026, 8, 11, 7, 0),
            protectedUntil: date(2026, 8, 11, 7, 30),
            outcome: .endedEarly,
            endedAt: date(2026, 8, 10, 21, 50),
            windDownMinutes: 0,
            morningMinutes: 0
        )

        let summary = NightsHistoryAggregator.summary(
            for: date(2026, 8, 11),
            from: [first, second],
            calendar: calendar
        )

        XCTAssertEqual(summary.primaryOutcome, .endedEarly)
        XCTAssertEqual(summary.primaryAttemptCount, 2)
        XCTAssertEqual(summary.earlyEndedPrimaryCount, 2)
        XCTAssertEqual(summary.protectedNightCount, 0)
        XCTAssertEqual(summary.totalOccurrenceCount, 2)
    }

    func testOccurrenceCountAndRecordIDsIncludeEveryMixedPeriod() throws {
        let protected = try primaryRecord(
            bedtime: date(2026, 8, 10, 22, 0),
            wake: date(2026, 8, 11, 7, 0),
            protectedUntil: date(2026, 8, 11, 7, 30)
        )
        let early = try primaryRecord(
            bedtime: date(2026, 8, 10, 22, 0),
            wake: date(2026, 8, 11, 7, 0),
            protectedUntil: date(2026, 8, 11, 7, 30),
            outcome: .endedEarly,
            endedAt: date(2026, 8, 10, 21, 50),
            windDownMinutes: 0,
            morningMinutes: 0
        )
        let firstAdditional = additionalRecord(
            start: date(2026, 8, 11, 12, 0),
            end: date(2026, 8, 11, 12, 15)
        )
        let secondAdditional = additionalRecord(
            start: date(2026, 8, 11, 18, 0),
            end: date(2026, 8, 11, 18, 20)
        )

        let summary = NightsHistoryAggregator.summary(
            for: date(2026, 8, 11),
            from: [protected, early, firstAdditional, secondAdditional],
            calendar: calendar
        )

        XCTAssertEqual(summary.primaryOutcome, .protected)
        XCTAssertEqual(summary.earlyEndedPrimaryCount, 1)
        XCTAssertEqual(summary.totalOccurrenceCount, 4)
        XCTAssertEqual(Set(summary.primaryRecordIDs), Set([protected.id, early.id]))
        XCTAssertEqual(
            Set(summary.additionalRecordIDs),
            Set([firstAdditional.id, secondAdditional.id])
        )
    }

    func testAdditionalOnlyDayStaysVisible() {
        let record = additionalRecord(
            start: date(2026, 8, 11, 18, 0),
            end: date(2026, 8, 11, 18, 29)
        )

        let summaries = NightsHistoryAggregator.month(
            from: [record],
            containing: date(2026, 8, 1),
            calendar: calendar
        )

        XCTAssertEqual(summaries.count, 1)
        XCTAssertNil(summaries[0].primaryOutcome)
        XCTAssertEqual(summaries[0].additionalCount, 1)
        XCTAssertEqual(summaries[0].additionalQuietMinutes, 29)
        XCTAssertTrue(summaries[0].hasRecords)
    }

    func testOverlappingAdditionalIntervalsAreCountedOnce() {
        let first = additionalRecord(
            start: date(2026, 8, 11, 8, 0),
            end: date(2026, 8, 11, 8, 30)
        )
        let second = additionalRecord(
            start: date(2026, 8, 11, 8, 15),
            end: date(2026, 8, 11, 8, 45)
        )

        let summary = NightsHistoryAggregator.summary(
            for: date(2026, 8, 11),
            from: [first, second],
            calendar: calendar
        )

        XCTAssertEqual(summary.additionalCount, 2)
        XCTAssertEqual(summary.additionalQuietMinutes, 45)
        XCTAssertEqual(summary.recordedQuietMinutes, 45)
        XCTAssertEqual(summary.totalOccurrenceCount, 2)
    }

    func testMonthTotalsUnionOverlapsAcrossDifferentDisplayDays() throws {
        let primary = try primaryRecord(
            bedtime: date(2026, 8, 10, 22, 0),
            wake: date(2026, 8, 11, 7, 0),
            protectedUntil: date(2026, 8, 11, 7, 30),
            windDownMinutes: 60,
            morningMinutes: 30
        )
        let additional = additionalRecord(
            start: date(2026, 8, 10, 21, 30),
            end: date(2026, 8, 10, 22, 30)
        )

        let summary = NightsHistoryAggregator.monthSummary(
            from: [primary, additional],
            containing: date(2026, 8, 1),
            calendar: calendar
        )

        XCTAssertEqual(summary.days.count, 2)
        XCTAssertEqual(summary.totalOccurrenceCount, 2)
        XCTAssertEqual(summary.recordedQuietMinutes, 120)
    }

    func testWeekAlwaysContainsSevenOrderedDaysIncludingEmptyDays() {
        let end = date(2026, 8, 11, 18, 0)

        let week = NightsHistoryAggregator.week(
            from: [],
            endingAt: end,
            calendar: calendar
        )

        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.first?.day, date(2026, 8, 5))
        XCTAssertEqual(week.last?.day, date(2026, 8, 11))
        XCTAssertTrue(week.allSatisfy { !$0.hasRecords })
    }

    func testDisplayDayRespectsProvidedTimeZone() throws {
        var singapore = Calendar(identifier: .gregorian)
        singapore.timeZone = TimeZone(identifier: "Asia/Singapore")!
        let record = try primaryRecord(
            bedtime: date(2026, 8, 10, 14, 0),
            wake: date(2026, 8, 10, 23, 30),
            protectedUntil: date(2026, 8, 11, 0, 0)
        )

        let displayDay = NightsHistoryAggregator.displayDay(
            for: record,
            calendar: singapore
        )

        XCTAssertEqual(
            singapore.dateComponents([.year, .month, .day], from: displayDay),
            DateComponents(year: 2026, month: 8, day: 11)
        )
    }

    func testLatestPrimaryIsNotDisplacedByNewerAdditionalQuiet() throws {
        let primary = try primaryRecord(
            bedtime: date(2026, 8, 9, 22, 0),
            wake: date(2026, 8, 10, 7, 0),
            protectedUntil: date(2026, 8, 10, 7, 30)
        )
        let additional = additionalRecord(
            start: date(2026, 8, 11, 18, 0),
            end: date(2026, 8, 11, 18, 30)
        )

        XCTAssertEqual(
            NightsHistoryAggregator.latestPrimaryRecord(from: [primary, additional])?.id,
            primary.id
        )
        XCTAssertEqual(
            NightsHistoryAggregator.latestAdditionalRecord(from: [primary, additional])?.id,
            additional.id
        )
    }

    func testLatestPrimaryUsesNightEndingDayInsteadOfLateRecordUpdate() throws {
        let olderNightUpdatedLate = try primaryRecord(
            bedtime: date(2026, 8, 9, 22, 0),
            wake: date(2026, 8, 10, 7, 0),
            protectedUntil: date(2026, 8, 10, 7, 30),
            endedAt: date(2026, 8, 12, 9, 0)
        )
        let newerNight = try primaryRecord(
            bedtime: date(2026, 8, 10, 22, 0),
            wake: date(2026, 8, 11, 7, 0),
            protectedUntil: date(2026, 8, 11, 7, 30)
        )

        XCTAssertEqual(
            NightsHistoryAggregator.latestPrimaryRecord(
                from: [olderNightUpdatedLate, newerNight]
            )?.id,
            newerNight.id
        )
    }

    private func primaryRecord(
        bedtime: Date,
        wake: Date,
        protectedUntil: Date,
        outcome: NightWatchOutcome = .completed,
        endedAt: Date? = nil,
        windDownMinutes: Int = 30,
        morningMinutes: Int = 30
    ) throws -> NightWatchRecord {
        let plan = NightWatchPlan(
            intendedBedtime: bedtime,
            wakeTime: wake,
            protectedUntil: protectedUntil,
            windDownMinutes: max(30, windDownMinutes),
            morningQuietMinutes: max(30, morningMinutes),
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        let start = bedtime.addingTimeInterval(TimeInterval(-windDownMinutes * 60))
        let finish = endedAt ?? protectedUntil
        return NightWatchRecord(
            id: UUID(),
            plan: plan,
            startedAt: start,
            endedAt: finish,
            startMethod: .honorTimer,
            outcome: outcome,
            creditedWindDownMinutes: windDownMinutes,
            creditedMorningQuietMinutes: morningMinutes,
            role: .primarySleepBookend,
            updatedAt: finish
        )
    }

    private func additionalRecord(
        start: Date,
        end: Date
    ) -> NightWatchRecord {
        let minutes = Int(end.timeIntervalSince(start) / 60)
        let plan = NightWatchPlan.additionalQuiet(start: start, end: end)
        return NightWatchRecord(
            id: UUID(),
            plan: plan,
            startedAt: start,
            endedAt: end,
            startMethod: .honorTimer,
            outcome: .completed,
            creditedWindDownMinutes: minutes,
            creditedMorningQuietMinutes: 0,
            role: .additionalQuiet,
            updatedAt: end
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }
}
