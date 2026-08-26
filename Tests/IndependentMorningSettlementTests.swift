import XCTest

final class IndependentMorningSettlementTests: XCTestCase {
    func testOrdinaryMorningIdentityIsStableAndSeparateFromWindDownRegistryIdentity() {
        let runID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let first = MorningQuietOccurrenceIdentity.ordinary(for: runID)
        XCTAssertEqual(first, MorningQuietOccurrenceIdentity.ordinary(for: runID))
        XCTAssertNotEqual(first, runID)
    }

    func testOrdinaryMorningIdentityIsDistinctAcrossEveryLeadingUUIDNibble() {
        let suffix = "0000000-0000-4000-8000-000000000001"
        let runIDs = "0123456789abcdef".compactMap { UUID(uuidString: "\($0)\(suffix)") }
        XCTAssertEqual(runIDs.count, 16)
        let occurrenceIDs = runIDs.map(MorningQuietOccurrenceIdentity.ordinary)
        XCTAssertEqual(Set(occurrenceIDs).count, runIDs.count)
        XCTAssertTrue(zip(runIDs, occurrenceIDs).allSatisfy { $0 != $1 })
    }

    func testMorningBoundaryUsesNextScheduledStartThenActiveEnd() {
        let scheduled = MorningQuietOccurrence(
            scheduledStart: start.addingTimeInterval(60),
            scheduledEnd: start.addingTimeInterval(120),
            outcome: .scheduled
        )
        let active = MorningQuietOccurrence(
            scheduledStart: start.addingTimeInterval(-60),
            scheduledEnd: start.addingTimeInterval(30),
            actualStart: start.addingTimeInterval(-60),
            outcome: .active
        )
        XCTAssertEqual(
            MorningQuietOccurrenceBoundary.next(after: start, occurrences: [scheduled, active]),
            active.scheduledEnd
        )
        XCTAssertEqual(
            MorningQuietOccurrenceBoundary.next(after: active.scheduledEnd, occurrences: [scheduled]),
            scheduled.scheduledStart
        )
    }
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testBenefitResolvesAt420MinutesWithoutDeliveryAndPersistsImmutableOutcome() {
        let run = primaryRun(minutes: 480)
        var journal = WindDownMorningSettlementJournal()
        let entitledAt = start.addingTimeInterval(420 * 60)

        let settlement = journal.resolveWindDown(run: run, at: entitledAt)
        XCTAssertEqual(settlement?.phoneAwaySpanMinutes, 420)
        XCTAssertNil(settlement?.deliveredAt)
        XCTAssertNil(settlement?.revealedAt)

        let outcome = SheepSearchOutcome(
            id: UUID(), runID: run.id, origin: .windDown, protectedNightNumber: 1,
            result: .found, sheepID: "mabel", rarity: .common, habitat: .starterPasture,
            trailStrength: 42, encounterOdds: 1, trailDistance: 1, consecutiveNoFinds: 0,
            bonusPoints: 0, createdAt: entitledAt
        )
        journal.persistHiddenOutcome(outcome, for: run.id)
        journal.persistHiddenOutcome(
            SheepSearchOutcome(
                id: UUID(), runID: run.id, origin: .windDown, protectedNightNumber: 99,
                result: .trailOnly, sheepID: nil, rarity: nil, habitat: nil, trailStrength: 0,
                encounterOdds: 0, trailDistance: 0, consecutiveNoFinds: 0, bonusPoints: 0, createdAt: start
            ),
            for: run.id
        )
        XCTAssertEqual(journal.benefit(for: run.id)?.hiddenSearchOutcome, outcome)
        XCTAssertEqual(journal.resolveWindDown(run: run, at: entitledAt.addingTimeInterval(60))?.hiddenSearchOutcome, outcome)
    }

    func test419MinutesDoesNotCreateBenefit() {
        var journal = WindDownMorningSettlementJournal()
        let run = primaryRun(minutes: 480)
        XCTAssertNil(journal.resolveWindDown(run: run, at: start.addingTimeInterval(419 * 60)))
        XCTAssertTrue(journal.windDownBenefits.isEmpty)
    }

    func testDeliveryAndRevealAreSeparatelyIdempotent() {
        let run = primaryRun(minutes: 480)
        var journal = WindDownMorningSettlementJournal()
        _ = journal.resolveWindDown(run: run, at: start.addingTimeInterval(420 * 60))
        XCTAssertNil(journal.markRevealed(runID: run.id, at: start))
        let delivered = journal.markDelivered(runID: run.id, at: start)
        XCTAssertEqual(delivered?.deliveredAt, start)
        XCTAssertEqual(journal.markDelivered(runID: run.id, at: start.addingTimeInterval(60))?.deliveredAt, start)
        XCTAssertEqual(journal.markRevealed(runID: run.id, at: start.addingTimeInterval(120))?.revealedAt, start.addingTimeInterval(120))
    }

    func testTerminalProjectionPlanIsImmutableAcrossReplay() {
        let run = primaryRun(minutes: 480)
        var journal = WindDownMorningSettlementJournal()
        _ = journal.resolveWindDown(run: run, at: start.addingTimeInterval(420 * 60))
        let first = UserProgress(totalCompletedRuns: 1, totalFocusMinutes: 30, currentStreak: 1, longestStreak: 1, rewardsCollected: 0, ollieLevel: 1)
        journal.persistTerminalProjections(for: run.id, reward: nil, progress: first)
        let changed = UserProgress(totalCompletedRuns: 99, totalFocusMinutes: 99, currentStreak: 99, longestStreak: 99, rewardsCollected: 99, ollieLevel: 5)
        journal.persistTerminalProjections(for: run.id, reward: nil, progress: changed)
        XCTAssertEqual(journal.benefit(for: run.id)?.deliveredProgress, first)
    }

    func testEarlyWakeStartsFullConfiguredDurationWithoutMutatingPlan() {
        let run = primaryRun(minutes: 600)
        let at = start.addingTimeInterval(7 * 60 * 60)
        let occurrence = MorningQuietIntentEngine.occurrence(for: .startNow, run: run, at: at)
        XCTAssertEqual(occurrence?.scheduledStart, at)
        XCTAssertEqual(occurrence?.scheduledEnd.timeIntervalSince(at), 30 * 60)
        XCTAssertEqual(run.nightWatchPlan?.wakeTime, start.addingTimeInterval(8 * 60 * 60))
    }

    func testSunriseTrailMultipleFillsUseSequentialStableIndicesAndReplayOnce() {
        let occurrence = MorningQuietOccurrence(
            id: UUID(), scheduledStart: start, scheduledEnd: start.addingTimeInterval(240 * 60),
            actualStart: start, endedAt: start.addingTimeInterval(240 * 60), outcome: .finished
        )
        let result = SunriseTrailSettlementEngine.settle(
            occurrence: occurrence, at: occurrence.endedAt!, state: .empty, protectedWindDownCount: 0
        )
        XCTAssertEqual(result.appliedMinutes, 240)
        XCTAssertEqual(result.fills.map(\.fillIndex), [1, 2])
        XCTAssertEqual(result.woolGranted, 2)
        let replay = SunriseTrailSettlementEngine.settle(
            occurrence: occurrence, at: occurrence.endedAt!, state: result.state, protectedWindDownCount: 0
        )
        XCTAssertEqual(replay.fills.map(\.id), result.fills.map(\.id))
        XCTAssertEqual(replay.state.completedSearchCount, 2)
    }

    func testUnderFifteenMinutesDoesNotBankSunriseTrail() {
        let occurrence = MorningQuietOccurrence(
            scheduledStart: start, scheduledEnd: start.addingTimeInterval(30 * 60), actualStart: start,
            endedAt: start.addingTimeInterval(14 * 60), outcome: .finished
        )
        let result = SunriseTrailSettlementEngine.settle(
            occurrence: occurrence, at: occurrence.endedAt!, state: .empty, protectedWindDownCount: 0
        )
        XCTAssertEqual(result.appliedMinutes, 0)
        XCTAssertTrue(result.fills.isEmpty)
    }

    func testSunriseFillProjectsOneWoolAndOneIndependentSearchWithoutOtherTrackMutation() {
        let occurrence = MorningQuietOccurrence(
            scheduledStart: start,
            scheduledEnd: start.addingTimeInterval(100 * 60),
            actualStart: start,
            endedAt: start.addingTimeInterval(100 * 60),
            outcome: .finished
        )
        let settlement = SunriseTrailSettlementEngine.settle(
            occurrence: occurrence,
            at: occurrence.endedAt!,
            state: .empty,
            protectedWindDownCount: 0
        )
        XCTAssertEqual(settlement.fills.count, 1)
        XCTAssertEqual(settlement.woolGranted, 1)
        XCTAssertEqual(settlement.fills.first?.outcome.origin, .sunrise)

        var search = SheepSearchState.empty
        search.consecutiveNoFinds = 3
        search.phoneBreakConsecutiveNoFinds = 2
        search.trailMap.pendingMappedMinutes = 40
        let originalWindDownDrought = search.consecutiveNoFinds
        let originalPhoneAwayDrought = search.phoneBreakConsecutiveNoFinds
        let originalPhoneAwayMinutes = search.trailMap.pendingMappedMinutes
        var farm = FarmState.empty
        guard let fill = settlement.fills.first else { return XCTFail("Expected one fill") }
        search.append(fill.outcome)
        farm.applySunriseTrailFill(fill)
        farm.applySunriseTrailFill(fill)

        XCTAssertEqual(search.outcomes.filter { $0.origin == .sunrise }.count, 1)
        XCTAssertEqual(search.consecutiveNoFinds, originalWindDownDrought)
        XCTAssertEqual(search.phoneBreakConsecutiveNoFinds, originalPhoneAwayDrought)
        XCTAssertEqual(search.trailMap.pendingMappedMinutes, originalPhoneAwayMinutes)
        XCTAssertEqual(farm.woolBalance, SunriseTrailRules.woolPerFill)
        XCTAssertEqual(farm.transactions.filter { $0.kind == .sunriseTrail }.count, 1)
        XCTAssertEqual(farm.sheep.filter { $0.sourceOutcomeID == fill.outcome.id }.count, fill.outcome.result == .found ? 1 : 0)

        var repairedFarm = FarmState.empty
        repairedFarm.woolBalance = SunriseTrailRules.woolPerFill
        repairedFarm.transactions = [FarmTransaction(
            id: UUID(),
            idempotencyKey: "sunrise:\(fill.id.uuidString):wool",
            kind: .sunriseTrail,
            sheepID: nil,
            itemID: nil,
            woolDelta: SunriseTrailRules.woolPerFill,
            createdAt: fill.settledAt
        )]
        repairedFarm.applySunriseTrailFill(fill)
        XCTAssertEqual(repairedFarm.woolBalance, SunriseTrailRules.woolPerFill)
        XCTAssertEqual(repairedFarm.sheep.filter { $0.sourceOutcomeID == fill.outcome.id }.count, 1)

        var fullFarm = FarmState.empty
        fullFarm.sheep = (0..<fullFarm.activeCapacity).map { index in
            FlockSheep(
                id: UUID(),
                definitionID: "starter_\(index)",
                displayName: "Pasture \(index)",
                arrivedAt: start,
                protectedNightNumber: 0,
                rarity: .common,
                status: .active
            )
        }
        fullFarm.applySunriseTrailFill(fill)
        XCTAssertEqual(fullFarm.sheep.first { $0.sourceOutcomeID == fill.outcome.id }?.status, .pending)
    }

    func testLegacyJournalWithoutNewFieldsDecodesWithoutRetroactiveSettlement() throws {
        let data = Data("{\"schemaVersion\":1}".utf8)
        let journal = try JSONDecoder().decode(WindDownMorningSettlementJournal.self, from: data)
        XCTAssertTrue(journal.windDownBenefits.isEmpty)
        XCTAssertTrue(journal.morningOccurrences.isEmpty)
        XCTAssertEqual(journal.sunriseTrail, .empty)
    }

    func testLegacyMorningOccurrenceDefaultsLiveActivityChoiceToEnabled() throws {
        let json = """
        {"scheduledStart":1000000,"scheduledEnd":1000060,"outcome":"scheduled"}
        """
        let occurrence = try JSONDecoder().decode(MorningQuietOccurrence.self, from: Data(json.utf8))
        XCTAssertTrue(occurrence.liveActivityRequested)
    }

    func testDeferredAndSkippedOccurrencesKeepSavedPreferencesUnchanged() {
        let run = primaryRun(minutes: 600)
        let before = run.nightWatchPlan
        let early = start.addingTimeInterval(7 * 60 * 60)
        let deferred = MorningQuietIntentEngine.occurrence(for: .deferToUsualTime, run: run, at: early)
        let skipped = MorningQuietIntentEngine.occurrence(for: .skipToday, run: run, at: early)
        XCTAssertEqual(deferred?.scheduledStart, run.nightWatchPlan?.wakeTime)
        XCTAssertEqual(deferred?.scheduledEnd, run.nightWatchPlan?.protectedUntil)
        XCTAssertEqual(skipped?.outcome, .skipped)
        XCTAssertEqual(run.nightWatchPlan, before)
    }

    func testEarlyWakeIntentRejectsWindDownAndUnrelatedRuns() {
        var run = primaryRun(minutes: 600)
        XCTAssertNil(MorningQuietIntentEngine.occurrence(for: .startNow, run: run, at: start.addingTimeInterval(10 * 60)))
        run.nightWatchPlan?.role = .additionalQuiet
        XCTAssertNil(MorningQuietIntentEngine.occurrence(for: .startNow, run: run, at: start.addingTimeInterval(7 * 60 * 60)))
    }

    func testKeepRunningHasNoOccurrenceAndDeferredCannotDuplicateLinkedRun() {
        let run = primaryRun(minutes: 600)
        let early = start.addingTimeInterval(7 * 60 * 60)
        XCTAssertNil(MorningQuietIntentEngine.occurrence(for: .keepWindDownRunning, run: run, at: early))

        guard let deferred = MorningQuietIntentEngine.occurrence(for: .deferToUsualTime, run: run, at: early),
              let startNow = MorningQuietIntentEngine.occurrence(for: .startNow, run: run, at: early.addingTimeInterval(60)) else {
            return XCTFail("Expected valid early-wake occurrences")
        }
        var journal = WindDownMorningSettlementJournal()
        journal.appendOccurrence(deferred)
        journal.appendOccurrence(startNow)
        XCTAssertEqual(journal.morningOccurrences, [deferred])
    }

    func testDeferredWholeWindowCompletesWithNonnegativeCappedMinutes() {
        let run = primaryRun(minutes: 600)
        let early = start.addingTimeInterval(7 * 60 * 60)
        guard var occurrence = MorningQuietIntentEngine.occurrence(for: .deferToUsualTime, run: run, at: early) else {
            return XCTFail("Expected deferred occurrence")
        }
        occurrence.actualStart = occurrence.scheduledStart
        occurrence.endedAt = occurrence.scheduledEnd.addingTimeInterval(60 * 60)
        occurrence.outcome = .finished

        guard let endedAt = occurrence.endedAt else { return XCTFail("Expected terminal date") }
        XCTAssertEqual(occurrence.eligibleElapsedMinutes(at: endedAt), occurrence.configuredDurationMinutes)
        XCTAssertGreaterThanOrEqual(occurrence.eligibleElapsedMinutes(at: endedAt), 0)
    }

    private func primaryRun(minutes: Int) -> FocusRun {
        let plan = NightWatchPlan(
            intendedBedtime: start.addingTimeInterval(30 * 60),
            wakeTime: start.addingTimeInterval(8 * 60 * 60),
            protectedUntil: start.addingTimeInterval(8.5 * 60 * 60),
            windDownMinutes: 30, morningQuietMinutes: 30, eveningActivity: .read, morningActivity: .openCurtains
        )
        var run = FocusRun(
            plannedDurationSeconds: TimeInterval(minutes * 60), startedAt: start, state: .running,
            guardKind: .honorTimer, nightWatchPlan: plan
        )
        run.placementStatus = .confirmed
        return run
    }
}
