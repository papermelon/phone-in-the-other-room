import XCTest

final class FocusRunLiveActivityPushContractTests: XCTestCase {
    func testTerminalPresentationsStayFactualAndDistinct() {
        let completed = FocusRunLiveActivityTerminalStatus.completed.presentation(for: .primarySleepBookend)
        let endedEarly = FocusRunLiveActivityTerminalStatus.endedEarly.presentation(for: .primarySleepBookend)
        let phoneAway = FocusRunLiveActivityTerminalStatus.completed.presentation(for: .additionalQuiet)

        XCTAssertEqual(completed.headline, "WIND DOWN TIMER ENDED")
        XCTAssertEqual(completed.message, "Well done. Open Counting Sheep for your summary.")
        XCTAssertEqual(endedEarly.headline, "WIND DOWN ENDED EARLY")
        XCTAssertEqual(phoneAway.headline, "PHONE AWAY TIMER ENDED")
        XCTAssertNotEqual(endedEarly, completed)

        for copy in [completed.headline, completed.message, endedEarly.headline, endedEarly.message, phoneAway.headline, phoneAway.message] {
            let lowercased = copy.lowercased()
            XCTAssertFalse(lowercased.contains("sheep found"))
            XCTAssertFalse(lowercased.contains("found a sheep"))
            XCTAssertFalse(lowercased.contains("reward resolved"))
            XCTAssertFalse(lowercased.contains("tucked"))
            XCTAssertFalse(lowercased.contains("slept"))
            XCTAssertFalse(lowercased.contains("phone-free"))
        }
    }

    func testRunSyncRoundTripsWithoutActivityKitToken() throws {
        let sync = FocusRunCloudSync(
            runID: UUID(),
            installationID: UUID(),
            plannedEndAt: Date(timeIntervalSince1970: 1_800_000_000),
            observedAt: Date(timeIntervalSince1970: 1_799_999_000),
            status: .active,
            runRevision: 1,
            appVersion: "0.1.0",
            idempotencyKey: "run-sync-idempotency"
        )

        let data = try JSONEncoder().encode(sync)
        let decoded = try JSONDecoder().decode(FocusRunCloudSync.self, from: data)

        XCTAssertEqual(decoded, sync)
        XCTAssertEqual(decoded.schemaVersion, FocusRunCloudSync.currentSchemaVersion)
    }

    func testRegistrationRoundTripsWithoutLosingRunAssociation() throws {
        let installationID = UUID()
        let registration = FocusRunLiveActivityPushRegistration(
            runID: UUID(),
            activityID: "activity-1",
            pushToken: "a1b2c3",
            plannedEndAt: Date(timeIntervalSince1970: 1_800_000_000),
            observedAt: Date(timeIntervalSince1970: 1_799_999_000),
            environment: .sandbox,
            installationID: installationID,
            runRevision: 3,
            tokenGeneration: 2,
            idempotencyKey: "registration-idempotency",
            phase: .windDown,
            bedtimeAt: Date(timeIntervalSince1970: 1_800_001_000),
            wakeAt: Date(timeIntervalSince1970: 1_800_029_800),
            morningQuietEndsAt: Date(timeIntervalSince1970: 1_800_031_600),
            eveningActivityTitle: "Read",
            morningActivityTitle: "Open curtains"
        )

        let data = try JSONEncoder().encode(registration)
        let decoded = try JSONDecoder().decode(FocusRunLiveActivityPushRegistration.self, from: data)

        XCTAssertEqual(decoded, registration)
        XCTAssertEqual(decoded.schemaVersion, FocusRunLiveActivityPushRegistration.currentSchemaVersion)
        XCTAssertEqual(decoded.installationID, installationID)
        XCTAssertEqual(decoded.phase, .windDown)
        XCTAssertEqual(decoded.eveningActivityTitle, "Read")
        XCTAssertEqual(decoded.morningActivityTitle, "Open curtains")
    }

    func testCancellationRoundTripsWithIdempotencyIdentity() throws {
        let cancellation = FocusRunLiveActivityCancellation(
            runID: UUID(),
            activityID: "activity-2",
            reason: .endedEarly,
            occurredAt: Date(timeIntervalSince1970: 1_800_000_100),
            installationID: UUID(),
            runRevision: 4,
            idempotencyKey: "cancellation-idempotency"
        )

        let data = try JSONEncoder().encode(cancellation)
        let decoded = try JSONDecoder().decode(FocusRunLiveActivityCancellation.self, from: data)

        XCTAssertEqual(decoded, cancellation)
    }

    func testVersionOneRegistrationStillDecodes() throws {
        let runID = UUID()
        let json = """
        {
          "schemaVersion": 1,
          "runID": "\(runID.uuidString)",
          "activityID": "legacy-activity",
          "pushToken": "a1b2c3",
          "plannedEndAt": 821692800,
          "observedAt": 821691800,
          "environment": "sandbox"
        }
        """

        let decoded = try JSONDecoder().decode(
            FocusRunLiveActivityPushRegistration.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(decoded.runID, runID)
        XCTAssertNil(decoded.installationID)
        XCTAssertNil(decoded.idempotencyKey)
    }

    func testForegroundCleanupRetainsOnlyLiveTimersIncludingLinkedMorning() {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        var run = FocusRun(plannedDurationSeconds: 600, startedAt: now, state: .running, guardKind: .honorTimer)
        XCTAssertEqual(FocusRunLiveActivityLifecycle.retainedRunIDs(run: run, mornings: [], at: now), [run.id])
        XCTAssertTrue(FocusRunLiveActivityLifecycle.retainedRunIDs(run: run, mornings: [], at: run.plannedEndAt).isEmpty)
        run.state = .completed
        XCTAssertTrue(FocusRunLiveActivityLifecycle.retainedRunIDs(run: run, mornings: [], at: now).isEmpty)
        var morning = MorningQuietOccurrence(
            linkedWindDownRunID: run.id, scheduledStart: now,
            scheduledEnd: now.addingTimeInterval(1800), actualStart: now, outcome: .active
        )
        XCTAssertEqual(FocusRunLiveActivityLifecycle.retainedRunIDs(run: run, mornings: [morning], at: now), [run.id])
        XCTAssertTrue(FocusRunLiveActivityLifecycle.retainedRunIDs(run: run, mornings: [morning], at: morning.scheduledEnd).isEmpty)
        morning.linkedWindDownRunID = nil
        XCTAssertEqual(FocusRunLiveActivityLifecycle.retainedRunIDs(run: nil, mornings: [morning], at: now), [morning.id])
        for outcome in [MorningQuietOccurrenceOutcome.scheduled, .finished, .skipped] {
            morning.outcome = outcome
            XCTAssertTrue(FocusRunLiveActivityLifecycle.retainedRunIDs(run: nil, mornings: [morning], at: now).isEmpty)
        }
        run.state = .endedEarly
        XCTAssertTrue(FocusRunLiveActivityLifecycle.retainedRunIDs(run: run, mornings: [], at: now).isEmpty)
        XCTAssertTrue(FocusRunLiveActivityLifecycle.retainedRunIDs(run: nil, mornings: [], at: now).isEmpty)
    }

#if canImport(ActivityKit)
    func testLegacyContentStateStillDecodesWithoutTerminalStatus() throws {
        let json = """
        {
          "plannedEndAt": 800000000,
          "isComplete": false,
          "phase": "windDown",
          "bedtimeAt": 800000100,
          "wakeAt": 800028900,
          "morningQuietEndsAt": 800030700,
          "eveningActivityTitle": "Read",
          "morningActivityTitle": "Open curtains"
        }
        """

        let decoded = try JSONDecoder().decode(
            FocusRunLiveActivityAttributes.ContentState.self,
            from: Data(json.utf8)
        )

        XCTAssertFalse(decoded.isComplete)
        XCTAssertEqual(decoded.phase, .windDown)
        XCTAssertNil(decoded.terminalStatus)
        XCTAssertNil(decoded.eveningRoutineTitles)
        XCTAssertNil(decoded.morningRoutineTitles)
    }
    func testStaleEveningStateDisplaysOvernightWithoutAnAppUpdate() {
        let bedtime = Date(timeIntervalSince1970: 1_900_000_000)
        let wake = bedtime.addingTimeInterval(7 * 3600)
        let original = FocusRunLiveActivityAttributes.ContentState(
            plannedEndAt: wake, isComplete: false, phase: .windDown,
            bedtimeAt: bedtime, wakeAt: wake, morningQuietEndsAt: wake.addingTimeInterval(1800)
        )
        XCTAssertEqual(original.nextContentRefreshDate(at: bedtime.addingTimeInterval(-1)), bedtime)
        let rendered = original.resolvedForDisplay(at: bedtime, isStale: true)
        XCTAssertEqual(rendered.phase, .overnight)
        XCTAssertEqual(rendered.countdownEnd(at: bedtime), wake)
        XCTAssertEqual(original.phase, .windDown)
        XCTAssertFalse(rendered.isComplete)
        XCTAssertNil(rendered.terminalStatus)
        XCTAssertEqual(original.displayPhase(at: wake), .morningQuiet)
        XCTAssertEqual(original.countdownEnd(at: wake), wake.addingTimeInterval(1800))
    }

    func testCurrentClockOutranksOldPhaseEvenBeforeFreshnessNotification() {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let state = FocusRunLiveActivityAttributes.ContentState(
            plannedEndAt: now.addingTimeInterval(7200), isComplete: false, phase: .windDown,
            bedtimeAt: now.addingTimeInterval(-60), wakeAt: now.addingTimeInterval(3600),
            morningQuietEndsAt: now.addingTimeInterval(7200)
        )
        XCTAssertEqual(state.resolvedForDisplay(at: now, isStale: false).phase, .overnight)
        XCTAssertEqual(state.nextContentRefreshDate(at: now), state.wakeAt)
    }

    func testTerminalAndPhoneAwayStatesNeverRestartAsOvernight() {
        let now = Date()
        var state = FocusRunLiveActivityAttributes.ContentState(
            plannedEndAt: now.addingTimeInterval(600), isComplete: false, phase: .windDown,
            role: .additionalQuiet, bedtimeAt: now.addingTimeInterval(-600),
            wakeAt: now.addingTimeInterval(300), morningQuietEndsAt: now.addingTimeInterval(900)
        )
        XCTAssertEqual(state.displayPhase(at: now), .windDown)
        XCTAssertEqual(state.countdownEnd(at: now), state.plannedEndAt)
        state.terminalStatus = .endedEarly
        XCTAssertNil(state.resolvedForDisplay(at: now, isStale: true).phase)
        XCTAssertNil(state.nextContentRefreshDate(at: now))
        state.terminalStatus = .completed
        XCTAssertEqual(state.displayPhase(at: now), .complete)
    }

    func testExpiredPayloadShowsCompletionWithoutClaimingSettlement() {
        let end = Date(timeIntervalSince1970: 1_900_000_000)
        let original = FocusRunLiveActivityAttributes.ContentState(
            plannedEndAt: end, isComplete: false, phase: .morningQuiet,
            bedtimeAt: end.addingTimeInterval(-8 * 3600), wakeAt: end.addingTimeInterval(-1800),
            morningQuietEndsAt: end
        )
        let before = original.resolvedForDisplay(at: end.addingTimeInterval(-1), isStale: false)
        XCTAssertFalse(before.isDisplayComplete)
        XCTAssertNil(before.completionPresentation)
        let expired = original.resolvedForDisplay(at: end, isStale: true)
        XCTAssertTrue(expired.isDisplayComplete)
        XCTAssertEqual(expired.completionPresentation?.headline, "WIND DOWN TIMER ENDED")
        XCTAssertFalse(expired.isComplete)
        XCTAssertNil(expired.terminalStatus)
        XCTAssertEqual(original.phase, .morningQuiet)
    }

    func testExpiredIndependentMorningUsesMorningCompletionCopy() {
        let end = Date(timeIntervalSince1970: 1_900_000_000)
        let morning = MorningQuietOccurrence(scheduledStart: end.addingTimeInterval(-1800), scheduledEnd: end, outcome: .active)
        let original = FocusRunLiveActivityAttributes.ContentState(
            plannedEndAt: end, isComplete: false, screenFreeMorning: ScreenFreeMorningPresentation(occurrence: morning)
        )
        let expired = original.resolvedForDisplay(at: end, isStale: true)
        XCTAssertTrue(expired.isDisplayComplete)
        XCTAssertEqual(expired.completionPresentation?.headline, "SCREEN-FREE MORNING TIMER ENDED")
        XCTAssertEqual(expired.screenFreeMorning?.status, .active)
        XCTAssertFalse(expired.isComplete)
        XCTAssertNil(expired.terminalStatus)
    }

    func testExpiredLegacyAndPhoneAwayPayloadsStopDisplayingCountdown() {
        let end = Date(timeIntervalSince1970: 1_900_000_000)
        for role in [WindDownOccurrenceRole?.none, .additionalQuiet] {
            let original = FocusRunLiveActivityAttributes.ContentState(plannedEndAt: end, isComplete: false, role: role)
            let expired = original.resolvedForDisplay(at: end, isStale: false)
            XCTAssertTrue(expired.isDisplayComplete)
            XCTAssertNotNil(expired.completionPresentation)
        }
    }

    func testRoutinePayloadIsBoundedAndRoundTripsWithUnicodeCustomIdeas() throws {
        let text = String(repeating: "👩‍👩‍👧‍👦", count: 80)
        let bounded = FocusRunLiveActivityCue.bounded(text)
        XCTAssertLessThanOrEqual(bounded.utf8.count, 160)
        let state = FocusRunLiveActivityAttributes.ContentState(
            plannedEndAt: Date(), isComplete: false,
            eveningActivityTitle: bounded, morningActivityTitle: bounded,
            eveningRoutineTitles: Array(repeating: bounded, count: 3),
            morningRoutineTitles: Array(repeating: bounded, count: 2)
        )
        let data = try JSONEncoder().encode(state)
        XCTAssertLessThan(data.count, 3500) // Leave room for attributes and system fields.
        XCTAssertEqual(try JSONDecoder().decode(FocusRunLiveActivityAttributes.ContentState.self, from: data), state)
    }
#endif
}
