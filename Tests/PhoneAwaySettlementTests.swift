import XCTest

final class PhoneAwaySettlementTests: XCTestCase {
    private let settledAt = Date(timeIntervalSince1970: 1_000)

    func testFourteenMinutesEarnsNothing() {
        let result = settle(minutes: 14, protectedNights: 3)

        XCTAssertFalse(result.record.eligible)
        XCTAssertEqual(result.record.reason, .tooShort)
        XCTAssertEqual(result.record.appliedCreditDelta, 0)
        XCTAssertEqual(result.record.meterBefore, 0)
        XCTAssertEqual(result.record.meterAfter, 0)
        XCTAssertNil(result.outcome)
    }

    func testFifteenMinutesEarnsExactlyFifteen() {
        let result = settle(minutes: 15, protectedNights: 2)

        XCTAssertTrue(result.record.eligible)
        XCTAssertEqual(result.record.appliedCreditDelta, 15)
        XCTAssertEqual(result.record.meterBefore, 0)
        XCTAssertEqual(result.record.meterAfter, 15)
        XCTAssertNil(result.outcome)
    }

    func testFiveMinutePracticeIsRecordedButNeverEligible() {
        let result = settle(minutes: 5, protectedNights: 3, isPractice: true)

        XCTAssertFalse(result.record.eligible)
        XCTAssertEqual(result.record.reason, .practice)
        XCTAssertEqual(result.record.creditedMinutes, 5)
        XCTAssertEqual(result.record.appliedCreditDelta, 0)
        XCTAssertTrue(result.record.isPractice)
        XCTAssertEqual(result.state.trailMap.pendingMappedMinutes, 0)
    }

    func testEarlyEndingEarnsNothing() {
        let result = settle(minutes: 60, protectedNights: 3, completedSuccessfully: false)

        XCTAssertFalse(result.record.eligible)
        XCTAssertEqual(result.record.reason, .endedEarly)
        XCTAssertEqual(result.record.appliedCreditDelta, 0)
        XCTAssertEqual(result.state.phoneAwaySettlements.count, 1)
    }

    func testPerRunCreditIsCappedAtTheApprovedHundredMinutes() {
        let result = settle(minutes: 240, protectedNights: 2)

        XCTAssertEqual(PhoneAwaySearchMeter.perRunCreditCap, 100)
        XCTAssertEqual(result.record.creditedMinutes, 240)
        XCTAssertEqual(result.record.appliedCreditDelta, 100)
        XCTAssertEqual(result.state.trailMap.pendingMappedMinutes, 100)
    }

    func testLockedBankingKeepsOnlyOneFullMeterBeforeThreeWindDowns() {
        let first = settle(minutes: 100, protectedNights: 2)
        let second = settle(
            minutes: 100,
            protectedNights: 2,
            state: first.state
        )

        XCTAssertEqual(first.state.trailMap.pendingMappedMinutes, 100)
        XCTAssertEqual(second.record.appliedCreditDelta, 0)
        XCTAssertEqual(second.state.trailMap.pendingMappedMinutes, 100)
        XCTAssertNil(second.outcome)
    }

    func testFullLockedMeterWaitsForLaterEligiblePhoneAway() {
        let locked = settle(minutes: 100, protectedNights: 2)
        XCTAssertNil(locked.outcome)

        let unlocked = settle(
            minutes: 15,
            protectedNights: 3,
            state: locked.state,
            seed: 0
        )

        XCTAssertNotNil(unlocked.outcome)
        XCTAssertEqual(unlocked.record.meterBefore, 100)
        XCTAssertEqual(unlocked.record.meterAfter, 15)
        XCTAssertEqual(unlocked.state.trailMap.pendingMappedMinutes, 15)
    }

    func testCarriedRemainderSurvivesAResolvedBonusSearch() {
        var state = SheepSearchState.empty
        state.trailMap.pendingMappedMinutes = 90
        let result = settle(
            minutes: 25,
            protectedNights: 3,
            state: state,
            seed: 0
        )

        XCTAssertNotNil(result.outcome)
        XCTAssertEqual(result.record.appliedCreditDelta, 25)
        XCTAssertEqual(result.record.meterBefore, 90)
        XCTAssertEqual(result.record.meterAfter, 15)
    }

    func testARunCanResolveAtMostOneOutcomeAndReplayIsStable() {
        let runID = UUID(uuidString: "00000000-0000-0000-0000-000000000701")!
        var state = SheepSearchState.empty
        state.trailMap.pendingMappedMinutes = 100
        state.phoneBreakConsecutiveNoFinds = 4
        let input = PhoneAwaySearchSettlementInput(
            runID: runID,
            completedSuccessfully: true,
            creditedMinutes: 15,
            protectedWindDownCount: 3,
            settledAt: settledAt,
            seed: 0
        )

        let first = PhoneAwaySearchSettlementEngine.settle(input: input, state: state)
        let replay = PhoneAwaySearchSettlementEngine.settle(
            input: PhoneAwaySearchSettlementInput(
                runID: runID,
                completedSuccessfully: true,
                creditedMinutes: 100,
                protectedWindDownCount: 25,
                settledAt: settledAt.addingTimeInterval(50),
                seed: 999
            ),
            state: first.state
        )

        XCTAssertEqual(first.state.outcomes.count, 1)
        XCTAssertEqual(replay.state, first.state)
        XCTAssertEqual(replay.record, first.record)
        XCTAssertEqual(replay.outcome, first.outcome)
    }

    func testPhoneAwayDroughtIsIndependentFromWindDownDroughtAndStarterState() {
        let runID = UUID(uuidString: "00000000-0000-0000-0000-000000000702")!
        var state = SheepSearchState.empty
        state.consecutiveNoFinds = 8
        for index in 1...SheepSearchEngine.starterGuaranteeRuns {
            state.append(
                SheepSearchOutcome(
                    id: UUID(),
                    runID: UUID(),
                    origin: .phoneBreak,
                    protectedNightNumber: index,
                    result: .found,
                    sheepID: "mabel",
                    rarity: .common,
                    habitat: .starterPasture,
                    trailStrength: 50,
                    encounterOdds: 1,
                    trailDistance: 1,
                    consecutiveNoFinds: 0,
                    bonusPoints: 0,
                    createdAt: settledAt
                )
            )
        }
        state.phoneBreakConsecutiveNoFinds = 2
        state.trailMap.pendingMappedMinutes = 100
        let seed = trailOnlySeed(runID: runID, state: state)
        let result = settle(
            runID: runID,
            minutes: 15,
            protectedNights: 3,
            state: state,
            seed: seed
        )

        XCTAssertEqual(result.outcome?.result, .trailOnly)
        XCTAssertEqual(result.state.consecutiveNoFinds, 8)
        XCTAssertEqual(result.state.phoneBreakConsecutiveNoFinds, 3)
        XCTAssertEqual(result.state.completedWindDownSearchCount, 0)
    }

    func testResolvedCatalogueUsesProtectedNightCount() throws {
        var state = SheepSearchState.empty
        state.trailMap.pendingMappedMinutes = 100
        state.phoneBreakConsecutiveNoFinds = 4
        let result = settle(
            minutes: 15,
            protectedNights: 4,
            state: state,
            seed: 0
        )
        let outcome = try XCTUnwrap(result.outcome)
        let sheepID = try XCTUnwrap(outcome.sheepID)
        let sheep = try XCTUnwrap(SheepCatalog.definition(for: sheepID))

        XCTAssertEqual(outcome.protectedNightNumber, 4)
        XCTAssertLessThanOrEqual(SheepCatalog.arrivalNight(for: sheep), 4)
    }

    func testResolvedOutcomeReconcilesIntoAvailableOrFullBarn() throws {
        var state = SheepSearchState.empty
        state.trailMap.pendingMappedMinutes = 100
        state.phoneBreakConsecutiveNoFinds = 4
        let result = settle(minutes: 15, protectedNights: 3, state: state, seed: 0)
        let outcome = try XCTUnwrap(result.outcome)

        var available = FarmState.empty
        available.reconcile(searchState: result.state)
        XCTAssertTrue(available.activeSheep.contains { $0.sourceOutcomeID == outcome.id })
        XCTAssertTrue(available.pendingSheep.isEmpty)

        var full = FarmState.empty
        for index in 0..<full.activeCapacity {
            full.sheep.append(FlockSheep(
                id: UUID(),
                definitionID: "mabel",
                displayName: "Existing \(index)",
                arrivedAt: settledAt,
                protectedNightNumber: 1,
                rarity: .common
            ))
        }
        full.reconcile(searchState: result.state)
        XCTAssertTrue(full.pendingSheep.contains { $0.sourceOutcomeID == outcome.id })
    }

    func testPersistedSearchStateReconcilesMissingFarmArrivalAfterSimulatedCrash() throws {
        var searchState = SheepSearchState.empty
        searchState.trailMap.pendingMappedMinutes = 100
        searchState.phoneBreakConsecutiveNoFinds = 4
        let settlement = settle(minutes: 15, protectedNights: 3, state: searchState, seed: 0)
        let outcome = try XCTUnwrap(settlement.outcome)
        // Simulate termination after the search-state write and before Farm's
        // write. PersistenceService performs this same migration on launch;
        // the Shared-only seam is FarmMigration.migrated.
        let persisted = try JSONDecoder().decode(
            SheepSearchState.self,
            from: JSONEncoder().encode(settlement.state)
        )
        let recovered = FarmMigration.migrated(existing: nil, searchState: persisted)
        let reconciledAgain = FarmMigration.migrated(existing: recovered, searchState: persisted)

        XCTAssertTrue(recovered.sheep.contains { $0.sourceOutcomeID == outcome.id })
        XCTAssertEqual(recovered.transactions.filter { $0.idempotencyKey == "arrival:\(outcome.id.uuidString)" }.count, 1)
        XCTAssertEqual(reconciledAgain, recovered)
    }

    func testTerminalRunCanRebuildSettlementAfterLastRunWriteGap() throws {
        let bedtime = Date(timeIntervalSince1970: 2_000)
        let plan = NightWatchPlan(
            intendedBedtime: bedtime,
            wakeTime: bedtime.addingTimeInterval(60 * 60),
            protectedUntil: bedtime.addingTimeInterval(2 * 60 * 60),
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains,
            role: .additionalQuiet
        )
        var terminalRun = FocusRun(
            plannedDurationSeconds: 30 * 60,
            startedAt: bedtime,
            state: .completed,
            guardKind: .honorTimer,
            nightWatchPlan: plan
        )
        terminalRun.completedSuccessfully = true
        terminalRun.endedAt = bedtime.addingTimeInterval(30 * 60)
        terminalRun.actualDurationSeconds = terminalRun.plannedDurationSeconds

        let input = try XCTUnwrap(
            PhoneAwaySearchSettlementInput.terminalRun(
                terminalRun,
                protectedWindDownCount: 2,
                trackedSheepID: nil
            )
        )
        var state = SheepSearchState.empty
        state.trailMap.pendingMappedMinutes = 90
        let first = PhoneAwaySearchSettlementEngine.settle(input: input, state: state)
        let replay = PhoneAwaySearchSettlementEngine.settle(input: input, state: first.state)

        XCTAssertEqual(input.creditedMinutes, 30)
        XCTAssertEqual(first.record.appliedCreditDelta, 10)
        XCTAssertEqual(first.record.meterAfter, 100)
        XCTAssertEqual(replay.state, first.state)
        XCTAssertEqual(replay.record, first.record)
    }

    func testLegacySearchStateDecodesWithoutSettlementRecords() throws {
        let legacy = Data(#"{"schemaVersion":3,"outcomes":[],"foundSheepIDs":[],"consecutiveNoFinds":0,"phoneBreakConsecutiveNoFinds":0,"totalTrailDistance":0,"showExactOdds":false,"trailMap":{"schemaVersion":3,"pendingMappedMinutes":25,"creditedAdHocRunIDs":[]}}"#.utf8)

        let decoded = try JSONDecoder().decode(SheepSearchState.self, from: legacy)

        XCTAssertEqual(decoded.schemaVersion, SheepSearchState.currentSchemaVersion)
        XCTAssertTrue(decoded.phoneAwaySettlements.isEmpty)
        XCTAssertEqual(decoded.trailMap.pendingMappedMinutes, 25)
    }

    func testPracticeReceiptNamesPracticeWithoutRewardOrProtectedNightImplication() {
        let result = settle(minutes: 5, protectedNights: 3, isPractice: true)
        let presentation = PhoneAwayReceiptPresentation.make(record: result.record)

        XCTAssertEqual(presentation.state, .practice)
        XCTAssertTrue(presentation.message.contains("practice"))
        XCTAssertTrue(presentation.message.contains("Phone Away gift progress was not added"))
        XCTAssertFalse(presentation.message.contains("protected"))
        XCTAssertFalse(presentation.message.contains("reward"))
        XCTAssertEqual(presentation.accessibilityLabel, "Phone Away practice complete. This was practice. 5 completed minutes were saved in Nights. Phone Away gift progress was not added.")
    }

    func testBelowMinimumReceiptExplainsTheFifteenMinuteStartWithoutFailureLanguage() {
        let result = settle(minutes: 14, protectedNights: 3)
        let presentation = PhoneAwayReceiptPresentation.make(record: result.record)

        XCTAssertEqual(presentation.state, .belowMinimum)
        XCTAssertTrue(presentation.message.contains("No Phone Away gift progress was added"))
        XCTAssertTrue(presentation.message.contains("15 completed minutes"))
        XCTAssertFalse(presentation.message.localizedCaseInsensitiveContains("failed"))
        XCTAssertNil(presentation.searchLinkTitle)
    }

    func testCreditedReceiptShowsDeltaMeterTotalAndLockedBanking() {
        let result = settle(minutes: 15, protectedNights: 2)
        let presentation = PhoneAwayReceiptPresentation.make(record: result.record)

        XCTAssertEqual(presentation.state, .credited)
        XCTAssertTrue(presentation.message.contains("15 minutes added"))
        XCTAssertTrue(presentation.message.contains("15 of 100 minutes"))
        XCTAssertTrue(presentation.message.contains("banking"))
        XCTAssertTrue(presentation.accessibilityLabel.contains("15 minutes added"))
    }

    func testFullLockedReceiptSaysMeterIsWaitingWhenAppliedDeltaIsZero() {
        let full = settle(minutes: 100, protectedNights: 2)
        let result = settle(minutes: 15, protectedNights: 2, state: full.state)
        let presentation = PhoneAwayReceiptPresentation.make(record: result.record)

        XCTAssertEqual(presentation.state, .meterFullWhileLocked)
        XCTAssertEqual(result.record.appliedCreditDelta, 0)
        XCTAssertTrue(presentation.message.contains("saved meter is waiting"))
        XCTAssertTrue(presentation.message.contains("full at 100 of 100 minutes"))
        XCTAssertFalse(presentation.message.contains("updated"))
    }

    func testResolvedReceiptLinksSearchJournalAndShowsCarriedRemainder() throws {
        var state = SheepSearchState.empty
        state.trailMap.pendingMappedMinutes = 90
        let result = settle(minutes: 25, protectedNights: 3, state: state, seed: 0)
        let outcome = try XCTUnwrap(result.outcome)
        let presentation = PhoneAwayReceiptPresentation.make(record: result.record, outcome: outcome)

        XCTAssertEqual(presentation.state, .resolved)
        XCTAssertEqual(presentation.searchLinkTitle, "Open Search Journal")
        XCTAssertEqual(presentation.searchLinkHint, "Shows the Search Journal note for this Phone Away")
        XCTAssertTrue(presentation.message.contains("Search Journal"))
        XCTAssertTrue(presentation.message.contains("15 of 100 minutes remaining"))
        XCTAssertTrue(presentation.title.contains("Ollie found a missing sheep") || presentation.title.contains("Ollie kept a clue"))
        XCTAssertTrue(presentation.accessibilityLabel.contains("Search Journal"))
    }

    func testEarlyEndingReceiptDoesNotOfferBonusSearchCredit() {
        let result = settle(minutes: 60, protectedNights: 3, completedSuccessfully: false)
        let presentation = PhoneAwayReceiptPresentation.make(record: result.record)

        XCTAssertEqual(presentation.state, .endedEarly)
        XCTAssertTrue(presentation.title.contains("ended early"))
        XCTAssertTrue(presentation.message.contains("saved in Nights"))
        XCTAssertTrue(presentation.message.contains("begins at 15 completed minutes"))
        XCTAssertNil(presentation.searchLinkTitle)
    }

    func testLegacyReceiptDoesNotInferProgressFromCurrentMeter() {
        let presentation = PhoneAwayReceiptPresentation.make(record: nil)

        XCTAssertEqual(presentation.state, .legacy)
        XCTAssertTrue(presentation.message.contains("no saved Phone Away gift progress"))
        XCTAssertNil(presentation.searchLinkTitle)
    }

    private func settle(
        runID: UUID = UUID(),
        minutes: Int,
        protectedNights: Int,
        state: SheepSearchState = .empty,
        isPractice: Bool = false,
        completedSuccessfully: Bool = true,
        seed: UInt64? = nil
    ) -> PhoneAwaySearchSettlementResult {
        PhoneAwaySearchSettlementEngine.settle(
            input: PhoneAwaySearchSettlementInput(
                runID: runID,
                completedSuccessfully: completedSuccessfully,
                isPractice: isPractice,
                creditedMinutes: minutes,
                protectedWindDownCount: protectedNights,
                settledAt: settledAt,
                seed: seed
            ),
            state: state
        )
    }

    private func trailOnlySeed(runID: UUID, state: SheepSearchState) -> UInt64 {
        for seed in UInt64(0)..<10_000 {
            let calculation = SheepSearchEngine.calculatePhoneBreak(
                runID: runID,
                protectedNightNumber: 3,
                state: state,
                seed: seed
            )
            if calculation.outcome.result == .trailOnly { return seed }
        }
        XCTFail("Expected a deterministic trail-only seed")
        return 0
    }
}
