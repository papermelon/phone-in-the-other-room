import XCTest

final class QuietTimeBriefAccessTests: XCTestCase {
    func testGrantIsClampedToProtectedIntervalEndAndBoundaryBecomesIneligible() {
        let start = Date(timeIntervalSince1970: 1_900_000_000)
        let end = start.addingTimeInterval(4 * 60)
        let schedule = makeSchedule(start: start, end: end)
        let requestedAt = start.addingTimeInterval(60)

        let grant = QuietTimeBriefAccessPolicy.makeGrant(
            runID: schedule.runID,
            scheduleRevision: schedule.revision,
            requestedAt: requestedAt,
            schedule: schedule
        )

        XCTAssertEqual(grant?.expiresAt, end)
        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.validate(
                route: .application,
                schedule: schedule,
                state: nil,
                at: end.addingTimeInterval(-0.1),
                hasApplicationOrCategorySelection: true
            ),
            .eligible
        )
        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.validate(
                route: .category,
                schedule: schedule,
                state: nil,
                at: end,
                hasApplicationOrCategorySelection: true
            ),
            .outsideShieldedPhase
        )
        XCTAssertNil(
            QuietTimeBriefAccessPolicy.makeGrant(
                runID: schedule.runID,
                scheduleRevision: schedule.revision,
                requestedAt: end.addingTimeInterval(-1),
                schedule: schedule
            )
        )
    }

    func testClampedGrantStillUsesAValidMinimumRestoreEnvelope() throws {
        let start = Date(timeIntervalSince1970: 1_900_000_000)
        let end = start.addingTimeInterval(3)
        let schedule = makeSchedule(start: start, end: end)
        let grant = try XCTUnwrap(
            QuietTimeBriefAccessPolicy.makeGrant(
                runID: schedule.runID,
                scheduleRevision: schedule.revision,
                requestedAt: start,
                schedule: schedule
            )
        )
        let restore = try XCTUnwrap(
            QuietTimeBriefAccessRestorePlan.make(requestedAt: start, expiresAt: grant.expiresAt)
        )

        XCTAssertEqual(grant.expiresAt, end)
        XCTAssertGreaterThanOrEqual(
            restore.duration,
            QuietTimeBriefAccessConstants.minimumRestoreMonitoringDuration
        )
        XCTAssertGreaterThan(restore.intervalEnd, grant.expiresAt)
        let warningSeconds = (restore.warningTime.hour ?? 0) * 3600
            + (restore.warningTime.minute ?? 0) * 60
            + (restore.warningTime.second ?? 0)
        XCTAssertEqual(warningSeconds, Int(ceil(restore.intervalEnd.timeIntervalSince(grant.expiresAt))))
        XCTAssertFalse(
            QuietTimeBriefAccessPolicy.shouldRestore(
                at: grant.expiresAt.addingTimeInterval(-0.1),
                for: grant
            )
        )
        XCTAssertTrue(QuietTimeBriefAccessPolicy.shouldRestore(at: grant.expiresAt, for: grant))
    }

    func testSuccessfulScheduleMarksOneUseAndDuplicateDoesNotExtendGrant() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let schedule = makeSchedule(start: now, end: now.addingTimeInterval(20 * 60))
        let grant = try XCTUnwrap(
            QuietTimeBriefAccessPolicy.makeGrant(
                runID: schedule.runID,
                scheduleRevision: schedule.revision,
                requestedAt: now,
                schedule: schedule
            )
        )
        var state = QuietTimeBriefAccessState(
            runID: schedule.runID,
            scheduleRevision: schedule.revision,
            updatedAt: now
        )

        XCTAssertTrue(state.propose(grant, at: now))
        XCTAssertTrue(state.markScheduled(nonce: grant.nonce, at: now))
        XCTAssertEqual(state.successfulUseCount, 1)
        XCTAssertEqual(state.activeGrant?.expiresAt, grant.expiresAt)
        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.validate(
                route: .application,
                schedule: schedule,
                state: state,
                at: now.addingTimeInterval(30),
                hasApplicationOrCategorySelection: true
            ),
            .activeGrant
        )
        XCTAssertEqual(state.successfulUseCount, 1)
        XCTAssertEqual(state.activeGrant?.expiresAt, grant.expiresAt)
    }

    func testSchedulingFailureRollsBackWithoutIncrementing() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let schedule = makeSchedule(start: now, end: now.addingTimeInterval(20 * 60))
        let grant = try XCTUnwrap(
            QuietTimeBriefAccessPolicy.makeGrant(
                runID: schedule.runID,
                scheduleRevision: schedule.revision,
                requestedAt: now,
                schedule: schedule
            )
        )
        var state = QuietTimeBriefAccessState(
            runID: schedule.runID,
            scheduleRevision: schedule.revision,
            updatedAt: now
        )

        XCTAssertTrue(state.propose(grant, at: now))
        state.rollback(nonce: grant.nonce, at: now.addingTimeInterval(1))

        XCTAssertNil(state.activeGrant)
        XCTAssertEqual(state.successfulUseCount, 0)
        XCTAssertTrue(state.successfulUses.isEmpty)
    }

    func testStaleRunOccurrenceAndRevisionAreRejectedIndependently() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let schedule = makeSchedule(start: now, end: now.addingTimeInterval(20 * 60))
        let otherRun = QuietTimeShieldScheduleSnapshot(
            runID: UUID(),
            revision: schedule.revision,
            windDownInterval: schedule.windDownInterval,
            morningQuietInterval: schedule.morningQuietInterval,
            updatedAt: now
        )
        let state = QuietTimeBriefAccessState(
            runID: otherRun.runID,
            scheduleRevision: otherRun.revision,
            updatedAt: now
        )

        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.validate(
                route: .application,
                schedule: schedule,
                state: state,
                at: now,
                hasApplicationOrCategorySelection: true
            ),
            .staleRun
        )

        var staleOccurrence = state
        staleOccurrence.runID = schedule.runID
        staleOccurrence.scheduleRevision = schedule.revision
        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.validate(
                route: .category,
                schedule: schedule,
                state: staleOccurrence,
                at: now,
                hasApplicationOrCategorySelection: true
            ),
            .staleOccurrence
        )

        var staleRevision = state
        staleRevision.runID = schedule.runID
        staleRevision.occurrenceID = schedule.runID
        staleRevision.scheduleRevision = schedule.revision + 1
        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.validate(
                route: .category,
                schedule: schedule,
                state: staleRevision,
                at: now,
                hasApplicationOrCategorySelection: true
            ),
            .staleRevision
        )
    }

    func testDelayedCallbackRestoresOnlyAtOrAfterExpiryAndNotAfterRunEnd() throws {
        let start = Date(timeIntervalSince1970: 1_900_000_000)
        let end = start.addingTimeInterval(20 * 60)
        let schedule = makeSchedule(start: start, end: end)
        let requestedAt = start.addingTimeInterval(60)
        let grant = try XCTUnwrap(
            QuietTimeBriefAccessPolicy.makeGrant(
                runID: schedule.runID,
                scheduleRevision: schedule.revision,
                requestedAt: requestedAt,
                schedule: schedule
            )
        )
        var state = QuietTimeBriefAccessState(
            runID: schedule.runID,
            scheduleRevision: schedule.revision,
            updatedAt: requestedAt
        )
        XCTAssertTrue(state.propose(grant, at: requestedAt))
        XCTAssertTrue(state.markScheduled(nonce: grant.nonce, at: requestedAt))

        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.reconciliation(
                state: state,
                schedule: schedule,
                currentRunID: schedule.runID,
                currentRevision: schedule.revision,
                at: grant.expiresAt.addingTimeInterval(-0.1)
            ),
            .keepShieldClear(until: grant.expiresAt)
        )
        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.reconciliation(
                state: state,
                schedule: schedule,
                currentRunID: schedule.runID,
                currentRevision: schedule.revision,
                at: grant.expiresAt
            ),
            .restoreShield
        )
        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.reconciliation(
                state: state,
                schedule: schedule,
                currentRunID: schedule.runID,
                currentRevision: schedule.revision,
                at: end.addingTimeInterval(1)
            ),
            .discardStaleGrant
        )
    }

    func testMonitorRejectionTombstoneBlocksStaleActionCommit() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let schedule = makeSchedule(start: now, end: now.addingTimeInterval(20 * 60))
        let grant = try XCTUnwrap(
            QuietTimeBriefAccessPolicy.makeGrant(
                runID: schedule.runID,
                scheduleRevision: schedule.revision,
                requestedAt: now,
                schedule: schedule
            )
        )
        var state = QuietTimeBriefAccessState(
            runID: schedule.runID,
            scheduleRevision: schedule.revision,
            updatedAt: now
        )
        XCTAssertTrue(state.propose(grant, at: now))

        state.rejectPendingGrant(nonce: grant.nonce, at: now.addingTimeInterval(1))

        XCTAssertEqual(state.rejectedGrantNonce, grant.nonce)
        XCTAssertNil(state.activeGrant)
        XCTAssertEqual(state.successfulUseCount, 0)
        XCTAssertFalse(
            QuietTimeBriefAccessPolicy.canCommitScheduledGrant(
                state: state,
                grant: grant,
                currentRunID: schedule.runID,
                currentRevision: schedule.revision
            )
        )
    }

    func testPendingAndPriorRevisionCallbacksNeverClearCurrentEligibleShield() throws {
        let start = Date(timeIntervalSince1970: 1_900_000_000)
        let schedule = makeSchedule(start: start, end: start.addingTimeInterval(20 * 60))
        let grant = try XCTUnwrap(
            QuietTimeBriefAccessPolicy.makeGrant(
                runID: schedule.runID,
                scheduleRevision: schedule.revision,
                requestedAt: start,
                schedule: schedule
            )
        )
        var pendingState = QuietTimeBriefAccessState(
            runID: schedule.runID,
            scheduleRevision: schedule.revision,
            updatedAt: start
        )
        XCTAssertTrue(pendingState.propose(grant, at: start))

        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.reconciliation(
                state: pendingState,
                schedule: schedule,
                currentRunID: schedule.runID,
                currentRevision: schedule.revision,
                at: start.addingTimeInterval(1)
            ),
            .rejectPendingGrant
        )
        XCTAssertTrue(
            QuietTimeBriefAccessPolicy.canCommitScheduledGrant(
                state: pendingState,
                grant: grant,
                currentRunID: schedule.runID,
                currentRevision: schedule.revision
            )
        )
        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.staleGrantAction(
                schedule: schedule,
                at: start.addingTimeInterval(1)
            ),
            .reapplyCurrentShield
        )

        let newerSchedule = QuietTimeShieldScheduleSnapshot(
            runID: schedule.runID,
            revision: schedule.revision + 1,
            protectedSessionInterval: schedule.protectedSessionInterval,
            windDownInterval: schedule.windDownInterval,
            morningQuietInterval: schedule.morningQuietInterval,
            updatedAt: start.addingTimeInterval(2)
        )
        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.reconciliation(
                state: pendingState,
                schedule: newerSchedule,
                currentRunID: newerSchedule.runID,
                currentRevision: newerSchedule.revision,
                at: start.addingTimeInterval(3)
            ),
            .discardStaleGrant
        )
        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.staleGrantAction(
                schedule: newerSchedule,
                at: start.addingTimeInterval(3)
            ),
            .reapplyCurrentShield
        )
        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.staleGrantAction(
                schedule: newerSchedule,
                at: newerSchedule.protectedSessionInterval!.end
            ),
            .clearProtection
        )
    }

    func testAutomaticScheduleUsesItsStableScheduleIdentityForRestore() throws {
        let start = Date(timeIntervalSince1970: 1_900_000_000)
        let schedule = makeSchedule(start: start, end: start.addingTimeInterval(20 * 60))
        let grant = try XCTUnwrap(
            QuietTimeBriefAccessPolicy.makeGrant(
                runID: schedule.runID,
                scheduleRevision: schedule.revision,
                requestedAt: start,
                schedule: schedule
            )
        )
        var state = QuietTimeBriefAccessState(
            runID: schedule.runID,
            scheduleRevision: schedule.revision,
            updatedAt: start
        )
        XCTAssertTrue(state.propose(grant, at: start))
        XCTAssertTrue(state.markScheduled(nonce: grant.nonce, at: start))

        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.reconciliation(
                state: state,
                schedule: schedule,
                currentRunID: schedule.runID,
                currentRevision: schedule.revision,
                at: start.addingTimeInterval(30)
            ),
            .keepShieldClear(until: grant.expiresAt)
        )
        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.reconciliation(
                state: state,
                schedule: schedule,
                currentRunID: UUID(),
                currentRevision: schedule.revision,
                at: start.addingTimeInterval(30)
            ),
            .discardStaleGrant
        )
    }

    func testTerminalCleanupArchivesCountForLaterIdempotentImport() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let schedule = makeSchedule(start: now, end: now.addingTimeInterval(20 * 60))
        let grant = try XCTUnwrap(
            QuietTimeBriefAccessPolicy.makeGrant(
                runID: schedule.runID,
                scheduleRevision: schedule.revision,
                requestedAt: now,
                schedule: schedule
            )
        )
        var state = QuietTimeBriefAccessState(
            runID: schedule.runID,
            scheduleRevision: schedule.revision,
            updatedAt: now
        )
        XCTAssertTrue(state.propose(grant, at: now))
        XCTAssertTrue(state.markScheduled(nonce: grant.nonce, at: now))

        state.archiveCurrentRun(at: schedule.morningQuietInterval.end)
        XCTAssertNil(state.activeGrant)
        XCTAssertEqual(state.durableCount(for: schedule.runID), 1)

        let decoded = try JSONDecoder().decode(
            QuietTimeBriefAccessState.self,
            from: JSONEncoder().encode(state)
        )
        XCTAssertEqual(decoded.durableCount(for: schedule.runID), 1)
        XCTAssertEqual(decoded.durableCount(for: schedule.runID), 1)

        let plan = NightWatchPlan(
            intendedBedtime: now.addingTimeInterval(30 * 60),
            wakeTime: now.addingTimeInterval(8 * 60 * 60),
            protectedUntil: now.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        var run = FocusRun(
            id: schedule.runID,
            plannedDurationSeconds: plan.protectedUntil.timeIntervalSince(now),
            startedAt: now,
            state: .completed,
            guardKind: .nfcTag,
            nightWatchPlan: plan
        )
        run.briefAccessUseCount = decoded.durableCount(for: run.id)

        var history = NightWatchHistory(now: now)
        history.upsert(run.nightWatchRecord(updatedAt: plan.protectedUntil)!, now: plan.protectedUntil)
        history.upsert(
            run.nightWatchRecord(
                updatedAt: plan.protectedUntil.addingTimeInterval(1),
                briefAccessUseCount: decoded.durableCount(for: run.id)
            )!,
            now: plan.protectedUntil.addingTimeInterval(1)
        )

        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(history.record(for: run.id)?.briefAccessUseCount, 1)
    }

    func testLegacyBriefAccessStateDecodesDefaults() throws {
        let runID = UUID()
        let object: [String: Any] = [
            "schemaVersion": 1,
            "runID": runID.uuidString,
            "scheduleRevision": 1,
            "successfulUseCount": 2
        ]
        let data = try JSONSerialization.data(withJSONObject: object)
        let state = try JSONDecoder().decode(QuietTimeBriefAccessState.self, from: data)

        XCTAssertEqual(state.successfulUseCount, 2)
        XCTAssertEqual(state.occurrenceID, runID)
        XCTAssertEqual(state.scheduleEpoch, 1)
        XCTAssertTrue(state.successfulUses.isEmpty)
        XCTAssertTrue(state.completedRunCounts.isEmpty)
        XCTAssertNil(state.activeGrant)
    }

    func testLegacyGrantDefaultsToItsRunIdentityAndFirstEpoch() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let runID = UUID()
        let grant = QuietTimeBriefAccessGrant(
            runID: runID,
            occurrenceID: UUID(),
            scheduleRevision: 4,
            scheduleEpoch: 8,
            requestedAt: now,
            expiresAt: now.addingTimeInterval(60)
        )
        guard var object = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(grant)
        ) as? [String: Any] else {
            return XCTFail("Expected a JSON grant object")
        }
        object.removeValue(forKey: "occurrenceID")
        object.removeValue(forKey: "scheduleEpoch")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(QuietTimeBriefAccessGrant.self, from: legacyData)

        XCTAssertEqual(decoded.occurrenceID, runID)
        XCTAssertEqual(decoded.scheduleEpoch, 1)
    }

    func testOccurrenceRevisionAndEpochMustAllMatchBeforeCommittingGrant() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let schedule = makeSchedule(start: now, end: now.addingTimeInterval(20 * 60))
        let occurrenceID = UUID()
        let grant = try XCTUnwrap(
            QuietTimeBriefAccessPolicy.makeGrant(
                runID: schedule.runID,
                scheduleRevision: 7,
                requestedAt: now,
                schedule: schedule,
                occurrenceID: occurrenceID,
                scheduleEpoch: 11
            )
        )
        var state = QuietTimeBriefAccessState(
            runID: schedule.runID,
            occurrenceID: occurrenceID,
            scheduleRevision: 7,
            scheduleEpoch: 11,
            updatedAt: now
        )
        XCTAssertTrue(state.propose(grant, at: now))
        XCTAssertTrue(
            QuietTimeBriefAccessPolicy.canCommitScheduledGrant(
                state: state,
                grant: grant,
                currentRunID: schedule.runID,
                currentRevision: 7,
                currentOccurrenceID: occurrenceID,
                currentEpoch: 11
            )
        )
        XCTAssertFalse(
            QuietTimeBriefAccessPolicy.canCommitScheduledGrant(
                state: state,
                grant: grant,
                currentRunID: schedule.runID,
                currentRevision: 7,
                currentOccurrenceID: occurrenceID,
                currentEpoch: 12
            )
        )
        XCTAssertFalse(
            QuietTimeBriefAccessPolicy.canCommitScheduledGrant(
                state: state,
                grant: grant,
                currentRunID: schedule.runID,
                currentRevision: 7,
                currentOccurrenceID: UUID(),
                currentEpoch: 11
            )
        )
    }

    func testIdentityRolloverArchivesPriorLedgerWithoutAcceptingThePriorGrant() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let schedule = makeSchedule(start: now, end: now.addingTimeInterval(20 * 60))
        let originalOccurrence = UUID()
        let grant = try XCTUnwrap(
            QuietTimeBriefAccessPolicy.makeGrant(
                runID: schedule.runID,
                scheduleRevision: 3,
                requestedAt: now,
                schedule: schedule,
                occurrenceID: originalOccurrence,
                scheduleEpoch: 5
            )
        )
        var state = QuietTimeBriefAccessState(
            runID: schedule.runID,
            occurrenceID: originalOccurrence,
            scheduleRevision: 3,
            scheduleEpoch: 5,
            updatedAt: now
        )
        XCTAssertTrue(state.propose(grant, at: now))
        XCTAssertTrue(state.markScheduled(nonce: grant.nonce, at: now))

        let nextRunID = UUID()
        let nextOccurrence = UUID()
        state.carryingLedgerForward(
            to: nextRunID,
            occurrenceID: nextOccurrence,
            revision: 1,
            epoch: 6,
            at: now.addingTimeInterval(1)
        )

        XCTAssertEqual(state.durableCount(for: schedule.runID), 1)
        XCTAssertEqual(state.occurrenceID, nextOccurrence)
        XCTAssertEqual(state.scheduleEpoch, 6)
        XCTAssertFalse(
            QuietTimeBriefAccessPolicy.canCommitScheduledGrant(
                state: state,
                grant: grant,
                currentRunID: nextRunID,
                currentRevision: 1,
                currentOccurrenceID: nextOccurrence,
                currentEpoch: 6
            )
        )
    }

    func testWebDomainIsRejectedAndEmptySelectionIsIneligible() {
        let start = Date(timeIntervalSince1970: 1_900_000_000)
        let schedule = makeSchedule(start: start, end: start.addingTimeInterval(20 * 60))

        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.validate(
                route: .webDomain,
                schedule: schedule,
                state: nil,
                at: start,
                hasApplicationOrCategorySelection: true
            ),
            .webDomainRejected
        )
        XCTAssertEqual(
            QuietTimeBriefAccessPolicy.validate(
                route: .category,
                schedule: schedule,
                state: nil,
                at: start,
                hasApplicationOrCategorySelection: false
            ),
            .missingSelection
        )
    }

    private func makeSchedule(start: Date, end: Date) -> QuietTimeShieldScheduleSnapshot {
        QuietTimeShieldScheduleSnapshot(
            runID: UUID(),
            revision: 1,
            protectedSessionInterval: DateInterval(start: start, end: end),
            windDownInterval: nil,
            morningQuietInterval: DateInterval(start: end.addingTimeInterval(-30 * 60), end: end),
            updatedAt: start
        )
    }
}
