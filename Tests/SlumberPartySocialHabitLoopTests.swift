import XCTest

final class SlumberPartySocialHabitLoopTests: XCTestCase {
    func testPrimaryAdmissionRequiresDurableDecisionAndCurrentTransaction() {
        XCTAssertTrue(NightFlockPrimaryRunAdmissionRules.mayAdmit(sharingDecisionStaged: true, transactionIsCurrent: true))
        XCTAssertFalse(NightFlockPrimaryRunAdmissionRules.mayAdmit(sharingDecisionStaged: false, transactionIsCurrent: true))
        XCTAssertFalse(NightFlockPrimaryRunAdmissionRules.mayAdmit(sharingDecisionStaged: true, transactionIsCurrent: false))
        XCTAssertTrue(
            NightFlockPrimaryRunAdmissionRules.mayEnterStart(
                isStartInFlight: true,
                hasVerifiedStagedRun: true
            ),
            "The verified staged continuation reaches coordinator admission exactly once."
        )
        XCTAssertFalse(
            NightFlockPrimaryRunAdmissionRules.mayEnterStart(
                isStartInFlight: true,
                hasVerifiedStagedRun: false
            ),
            "A second manual/NFC tap cannot bypass the staged continuation."
        )
        XCTAssertFalse(
            NightFlockPrimaryRunAdmissionRules.mayEnterStart(
                isStartInFlight: false,
                hasVerifiedStagedRun: true
            )
        )
        let stagedPrivateDecision = NightFlockPrimaryRunSharingDecision(
            runID: UUID(),
            allowsSharing: false,
            capturedAt: .now
        )
        XCTAssertFalse(
            NightFlockPrimaryRunSharingHandoffRules.selectionForStagedContinuation(
                decision: stagedPrivateDecision,
                fallbackSelection: true
            ),
            "A mutable next-run toggle cannot change an already staged automatic admission."
        )
        XCTAssertFalse(
            NightFlockPrimaryRunAdmissionRules.mayMaterializeAutomaticRun(stagedDecision: nil)
        )
        XCTAssertTrue(
            NightFlockPrimaryRunAdmissionRules.mayMaterializeAutomaticRun(
                stagedDecision: stagedPrivateDecision
            ),
            "An expired automatic run is materialized only after its decision is durable."
        )
    }

    func testDecisionStagingPreservesExistingPrivateAutomaticChoice() {
        let runID = UUID()
        let existing = NightFlockPrimaryRunSharingDecision(
            runID: runID,
            allowsSharing: false,
            capturedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let fallback = NightFlockPrimaryRunSharingDecision(
            runID: runID,
            allowsSharing: true,
            capturedAt: existing.capturedAt.addingTimeInterval(60)
        )
        XCTAssertEqual(
            NightFlockPrimaryRunSharingDecisionRules.durableDecision(
                incoming: fallback,
                existing: existing
            ),
            existing,
            "Relaunch staging must return the original private decision, not the current default."
        )
    }

    func testDelayedTerminalReplayRequiresSharedDecisionAndKeepsNightWinnerStable() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let firstID = UUID()
        let strongerID = UUID()
        func terminalRecord(_ id: UUID, minutes: Int, outcome: NightWatchOutcome) -> NightWatchRecord {
            let plan = NightWatchPlan(
                intendedBedtime: base,
                wakeTime: base.addingTimeInterval(8 * 60 * 60),
                protectedUntil: base.addingTimeInterval(8.5 * 60 * 60),
                windDownMinutes: 30,
                morningQuietMinutes: 30,
                eveningActivity: .read,
                morningActivity: .openCurtains,
                calendar: Calendar(identifier: .gregorian)
            )
            return NightWatchRecord(
                id: id,
                plan: plan,
                startedAt: base,
                endedAt: base.addingTimeInterval(TimeInterval(minutes * 60)),
                startMethod: .honorTimer,
                outcome: outcome,
                creditedWindDownMinutes: minutes,
                role: .primarySleepBookend,
                isPractice: false,
                updatedAt: base.addingTimeInterval(TimeInterval(minutes * 60))
            )
        }
        let weaker = terminalRecord(firstID, minutes: 10, outcome: .endedEarly)
        let stronger = terminalRecord(strongerID, minutes: 30, outcome: .completed)
        XCTAssertTrue(
            NightFlockPrimaryRunTerminalReplayRules.recordsEligibleForReplay(
                from: [weaker, stronger],
                decisions: [:]
            ).isEmpty,
            "Missing modern decisions fail closed until restoration completes."
        )
        let shared: [UUID: NightFlockPrimaryRunSharingDecision] = [
            firstID: .init(runID: firstID, allowsSharing: true, capturedAt: base),
            strongerID: .init(runID: strongerID, allowsSharing: true, capturedAt: base)
        ]
        let eligible = NightFlockPrimaryRunTerminalReplayRules.recordsEligibleForReplay(
            from: [weaker, stronger],
            decisions: shared
        )
        XCTAssertEqual(eligible.map(\.id), [strongerID])
        XCTAssertEqual(
            NightFlockPrimaryRunTerminalReplayRules.recordsEligibleForReplay(
                from: [weaker, stronger], decisions: shared
            ),
            eligible,
            "Decision and agreement callbacks can safely replay the same source IDs."
        )
        XCTAssertTrue(
            NightFlockPrimaryRunTerminalReplayRules.recordsEligibleForReplay(
                from: [stronger],
                decisions: [strongerID: .init(runID: strongerID, allowsSharing: false, capturedAt: base)]
            ).isEmpty,
            "A private decision never becomes terminal replay work."
        )
    }

    func testTerminalReceiptReplaySkipsIdenticalFactsAndDoesNotEraseObservedEmergencyFact() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = NightWatchPlan(
            intendedBedtime: date,
            wakeTime: date.addingTimeInterval(8 * 60 * 60),
            protectedUntil: date.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        let record = NightWatchRecord(
            id: UUID(), plan: plan, startedAt: date, endedAt: date.addingTimeInterval(30 * 60),
            startMethod: .honorTimer, outcome: .completed, creditedWindDownMinutes: 30,
            shieldedWindDownMinutes: 30, shieldProtectionEvidence: .observed,
            role: .primarySleepBookend, isPractice: false
        )
        let existing = SharedNightReceipt(
            receiptID: UUID(), partyID: UUID(), memberID: UUID(), memberEpochID: UUID(), agreementID: UUID(),
            planID: nil, planRevision: nil, sourceID: UUID(), revision: 4,
            nightEndingDate: .init(year: 2026, month: 9, day: 1), timeZoneIdentifier: "UTC",
            actualStart: record.startedAt, terminalAt: record.endedAt, outcome: .completed,
            windDownMinutes: 30, protectionMinutes: 30, protectionEvidence: .observed,
            emergencyExitUsed: true, profileSnapshot: .init(displayName: "Moss", avatarID: nil)
        )
        XCTAssertFalse(
            SharedNightReceiptReplayRules.needsPublication(
                record: record,
                evidence: .observed,
                emergencyExitUsed: nil,
                existing: existing
            ),
            "A delayed replay keeps an observed emergency fact when its local terminal record is unknown."
        )
        var corrected = record
        corrected.creditedWindDownMinutes = 25
        XCTAssertFalse(
            SharedNightReceiptReplayRules.needsPublication(
                record: corrected,
                evidence: .observed,
                emergencyExitUsed: nil,
                existing: existing
            ),
            "A lower-minute replay cannot replace the stronger member-night receipt."
        )
        for evidence in [
            SharedNightProtectionEvidence.unavailable,
            .failedOpen,
            .unknown
        ] {
            var nonObserved = existing
            nonObserved.protectionEvidence = evidence
            nonObserved.protectionMinutes = nil
            XCTAssertFalse(
                SharedNightReceiptReplayRules.needsPublication(
                    record: record,
                    evidence: evidence,
                    emergencyExitUsed: nil,
                    existing: nonObserved
                ),
                "\(evidence.rawValue) normalizes protection minutes to unknown, not zero."
            )
        }
        var changedEvidence = existing
        changedEvidence.protectionEvidence = .partial
        XCTAssertTrue(
            SharedNightReceiptReplayRules.needsPublication(
                record: record,
                evidence: .observed,
                emergencyExitUsed: nil,
                existing: changedEvidence
            )
        )
        XCTAssertFalse(
            SharedNightReceiptReplayRules.needsPublication(
                record: record,
                evidence: .partial,
                emergencyExitUsed: nil,
                existing: existing
            ),
            "A weaker evidence correction cannot erase observed protection."
        )
        var unknownEmergency = existing
        unknownEmergency.emergencyExitUsed = nil
        XCTAssertTrue(
            SharedNightReceiptReplayRules.needsPublication(
                record: record,
                evidence: .observed,
                emergencyExitUsed: false,
                existing: unknownEmergency
            ),
            "A known false emergency fact is an information upgrade over unknown."
        )
        XCTAssertTrue(
            SharedNightReceiptReplayRules.needsPublication(
                record: record,
                evidence: .observed,
                emergencyExitUsed: false,
                existing: existing
            ),
            "A known emergency correction remains distinct from an unknown replay."
        )
    }

    func testRelaunchRecoverySelectsEachPersistedPrivatePrimaryPlanOnce() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let privateID = UUID()
        let sharedID = UUID()
        func record(_ id: UUID, role: WindDownOccurrenceRole = .primarySleepBookend) -> NightWatchRecord {
            let plan = NightWatchPlan(
                intendedBedtime: date,
                wakeTime: date.addingTimeInterval(8 * 60 * 60),
                protectedUntil: date.addingTimeInterval(8.5 * 60 * 60),
                windDownMinutes: 30,
                morningQuietMinutes: 30,
                eveningActivity: .read,
                morningActivity: .openCurtains,
                role: role
            )
            return NightWatchRecord(
                id: id,
                plan: plan,
                startedAt: date,
                startMethod: .honorTimer,
                outcome: .completed,
                role: role,
                isPractice: false
            )
        }
        let orphanID = UUID()
        let decisions: [UUID: NightFlockPrimaryRunSharingDecision] = [
            privateID: .init(runID: privateID, allowsSharing: false, capturedAt: date),
            sharedID: .init(runID: sharedID, allowsSharing: true, capturedAt: date),
            orphanID: .init(runID: orphanID, allowsSharing: false, capturedAt: date)
        ]
        let selected = NightFlockPrimaryRunPrivacyRecoveryRules.recordsNeedingPlanFence(
            from: [record(privateID), record(sharedID), record(privateID)],
            decisions: decisions
        )
        XCTAssertEqual(selected.map(\.id), [privateID])
    }

    func testPlanRoundsTimesAndRejectsCustomOrDuplicateSuggestions() {
        let plan = SharedNightPlan(
            planID: UUID(), partyID: UUID(), memberID: UUID(), memberEpochID: UUID(), agreementID: UUID(), revision: 2,
            nightEndingDate: .init(year: 2026, month: 8, day: 31), timeZoneIdentifier: "Asia/Singapore",
            plannedWindDownStart: Date(timeIntervalSince1970: 1_788_192_123), intendedBedtime: Date(timeIntervalSince1970: 1_788_193_234),
            intendedWakeTime: Date(timeIntervalSince1970: 1_788_221_987), morningQuietEnd: Date(timeIntervalSince1970: 1_788_223_001),
            beforeBedMinutes: 30, afterWakingMinutes: 30,
            eveningSuggestionIDs: ["read", "read", "custom note", "stretch"], morningSuggestionIDs: ["openCurtains", "breakfast", "morningWalk"]
        )
        XCTAssertEqual(plan.eveningSuggestionIDs, ["read", "stretch"])
        XCTAssertEqual(plan.morningSuggestionIDs, ["openCurtains", "breakfast"])
        XCTAssertEqual(plan.plannedWindDownStart.timeIntervalSince1970.truncatingRemainder(dividingBy: 300), 0)
    }

    func testReceiptKeepsUnknownDistinctAndNeverCreatesProtectionClaim() {
        let receipt = SharedNightReceipt(
            receiptID: UUID(), partyID: UUID(), memberID: UUID(), memberEpochID: UUID(), agreementID: UUID(), planID: nil, planRevision: nil, sourceID: nil, revision: 1,
            nightEndingDate: .init(year: 2026, month: 8, day: 31), timeZoneIdentifier: "Asia/Singapore", actualStart: nil, terminalAt: nil,
            outcome: .unknown, windDownMinutes: nil, protectionMinutes: 20, protectionEvidence: .unknown, emergencyExitUsed: nil,
            profileSnapshot: .init(displayName: "Clover", avatarID: nil)
        )
        XCTAssertNil(receipt.protectionMinutes)
        XCTAssertEqual(SharedNightPresentation.receiptText(plan: nil, receipt: receipt), "Result unavailable")
    }

    func testReceiptPublicationRequiresRawAndRoundedPostConsentStart() {
        let bucket = Date(timeIntervalSince1970: 1_800_000_000)
        let accepted = bucket.addingTimeInterval(240)
        XCTAssertFalse(SharedNightReceiptPublicationRules.permits(actualStart: nil, acceptedAt: accepted))
        XCTAssertFalse(SharedNightReceiptPublicationRules.permits(actualStart: accepted.addingTimeInterval(-300), acceptedAt: accepted))
        XCTAssertFalse(SharedNightReceiptPublicationRules.permits(actualStart: bucket.addingTimeInterval(180), acceptedAt: accepted))
        XCTAssertTrue(SharedNightReceiptPublicationRules.permits(actualStart: accepted.addingTimeInterval(1), acceptedAt: accepted))
        XCTAssertTrue(SharedNightReceiptPublicationRules.permits(actualStart: accepted.addingTimeInterval(300), acceptedAt: accepted))
    }

    func testStartDifferenceIsFactualNotMetPlanScore() {
        let date = Date(timeIntervalSince1970: 1_788_192_000)
        let ids = (UUID(), UUID(), UUID(), UUID())
        let plan = SharedNightPlan(planID: ids.0, partyID: ids.1, memberID: ids.2, memberEpochID: ids.3, agreementID: UUID(), revision: 1, nightEndingDate: .init(year: 2026, month: 8, day: 31), timeZoneIdentifier: "UTC", plannedWindDownStart: date, intendedBedtime: date, intendedWakeTime: date, morningQuietEnd: date, beforeBedMinutes: 30, afterWakingMinutes: 30, eveningSuggestionIDs: [], morningSuggestionIDs: [])
        let receipt = SharedNightReceipt(receiptID: UUID(), partyID: ids.1, memberID: ids.2, memberEpochID: ids.3, agreementID: plan.agreementID, planID: plan.planID, planRevision: 1, sourceID: UUID(), revision: 1, nightEndingDate: plan.nightEndingDate, timeZoneIdentifier: "UTC", actualStart: date.addingTimeInterval(40 * 60), terminalAt: nil, outcome: .completed, windDownMinutes: 30, protectionMinutes: nil, protectionEvidence: .unavailable, emergencyExitUsed: nil, profileSnapshot: .init(displayName: "Clover", avatarID: nil))
        XCTAssertEqual(SharedNightPlanRules.startRelationship(plan: plan, receipt: receipt), .afterPlan(minutes: 40))
        XCTAssertFalse(SharedNightPresentation.receiptText(plan: plan, receipt: receipt).contains("Met plan"))
    }

    func testV2CapabilitiesRequireBothNegotiatedVersions() {
        let v1 = NightFlockV4ListStateResponse(parties: [], sharedHabitsVersion: 1)
        let v2WithoutPlans = NightFlockV4ListStateResponse(parties: [], sharedHabitsVersion: 2)
        let current = NightFlockV4ListStateResponse(parties: [], sharedHabitsVersion: 2, sharedRoutinePlansVersion: 1)
        XCTAssertTrue(v1.supportsSharedHabits); XCTAssertFalse(v1.supportsSharedNightPlans)
        XCTAssertTrue(v2WithoutPlans.supportsSharedHabits); XCTAssertFalse(v2WithoutPlans.supportsSharedNightPlans)
        XCTAssertTrue(current.supportsSharedNightPlans)
    }

    func testCanonicalPrimaryOccurrencePreservesMidnightMorningQuietExtension() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let preferences = NightWatchPreferences(
            bedtimeHour: 22, bedtimeMinute: 0, wakeHour: 23, wakeMinute: 30,
            windDownMinutes: 30, morningQuietMinutes: 180,
            eveningActivity: .read, morningActivity: .openCurtains,
            guardKind: .honorTimer, isConfigured: true
        )
        let routine = WindDownRoutine.primary(from: preferences)
        let day = try XCTUnwrap(calendar.date(from: .init(year: 2026, month: 11, day: 1)))
        let occurrence = try XCTUnwrap(WindDownScheduleEngine.occurrence(for: routine, on: day, calendar: calendar))
        let projected = WindDownScheduleEngine.plan(
            for: .init(occurrence: occurrence, title: routine.title, recurring: true),
            preferences: preferences,
            startedAt: occurrence.interval.start,
            calendar: calendar
        )
        XCTAssertEqual(calendar.component(.day, from: projected.wakeTime), 1)
        XCTAssertEqual(calendar.component(.day, from: projected.protectedUntil), 2)
        XCTAssertEqual(projected.protectedUntil.timeIntervalSince(projected.wakeTime), 180 * 60)
    }

    func testScheduleReconciliationCancelsRemovedOrMovedFuturePlansButKeepsStartedPlans() {
        let party = UUID(); let member = UUID(); let epoch = UUID(); let agreement = UUID()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let removed = NightFlockLocalDate(year: 2027, month: 1, day: 2)
        let movedFrom = NightFlockLocalDate(year: 2027, month: 1, day: 3)
        let movedTo = NightFlockLocalDate(year: 2027, month: 1, day: 4)
        let started = NightFlockLocalDate(year: 2027, month: 1, day: 5)
        func plan(_ night: NightFlockLocalDate, _ revision: Int64, start: Date) -> SharedNightPlan {
            SharedNightPlan(
                planID: SharedNightPlanRules.versionedPlanID(partyID: party, memberEpochID: epoch, nightEndingDate: night, revision: revision),
                partyID: party, memberID: member, memberEpochID: epoch, agreementID: agreement, revision: revision,
                nightEndingDate: night, timeZoneIdentifier: "UTC", plannedWindDownStart: start,
                intendedBedtime: start.addingTimeInterval(30 * 60), intendedWakeTime: start.addingTimeInterval(9 * 60 * 60),
                morningQuietEnd: start.addingTimeInterval(9.5 * 60 * 60), beforeBedMinutes: 30, afterWakingMinutes: 30,
                eveningSuggestionIDs: [], morningSuggestionIDs: []
            )
        }
        let oldPlans = [
            plan(removed, 1, start: now.addingTimeInterval(3_600)),
            plan(movedFrom, 1, start: now.addingTimeInterval(7_200)),
            plan(started, 1, start: now.addingTimeInterval(-300)),
        ]
        let stale = SharedNightPlanRules.staleFuturePlans(oldPlans, desiredNightEndingDates: [movedTo], now: now)
        XCTAssertEqual(Set(stale.map(\.nightEndingDate)), [removed, movedFrom], "A disabled or moved occurrence retracts its old future anchor.")
        XCTAssertFalse(stale.contains { $0.nightEndingDate == started }, "A started plan stays available for its frozen receipt.")
        XCTAssertEqual(
            SharedNightPlanRules.staleFuturePlans(oldPlans, desiredNightEndingDates: [movedTo], now: now),
            stale,
            "Relaunch reconciliation is idempotent before its revision-fenced cancellation is acknowledged."
        )
    }

    func testSharedNightOutboxReplacesSameNightButSeparatesMembershipEpochs() {
        let partyID = UUID(); let epoch = UUID(); let nextEpoch = UUID(); let agreement = UUID()
        func plan(_ epoch: UUID, _ revision: Int64) -> SharedNightPlan {
            .init(planID: SharedNightPlanRules.stablePlanID(partyID: partyID, memberEpochID: epoch, nightEndingDate: .init(year: 2026, month: 9, day: 1)), partyID: partyID, memberID: UUID(), memberEpochID: epoch, agreementID: agreement, revision: revision, nightEndingDate: .init(year: 2026, month: 9, day: 1), timeZoneIdentifier: "UTC", plannedWindDownStart: .now, intendedBedtime: .now, intendedWakeTime: .now, morningQuietEnd: .now, beforeBedMinutes: 30, afterWakingMinutes: 30, eveningSuggestionIDs: [], morningSuggestionIDs: [])
        }
        let first = NightFlockSharedNightOutboxRecord(id: UUID(), payload: .plan(plan(epoch, 1)), partyID: partyID, agreementID: agreement, memberEpochID: epoch, idempotencyKey: "one", attemptCount: 0, createdAt: .now)
        let revision = NightFlockSharedNightOutboxRecord(id: UUID(), payload: .plan(plan(epoch, 2)), partyID: partyID, agreementID: agreement, memberEpochID: epoch, idempotencyKey: "two", attemptCount: 0, createdAt: .now)
        let rejoined = NightFlockSharedNightOutboxRecord(id: UUID(), payload: .plan(plan(nextEpoch, 1)), partyID: partyID, agreementID: agreement, memberEpochID: nextEpoch, idempotencyKey: "three", attemptCount: 0, createdAt: .now)
        let replaced = try? XCTUnwrap(NightFlockSharedNightOutboxRules.merge(revision, into: [first]))
        XCTAssertEqual(replaced?.count, 1)
        XCTAssertEqual((try? XCTUnwrap(replaced?.first))?.idempotencyKey, "two")
        XCTAssertEqual(NightFlockSharedNightOutboxRules.markingAttempt(first, in: replaced ?? []).first?.attemptCount, 0)
        XCTAssertEqual(NightFlockSharedNightOutboxRules.merge(rejoined, into: replaced ?? [])?.count, 2)
        let reverse = NightFlockSharedNightOutboxRules.merge(first, into: replaced ?? [])
        XCTAssertEqual((try? XCTUnwrap(reverse?.first(where: { $0.memberEpochID == epoch })))?.idempotencyKey, "two")
        let cancellation = SharedNightPlanCancellation(
            partyID: partyID, memberEpochID: epoch, agreementID: agreement,
            nightEndingDate: .init(year: 2026, month: 9, day: 1), timeZoneIdentifier: "UTC", revision: 3
        )
        let cancelled = NightFlockSharedNightOutboxRules.merge(
            .init(id: UUID(), payload: .cancellation(cancellation), partyID: partyID, agreementID: agreement, memberEpochID: epoch, idempotencyKey: "cancel", attemptCount: 0, createdAt: .now),
            into: reverse ?? []
        )
        XCTAssertEqual(cancelled?.filter { $0.memberEpochID == epoch }.count, 1)
        XCTAssertNil(NightFlockSharedNightOutboxRules.merge(first, into: cancelled ?? [])?.first(where: { $0.memberEpochID == epoch && $0.idempotencyKey == "one" }))
        let olderCancellation = SharedNightPlanCancellation(
            partyID: partyID, memberEpochID: epoch, agreementID: agreement,
            nightEndingDate: cancellation.nightEndingDate, timeZoneIdentifier: "UTC", revision: 2
        )
        let reverseCancellation = NightFlockSharedNightOutboxRules.merge(
            .init(id: UUID(), payload: .cancellation(olderCancellation), partyID: partyID, agreementID: agreement, memberEpochID: epoch, idempotencyKey: "older-cancel", attemptCount: 0, createdAt: .now),
            into: cancelled ?? []
        )
        XCTAssertEqual(reverseCancellation?.first(where: { $0.memberEpochID == epoch })?.idempotencyKey, "cancel")
        let equalCancellation = NightFlockSharedNightOutboxRules.merge(
            .init(id: UUID(), payload: .cancellation(cancellation), partyID: partyID, agreementID: agreement, memberEpochID: epoch, idempotencyKey: "equal-cancel", attemptCount: 0, createdAt: .now),
            into: cancelled ?? []
        )
        XCTAssertEqual(equalCancellation?.first(where: { $0.memberEpochID == epoch })?.idempotencyKey, "cancel")
        XCTAssertEqual(
            SharedNightPlanCancellationRules.merging(olderCancellation, into: [cancellation]),
            [cancellation],
            "A relaunch must not downgrade the durable privacy fence."
        )
        let newerCancellation = SharedNightPlanCancellation(
            partyID: partyID, memberEpochID: epoch, agreementID: agreement,
            nightEndingDate: cancellation.nightEndingDate, timeZoneIdentifier: "UTC", revision: 4
        )
        XCTAssertEqual(
            SharedNightPlanCancellationRules.merging(newerCancellation, into: [cancellation]),
            [newerCancellation]
        )
    }

    func testSharedNightOutboxPrivacyCancellationDominatesScheduleRegardlessOfRevisionOrArrivalOrder() throws {
        let party = UUID(), epoch = UUID(), agreement = UUID()
        let night = NightFlockLocalDate(year: 2026, month: 9, day: 1)
        let created = Date(timeIntervalSince1970: 1_800_000_000)

        func record(
            _ authority: SharedNightPlanCancellation.Authority,
            revision: Int64,
            key: String,
            id: UUID = UUID()
        ) -> NightFlockSharedNightOutboxRecord {
            let cancellation = SharedNightPlanCancellation(
                partyID: party,
                memberEpochID: epoch,
                agreementID: agreement,
                nightEndingDate: night,
                timeZoneIdentifier: "UTC",
                revision: revision,
                authority: authority
            )
            return .init(
                id: id,
                payload: .cancellation(cancellation),
                partyID: party,
                agreementID: agreement,
                memberEpochID: epoch,
                idempotencyKey: key,
                attemptCount: 0,
                createdAt: created
            )
        }

        let highSchedule = record(.schedule, revision: 9, key: "schedule-9")
        let lowPrivacy = record(.privacy, revision: 2, key: "privacy-2")

        let privacyAfterSchedule = try XCTUnwrap(
            NightFlockSharedNightOutboxRules.merge(lowPrivacy, into: [highSchedule])
        )
        let scheduleAfterPrivacy = try XCTUnwrap(
            NightFlockSharedNightOutboxRules.merge(highSchedule, into: [lowPrivacy])
        )

        for queue in [privacyAfterSchedule, scheduleAfterPrivacy] {
            let selected = try XCTUnwrap(queue.first)
            guard case let .cancellation(value) = selected.payload else {
                return XCTFail("expected the privacy cancellation")
            }
            XCTAssertEqual(value.authority, .privacy)
            XCTAssertEqual(value.revision, 2, "Privacy must upgrade schedule authority without requiring a higher revision.")
            XCTAssertEqual(selected.idempotencyKey, "privacy-2")
        }

        let restored = try JSONDecoder().decode(
            [NightFlockSharedNightOutboxRecord].self,
            from: JSONEncoder().encode(privacyAfterSchedule)
        )
        XCTAssertEqual(
            NightFlockSharedNightOutboxRules.acknowledging(highSchedule, in: restored),
            restored,
            "An in-flight schedule acknowledgement cannot remove the privacy replacement."
        )
        XCTAssertEqual(
            NightFlockSharedNightOutboxRules.markingAttempt(highSchedule, in: restored),
            restored,
            "An in-flight schedule failure cannot increment the privacy replacement."
        )

        // A malformed/recovered queue with a reused physical UUID still gets
        // a fresh identity when privacy replaces schedule, so stale ack safety
        // does not rely on well-formed callers.
        let collidingPrivacy = record(.privacy, revision: 2, key: "privacy-colliding", id: highSchedule.id)
        let collisionSafe = try XCTUnwrap(
            NightFlockSharedNightOutboxRules.merge(collidingPrivacy, into: [highSchedule])
        )
        let collisionReplacement = try XCTUnwrap(collisionSafe.first)
        XCTAssertNotEqual(collisionReplacement.id, highSchedule.id)
        XCTAssertEqual(
            NightFlockSharedNightOutboxRules.acknowledging(highSchedule, in: collisionSafe),
            collisionSafe
        )
    }

    func testSharedNightReceiptOutboxKeepsStrongestFactualCorrectionOffline() {
        let party = UUID(), epoch = UUID(), agreement = UUID(), member = UUID()
        let night = NightFlockLocalDate(year: 2026, month: 9, day: 1)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        func receipt(_ revision: Int64, evidence: SharedNightProtectionEvidence, emergency: Bool?) -> SharedNightReceipt {
            .init(
                receiptID: UUID(), partyID: party, memberID: member, memberEpochID: epoch, agreementID: agreement,
                planID: nil, planRevision: nil,
                sourceID: SharedNightPlanRules.stableReceiptSourceID(partyID: party, memberEpochID: epoch, nightEndingDate: night),
                revision: revision, nightEndingDate: night, timeZoneIdentifier: "UTC", actualStart: start,
                terminalAt: start.addingTimeInterval(30 * 60), outcome: .completed,
                windDownMinutes: 30, protectionMinutes: 30, protectionEvidence: evidence,
                emergencyExitUsed: emergency, profileSnapshot: .init(displayName: "Moss", avatarID: nil)
            )
        }
        func queued(_ receipt: SharedNightReceipt, attempts: Int = 0) -> NightFlockSharedNightOutboxRecord {
            .init(id: UUID(), payload: .receipt(receipt), partyID: party, agreementID: agreement,
                  memberEpochID: epoch, idempotencyKey: "r-\(receipt.revision)", attemptCount: attempts, createdAt: start)
        }
        let observed = queued(receipt(1, evidence: .observed, emergency: true), attempts: 3)
        let partial = queued(receipt(2, evidence: .partial, emergency: nil))
        let protected = try! XCTUnwrap(
            try! XCTUnwrap(NightFlockSharedNightOutboxRules.merge(partial, into: [observed])).first
        )
        guard case let .receipt(protectedReceipt) = protected.payload else { return XCTFail("expected receipt") }
        XCTAssertEqual(protectedReceipt.protectionEvidence, .observed)
        XCTAssertEqual(protectedReceipt.emergencyExitUsed, true)
        XCTAssertEqual(protectedReceipt.revision, 3)
        XCTAssertEqual(protected.attemptCount, 3)

        let partialFirst = queued(receipt(1, evidence: .partial, emergency: nil))
        let observedUpgrade = queued(receipt(2, evidence: .observed, emergency: nil))
        let upgraded = try! XCTUnwrap(
            try! XCTUnwrap(NightFlockSharedNightOutboxRules.merge(observedUpgrade, into: [partialFirst])).first
        )
        guard case let .receipt(upgradedReceipt) = upgraded.payload else { return XCTFail("expected receipt") }
        XCTAssertEqual(upgradedReceipt.protectionEvidence, .observed)

        let emergencyCorrection = queued(receipt(3, evidence: .observed, emergency: false))
        let corrected = try! XCTUnwrap(
            try! XCTUnwrap(NightFlockSharedNightOutboxRules.merge(emergencyCorrection, into: [upgraded])).first
        )
        guard case let .receipt(correctedReceipt) = corrected.payload else { return XCTFail("expected receipt") }
        XCTAssertEqual(correctedReceipt.emergencyExitUsed, false)

        let reverse = try! XCTUnwrap(
            try! XCTUnwrap(NightFlockSharedNightOutboxRules.merge(observed, into: [partial])).first
        )
        guard case let .receipt(reverseReceipt) = reverse.payload else { return XCTFail("expected receipt") }
        XCTAssertEqual(reverseReceipt.protectionEvidence, .observed)
        XCTAssertEqual(reverseReceipt.emergencyExitUsed, true)
        XCTAssertEqual(reverseReceipt.revision, protectedReceipt.revision)

        let knownLow = queued(receipt(1, evidence: .observed, emergency: true))
        let unknownHigh = queued(receipt(2, evidence: .observed, emergency: nil))
        let forwardHybrid = try! XCTUnwrap(
            try! XCTUnwrap(NightFlockSharedNightOutboxRules.merge(unknownHigh, into: [knownLow])).first
        )
        let reverseHybrid = try! XCTUnwrap(
            try! XCTUnwrap(NightFlockSharedNightOutboxRules.merge(knownLow, into: [unknownHigh])).first
        )
        guard case let .receipt(forwardReceipt) = forwardHybrid.payload,
              case let .receipt(reverseReceipt) = reverseHybrid.payload
        else { return XCTFail("expected receipt") }
        XCTAssertEqual(forwardReceipt.emergencyExitUsed, true)
        XCTAssertEqual(reverseReceipt.emergencyExitUsed, true)
        XCTAssertEqual(forwardReceipt.revision, 3)
        XCTAssertEqual(reverseReceipt.revision, 3)
        XCTAssertEqual(forwardHybrid.idempotencyKey, reverseHybrid.idempotencyKey)

        let sameAgain = try! XCTUnwrap(
            try! XCTUnwrap(NightFlockSharedNightOutboxRules.merge(forwardHybrid, into: [forwardHybrid])).first
        )
        guard case let .receipt(sameAgainReceipt) = sameAgain.payload else { return XCTFail("expected receipt") }
        XCTAssertEqual(sameAgainReceipt.revision, forwardReceipt.revision)

        let nilFacts = SharedNightReceiptCorrectionFacts(actualStart: start, terminalAt: nil, outcome: .completed, windDownMinutes: 30, protectionMinutes: 30, protectionEvidence: .observed, emergencyExitUsed: nil)
        var falseFacts = nilFacts; falseFacts.emergencyExitUsed = false
        XCTAssertTrue(SharedNightReceiptCorrectionRules.permits(candidate: falseFacts, over: nilFacts))
        XCTAssertFalse(SharedNightReceiptCorrectionRules.permits(candidate: nilFacts, over: falseFacts))

        let falseHigh = queued(receipt(3, evidence: .observed, emergency: false))
        let trueLow = queued(receipt(2, evidence: .observed, emergency: true))
        let falseWinnerA = try! XCTUnwrap(try! XCTUnwrap(NightFlockSharedNightOutboxRules.merge(trueLow, into: [falseHigh])).first)
        let falseWinnerB = try! XCTUnwrap(try! XCTUnwrap(NightFlockSharedNightOutboxRules.merge(falseHigh, into: [trueLow])).first)
        guard case let .receipt(falseReceiptA) = falseWinnerA.payload,
              case let .receipt(falseReceiptB) = falseWinnerB.payload else { return XCTFail("expected receipt") }
        XCTAssertEqual(falseReceiptA.emergencyExitUsed, false)
        XCTAssertEqual(falseReceiptA, falseReceiptB)

        let trueEqual = queued(receipt(4, evidence: .observed, emergency: true))
        let falseEqual = queued(receipt(4, evidence: .observed, emergency: false))
        let equalA = try! XCTUnwrap(try! XCTUnwrap(NightFlockSharedNightOutboxRules.merge(falseEqual, into: [trueEqual])).first)
        let equalB = try! XCTUnwrap(try! XCTUnwrap(NightFlockSharedNightOutboxRules.merge(trueEqual, into: [falseEqual])).first)
        guard case let .receipt(equalReceiptA) = equalA.payload,
              case let .receipt(equalReceiptB) = equalB.payload else { return XCTFail("expected receipt") }
        XCTAssertEqual(equalReceiptA.emergencyExitUsed, true)
        XCTAssertEqual(equalReceiptA, equalReceiptB)

        var earlierTimestampReceipt = receipt(5, evidence: .observed, emergency: true)
        earlierTimestampReceipt.terminalAt = start.addingTimeInterval(25 * 60)
        var laterTimestampReceipt = receipt(6, evidence: .observed, emergency: true)
        laterTimestampReceipt.terminalAt = start.addingTimeInterval(30 * 60)
        let earlierTimestamp = queued(earlierTimestampReceipt)
        let laterTimestamp = queued(laterTimestampReceipt)
        let timestampA = try! XCTUnwrap(try! XCTUnwrap(NightFlockSharedNightOutboxRules.merge(laterTimestamp, into: [earlierTimestamp])).first)
        let timestampB = try! XCTUnwrap(try! XCTUnwrap(NightFlockSharedNightOutboxRules.merge(earlierTimestamp, into: [laterTimestamp])).first)
        guard case let .receipt(timestampReceiptA) = timestampA.payload,
              case let .receipt(timestampReceiptB) = timestampB.payload else { return XCTFail("expected receipt") }
        XCTAssertEqual(timestampReceiptA.terminalAt, laterTimestampReceipt.terminalAt)
        XCTAssertEqual(timestampReceiptA, timestampReceiptB)
        XCTAssertEqual(timestampA.idempotencyKey, timestampB.idempotencyKey)

        earlierTimestampReceipt.revision = 7
        laterTimestampReceipt.revision = 7
        let equalTimestampA = try! XCTUnwrap(try! XCTUnwrap(NightFlockSharedNightOutboxRules.merge(queued(laterTimestampReceipt), into: [queued(earlierTimestampReceipt)])).first)
        let equalTimestampB = try! XCTUnwrap(try! XCTUnwrap(NightFlockSharedNightOutboxRules.merge(queued(earlierTimestampReceipt), into: [queued(laterTimestampReceipt)])).first)
        guard case let .receipt(equalTimestampReceiptA) = equalTimestampA.payload,
              case let .receipt(equalTimestampReceiptB) = equalTimestampB.payload else { return XCTFail("expected receipt") }
        XCTAssertEqual(equalTimestampReceiptA.terminalAt, laterTimestampReceipt.terminalAt)
        XCTAssertEqual(equalTimestampReceiptA, equalTimestampReceiptB)
        XCTAssertEqual(equalTimestampA.idempotencyKey, equalTimestampB.idempotencyKey)
    }

    func testSharedNightReceiptAcknowledgementCannotRemoveOrRetryMergedReplacement() throws {
        let party = UUID(), epoch = UUID(), agreement = UUID(), member = UUID()
        let night = NightFlockLocalDate(year: 2026, month: 9, day: 1)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let source = SharedNightPlanRules.stableReceiptSourceID(
            partyID: party, memberEpochID: epoch, nightEndingDate: night
        )

        func receipt(_ revision: Int64, evidence: SharedNightProtectionEvidence, emergency: Bool?) -> SharedNightReceipt {
            .init(
                receiptID: UUID(), partyID: party, memberID: member, memberEpochID: epoch, agreementID: agreement,
                planID: nil, planRevision: nil, sourceID: source, revision: revision,
                nightEndingDate: night, timeZoneIdentifier: "UTC", actualStart: start,
                terminalAt: start.addingTimeInterval(30 * 60), outcome: .completed,
                windDownMinutes: 30, protectionMinutes: 30, protectionEvidence: evidence,
                emergencyExitUsed: emergency, profileSnapshot: .init(displayName: "Moss", avatarID: nil)
            )
        }
        func queued(_ receipt: SharedNightReceipt, key: String) -> NightFlockSharedNightOutboxRecord {
            .init(
                id: UUID(), payload: .receipt(receipt), partyID: party, agreementID: agreement,
                memberEpochID: epoch, idempotencyKey: key, attemptCount: 0, createdAt: start
            )
        }

        // The in-flight observed receipt wins factual precedence, but must be
        // promoted above the newer weak retry. Its new command needs a fresh
        // physical row so the old acknowledgement cannot remove it.
        let observedInFlight = queued(receipt(1, evidence: .observed, emergency: true), key: "old-observed")
        let weakerNewer = queued(receipt(2, evidence: .partial, emergency: nil), key: "newer-partial")
        let promotedExisting = try XCTUnwrap(
            NightFlockSharedNightOutboxRules.merge(weakerNewer, into: [observedInFlight])?.first
        )
        guard case let .receipt(promotedExistingReceipt) = promotedExisting.payload else {
            return XCTFail("expected receipt")
        }
        XCTAssertNotEqual(promotedExisting.id, observedInFlight.id)
        XCTAssertEqual(promotedExistingReceipt.revision, 3)
        XCTAssertEqual(promotedExistingReceipt.emergencyExitUsed, true)
        XCTAssertNotEqual(promotedExisting.idempotencyKey, observedInFlight.idempotencyKey)
        let restoredExisting = try JSONDecoder().decode(
            [NightFlockSharedNightOutboxRecord].self,
            from: JSONEncoder().encode([promotedExisting])
        )
        XCTAssertEqual(
            NightFlockSharedNightOutboxRules.acknowledging(observedInFlight, in: restoredExisting),
            restoredExisting,
            "An acknowledgement from the old physical command cannot erase a durable promoted replacement."
        )
        XCTAssertEqual(
            NightFlockSharedNightOutboxRules.markingAttempt(observedInFlight, in: restoredExisting),
            restoredExisting,
            "A stale transient failure cannot increment the replacement's retry count."
        )

        // Here the incoming observed receipt wins core facts, then receives a
        // known emergency fact from the older partial row. That hybrid is also
        // a new command and must not retain either physical id.
        let partialInFlight = queued(receipt(1, evidence: .partial, emergency: false), key: "old-partial")
        let observedUnknown = queued(receipt(2, evidence: .observed, emergency: nil), key: "new-observed")
        let promotedIncoming = try XCTUnwrap(
            NightFlockSharedNightOutboxRules.merge(observedUnknown, into: [partialInFlight])?.first
        )
        guard case let .receipt(promotedIncomingReceipt) = promotedIncoming.payload else {
            return XCTFail("expected receipt")
        }
        XCTAssertNotEqual(promotedIncoming.id, partialInFlight.id)
        XCTAssertNotEqual(promotedIncoming.id, observedUnknown.id)
        XCTAssertEqual(promotedIncomingReceipt.revision, 3)
        XCTAssertEqual(promotedIncomingReceipt.protectionEvidence, .observed)
        XCTAssertEqual(promotedIncomingReceipt.emergencyExitUsed, false)
        XCTAssertNotEqual(promotedIncoming.idempotencyKey, observedUnknown.idempotencyKey)
        XCTAssertEqual(
            NightFlockSharedNightOutboxRules.acknowledging(partialInFlight, in: [promotedIncoming]),
            [promotedIncoming]
        )
        XCTAssertEqual(
            NightFlockSharedNightOutboxRules.markingAttempt(partialInFlight, in: [promotedIncoming]),
            [promotedIncoming]
        )
    }

    func testV1SharedHabitsEqualRevisionCorrectionPromotesAndSurvivesOldCompletion() throws {
        let party = UUID(), agreement = UUID(), epoch = UUID(), member = UUID(), source = UUID()
        let date = NightFlockLocalDate(year: 2026, month: 9, day: 1)
        func queued(minutes: Int, evidence: NightFlockSharedHabitEvidence, revision: Int64, key: String) -> NightFlockSharedHabitsOutboxRecord {
            let record = NightFlockSharedHabitRecord(
                recordID: UUID(), partyID: party, memberID: member, sourceID: source, revision: revision,
                kind: .windDown, localDate: date, activityDate: nil, timeZoneIdentifier: "UTC",
                minutes: minutes, outcome: minutes >= 30 ? .completed : .partlyCompleted,
                protectionMinutes: evidence == .appRecorded ? minutes : nil, evidence: evidence,
                profileSnapshot: .init(displayName: "Moss", avatarID: nil), isFormerMember: false, migratedAt: nil
            )
            return .init(record: record, agreementID: agreement, memberEpochID: epoch, idempotencyKey: key, attemptCount: 0, createdAt: .now)
        }

        let weakInFlight = queued(minutes: 20, evidence: .none, revision: 4, key: "weak")
        let strongEqualRevision = queued(minutes: 30, evidence: .appRecorded, revision: 4, key: "strong")
        let incomingWinner = try XCTUnwrap(
            NightFlockSharedHabitsOutboxRules.merge(strongEqualRevision, into: [weakInFlight])?.first
        )
        XCTAssertEqual(incomingWinner.record.minutes, 30)
        XCTAssertEqual(incomingWinner.record.revision, 5)
        XCTAssertNotEqual(incomingWinner.record.recordID, strongEqualRevision.record.recordID)
        XCTAssertNotEqual(incomingWinner.idempotencyKey, strongEqualRevision.idempotencyKey)
        let reloaded = try JSONDecoder().decode(
            [NightFlockSharedHabitsOutboxRecord].self,
            from: JSONEncoder().encode([incomingWinner])
        )
        XCTAssertEqual(NightFlockSharedHabitsOutboxRules.acknowledging(weakInFlight, in: reloaded), reloaded)
        XCTAssertEqual(NightFlockSharedHabitsOutboxRules.markingAttempt(weakInFlight, in: reloaded), reloaded)

        let strongInFlight = queued(minutes: 30, evidence: .appRecorded, revision: 4, key: "strong-old")
        let weakEqualRevision = queued(minutes: 20, evidence: .none, revision: 4, key: "weak-new")
        let existingWinner = try XCTUnwrap(
            NightFlockSharedHabitsOutboxRules.merge(weakEqualRevision, into: [strongInFlight])?.first
        )
        XCTAssertEqual(existingWinner.record.minutes, 30)
        XCTAssertEqual(existingWinner.record.revision, 5)
        XCTAssertNotEqual(existingWinner.record.recordID, strongInFlight.record.recordID)
        XCTAssertNotEqual(existingWinner.idempotencyKey, strongInFlight.idempotencyKey)
        XCTAssertEqual(NightFlockSharedHabitsOutboxRules.acknowledging(strongInFlight, in: [existingWinner]), [existingWinner])
        XCTAssertEqual(NightFlockSharedHabitsOutboxRules.markingAttempt(strongInFlight, in: [existingWinner]), [existingWinner])
        XCTAssertEqual(
            NightFlockSharedHabitsOutboxRules.merge(weakEqualRevision, into: [existingWinner])?.first?.record.revision,
            5,
            "A delayed weak duplicate cannot cause promoted revision growth."
        )
        XCTAssertEqual(
            NightFlockSharedHabitsOutboxFailurePolicy.disposition(for: .staleRevision),
            .dropRecordAndReconcile,
            "A server-stale exact row is reconciled rather than retried forever."
        )
    }

    func testPlanAcknowledgementCannotRestoreBindingAfterQueuedCancellation() throws {
        let party = UUID(), epoch = UUID(), agreement = UUID(), member = UUID()
        let night = NightFlockLocalDate(year: 2026, month: 9, day: 1)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = SharedNightPlan(
            planID: SharedNightPlanRules.versionedPlanID(
                partyID: party, memberEpochID: epoch, nightEndingDate: night, revision: 1
            ),
            partyID: party, memberID: member, memberEpochID: epoch, agreementID: agreement, revision: 1,
            nightEndingDate: night, timeZoneIdentifier: "UTC", plannedWindDownStart: start,
            intendedBedtime: start.addingTimeInterval(30 * 60), intendedWakeTime: start.addingTimeInterval(9 * 60 * 60),
            morningQuietEnd: start.addingTimeInterval(9.5 * 60 * 60), beforeBedMinutes: 30, afterWakingMinutes: 30,
            eveningSuggestionIDs: [], morningSuggestionIDs: []
        )
        let inFlightPlan = NightFlockSharedNightOutboxRecord(
            id: UUID(), payload: .plan(plan), partyID: party, agreementID: agreement, memberEpochID: epoch,
            idempotencyKey: "plan-1", attemptCount: 0, createdAt: start
        )
        func cancellation(_ authority: SharedNightPlanCancellation.Authority) -> NightFlockSharedNightOutboxRecord {
            let value = SharedNightPlanCancellation(
                partyID: party, memberEpochID: epoch, agreementID: agreement, nightEndingDate: night,
                timeZoneIdentifier: "UTC", revision: 2, authority: authority
            )
            return .init(
                id: UUID(), payload: .cancellation(value), partyID: party, agreementID: agreement,
                memberEpochID: epoch, idempotencyKey: "cancel-\(authority.rawValue)", attemptCount: 0, createdAt: start
            )
        }

        for authority in [SharedNightPlanCancellation.Authority.privacy, .schedule] {
            let queuedCancellation = cancellation(authority)
            let queue = try XCTUnwrap(NightFlockSharedNightOutboxRules.merge(queuedCancellation, into: [inFlightPlan]))
            let reloaded = try JSONDecoder().decode(
                [NightFlockSharedNightOutboxRecord].self,
                from: JSONEncoder().encode(queue)
            )
            XCTAssertFalse(
                NightFlockSharedNightOutboxRules.shouldRecordPlanBinding(
                    for: inFlightPlan, plan: plan, serverAcceptedBinding: true, in: reloaded
                ),
                "A \(authority.rawValue) cancellation that arrived first blocks the old plan acknowledgement."
            )
            XCTAssertTrue(
                SharedNightPlanBindingPolicy.shouldClearBinding(
                    binding: plan,
                    acknowledgedPlan: plan,
                    acknowledgement: .bind,
                    queuedCancellation: true,
                    hasNewerQueuedPlan: false
                ),
                "Once this cancellation is durable, the same actor turn clears the old frozen-plan binding."
            )
            XCTAssertEqual(
                NightFlockSharedNightOutboxRules.acknowledging(inFlightPlan, in: reloaded),
                reloaded,
                "The old plan is already superseded; its success cannot remove the queued cancellation."
            )
            XCTAssertEqual(reloaded.count, 1)
            guard case .cancellation = reloaded[0].payload else { return XCTFail("expected queued cancellation") }
        }
    }

    func testCancellationWinsAtCapacityWithoutLeavingAPlanBindingCandidate() throws {
        let party = UUID(), epoch = UUID(), agreement = UUID(), member = UUID()
        let night = NightFlockLocalDate(year: 2026, month: 9, day: 1)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = SharedNightPlan(
            planID: SharedNightPlanRules.versionedPlanID(
                partyID: party, memberEpochID: epoch, nightEndingDate: night, revision: 1
            ),
            partyID: party, memberID: member, memberEpochID: epoch, agreementID: agreement, revision: 1,
            nightEndingDate: night, timeZoneIdentifier: "UTC", plannedWindDownStart: start,
            intendedBedtime: start.addingTimeInterval(30 * 60), intendedWakeTime: start.addingTimeInterval(9 * 60 * 60),
            morningQuietEnd: start.addingTimeInterval(9.5 * 60 * 60), beforeBedMinutes: 30, afterWakingMinutes: 30,
            eveningSuggestionIDs: [], morningSuggestionIDs: []
        )
        let inFlight = NightFlockSharedNightOutboxRecord(
            id: UUID(), payload: .plan(plan), partyID: party, agreementID: agreement, memberEpochID: epoch,
            idempotencyKey: "plan", attemptCount: 0, createdAt: start
        )
        let fillers = (0..<127).map { offset in
            NightFlockSharedNightOutboxRecord(
                id: UUID(), payload: .plan(plan), partyID: UUID(), agreementID: agreement, memberEpochID: epoch,
                idempotencyKey: "filler-\(offset)", attemptCount: 0, createdAt: start.addingTimeInterval(Double(offset + 1))
            )
        }
        let cancellation = SharedNightPlanCancellation(
            partyID: party, memberEpochID: epoch, agreementID: agreement, nightEndingDate: night,
            timeZoneIdentifier: "UTC", revision: 2, authority: .privacy
        )
        let queuedCancellation = NightFlockSharedNightOutboxRecord(
            id: UUID(), payload: .cancellation(cancellation), partyID: party, agreementID: agreement,
            memberEpochID: epoch, idempotencyKey: "cancel", attemptCount: 0, createdAt: start
        )

        let merged = try XCTUnwrap(NightFlockSharedNightOutboxRules.merge(queuedCancellation, into: [inFlight] + fillers))
        let reloaded = try JSONDecoder().decode(
            [NightFlockSharedNightOutboxRecord].self,
            from: JSONEncoder().encode(merged)
        )
        XCTAssertEqual(reloaded.count, 128)
        XCTAssertFalse(reloaded.contains { $0.isExactPublication(inFlight) })
        XCTAssertTrue(reloaded.contains { $0.isExactPublication(queuedCancellation) })
        XCTAssertFalse(
            NightFlockSharedNightOutboxRules.shouldRecordPlanBinding(
                for: inFlight, plan: plan, serverAcceptedBinding: true, in: reloaded
            ),
            "An old accepted callback cannot recreate a binding after the capacity-prioritized cancellation."
        )
    }

    func testCancellationCapacityNeverEvictsAnUnrelatedTombstone() throws {
        let agreement = UUID(), epoch = UUID(), member = UUID()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let night = NightFlockLocalDate(year: 2026, month: 9, day: 1)
        func cancellationRecord(
            party: UUID = UUID(),
            nightEndingDate: NightFlockLocalDate = night,
            revision: Int64 = 1,
            authority: SharedNightPlanCancellation.Authority = .privacy
        ) -> NightFlockSharedNightOutboxRecord {
            let cancellation = SharedNightPlanCancellation(
                partyID: party, memberEpochID: epoch, agreementID: agreement,
                nightEndingDate: nightEndingDate, timeZoneIdentifier: "UTC",
                revision: revision, authority: authority
            )
            return .init(
                id: UUID(), payload: .cancellation(cancellation), partyID: party,
                agreementID: agreement, memberEpochID: epoch,
                idempotencyKey: "cancel-\(party.uuidString)-\(revision)", attemptCount: 0,
                createdAt: start.addingTimeInterval(Double(revision))
            )
        }

        let allTombstones = (0..<128).map { index in
            cancellationRecord(
                revision: Int64(index + 1),
                authority: index.isMultiple(of: 2) ? .privacy : .schedule
            )
        }
        let unrelated = cancellationRecord(revision: 500, authority: .schedule)
        XCTAssertNil(
            NightFlockSharedNightOutboxRules.merge(unrelated, into: allTombstones),
            "A full tombstone queue is authoritative and cannot silently discard another party's cancellation."
        )

        let planParty = UUID()
        let plan = SharedNightPlan(
            planID: UUID(), partyID: planParty, memberID: member, memberEpochID: epoch,
            agreementID: agreement, revision: 1, nightEndingDate: night,
            timeZoneIdentifier: "UTC", plannedWindDownStart: start,
            intendedBedtime: start.addingTimeInterval(30 * 60),
            intendedWakeTime: start.addingTimeInterval(9 * 60 * 60),
            morningQuietEnd: start.addingTimeInterval(9.5 * 60 * 60),
            beforeBedMinutes: 30, afterWakingMinutes: 30,
            eveningSuggestionIDs: [], morningSuggestionIDs: []
        )
        let ordinaryPlan = NightFlockSharedNightOutboxRecord(
            id: UUID(), payload: .plan(plan), partyID: planParty, agreementID: agreement,
            memberEpochID: epoch, idempotencyKey: "ordinary-plan", attemptCount: 0, createdAt: .distantPast
        )
        let incoming = cancellationRecord(revision: 501, authority: .privacy)
        let withOrdinaryWork = Array(allTombstones.dropLast()) + [ordinaryPlan]
        let admitted = try XCTUnwrap(NightFlockSharedNightOutboxRules.merge(incoming, into: withOrdinaryWork))
        XCTAssertEqual(admitted.count, 128)
        XCTAssertFalse(admitted.contains { $0.isExactPublication(ordinaryPlan) })
        XCTAssertTrue(admitted.contains { $0.isExactPublication(incoming) })
        XCTAssertTrue(allTombstones.dropLast().allSatisfy { retained in
            admitted.contains { $0.isExactPublication(retained) }
        })

        let sameNightExisting = cancellationRecord(party: planParty, revision: 1, authority: .schedule)
        let sameNightNewer = cancellationRecord(party: planParty, revision: 2, authority: .privacy)
        let sameNightQueue = Array(allTombstones.dropLast()) + [sameNightExisting]
        let replaced = try XCTUnwrap(NightFlockSharedNightOutboxRules.merge(sameNightNewer, into: sameNightQueue))
        XCTAssertEqual(replaced.count, 128)
        XCTAssertFalse(replaced.contains { $0.isExactPublication(sameNightExisting) })
        XCTAssertTrue(replaced.contains { $0.isExactPublication(sameNightNewer) })
        XCTAssertTrue(allTombstones.dropLast().allSatisfy { retained in
            replaced.contains { $0.isExactPublication(retained) }
        })
    }

    func testStablePlanIDIsEpochScoped() {
        let party = UUID(); let date = NightFlockLocalDate(year: 2026, month: 9, day: 1)
        let firstEpoch = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let rejoinedEpoch = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let planID = SharedNightPlanRules.stablePlanID(partyID: party, memberEpochID: firstEpoch, nightEndingDate: date)
        let receiptSourceID = SharedNightPlanRules.stableReceiptSourceID(partyID: party, memberEpochID: firstEpoch, nightEndingDate: date)
        XCTAssertEqual(planID, SharedNightPlanRules.stablePlanID(partyID: party, memberEpochID: firstEpoch, nightEndingDate: date))
        XCTAssertNotEqual(planID, SharedNightPlanRules.stablePlanID(partyID: party, memberEpochID: rejoinedEpoch, nightEndingDate: date))
        XCTAssertNotEqual(planID, receiptSourceID)
        for identifier in [planID, receiptSourceID] {
            XCTAssertTrue(identifier.uuidString.lowercased().range(
                of: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
                options: .regularExpression
            ) != nil)
        }
    }

    func testSharedSleepSourceUsesTransportSafeUUIDAndMigratesLegacyQueueAndLedger() throws {
        let date = NightFlockLocalDate(year: 2026, month: 9, day: 1)
        let timezone = "Asia/Singapore"
        let legacy = NightFlockSharedHabitsSleepIdentifierRules.legacySourceID(
            nightEndingDate: date, timeZoneIdentifier: timezone
        )
        let canonical = NightFlockSharedHabitsSleepIdentifierRules.sourceID(
            nightEndingDate: date, timeZoneIdentifier: timezone
        )
        XCTAssertTrue(canonical.uuidString.lowercased().range(
            of: "^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
            options: .regularExpression
        ) != nil)

        let party = UUID(), agreement = UUID(), epoch = UUID()
        let shared = NightFlockSharedHabitRecord(
            recordID: UUID(), partyID: party, memberID: UUID(), sourceID: legacy, revision: 1,
            kind: .sleep, localDate: date, timeZoneIdentifier: timezone, minutes: 420,
            outcome: .completed, protectionMinutes: nil, evidence: .none,
            profileSnapshot: .init(displayName: "Moss", avatarID: nil), isFormerMember: false, migratedAt: nil
        )
        let queued = NightFlockSharedHabitsOutboxRecord(
            record: shared, agreementID: agreement, memberEpochID: epoch, idempotencyKey: "legacy"
        )
        let migratedQueue = NightFlockSharedHabitsSleepIdentifierRules.migratingOutboxRecords([queued])
        XCTAssertEqual(migratedQueue.count, 1)
        XCTAssertEqual(migratedQueue.first?.record.sourceID, canonical)
        XCTAssertEqual(migratedQueue.first?.idempotencyKey, NightFlockSharedHabitsSleepIdentifierRules.idempotencyKey(for: migratedQueue[0]))
        var alreadyCanonical = queued
        alreadyCanonical.record.sourceID = canonical
        alreadyCanonical.idempotencyKey = NightFlockSharedHabitsSleepIdentifierRules.idempotencyKey(for: alreadyCanonical)
        XCTAssertEqual(
            NightFlockSharedHabitsSleepIdentifierRules.migratingOutboxRecords([queued, alreadyCanonical]).count,
            1
        )
        let request = NightFlockSharedHabitsCommandRequest(command: .publish(
            record: migratedQueue[0].record, agreementID: agreement, memberEpochID: epoch,
            idempotencyKey: migratedQueue[0].idempotencyKey
        ))
        let body = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        XCTAssertEqual(body?["sourceID"] as? String, canonical.uuidString)

        let pending = NightFlockSharedHabitsPendingProjection(
            id: UUID(), partyID: party,
            projection: .init(sourceID: legacy, revision: 1, kind: .sleep, localDate: date,
                              timeZoneIdentifier: timezone, minutes: 420),
            startedAt: .now, sleepEligibleAfter: nil
        )
        XCTAssertEqual(
            NightFlockSharedHabitsSleepIdentifierRules.migratingPendingProjections([pending]).first?.projection.sourceID,
            canonical
        )

        let legacyLedger = NightFlockSharedHabitsSleepPublicationLedger(
            sourceID: legacy, nightEndingDate: date, timeZoneIdentifier: timezone,
            minutes: 420, revision: 1, delivered: false, deliveries: []
        )
        XCTAssertEqual(
            NightFlockSharedHabitsSleepIdentifierRules.migratingSleepLedger([legacyLedger]).first?.sourceID,
            canonical
        )

        // This raw SHA value has valid RFC version/variant bits. It can have
        // reached the server already, so a migration must never replace it.
        let safeDate = NightFlockLocalDate(year: 2026, month: 9, day: 24)
        let safeLegacy = NightFlockSharedHabitsSleepIdentifierRules.legacySourceID(
            nightEndingDate: safeDate, timeZoneIdentifier: timezone
        )
        XCTAssertEqual(
            NightFlockSharedHabitsSleepIdentifierRules.sourceID(nightEndingDate: safeDate, timeZoneIdentifier: timezone),
            safeLegacy
        )
        var safeRecord = shared
        safeRecord.sourceID = safeLegacy
        safeRecord.localDate = safeDate
        var safeQueue = NightFlockSharedHabitsOutboxRecord(
            record: safeRecord, agreementID: agreement, memberEpochID: epoch, idempotencyKey: ""
        )
        safeQueue.idempotencyKey = NightFlockSharedHabitsSleepIdentifierRules.idempotencyKey(for: safeQueue)
        XCTAssertEqual(NightFlockSharedHabitsSleepIdentifierRules.migratingOutboxRecords([safeQueue]), [safeQueue])

        // A pre-correction candidate normalized this otherwise valid legacy
        // source. It must converge back to the published raw provenance.
        var candidateQueue = safeQueue
        candidateQueue.record.sourceID = NightFlockSharedHabitsSleepIdentifierRules.normalizedCandidateSourceID(
            nightEndingDate: safeDate, timeZoneIdentifier: timezone
        )
        candidateQueue.idempotencyKey = NightFlockSharedHabitsSleepIdentifierRules.idempotencyKey(for: candidateQueue)
        let converged = NightFlockSharedHabitsSleepIdentifierRules.migratingOutboxRecords([candidateQueue])
        XCTAssertEqual(converged.first?.record.sourceID, safeLegacy)
        XCTAssertEqual(converged.first?.idempotencyKey, NightFlockSharedHabitsSleepIdentifierRules.idempotencyKey(for: safeQueue))

        var arbitrary = safeQueue
        arbitrary.record.sourceID = UUID()
        arbitrary.idempotencyKey = "unrelated"
        XCTAssertEqual(NightFlockSharedHabitsSleepIdentifierRules.migratingOutboxRecords([arbitrary]), [arbitrary])
    }

    func testMosaicKeepsFrozenSupersededPlanAndOneReceiptPerMemberNight() {
        let party = UUID(), member = UUID(), epoch = UUID(), agreement = UUID()
        let night = NightFlockLocalDate(year: 2026, month: 9, day: 1)
        func plan(_ revision: Int64, superseded: Bool) -> SharedNightPlan {
            .init(planID: SharedNightPlanRules.versionedPlanID(partyID: party, memberEpochID: epoch, nightEndingDate: night, revision: revision), partyID: party, memberID: member, memberEpochID: epoch, agreementID: agreement, revision: revision, nightEndingDate: night, timeZoneIdentifier: "UTC", plannedWindDownStart: .now, intendedBedtime: .now, intendedWakeTime: .now, morningQuietEnd: .now, beforeBedMinutes: 0, afterWakingMinutes: 0, eveningSuggestionIDs: [], morningSuggestionIDs: [], supersededAt: superseded ? .now : nil)
        }
        let old = plan(1, superseded: true), latest = plan(2, superseded: false)
        func receipt(_ revision: Int64) -> SharedNightReceipt {
            .init(receiptID: UUID(), partyID: party, memberID: member, memberEpochID: epoch, agreementID: agreement, planID: old.planID, planRevision: old.revision, sourceID: UUID(), revision: revision, nightEndingDate: night, timeZoneIdentifier: "UTC", actualStart: nil, terminalAt: nil, outcome: .partlyCompleted, windDownMinutes: nil, protectionMinutes: nil, protectionEvidence: .unknown, emergencyExitUsed: nil, profileSnapshot: .init(displayName: "Moss", avatarID: nil))
        }
        let receipts = SharedNightMosaicPresentation.receipts(in: [night], from: [receipt(1), receipt(2)])
        XCTAssertEqual(receipts.count, 1)
        XCTAssertEqual(receipts.first?.revision, 2)
        let plans = SharedNightMosaicPresentation.plans(in: [night], plans: [old, latest], receipts: receipts)
        XCTAssertEqual(Set(plans.map(\.planID)), Set([old.planID, latest.planID]))
        XCTAssertEqual(SharedNightMosaicPresentation.coverageSlotCount(for: plans), 1)
        var planless = receipt(3)
        planless.planID = nil
        planless.planRevision = nil
        XCTAssertEqual(SharedNightMosaicPresentation.planBackedReceipts(receipts + [planless], plans: plans).count, 1)
    }

    func testPlanBindingIsAcknowledgementOnlyAndStartedPlansAreNotCandidates() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = SharedNightPlan(planID: UUID(), partyID: UUID(), memberID: UUID(), memberEpochID: UUID(), agreementID: UUID(), revision: 1, nightEndingDate: .init(year: 2026, month: 9, day: 2), timeZoneIdentifier: "UTC", plannedWindDownStart: now, intendedBedtime: now, intendedWakeTime: now.addingTimeInterval(60), morningQuietEnd: now.addingTimeInterval(60), beforeBedMinutes: 0, afterWakingMinutes: 0, eveningSuggestionIDs: [], morningSuggestionIDs: [])
        XCTAssertFalse(SharedNightPlanRules.isFuturePublicationCandidate(plan, now: now))
        XCTAssertTrue(SharedNightPlanBindingPolicy.shouldPersistAfterAcknowledgement(accepted: true, staleRevision: false))
        XCTAssertFalse(SharedNightPlanBindingPolicy.shouldPersistAfterAcknowledgement(accepted: true, staleRevision: true))
        XCTAssertFalse(SharedNightPlanBindingPolicy.shouldPersistAfterAcknowledgement(accepted: false, staleRevision: false))
    }

    func testStalePlanAcknowledgementClearsOnlyItsPersistedBinding() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let party = UUID(), epoch = UUID(), agreement = UUID(), member = UUID()
        let night = NightFlockLocalDate(year: 2026, month: 9, day: 2)
        func plan(_ revision: Int64) -> SharedNightPlan {
            .init(
                planID: SharedNightPlanRules.versionedPlanID(
                    partyID: party, memberEpochID: epoch, nightEndingDate: night, revision: revision
                ),
                partyID: party, memberID: member, memberEpochID: epoch, agreementID: agreement, revision: revision,
                nightEndingDate: night, timeZoneIdentifier: "UTC", plannedWindDownStart: now.addingTimeInterval(3_600),
                intendedBedtime: now.addingTimeInterval(5_400), intendedWakeTime: now.addingTimeInterval(9 * 60 * 60),
                morningQuietEnd: now.addingTimeInterval(9.5 * 60 * 60), beforeBedMinutes: 30, afterWakingMinutes: 30,
                eveningSuggestionIDs: [], morningSuggestionIDs: []
            )
        }
        let oldPlan = plan(1)
        let newerPlan = plan(2)
        let oldRecord = NightFlockSharedNightOutboxRecord(
            id: UUID(), payload: .plan(oldPlan), partyID: party, agreementID: agreement, memberEpochID: epoch,
            idempotencyKey: "old", attemptCount: 0, createdAt: now
        )
        let newerRecord = NightFlockSharedNightOutboxRecord(
            id: UUID(), payload: .plan(newerPlan), partyID: party, agreementID: agreement, memberEpochID: epoch,
            idempotencyKey: "new", attemptCount: 0, createdAt: now
        )
        let stale = SharedNightPlanBindingPolicy.acknowledgement(accepted: true, staleRevision: true)
        let current = SharedNightPlanBindingPolicy.acknowledgement(accepted: true, staleRevision: false)
        let reloadedQueue = try JSONDecoder().decode(
            [NightFlockSharedNightOutboxRecord].self,
            from: JSONEncoder().encode([oldRecord])
        )
        XCTAssertTrue(
            SharedNightPlanBindingPolicy.shouldClearBinding(
                binding: oldPlan, acknowledgedPlan: oldPlan, acknowledgement: stale,
                queuedCancellation: false, hasNewerQueuedPlan: false
            ),
            "A stale response clears the old persisted receipt binding after relaunch."
        )
        XCTAssertTrue(
            NightFlockSharedNightOutboxRules.acknowledging(oldRecord, in: reloadedQueue).isEmpty
        )
        XCTAssertFalse(
            SharedNightPlanBindingPolicy.shouldClearBinding(
                binding: newerPlan, acknowledgedPlan: oldPlan, acknowledgement: stale,
                queuedCancellation: false, hasNewerQueuedPlan: true
            ),
            "An old response cannot clear a newer local plan binding."
        )
        XCTAssertFalse(
            SharedNightPlanBindingPolicy.shouldClearBinding(
                binding: oldPlan, acknowledgedPlan: oldPlan, acknowledgement: current,
                queuedCancellation: false, hasNewerQueuedPlan: false
            ),
            "A current exact acknowledgement retains its binding."
        )
        XCTAssertTrue(
            SharedNightPlanBindingPolicy.shouldClearBinding(
                binding: newerPlan, acknowledgedPlan: oldPlan, acknowledgement: stale,
                queuedCancellation: true, hasNewerQueuedPlan: false
            ),
            "A queued cancellation wins over every same-night local binding."
        )
        XCTAssertTrue(NightFlockSharedNightOutboxRules.hasNewerQueuedPlan(than: oldPlan, in: [newerRecord]))
    }
}
