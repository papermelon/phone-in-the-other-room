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

    func testWindDownUsesWakeDayAcrossMidnight() throws {
        let record = try primaryRecord(
            bedtime: date(2026, 8, 10, 22, 30),
            wake: date(2026, 8, 11, 7, 0),
            morningEnd: date(2026, 8, 11, 7, 45)
        )

        XCTAssertEqual(
            NightsHistoryAggregator.displayDay(for: record, calendar: calendar),
            date(2026, 8, 11)
        )
    }

    func testPhoneAwayUsesItsStartDayAcrossMidnight() {
        let record = phoneAwayRecord(
            start: date(2026, 8, 10, 23, 45),
            end: date(2026, 8, 11, 0, 15)
        )

        XCTAssertEqual(
            NightsHistoryAggregator.displayDay(for: record, calendar: calendar),
            date(2026, 8, 10)
        )
    }

    func testScreenFreeMorningUsesItsScheduledStartDay() {
        let occurrence = morningOccurrence(
            scheduledStart: date(2026, 8, 11, 23, 50),
            scheduledEnd: date(2026, 8, 12, 0, 20),
            actualStart: date(2026, 8, 11, 23, 55),
            endedAt: date(2026, 8, 12, 0, 15)
        )

        XCTAssertEqual(
            NightsHistoryAggregator.displayDay(for: occurrence, calendar: calendar),
            date(2026, 8, 11)
        )
    }

    func testMixedDayKeepsAllThreeCurrentSourcesIndependent() throws {
        let windDown = try primaryRecord(
            bedtime: date(2026, 8, 10, 22, 0),
            wake: date(2026, 8, 11, 7, 0),
            morningEnd: date(2026, 8, 11, 7, 45),
            windDownMinutes: 60
        )
        let morning = morningOccurrence(
            linkedRunID: windDown.id,
            scheduledStart: date(2026, 8, 11, 7, 0),
            scheduledEnd: date(2026, 8, 11, 7, 45),
            actualStart: date(2026, 8, 11, 7, 0),
            endedAt: date(2026, 8, 11, 7, 35)
        )
        let phoneAway = phoneAwayRecord(
            start: date(2026, 8, 11, 18, 0),
            end: date(2026, 8, 11, 18, 20)
        )

        let summary = NightsHistoryAggregator.summary(
            for: date(2026, 8, 11),
            from: [windDown, phoneAway],
            morningOccurrences: [morning],
            calendar: calendar
        )

        XCTAssertEqual(summary.primaryOutcome, .completed)
        XCTAssertEqual(summary.completedWindDownCount, 1)
        XCTAssertEqual(summary.windDownMinutes, 60)
        XCTAssertEqual(summary.completedScreenFreeMorningCount, 1)
        XCTAssertEqual(summary.screenFreeMorningMinutes, 35)
        XCTAssertEqual(summary.additionalCount, 1)
        XCTAssertEqual(summary.phoneAwayMinutes, 20)
        XCTAssertEqual(summary.totalOccurrenceCount, 3)
        XCTAssertEqual(summary.primaryRecordIDs, [windDown.id])
        XCTAssertEqual(summary.screenFreeMorningOccurrenceIDs, [morning.id])
        XCTAssertEqual(summary.additionalRecordIDs, [phoneAway.id])
    }

    func testMultipleEarlyEndedWindDownAttemptsRemainCounted() throws {
        let first = try primaryRecord(
            bedtime: date(2026, 8, 10, 22, 0),
            wake: date(2026, 8, 11, 7, 0),
            morningEnd: date(2026, 8, 11, 7, 30),
            outcome: .endedEarly,
            endedAt: date(2026, 8, 10, 21, 35),
            windDownMinutes: 0
        )
        let second = try primaryRecord(
            bedtime: date(2026, 8, 10, 22, 0),
            wake: date(2026, 8, 11, 7, 0),
            morningEnd: date(2026, 8, 11, 7, 30),
            outcome: .endedEarly,
            endedAt: date(2026, 8, 10, 21, 50),
            windDownMinutes: 0
        )

        let summary = NightsHistoryAggregator.summary(
            for: date(2026, 8, 11),
            from: [first, second],
            calendar: calendar
        )

        XCTAssertEqual(summary.primaryOutcome, .endedEarly)
        XCTAssertEqual(summary.primaryAttemptCount, 2)
        XCTAssertEqual(summary.earlyEndedPrimaryCount, 2)
        XCTAssertEqual(summary.completedWindDownCount, 0)
        XCTAssertEqual(summary.totalOccurrenceCount, 2)
    }

    func testScreenFreeMorningOnlyDayStaysVisible() {
        let morning = morningOccurrence(
            scheduledStart: date(2026, 8, 11, 7, 0),
            scheduledEnd: date(2026, 8, 11, 7, 45),
            actualStart: date(2026, 8, 11, 7, 3),
            endedAt: date(2026, 8, 11, 7, 32)
        )

        let summaries = NightsHistoryAggregator.month(
            from: [],
            morningOccurrences: [morning],
            containing: date(2026, 8, 1),
            calendar: calendar
        )

        XCTAssertEqual(summaries.count, 1)
        XCTAssertNil(summaries[0].primaryOutcome)
        XCTAssertEqual(summaries[0].screenFreeMorningCount, 1)
        XCTAssertEqual(summaries[0].screenFreeMorningMinutes, 29)
        XCTAssertTrue(summaries[0].hasRecords)
    }

    func testSkippedMorningIsASettledRecordWithoutInventedMinutes() {
        let morning = morningOccurrence(
            scheduledStart: date(2026, 8, 11, 7, 0),
            scheduledEnd: date(2026, 8, 11, 7, 30),
            endedAt: date(2026, 8, 11, 6, 45),
            outcome: .skipped
        )

        let summary = NightsHistoryAggregator.summary(
            for: date(2026, 8, 11),
            from: [],
            morningOccurrences: [morning],
            calendar: calendar
        )

        XCTAssertTrue(summary.hasRecords)
        XCTAssertEqual(summary.screenFreeMorningCount, 1)
        XCTAssertEqual(summary.skippedScreenFreeMorningCount, 1)
        XCTAssertEqual(summary.completedScreenFreeMorningCount, 0)
        XCTAssertEqual(summary.screenFreeMorningMinutes, 0)
    }

    func testPlannedAndActiveMorningsAreNotHistoricalRecords() {
        let planned = morningOccurrence(
            scheduledStart: date(2026, 8, 11, 7, 0),
            scheduledEnd: date(2026, 8, 11, 7, 30),
            outcome: .scheduled
        )
        let active = morningOccurrence(
            scheduledStart: date(2026, 8, 12, 7, 0),
            scheduledEnd: date(2026, 8, 12, 7, 30),
            actualStart: date(2026, 8, 12, 7, 0),
            outcome: .active
        )

        XCTAssertTrue(
            NightsHistoryAggregator.daySummaries(
                from: [],
                morningOccurrences: [planned, active],
                calendar: calendar
            ).isEmpty
        )
    }

    func testOverlappingScreenFreeMorningIntervalsCountOnce() {
        let first = morningOccurrence(
            scheduledStart: date(2026, 8, 11, 7, 0),
            scheduledEnd: date(2026, 8, 11, 7, 45),
            actualStart: date(2026, 8, 11, 7, 0),
            endedAt: date(2026, 8, 11, 7, 30)
        )
        let second = morningOccurrence(
            scheduledStart: date(2026, 8, 11, 7, 15),
            scheduledEnd: date(2026, 8, 11, 8, 0),
            actualStart: date(2026, 8, 11, 7, 15),
            endedAt: date(2026, 8, 11, 7, 45)
        )

        let summary = NightsHistoryAggregator.summary(
            for: date(2026, 8, 11),
            from: [],
            morningOccurrences: [first, second],
            calendar: calendar
        )

        XCTAssertEqual(summary.screenFreeMorningCount, 2)
        XCTAssertEqual(summary.screenFreeMorningMinutes, 45)
    }

    func testFinishedMorningWithoutActualStartDoesNotInferEvidence() {
        let occurrence = morningOccurrence(
            scheduledStart: date(2026, 8, 11, 7, 0),
            scheduledEnd: date(2026, 8, 11, 7, 30),
            endedAt: date(2026, 8, 11, 7, 30)
        )

        let summary = NightsHistoryAggregator.summary(
            for: date(2026, 8, 11),
            from: [],
            morningOccurrences: [occurrence],
            calendar: calendar
        )

        XCTAssertEqual(summary.completedScreenFreeMorningCount, 1)
        XCTAssertEqual(summary.screenFreeMorningMinutes, 0)
    }

    func testScreenFreeMorningMinutesRespectConfiguredDurationCap() {
        let occurrence = morningOccurrence(
            scheduledStart: date(2026, 8, 11, 7, 0),
            scheduledEnd: date(2026, 8, 11, 7, 30),
            actualStart: date(2026, 8, 11, 6, 45),
            endedAt: date(2026, 8, 11, 7, 30)
        )

        let summary = NightsHistoryAggregator.summary(
            for: date(2026, 8, 11),
            from: [],
            morningOccurrences: [occurrence],
            calendar: calendar
        )

        XCTAssertEqual(summary.screenFreeMorningMinutes, 30)
    }

    func testLegacyAfterWakingCreditStaysExplicitAndOutOfMorningTotal() throws {
        let legacy = try primaryRecord(
            bedtime: date(2026, 8, 10, 22, 0),
            wake: date(2026, 8, 11, 7, 0),
            morningEnd: date(2026, 8, 11, 7, 45),
            windDownMinutes: 60,
            legacyMorningMinutes: 45
        )
        let morning = morningOccurrence(
            linkedRunID: legacy.id,
            scheduledStart: date(2026, 8, 11, 7, 0),
            scheduledEnd: date(2026, 8, 11, 7, 45),
            actualStart: date(2026, 8, 11, 7, 0),
            endedAt: date(2026, 8, 11, 7, 30)
        )

        let summary = NightsHistoryAggregator.summary(
            for: date(2026, 8, 11),
            from: [legacy],
            morningOccurrences: [morning],
            calendar: calendar
        )

        XCTAssertEqual(summary.windDownMinutes, 60)
        XCTAssertEqual(summary.screenFreeMorningMinutes, 30)
        XCTAssertEqual(summary.legacyMorningQuietMinutes, 45)
        XCTAssertEqual(summary.legacyMorningRecordCount, 1)
        XCTAssertEqual(summary.totalOccurrenceCount, 2)
        XCTAssertEqual(summary.primaryQuietMinutes, 60)
    }

    func testOverlappingPhoneAwayPeriodsCountOnce() {
        let first = phoneAwayRecord(
            start: date(2026, 8, 11, 8, 0),
            end: date(2026, 8, 11, 8, 30)
        )
        let second = phoneAwayRecord(
            start: date(2026, 8, 11, 8, 15),
            end: date(2026, 8, 11, 8, 45)
        )

        let summary = NightsHistoryAggregator.summary(
            for: date(2026, 8, 11),
            from: [first, second],
            calendar: calendar
        )

        XCTAssertEqual(summary.additionalCount, 2)
        XCTAssertEqual(summary.phoneAwayMinutes, 45)
        XCTAssertEqual(summary.totalOccurrenceCount, 2)
    }

    func testMonthRangeKeepsSourceTotalsSeparateAndUnionsEachSource() throws {
        let windDown = try primaryRecord(
            bedtime: date(2026, 8, 10, 22, 0),
            wake: date(2026, 8, 11, 7, 0),
            morningEnd: date(2026, 8, 11, 7, 30),
            windDownMinutes: 60,
            legacyMorningMinutes: 30
        )
        let morning = morningOccurrence(
            linkedRunID: windDown.id,
            scheduledStart: date(2026, 8, 11, 7, 0),
            scheduledEnd: date(2026, 8, 11, 7, 30),
            actualStart: date(2026, 8, 11, 7, 0),
            endedAt: date(2026, 8, 11, 7, 30)
        )
        let firstPhoneAway = phoneAwayRecord(
            start: date(2026, 8, 10, 23, 45),
            end: date(2026, 8, 11, 0, 30)
        )
        let secondPhoneAway = phoneAwayRecord(
            start: date(2026, 8, 11, 0, 0),
            end: date(2026, 8, 11, 0, 45)
        )

        let summary = NightsHistoryAggregator.monthSummary(
            from: [windDown, firstPhoneAway, secondPhoneAway],
            morningOccurrences: [morning],
            containing: date(2026, 8, 1),
            calendar: calendar
        )

        XCTAssertEqual(summary.completedWindDownCount, 1)
        XCTAssertEqual(summary.windDownMinutes, 60)
        XCTAssertEqual(summary.screenFreeMorningMinutes, 30)
        XCTAssertEqual(summary.phoneAwayMinutes, 60)
        XCTAssertEqual(summary.legacyMorningQuietMinutes, 30)
        XCTAssertEqual(summary.totalOccurrenceCount, 4)
    }

    func testWeekAlwaysContainsSevenDaysAndIncludesMorningOnlyDay() {
        let end = date(2026, 8, 11, 18, 0)
        let morning = morningOccurrence(
            scheduledStart: date(2026, 8, 9, 7, 0),
            scheduledEnd: date(2026, 8, 9, 7, 30),
            actualStart: date(2026, 8, 9, 7, 0),
            endedAt: date(2026, 8, 9, 7, 20)
        )

        let week = NightsHistoryAggregator.week(
            from: [],
            morningOccurrences: [morning],
            endingAt: end,
            calendar: calendar
        )

        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.first?.day, date(2026, 8, 5))
        XCTAssertEqual(week.last?.day, date(2026, 8, 11))
        XCTAssertEqual(week.filter(\.hasRecords).count, 1)
        XCTAssertEqual(week.first { calendar.isDate($0.day, inSameDayAs: date(2026, 8, 9)) }?.screenFreeMorningMinutes, 20)
    }

    func testDisplayDayRespectsProvidedTimeZone() throws {
        var singapore = Calendar(identifier: .gregorian)
        singapore.timeZone = TimeZone(identifier: "Asia/Singapore")!
        let record = try primaryRecord(
            bedtime: date(2026, 8, 10, 14, 0),
            wake: date(2026, 8, 10, 23, 30),
            morningEnd: date(2026, 8, 11, 0, 0)
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

    func testLatestWindDownIsNotDisplacedByNewerPhoneAway() throws {
        let windDown = try primaryRecord(
            bedtime: date(2026, 8, 9, 22, 0),
            wake: date(2026, 8, 10, 7, 0),
            morningEnd: date(2026, 8, 10, 7, 30)
        )
        let phoneAway = phoneAwayRecord(
            start: date(2026, 8, 11, 18, 0),
            end: date(2026, 8, 11, 18, 30)
        )

        XCTAssertEqual(
            NightsHistoryAggregator.latestPrimaryRecord(from: [windDown, phoneAway])?.id,
            windDown.id
        )
        XCTAssertEqual(
            NightsHistoryAggregator.latestAdditionalRecord(from: [windDown, phoneAway])?.id,
            phoneAway.id
        )
    }

    private func primaryRecord(
        bedtime: Date,
        wake: Date,
        morningEnd: Date,
        outcome: NightWatchOutcome = .completed,
        endedAt: Date? = nil,
        windDownMinutes: Int = 30,
        legacyMorningMinutes: Int = 0
    ) throws -> NightWatchRecord {
        let plan = NightWatchPlan(
            intendedBedtime: bedtime,
            wakeTime: wake,
            protectedUntil: morningEnd,
            windDownMinutes: max(30, windDownMinutes),
            morningQuietMinutes: max(30, Int(morningEnd.timeIntervalSince(wake) / 60)),
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        let start = bedtime.addingTimeInterval(TimeInterval(-windDownMinutes * 60))
        let finish = endedAt ?? morningEnd
        return NightWatchRecord(
            id: UUID(),
            plan: plan,
            startedAt: start,
            endedAt: finish,
            startMethod: .honorTimer,
            outcome: outcome,
            creditedWindDownMinutes: windDownMinutes,
            creditedMorningQuietMinutes: legacyMorningMinutes,
            role: .primarySleepBookend,
            updatedAt: finish
        )
    }

    private func phoneAwayRecord(start: Date, end: Date) -> NightWatchRecord {
        let minutes = Int(end.timeIntervalSince(start) / 60)
        return NightWatchRecord(
            id: UUID(),
            plan: NightWatchPlan.additionalQuiet(start: start, end: end),
            startedAt: start,
            endedAt: end,
            startMethod: .honorTimer,
            outcome: .completed,
            creditedWindDownMinutes: minutes,
            role: .additionalQuiet,
            updatedAt: end
        )
    }

    private func morningOccurrence(
        linkedRunID: UUID? = nil,
        scheduledStart: Date,
        scheduledEnd: Date,
        actualStart: Date? = nil,
        endedAt: Date? = nil,
        outcome: MorningQuietOccurrenceOutcome = .finished
    ) -> MorningQuietOccurrence {
        MorningQuietOccurrence(
            linkedWindDownRunID: linkedRunID,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            actualStart: actualStart,
            endedAt: endedAt,
            outcome: outcome
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
