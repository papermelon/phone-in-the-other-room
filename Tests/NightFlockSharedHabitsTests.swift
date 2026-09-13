import XCTest

final class NightFlockSharedHabitsTests: XCTestCase {
    func testNewPlanCapturesImmutableLocalNightAnchorAndLegacyDecodeRemainsUnknown() throws {
        let singapore = calendar(in: "Asia/Singapore")
        let plan = makePlan(
            bedtime: date(2026, 8, 28, 23, 0, calendar: singapore),
            wake: date(2026, 8, 29, 7, 0, calendar: singapore),
            calendar: singapore
        )
        XCTAssertEqual(plan.localDateAnchor?.intendedBedtimeDate, NightFlockLocalDate(year: 2026, month: 8, day: 28))
        XCTAssertEqual(plan.localDateAnchor?.nightEndingDate, NightFlockLocalDate(year: 2026, month: 8, day: 29))
        XCTAssertEqual(plan.localDateAnchor?.timeZoneIdentifier, "Asia/Singapore")

        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        json.removeValue(forKey: "localDateAnchor")
        let legacy = try JSONDecoder().decode(NightWatchPlan.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.localDateAnchor)
    }

    func testAnchorUsesGregorianDatesWhenPlanCalendarIsBuddhist() throws {
        let singapore = calendar(in: "Asia/Singapore")
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = singapore.timeZone
        let plan = makePlan(
            bedtime: date(2026, 8, 28, 23, 30, calendar: singapore),
            wake: date(2026, 8, 29, 7, 0, calendar: singapore),
            calendar: buddhist
        )
        XCTAssertEqual(plan.localDateAnchor?.intendedBedtimeDate, NightFlockLocalDate(year: 2026, month: 8, day: 28))
        XCTAssertEqual(plan.localDateAnchor?.nightEndingDate, NightFlockLocalDate(year: 2026, month: 8, day: 29))

        let anchor = try XCTUnwrap(plan.localDateAnchor)
        let window = try XCTUnwrap(NightFlockSharedSleepWindow(
            nightEndingDate: anchor.nightEndingDate,
            timeZoneIdentifier: anchor.timeZoneIdentifier
        ))
        XCTAssertEqual(window.nightEndingDate, NightFlockLocalDate(year: 2026, month: 8, day: 29))
    }

    func testAnchorStaysStableAcrossTravelAndAfterMidnightBedtime() {
        let singapore = calendar(in: "Asia/Singapore")
        let plan = makePlan(
            bedtime: date(2026, 8, 28, 23, 30, calendar: singapore),
            wake: date(2026, 8, 29, 7, 0, calendar: singapore),
            calendar: singapore
        )
        let record = completedRecord(plan: plan, minutes: 35, updatedAt: date(2026, 8, 29, 8, 0, calendar: singapore))
        let projection = NightFlockSharedHabitProjectionRules.windDownProjections(from: [record]).first

        XCTAssertEqual(projection?.localDate, NightFlockLocalDate(year: 2026, month: 8, day: 29))
        XCTAssertEqual(projection?.timeZoneIdentifier, "Asia/Singapore")
    }

    func testSleepWindowUsesCalendarLocalNoonAcrossDSTAndExcludesIncompleteWindows() throws {
        let losAngeles = "America/Los_Angeles"
        let spring = try XCTUnwrap(NightFlockSharedSleepWindow(
            nightEndingDate: NightFlockLocalDate(year: 2026, month: 3, day: 8),
            timeZoneIdentifier: losAngeles
        ))
        let autumn = try XCTUnwrap(NightFlockSharedSleepWindow(
            nightEndingDate: NightFlockLocalDate(year: 2026, month: 11, day: 1),
            timeZoneIdentifier: losAngeles
        ))
        let calendar = calendar(in: losAngeles)

        XCTAssertEqual(calendar.component(.hour, from: spring.interval.start), 12)
        XCTAssertEqual(calendar.component(.hour, from: spring.interval.end), 12)
        XCTAssertEqual(spring.interval.duration, 23 * 60 * 60, accuracy: 0.1)
        XCTAssertEqual(calendar.component(.hour, from: autumn.interval.start), 12)
        XCTAssertEqual(calendar.component(.hour, from: autumn.interval.end), 12)
        XCTAssertEqual(autumn.interval.duration, 25 * 60 * 60, accuracy: 0.1)
        XCTAssertFalse(spring.isComplete(at: spring.interval.end.addingTimeInterval(-1)))
        XCTAssertTrue(spring.isComplete(at: spring.interval.end))
    }

    func testSleepCutoffRequiresEntireWindowAfterAcceptanceAndMissingIsNotZero() throws {
        let window = try XCTUnwrap(NightFlockSharedSleepWindow(
            nightEndingDate: NightFlockLocalDate(year: 2026, month: 8, day: 29),
            timeZoneIdentifier: "Asia/Singapore"
        ))
        let laterAcceptance = window.interval.start.addingTimeInterval(90 * 60)
        let partialWindow = NightFlockSharedSleepQueryResult(
            window: window, state: .data(minutes: 420), earliestContributingIntervalStart: laterAcceptance
        )
        XCTAssertFalse(partialWindow.isEligibleForFirstPublication(acceptedAt: laterAcceptance))

        let fullWindow = NightFlockSharedSleepQueryResult(
            window: window, state: .data(minutes: 0), earliestContributingIntervalStart: window.interval.start
        )
        XCTAssertTrue(fullWindow.isEligibleForFirstPublication(acceptedAt: window.interval.start))
        XCTAssertEqual(fullWindow.state, .data(minutes: 0), "Observed sub-minute data must remain distinct from no data.")

        let missing = NightFlockSharedSleepQueryResult(window: window, state: .noData)
        XCTAssertFalse(missing.isEligibleForFirstPublication(acceptedAt: window.interval.start))
    }

    func testSleepReconciliationRejectsDelayedResultsAfterAuthorityChanges() {
        let captured = NightFlockSharedHabitSleepReconciliationAuthority(
            socialGeneration: 4,
            fenceGeneration: 2,
            reconcileGeneration: 7,
            accountIsLinked: true,
            supportsSharedHabits: true
        )
        XCTAssertTrue(NightFlockSharedHabitSleepReconciliationPolicy.permitsResult(
            captured: captured, current: captured, taskIsCancelled: false, hasActiveRun: false
        ))
        XCTAssertFalse(NightFlockSharedHabitSleepReconciliationPolicy.permitsResult(
            captured: captured,
            current: .init(socialGeneration: 5, fenceGeneration: 2, reconcileGeneration: 7, accountIsLinked: true, supportsSharedHabits: true),
            taskIsCancelled: false,
            hasActiveRun: false
        ), "Account/reset generation changes reject delayed Health results.")
        XCTAssertFalse(NightFlockSharedHabitSleepReconciliationPolicy.permitsResult(
            captured: captured,
            current: .init(socialGeneration: 4, fenceGeneration: 3, reconcileGeneration: 7, accountIsLinked: true, supportsSharedHabits: true),
            taskIsCancelled: false,
            hasActiveRun: false
        ), "A new privacy fence rejects delayed Health results.")
        XCTAssertFalse(NightFlockSharedHabitSleepReconciliationPolicy.permitsResult(
            captured: captured,
            current: .init(socialGeneration: 4, fenceGeneration: 2, reconcileGeneration: 7, accountIsLinked: false, supportsSharedHabits: true),
            taskIsCancelled: false,
            hasActiveRun: false
        ))
        XCTAssertFalse(NightFlockSharedHabitSleepReconciliationPolicy.permitsResult(
            captured: captured,
            current: captured,
            taskIsCancelled: false,
            hasActiveRun: true
        ))
    }

    func testSleepFanoutRequiresExactPartyReceiptTimezone() {
        XCTAssertTrue(NightFlockSharedHabitSleepReconciliationPolicy.permitsPartySleepPublication(
            projectionTimeZoneIdentifier: "Asia/Singapore",
            receiptTimeZoneIdentifier: "Asia/Singapore"
        ))
        XCTAssertFalse(NightFlockSharedHabitSleepReconciliationPolicy.permitsPartySleepPublication(
            projectionTimeZoneIdentifier: "Asia/Singapore",
            receiptTimeZoneIdentifier: "America/Los_Angeles"
        ))
    }

    func testBatchSleepAdmissionExcludesPreAgreementAndIncompleteWindowsBeforeQuerying() throws {
        let first = try XCTUnwrap(NightFlockSharedSleepWindow(
            nightEndingDate: NightFlockLocalDate(year: 2026, month: 8, day: 28),
            timeZoneIdentifier: "Asia/Singapore"
        ))
        let second = try XCTUnwrap(NightFlockSharedSleepWindow(
            nightEndingDate: NightFlockLocalDate(year: 2026, month: 8, day: 29),
            timeZoneIdentifier: "Asia/Singapore"
        ))
        let third = try XCTUnwrap(NightFlockSharedSleepWindow(
            nightEndingDate: NightFlockLocalDate(year: 2026, month: 8, day: 30),
            timeZoneIdentifier: "Asia/Singapore"
        ))
        let eligible = NightFlockSharedSleepWindowRules.eligibleBatchWindows(
            [first, second, third, second],
            acceptedAt: second.interval.start,
            now: third.interval.end.addingTimeInterval(-1)
        )
        XCTAssertEqual(eligible, [second])
    }

    func testWindDownUsesMaximumFactualResultPerNightAndExcludesPracticeAndLegacyAnchors() throws {
        let singapore = calendar(in: "Asia/Singapore")
        let anchoredPlan = makePlan(
            bedtime: date(2026, 8, 28, 23, 0, calendar: singapore),
            wake: date(2026, 8, 29, 7, 0, calendar: singapore),
            calendar: singapore
        )
        let first = completedRecord(plan: anchoredPlan, minutes: 20, updatedAt: date(2026, 8, 29, 7, 1, calendar: singapore))
        let restarted = completedRecord(plan: anchoredPlan, minutes: 40, updatedAt: date(2026, 8, 29, 7, 2, calendar: singapore))
        let practice = completedRecord(plan: anchoredPlan, minutes: 90, isPractice: true, updatedAt: date(2026, 8, 29, 7, 3, calendar: singapore))
        let unknownDate = completedRecord(plan: try legacyPlan(from: anchoredPlan), minutes: 120, updatedAt: date(2026, 8, 29, 7, 4, calendar: singapore))

        let projections = NightFlockSharedHabitProjectionRules.windDownProjections(from: [first, restarted, practice, unknownDate])
        XCTAssertEqual(projections.count, 1)
        XCTAssertEqual(projections.first?.minutes, 40)
        XCTAssertEqual(projections.first?.outcome, .completed)

        let sourceRevision = NightFlockSharedHabitProjectionRules.sourceRevision(for: restarted)
        XCTAssertLessThanOrEqual(sourceRevision, NightFlockSharedHabitProjectionRules.maximumJSONRevision)
        XCTAssertEqual(
            NightFlockSharedHabitProjectionRules.nextRevision(for: restarted, after: sourceRevision),
            sourceRevision + 1
        )
        XCTAssertNil(NightFlockSharedHabitProjectionRules.nextRevision(
            for: restarted,
            after: NightFlockSharedHabitProjectionRules.maximumJSONRevision
        ))
    }

    func testPeriodUsesAvailableNightCoverageAndRetainsObservedZero() {
        let zone = "Asia/Singapore"
        let ending = NightFlockLocalDate(year: 2026, month: 8, day: 29)
        let projections = [
            projection(kind: .windDown, date: ending, zone: zone, minutes: 0),
            projection(kind: .windDown, date: NightFlockLocalDate(year: 2026, month: 8, day: 27), zone: zone, minutes: 120),
            projection(kind: .windDown, date: NightFlockLocalDate(year: 2026, month: 8, day: 10), zone: zone, minutes: 300),
            NightFlockSharedHabitProjection(sourceID: UUID(), revision: 1, kind: .windDown, localDate: nil, timeZoneIdentifier: zone, minutes: 480)
        ]

        let week = NightFlockSharedHabitProjectionRules.periodSummary(
            for: .windDown, period: .last7Nights, endingOn: ending, timeZoneIdentifier: zone, projections: projections
        )
        XCTAssertEqual(week.availableNights, 7)
        XCTAssertEqual(week.coveredNights, 2)
        XCTAssertEqual(week.averageMinutes, 60)

        let lastNight = NightFlockSharedHabitProjectionRules.periodSummary(
            for: .windDown, period: .lastNight, endingOn: ending, timeZoneIdentifier: zone, projections: projections
        )
        XCTAssertEqual(lastNight.coveredNights, 1)
        XCTAssertEqual(lastNight.averageMinutes, 0)

        let missing = NightFlockSharedHabitProjectionRules.periodSummary(
            for: .sleep, period: .lastNight, endingOn: ending, timeZoneIdentifier: zone, projections: projections
        )
        XCTAssertEqual(missing.coveredNights, 0)
        XCTAssertNil(missing.averageMinutes)
    }

    func testPhoneAwayUsesActualTerminalDayAndDeduplicatesLatestSourceRevision() {
        let singapore = calendar(in: "Asia/Singapore")
        let start = date(2026, 8, 29, 23, 0, calendar: singapore)
        let plannedEnd = date(2026, 8, 30, 1, 0, calendar: singapore)
        let phoneAwayPlan = NightWatchPlan.additionalQuiet(start: start, end: plannedEnd, calendar: singapore)
        let phoneAway = NightWatchRecord(
            id: UUID(), plan: phoneAwayPlan, startedAt: start,
            endedAt: date(2026, 8, 29, 23, 30, calendar: singapore),
            startMethod: .honorTimer, outcome: .endedEarly,
            creditedWindDownMinutes: 30, role: .additionalQuiet,
            isPractice: false, updatedAt: plannedEnd
        )
        let phoneAwayProjection = NightFlockSharedHabitProjectionRules.phoneAwayProjections(from: [phoneAway]).first
        XCTAssertEqual(phoneAwayProjection?.localDate, NightFlockLocalDate(year: 2026, month: 8, day: 29))
        XCTAssertEqual(phoneAwayProjection?.outcome, .partlyCompleted)
        XCTAssertNil(phoneAwayProjection?.protectionMinutes)

        let firstSource = UUID()
        let day = NightFlockLocalDate(year: 2026, month: 8, day: 29)
        let projections = [
            projection(sourceID: firstSource, revision: 1, kind: .phoneAway, date: day, zone: "Asia/Singapore", minutes: 30),
            projection(sourceID: firstSource, revision: 2, kind: .phoneAway, date: day, zone: "Asia/Singapore", minutes: 10),
            projection(kind: .phoneAway, date: day, zone: "Asia/Singapore", minutes: 20)
        ]
        let summary = NightFlockSharedHabitProjectionRules.periodSummary(
            for: .phoneAway, period: .lastNight, endingOn: day,
            timeZoneIdentifier: "Asia/Singapore", projections: projections
        )
        XCTAssertEqual(summary.coveredNights, 1)
        XCTAssertEqual(summary.averageMinutes, 30)
    }

    func testWindDownProtectionIsLimitedToObservedPreBedMinutes() {
        let singapore = calendar(in: "Asia/Singapore")
        let windDown = completedRecord(
            plan: makePlan(
                bedtime: date(2026, 8, 28, 23, 0, calendar: singapore),
                wake: date(2026, 8, 29, 7, 0, calendar: singapore), calendar: singapore
            ),
            minutes: 30, shieldedMinutes: 50, evidence: .partial,
            updatedAt: date(2026, 8, 29, 14, 0, calendar: singapore)
        )
        let projection = NightFlockSharedHabitProjectionRules.windDownProjections(from: [windDown]).first
        XCTAssertEqual(projection?.protectionMinutes, 30)
        XCTAssertEqual(projection?.evidence, .appRecorded)
    }

    private func makePlan(bedtime: Date, wake: Date, calendar: Calendar) -> NightWatchPlan {
        NightWatchPlan(
            intendedBedtime: bedtime, wakeTime: wake, protectedUntil: wake,
            windDownMinutes: 30, morningQuietMinutes: 0,
            eveningActivity: .read, morningActivity: .openCurtains, calendar: calendar
        )
    }

    private func completedRecord(
        plan: NightWatchPlan, minutes: Int, shieldedMinutes: Int = 0,
        evidence: ShieldProtectionEvidence = .notRequested, isPractice: Bool = false,
        updatedAt: Date
    ) -> NightWatchRecord {
        NightWatchRecord(
            id: UUID(), plan: plan, startedAt: plan.intendedBedtime.addingTimeInterval(-30 * 60),
            endedAt: plan.wakeTime, startMethod: .honorTimer, outcome: .completed,
            creditedWindDownMinutes: minutes, shieldedWindDownMinutes: shieldedMinutes,
            shieldProtectionEvidence: evidence, role: .primarySleepBookend,
            isPractice: isPractice, updatedAt: updatedAt
        )
    }

    private func legacyPlan(from plan: NightWatchPlan) throws -> NightWatchPlan {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        json.removeValue(forKey: "localDateAnchor")
        return try JSONDecoder().decode(NightWatchPlan.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func projection(
        sourceID: UUID = UUID(), revision: Int64 = 1, kind: NightFlockSharedHabitKind,
        date: NightFlockLocalDate, zone: String, minutes: Int
    ) -> NightFlockSharedHabitProjection {
        NightFlockSharedHabitProjection(
            sourceID: sourceID, revision: revision, kind: kind, localDate: date,
            timeZoneIdentifier: zone, minutes: minutes
        )
    }

    private func calendar(in identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }
}

extension NightFlockSharedHabitsTests {
    func testSharedHabitPresentationUsesFactualDurationsAndDates() {
        XCTAssertEqual(NightFlockSharedHabitPresentation.durationText(0), "0 min")
        XCTAssertEqual(NightFlockSharedHabitPresentation.durationText(125), "2h 5m")
        XCTAssertEqual(NightFlockSharedHabitPresentation.meanDurationText(90.5), "~1h 31m")
        XCTAssertEqual(NightFlockSharedHabitPresentation.meanDurationText(420.5), "~7h 1m")
        XCTAssertEqual(
            NightFlockSharedHabitPresentation.localDateText(
                NightFlockLocalDate(year: 2026, month: 8, day: 29),
                locale: Locale(identifier: "en_SG")
            ),
            "29 Aug 2026"
        )
        XCTAssertEqual(NightFlockSharedHabitPresentation.methodTitle("eligibleMean"), "Mean of eligible observed nights")
    }
}


extension NightFlockSharedHabitsTests {
    func testHabitsWireReceiptAndArchiveDecodeKeyedCalendarDates() throws {
        // Matches the Edge adapter's output from PostgreSQL calendar-day strings.
        // Exercise the first post-agreement response and populated summaries, not
        // only the pre-agreement empty state that hid the original mismatch.
        let data = Data(#"""
        {"agreement":{"agreementID":"10000000-0000-4000-8000-000000000001",
          "memberEpochID":"20000000-0000-4000-8000-000000000001",
          "acceptedAt":"2026-08-28T17:44:12Z","timeZoneIdentifier":"Asia/Singapore",
          "firstEligibleSleepNight":{"year":2026,"month":8,"day":30}},
         "records":[{"recordID":"30000000-0000-4000-8000-000000000001",
          "partyID":"40000000-0000-4000-8000-000000000001",
          "memberID":"50000000-0000-4000-8000-000000000001",
          "sourceID":"60000000-0000-4000-8000-000000000001","revision":1,
          "kind":"phoneAway","localDate":{"year":2026,"month":8,"day":29},
          "activityDate":{"year":2026,"month":8,"day":29},
          "timeZoneIdentifier":"Asia/Singapore","minutes":20,"outcome":"completed",
          "evidence":"none","profileSnapshot":{"displayName":"Test Shepherd"},
          "isFormerMember":false}],"nextCursor":null,"snapshotRevision":2,
         "periods":[{"memberID":"50000000-0000-4000-8000-000000000001",
          "kind":"phoneAway","period":"last7Nights",
          "endingOn":{"year":2026,"month":8,"day":29},"availableNights":7,
          "coveredNights":1,"averageMinutes":20,"method":"eligibleMean"}]}
        """#.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(NightFlockSharedHabitsStateResponse.self, from: data)
        XCTAssertEqual(response.agreement?.firstEligibleSleepNight, .init(year: 2026, month: 8, day: 30))
        XCTAssertEqual(response.records.first?.localDate, .init(year: 2026, month: 8, day: 29))
        XCTAssertEqual(response.records.first?.activityDate, .init(year: 2026, month: 8, day: 29))
        XCTAssertEqual(response.periods.first?.endingOn, .init(year: 2026, month: 8, day: 29))

        let record = try XCTUnwrap(response.records.first)
        let receipt = try XCTUnwrap(response.agreement)
        let request = NightFlockSharedHabitsCommandRequest(command: .publish(
            record: record, agreementID: receipt.agreementID,
            memberEpochID: receipt.memberEpochID, idempotencyKey: String(repeating: "a", count: 64)
        ))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        // Shipped clients encode this keyed shape; the Edge must keep accepting it.
        XCTAssertEqual(object["localDate"] as? [String: Int], ["year": 2026, "month": 8, "day": 29])
    }
}
