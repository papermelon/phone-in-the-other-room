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

    func testCrossMidnightRoutineIsEligibleAfterMidnight() throws {
        let routine = WindDownRoutine(
            title: "Late quiet",
            role: .additionalQuiet,
            start: WindDownClockTime(hour: 23, minute: 30),
            end: WindDownClockTime(hour: 1, minute: 30),
            recurrence: .daily
        )
        let state = WindDownScheduleState(routines: [routine])

        let eligible = WindDownScheduleEngine.eligibleOccurrence(
            in: state,
            at: try date(2026, 8, 4, 0, 45),
            calendar: calendar
        )

        XCTAssertEqual(eligible?.title, "Late quiet")
        XCTAssertEqual(eligible?.occurrence.routineID, routine.id)
        XCTAssertEqual(eligible?.occurrence.interval.start, try date(2026, 8, 3, 23, 30))
    }

    func testRecurringSourceIdentitySurvivesOccurrenceRecalculation() throws {
        let routine = WindDownRoutine(
            title: "Evening quiet",
            role: .additionalQuiet,
            start: WindDownClockTime(hour: 20, minute: 0),
            end: WindDownClockTime(hour: 21, minute: 0),
            recurrence: .daily
        )
        let state = WindDownScheduleState(routines: [routine])
        let now = try date(2026, 8, 3, 20, 15)

        let requested = try XCTUnwrap(
            WindDownScheduleEngine.eligibleOccurrence(in: state, at: now, calendar: calendar)
        )
        let confirmed = try XCTUnwrap(
            WindDownScheduleEngine.eligibleOccurrence(
                in: state,
                at: now.addingTimeInterval(1),
                calendar: calendar
            )
        )

        XCTAssertNotEqual(requested.id, confirmed.id)
        XCTAssertEqual(requested.sourceID, routine.id)
        XCTAssertEqual(confirmed.sourceID, requested.sourceID)
    }

    func testScheduledPhoneAwayStartStaysSecondaryToWindDown() throws {
        let now = try date(2026, 8, 3, 20, 15)
        let period = WindDownOneTimePeriod(
            title: "A little room",
            role: .additionalQuiet,
            interval: DateInterval(start: now.addingTimeInterval(-15 * 60), end: now.addingTimeInterval(45 * 60))
        )
        let eligible = try XCTUnwrap(
            WindDownScheduleEngine.eligibleOccurrence(
                in: WindDownScheduleState(oneTimePeriods: [period]),
                at: now,
                calendar: calendar
            )
        )
        let context = WindDownStartContext(period: eligible, practicePeriodID: nil)

        XCTAssertTrue(context.isAdditionalQuiet)
        XCTAssertEqual(context.kind, .oneTimeQuiet)
        XCTAssertNotEqual(context.kind, .primary)
        XCTAssertEqual(context.title, "A little room")
    }

    func testLegacyPhoneBreakTitlesRenderAsPhoneAwayWithoutChangingStoredTitle() throws {
        let now = try date(2026, 8, 3, 20, 15)
        let period = WindDownOneTimePeriod(
            title: "Phone Break",
            role: .additionalQuiet,
            interval: DateInterval(
                start: now.addingTimeInterval(-15 * 60),
                end: now.addingTimeInterval(45 * 60)
            )
        )
        let eligible = try XCTUnwrap(
            WindDownScheduleEngine.eligibleOccurrence(
                in: WindDownScheduleState(oneTimePeriods: [period]),
                at: now,
                calendar: calendar
            )
        )

        XCTAssertEqual(period.title, "Phone Break")
        XCTAssertEqual(period.userFacingTitle, "Phone Away")
        XCTAssertEqual(eligible.title, "Phone Away")
    }

    func testRecurringPrimaryRestartIgnoresConsumedOccurrenceStateWithinProtectedWindow() throws {
        let preferences = NightWatchPreferences(
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains,
            guardKind: .honorTimer,
            isConfigured: true
        )
        let routine = WindDownRoutine.primary(from: preferences)
        let state = WindDownScheduleState(routines: [routine])
        let restartedAt = try date(2026, 8, 4, 5, 14)
        let eligible = try XCTUnwrap(
            WindDownScheduleEngine.eligibleOccurrence(
                in: state,
                at: restartedAt,
                calendar: calendar,
                primaryExtensionMinutes: preferences.morningQuietMinutes
            )
        )
        var consumedOccurrence = eligible.occurrence
        consumedOccurrence.state = .endedEarly
        let period = WindDownSchedulePeriod(
            occurrence: consumedOccurrence,
            title: eligible.title,
            recurring: eligible.recurring
        )

        let plan = WindDownScheduleEngine.plan(
            for: period,
            preferences: preferences,
            startedAt: restartedAt,
            calendar: calendar
        )

        XCTAssertEqual(plan.intendedBedtime, try date(2026, 8, 3, 23, 0))
        XCTAssertEqual(plan.phase(at: restartedAt), .overnight)
        XCTAssertEqual(plan.nextTransition(after: restartedAt), try date(2026, 8, 4, 7, 0))
    }

    func testOneTimeSourceIdentityUsesThePersistedPeriodID() throws {
        let now = try date(2026, 8, 3, 20, 15)
        let period = WindDownOneTimePeriod(
            title: "Practice quiet",
            interval: DateInterval(start: now, end: now.addingTimeInterval(5 * 60))
        )
        let state = WindDownScheduleState(oneTimePeriods: [period])

        let eligible = try XCTUnwrap(
            WindDownScheduleEngine.eligibleOccurrence(in: state, at: now, calendar: calendar)
        )

        XCTAssertEqual(eligible.sourceID, period.id)
    }

    func testExactEligibleOccurrenceUsesTheRequestedScheduledPeriod() throws {
        let now = try date(2026, 8, 3, 20, 15)
        let usual = WindDownRoutine(
            title: "Usual Wind Down",
            role: .primarySleepBookend,
            start: WindDownClockTime(hour: 20, minute: 0),
            end: WindDownClockTime(hour: 22, minute: 0)
        )
        let oneTime = WindDownOneTimePeriod(
            id: UUID(),
            title: "A saved one-time quiet",
            role: .primarySleepBookend,
            interval: DateInterval(
                start: now.addingTimeInterval(-60),
                end: now.addingTimeInterval(45 * 60)
            )
        )
        let state = WindDownScheduleState(oneTimePeriods: [oneTime], routines: [usual])

        let selected = try XCTUnwrap(
            WindDownScheduleEngine.eligibleOccurrence(
                in: state,
                at: now,
                sourceID: oneTime.id,
                calendar: calendar
            )
        )

        XCTAssertEqual(selected.sourceID, oneTime.id)
        XCTAssertEqual(selected.title, oneTime.title)
        XCTAssertEqual(selected.occurrence.interval, oneTime.interval)
    }

    func testCancellingAdHocStartTransactionRollsBackOnlyItsTemporaryPeriod() throws {
        let now = try date(2026, 8, 3, 20, 15)
        let existing = WindDownOneTimePeriod(
            title: "Keep this scheduled quiet",
            interval: DateInterval(start: now.addingTimeInterval(60 * 60), end: now.addingTimeInterval(90 * 60))
        )
        let temporary = WindDownOneTimePeriod(
            title: "Temporary quiet",
            interval: DateInterval(start: now, end: now.addingTimeInterval(30 * 60))
        )
        var schedule = WindDownScheduleState(oneTimePeriods: [existing, temporary])
        let transaction = WindDownStartTransaction(createdOneTimePeriodID: temporary.id)

        XCTAssertTrue(transaction.cancel(in: &schedule))
        XCTAssertEqual(schedule.oneTimePeriods.map(\.id), [existing.id])
        XCTAssertFalse(transaction.cancel(in: &schedule))
    }

    func testRecurringPrimaryPlanUsesSavedBedtimeRatherThanRoutineWakeEnd() throws {
        let preferences = NightWatchPreferences(
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains,
            guardKind: .honorTimer,
            isConfigured: true
        )
        let routine = WindDownRoutine.primary(from: preferences)
        let state = WindDownScheduleState(routines: [routine])
        let startedAt = try date(2026, 8, 3, 22, 30)
        let period = try XCTUnwrap(
            WindDownScheduleEngine.eligibleOccurrence(
                in: state,
                at: startedAt,
                calendar: calendar,
                primaryExtensionMinutes: preferences.morningQuietMinutes
            )
        )

        let plan = WindDownScheduleEngine.plan(
            for: period,
            preferences: preferences,
            startedAt: startedAt,
            calendar: calendar
        )

        XCTAssertEqual(plan.intendedBedtime, try date(2026, 8, 3, 23, 0))
        XCTAssertEqual(plan.wakeTime, try date(2026, 8, 4, 7, 0))
        XCTAssertEqual(plan.protectedUntil, try date(2026, 8, 4, 7, 30))
        XCTAssertEqual(plan.windDownMinutes, 30)
    }

    func testLateOneTimePlanCountsOnlyFromConfirmationUntilItsSavedEnd() throws {
        let now = try date(2026, 8, 3, 20, 15)
        let period = WindDownSchedulePeriod(
            occurrence: WindDownOccurrence(
                id: UUID(),
                routineID: UUID(),
                role: .additionalQuiet,
                interval: DateInterval(
                    start: now.addingTimeInterval(-10 * 60),
                    end: now.addingTimeInterval(5 * 60)
                )
            ),
            title: "Practice quiet",
            recurring: false
        )

        let plan = WindDownScheduleEngine.plan(
            for: period,
            preferences: .defaults,
            startedAt: now,
            calendar: calendar
        )

        XCTAssertEqual(plan.intendedBedtime, now)
        XCTAssertEqual(plan.protectedUntil, now.addingTimeInterval(5 * 60))
        XCTAssertEqual(plan.creditedQuietMinutes(startedAt: now, through: plan.protectedUntil), 5)
        XCTAssertEqual(plan.role, .additionalQuiet)
    }

    func testEmptyCustomRecurrenceIsInvalid() {
        XCTAssertFalse(WindDownRecurrence.custom([]).isValid)
        XCTAssertTrue(WindDownRecurrence.custom([2]).isValid)
        XCTAssertTrue(WindDownRecurrence.daily.isValid)
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
        let firstRoutineID = UUID()
        let secondRoutineID = UUID()
        let first = WindDownOccurrence(
            routineID: firstRoutineID,
            role: .additionalQuiet,
            interval: DateInterval(
                start: try date(2026, 8, 3, 20, 0),
                end: try date(2026, 8, 3, 21, 0)
            )
        )
        let second = WindDownOccurrence(
            routineID: secondRoutineID,
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
            XCTAssertEqual(firstID, firstRoutineID)
            XCTAssertEqual(secondID, secondRoutineID)
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

    func testLegacyRoutineDecodingMigratesWeekdayShapeToSemanticRecurrence() throws {
        let legacy = Data("""
        {"schemaVersion":1,"id":"00000000-0000-0000-0000-000000000001","title":"Study","role":"additionalQuiet","start":{"hour":12,"minute":0},"end":{"hour":13,"minute":0},"weekdays":[2,3,4,5,6],"enabled":true,"automaticStartEnabled":true}
        """.utf8)

        let routine = try JSONDecoder().decode(WindDownRoutine.self, from: legacy)

        XCTAssertEqual(routine.recurrence, .weekdays)
        XCTAssertEqual(routine.weekdays, Array(2...6))
        XCTAssertTrue(routine.automaticStartEnabled)
    }

    func testScheduleMigrationRetainsLegacyPluralRoutinesAndSingularOverride() throws {
        let routine = WindDownRoutine(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            title: "Read",
            role: .additionalQuiet,
            start: WindDownClockTime(hour: 12, minute: 0),
            end: WindDownClockTime(hour: 13, minute: 0),
            recurrence: .weekdays
        )
        let start = try date(2026, 8, 4, 15, 0)
        let override = NextWindDownOverride(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            routineID: routine.id,
            role: .additionalQuiet,
            interval: DateInterval(start: start, end: start.addingTimeInterval(45 * 60)),
            expiresAt: start.addingTimeInterval(45 * 60)
        )

        let state = WindDownScheduleState.migrated(routines: [routine], nextOverride: override)

        XCTAssertEqual(state.routines, [routine])
        XCTAssertEqual(state.oneTimePeriods.count, 1)
        XCTAssertEqual(state.oneTimePeriods[0].id, override.id)
        XCTAssertEqual(state.oneTimePeriods[0].interval, override.interval)
    }

    func testMultipleOneTimePeriodsAreOrderedPrunedAndConsumedIdempotently() throws {
        let now = try date(2026, 8, 3, 12, 0)
        let passed = WindDownOneTimePeriod(
            title: "Passed",
            interval: DateInterval(start: now.addingTimeInterval(-2 * 60 * 60), end: now.addingTimeInterval(-60))
        )
        let later = WindDownOneTimePeriod(
            title: "Later",
            interval: DateInterval(start: now.addingTimeInterval(4 * 60 * 60), end: now.addingTimeInterval(5 * 60 * 60))
        )
        let sooner = WindDownOneTimePeriod(
            title: "Sooner",
            interval: DateInterval(start: now.addingTimeInterval(60 * 60), end: now.addingTimeInterval(2 * 60 * 60))
        )
        var state = WindDownScheduleState(oneTimePeriods: [passed, later, sooner])

        state.prunePassedOneTimePeriods(at: now)
        XCTAssertEqual(state.upcomingPeriods(after: now).map(\.title), ["Sooner", "Later"])
        XCTAssertTrue(state.consumeOneTimePeriod(id: sooner.id))
        XCTAssertFalse(state.consumeOneTimePeriod(id: sooner.id))
        XCTAssertEqual(state.upcomingPeriods(after: now).map(\.title), ["Later"])
    }

    func testDisabledOneTimePeriodRemainsSavedButCannotRun() throws {
        let now = try date(2026, 8, 3, 12, 0)
        let disabled = WindDownOneTimePeriod(
            title: "Paused",
            interval: DateInterval(
                start: now.addingTimeInterval(60 * 60),
                end: now.addingTimeInterval(2 * 60 * 60)
            ),
            enabled: false
        )
        var state = WindDownScheduleState(oneTimePeriods: [disabled])

        state.prunePassedOneTimePeriods(at: now)

        XCTAssertEqual(state.oneTimePeriods.map(\.id), [disabled.id])
        XCTAssertNil(disabled.occurrence())
        XCTAssertFalse(state.consumeOneTimePeriod(id: disabled.id))
    }

    func testRecurrenceSupportsDailyWeekdaysAndCustomDays() throws {
        let day = try date(2026, 8, 3, 9, 0) // Monday in the test calendar.
        let daily = WindDownRoutine(
            title: "Daily", role: .additionalQuiet,
            start: WindDownClockTime(hour: 10, minute: 0), end: WindDownClockTime(hour: 11, minute: 0),
            recurrence: .daily
        )
        let weekdays = WindDownRoutine(
            title: "Weekdays", role: .additionalQuiet,
            start: WindDownClockTime(hour: 12, minute: 0), end: WindDownClockTime(hour: 13, minute: 0),
            recurrence: .weekdays
        )
        let custom = WindDownRoutine(
            title: "Custom", role: .additionalQuiet,
            start: WindDownClockTime(hour: 14, minute: 0), end: WindDownClockTime(hour: 15, minute: 0),
            recurrence: .custom([1, 7])
        )

        XCTAssertNotNil(daily.interval(on: day, calendar: calendar))
        XCTAssertNotNil(weekdays.interval(on: day, calendar: calendar))
        XCTAssertNil(custom.interval(on: day, calendar: calendar))
        XCTAssertNotNil(custom.interval(on: try date(2026, 8, 9, 9, 0), calendar: calendar))
    }

    func testOverlapBoundaryIsAllowedAndConflictIdentifiesBothPeriods() throws {
        let firstRoutineID = UUID(uuidString: "00000000-0000-0000-0000-000000000040")!
        let first = WindDownOccurrence(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000020")!,
            routineID: firstRoutineID, role: .additionalQuiet,
            interval: DateInterval(start: try date(2026, 8, 3, 20, 0), end: try date(2026, 8, 3, 21, 0))
        )
        let touching = WindDownOccurrence(
            id: UUID(), routineID: UUID(), role: .additionalQuiet,
            interval: DateInterval(start: try date(2026, 8, 3, 21, 0), end: try date(2026, 8, 3, 22, 0))
        )
        XCTAssertNoThrow(try WindDownScheduleEngine.validateNoOverlaps([first, touching]))

        let conflictRoutineID = UUID(uuidString: "00000000-0000-0000-0000-000000000041")!
        let conflict = WindDownOccurrence(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000021")!,
            routineID: conflictRoutineID, role: .additionalQuiet,
            interval: DateInterval(start: try date(2026, 8, 3, 20, 30), end: try date(2026, 8, 3, 21, 30))
        )
        XCTAssertThrowsError(try WindDownScheduleEngine.validateNoOverlaps([first, conflict])) { error in
            XCTAssertEqual(error as? WindDownScheduleError, .overlappingOccurrences(firstRoutineID, conflictRoutineID))
        }
    }

    func testEarliestAcrossOneTimeAndRecurringIsSelected() throws {
        let now = try date(2026, 8, 3, 9, 0)
        let routine = WindDownRoutine(
            title: "Repeating", role: .additionalQuiet,
            start: WindDownClockTime(hour: 11, minute: 0), end: WindDownClockTime(hour: 12, minute: 0),
            recurrence: .daily
        )
        let oneTime = WindDownOneTimePeriod(
            title: "Saved once",
            interval: DateInterval(start: now.addingTimeInterval(90 * 60), end: now.addingTimeInterval(150 * 60))
        )
        let state = WindDownScheduleState(oneTimePeriods: [oneTime], routines: [routine])

        XCTAssertEqual(state.upcomingPeriods(after: now, calendar: calendar, limit: 1).first?.title, "Saved once")
        XCTAssertNil(WindDownScheduleEngine.eligibleOccurrence(in: state, at: now, calendar: calendar))
        XCTAssertEqual(
            WindDownScheduleEngine.eligibleOccurrence(in: state, at: now.addingTimeInterval(100 * 60), calendar: calendar)?.title,
            "Saved once"
        )
    }

    func testDSTLocalClockTimeAndTimezoneChangesStayCalendarBased() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let springDay = try XCTUnwrap(newYork.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 0)))
        let routine = WindDownRoutine(
            title: "DST", role: .additionalQuiet,
            start: WindDownClockTime(hour: 1, minute: 30), end: WindDownClockTime(hour: 3, minute: 30),
            recurrence: .daily
        )
        let interval = try XCTUnwrap(routine.interval(on: springDay, calendar: newYork))
        XCTAssertEqual(interval.duration, 60 * 60, accuracy: 1)

        var singapore = newYork
        singapore.timeZone = TimeZone(identifier: "Asia/Singapore")!
        let moved = try XCTUnwrap(routine.interval(on: springDay, calendar: singapore))
        XCTAssertEqual(singapore.component(.hour, from: moved.start), 1)
        XCTAssertEqual(singapore.component(.hour, from: moved.end), 3)
    }

    func testUpcomingNotificationPlanIsFutureBoundedAndStable() throws {
        let now = try date(2026, 8, 3, 9, 0)
        let routine = WindDownRoutine(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000030")!,
            title: "Daily quiet", role: .additionalQuiet,
            start: WindDownClockTime(hour: 10, minute: 0), end: WindDownClockTime(hour: 10, minute: 30),
            recurrence: .daily
        )
        let state = WindDownScheduleState(routines: [routine])
        let first = UpcomingWindDownNotificationPlanBuilder.scheduledNotifications(
            for: state, after: now, calendar: calendar, primaryExtensionMinutes: 0,
            purpose: .defaultProfile, limit: 64
        )
        let second = UpcomingWindDownNotificationPlanBuilder.scheduledNotifications(
            for: state, after: now, calendar: calendar, primaryExtensionMinutes: 0,
            purpose: .defaultProfile, limit: 64
        )

        XCTAssertEqual(first, second)
        XCTAssertLessThanOrEqual(first.count, 64)
        XCTAssertTrue(first.allSatisfy { $0.date > now && $0.id.hasPrefix(UpcomingWindDownNotificationPlanBuilder.identifierPrefix) })
    }

    func testVersionedScheduleRoundTripsMultipleSourcesAndLegacyAutomaticScheduleDecodes() throws {
        let start = try date(2026, 8, 3, 12, 0)
        let state = WindDownScheduleState(
            oneTimePeriods: [WindDownOneTimePeriod(
                title: "Once",
                interval: DateInterval(start: start, end: start.addingTimeInterval(30 * 60))
            )],
            routines: [WindDownRoutine(
                title: "Custom repeat",
                role: .additionalQuiet,
                start: WindDownClockTime(hour: 18, minute: 0),
                end: WindDownClockTime(hour: 18, minute: 30),
                recurrence: .custom([2, 4, 6])
            )]
        )
        let decoded = try JSONDecoder().decode(
            WindDownScheduleState.self,
            from: JSONEncoder().encode(state)
        )
        XCTAssertEqual(decoded, state)

        let plan = NightWatchPlan.additionalQuiet(start: start, end: start.addingTimeInterval(30 * 60))
        let automatic = AutomaticWindDownSchedule(startedAt: start, plan: plan, sourceOccurrenceID: UUID())
        let encoded = try JSONEncoder().encode(automatic)
        var legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacyObject.removeValue(forKey: "sourceOccurrenceID")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacyDecoded = try JSONDecoder().decode(AutomaticWindDownSchedule.self, from: legacyData)
        XCTAssertNil(legacyDecoded.sourceOccurrenceID)
        XCTAssertEqual(legacyDecoded.plan, plan)
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
