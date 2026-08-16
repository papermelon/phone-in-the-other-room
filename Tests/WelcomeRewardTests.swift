import XCTest

final class WelcomeRewardTests: XCTestCase {
    func testFreshFarmReceivesOneStarterSheepOnly() {
        let first = WelcomeRewardEngine.reconcile(farm: .empty, search: .empty, ledger: .empty)
        let replay = WelcomeRewardEngine.reconcile(
            farm: first.farm,
            search: first.search,
            ledger: first.ledger
        )

        XCTAssertEqual(first.farm.activeSheep.count, 1)
        XCTAssertEqual(first.farm.activeSheep.first?.definitionID, WelcomeRewardCatalog.starterSheepID)
        XCTAssertEqual(first.farm.discoveries.map(\.definitionID), [WelcomeRewardCatalog.starterSheepID])
        XCTAssertEqual(first.search.outcomes.count, 1)
        XCTAssertEqual(first.search.outcomes.first?.origin, .starter)
        XCTAssertEqual(first.ledger.starterSheepGrant?.sheepDefinitionID, WelcomeRewardCatalog.starterSheepID)
        XCTAssertEqual(replay.farm, first.farm)
        XCTAssertEqual(replay.search.outcomes.count, 1)
        XCTAssertEqual(first.search.completedWindDownSearchCount, 0)
        XCTAssertEqual(first.search.completedPhoneAwaySearchCount, 0)
        XCTAssertEqual(first.search.trailMap.pendingMappedMinutes, 0)
    }

    func testExistingFarmDoesNotReceiveAStarterSheep() {
        var search = SheepSearchState.empty
        search.append(
            SheepSearchOutcome(
                id: uuid(9),
                runID: uuid(9),
                origin: .windDown,
                protectedNightNumber: 1,
                result: .found,
                sheepID: "oat",
                rarity: .common,
                habitat: .storybookBarn,
                trailStrength: 40,
                encounterOdds: 1,
                trailDistance: 1,
                consecutiveNoFinds: 0,
                bonusPoints: 0,
                createdAt: Date(timeIntervalSince1970: 5)
            )
        )
        let farm = FarmMigration.migrated(existing: .empty, searchState: search)
        let result = WelcomeRewardEngine.reconcile(farm: farm, search: search, ledger: .empty)

        XCTAssertEqual(result.farm.sheep.map(\.definitionID), ["oat"])
        XCTAssertNil(result.ledger.starterSheepGrant)
        XCTAssertTrue(result.ledger.preexistingFarm)
        XCTAssertEqual(result.search.outcomes.map(\.sheepID), ["oat"])
    }

    func testProfileGiftIsOwnedNotEquippedAndCannotBeGrantedTwice() throws {
        let welcome = WelcomeRewardEngine.reconcile(farm: .empty, search: .empty, ledger: .empty)
        let recommendation = WindDownProfileMapper.recommendation(for: .defaults)
        let first = try WelcomeRewardEngine.recordProfileGift(
            recommendation: recommendation,
            farm: welcome.farm,
            search: welcome.search,
            ledger: welcome.ledger
        )
        let replay = try WelcomeRewardEngine.recordProfileGift(
            recommendation: recommendation,
            farm: first.farm,
            search: first.search,
            ledger: first.ledger
        )

        XCTAssertEqual(first.farm.ownedShopItemIDs, [recommendation.wearableItemID])
        XCTAssertNil(first.farm.shepherd.outfitItemID)
        XCTAssertNil(first.farm.shepherd.accessoryItemID)
        XCTAssertEqual(first.farm.transactions.filter { $0.kind == .welcomeGift }.count, 1)
        XCTAssertEqual(replay.farm.ownedShopItemIDs, first.farm.ownedShopItemIDs)
        XCTAssertEqual(replay.ledger.grants.filter { $0.kind == .profileWearable }.count, 1)
        XCTAssertNotNil(replay.ledger.pendingWearableGrant)
    }

    func testProfileGiftCannotBeClaimedTwice() throws {
        let welcome = WelcomeRewardEngine.reconcile(farm: .empty, search: .empty, ledger: .empty)
        let recommendation = WindDownProfileMapper.recommendation(for: .defaults)
        let gifted = try WelcomeRewardEngine.recordProfileGift(
            recommendation: recommendation,
            farm: welcome.farm,
            search: welcome.search,
            ledger: welcome.ledger
        )
        let claimed = try WelcomeRewardEngine.claimWearable(
            farm: gifted.farm,
            search: gifted.search,
            ledger: gifted.ledger,
            now: Date(timeIntervalSince1970: 50)
        )

        XCTAssertEqual(claimed.farm.ownedShopItemIDs, [recommendation.wearableItemID])
        XCTAssertNil(claimed.farm.shepherd.outfitItemID)
        XCTAssertNil(claimed.farm.shepherd.accessoryItemID)
        XCTAssertNotNil(claimed.ledger.claimedWearableGrant)
        let equipped = try WelcomeRewardEngine.equipWearable(
            farm: claimed.farm,
            search: claimed.search,
            ledger: claimed.ledger
        )
        XCTAssertEqual(equipped.farm.shepherd.outfitItemID ?? equipped.farm.shepherd.accessoryItemID, recommendation.wearableItemID)
        XCTAssertThrowsError(
            try WelcomeRewardEngine.claimWearable(
                farm: claimed.farm,
                search: claimed.search,
                ledger: claimed.ledger
            )
        ) { error in
            XCTAssertEqual(error as? FarmActionError, .welcomeGiftAlreadyClaimed)
        }
    }

    func testSuccessfulPracticeGrantsExactlyOneSheepWithoutMetersOrGuarantees() {
        let welcome = WelcomeRewardEngine.reconcile(farm: .empty, search: .empty, ledger: .empty)
        let run = practiceRun(id: uuid(21), completed: true)
        let first = WelcomeRewardEngine.settlePractice(
            run: run,
            farm: welcome.farm,
            search: welcome.search,
            ledger: welcome.ledger
        )
        let replay = WelcomeRewardEngine.settlePractice(
            run: run,
            farm: first.farm,
            search: first.search,
            ledger: first.ledger
        )

        XCTAssertEqual(first.farm.activeSheep.map(\.definitionID).sorted(), ["mabel", "pippin"])
        XCTAssertEqual(first.outcome?.origin, .onboardingPractice)
        XCTAssertEqual(first.outcome?.sheepID, WelcomeRewardCatalog.practiceSheepID)
        XCTAssertEqual(first.search.completedWindDownSearchCount, 0)
        XCTAssertEqual(first.search.completedPhoneAwaySearchCount, 0)
        XCTAssertEqual(first.search.consecutiveNoFinds, 0)
        XCTAssertEqual(first.search.phoneBreakConsecutiveNoFinds, 0)
        XCTAssertEqual(first.search.trailMap.pendingMappedMinutes, 0)
        XCTAssertEqual(replay.farm.sheep.count, first.farm.sheep.count)
        XCTAssertEqual(replay.search.outcomes.filter { $0.origin == .onboardingPractice }.count, 1)
    }

    func testIncompletePracticeGrantsNothing() {
        let welcome = WelcomeRewardEngine.reconcile(farm: .empty, search: .empty, ledger: .empty)
        let result = WelcomeRewardEngine.settlePractice(
            run: practiceRun(id: uuid(22), completed: false),
            farm: welcome.farm,
            search: welcome.search,
            ledger: welcome.ledger
        )

        XCTAssertNil(result.outcome)
        XCTAssertEqual(result.farm.activeSheep.map(\.definitionID), [WelcomeRewardCatalog.starterSheepID])
        XCTAssertNil(result.ledger.practiceSheepGrant)
    }

    func testASecondPracticeRunDoesNotGrantAnotherSheep() {
        let welcome = WelcomeRewardEngine.reconcile(farm: .empty, search: .empty, ledger: .empty)
        let first = WelcomeRewardEngine.settlePractice(
            run: practiceRun(id: uuid(23), completed: true),
            farm: welcome.farm,
            search: welcome.search,
            ledger: welcome.ledger
        )
        let second = WelcomeRewardEngine.settlePractice(
            run: practiceRun(id: uuid(24), completed: true),
            farm: first.farm,
            search: first.search,
            ledger: first.ledger
        )

        XCTAssertEqual(second.farm.sheep.filter { $0.definitionID == "pippin" }.count, 1)
        XCTAssertNil(second.outcome)
    }

    func testExistingFarmDoesNotReceiveAPracticeSheepFromLeftoverRun() {
        var search = SheepSearchState.empty
        search.append(
            SheepSearchOutcome(
                id: uuid(9),
                runID: uuid(9),
                origin: .windDown,
                protectedNightNumber: 1,
                result: .found,
                sheepID: "oat",
                rarity: .common,
                habitat: .storybookBarn,
                trailStrength: 40,
                encounterOdds: 1,
                trailDistance: 1,
                consecutiveNoFinds: 0,
                bonusPoints: 0,
                createdAt: Date(timeIntervalSince1970: 5)
            )
        )
        let farm = FarmMigration.migrated(existing: .empty, searchState: search)
        let existing = WelcomeRewardEngine.reconcile(farm: farm, search: search, ledger: .empty)
        let result = WelcomeRewardEngine.settlePractice(
            run: practiceRun(id: uuid(25), completed: true),
            farm: existing.farm,
            search: existing.search,
            ledger: existing.ledger
        )

        XCTAssertTrue(existing.ledger.preexistingFarm)
        XCTAssertNil(result.outcome)
        XCTAssertNil(result.ledger.practiceSheepGrant)
        XCTAssertEqual(result.farm.sheep.map(\.definitionID), ["oat"])
    }

    func testPracticeRunDoesNotOpenAQualifyingWindDownNote() {
        var run = completedPrimaryRun(overnightMinutes: 360)
        run.isPractice = true
        XCTAssertFalse(FocusRunRules.qualifiesForProtectedNightSearch(run))
    }

    func testProtectedNightSearchRequiresAFourHundredTwentyMinuteSpan() {
        let short = completedPrimaryRun(overnightMinutes: 359)
        let qualifying = completedPrimaryRun(overnightMinutes: 360)

        XCTAssertEqual(FocusRunRules.protectedSpanMinutes(for: short), 419)
        XCTAssertFalse(FocusRunRules.qualifiesForProtectedNightSearch(short))
        XCTAssertEqual(FocusRunRules.protectedSpanMinutes(for: qualifying), 420)
        XCTAssertTrue(FocusRunRules.qualifiesForProtectedNightSearch(qualifying))
        XCTAssertEqual(qualifying.creditedQuietMinutes, 60)
    }

    func testExistingSettledOutcomesRemainIntactAfterWelcomeReconciliation() {
        var search = SheepSearchState.empty
        let settled = SheepSearchOutcome(
            id: uuid(31),
            runID: uuid(31),
            origin: .windDown,
            protectedNightNumber: 2,
            result: .trailOnly,
            sheepID: nil,
            rarity: nil,
            habitat: nil,
            trailStrength: 22,
            encounterOdds: 0.31,
            trailDistance: 1.2,
            consecutiveNoFinds: 1,
            bonusPoints: 0,
            createdAt: Date(timeIntervalSince1970: 8)
        )
        search.append(settled)
        let farm = FarmMigration.migrated(existing: .empty, searchState: search)
        let result = WelcomeRewardEngine.reconcile(farm: farm, search: search, ledger: .empty)

        XCTAssertEqual(result.search.outcomes, [settled])
        XCTAssertEqual(result.search.consecutiveNoFinds, 1)
        XCTAssertTrue(result.farm.sheep.isEmpty)
    }

    func testUnknownTransactionKindAndSearchOriginDecodeSafely() throws {
        let transactionJSON = Data(#"{"id":"00000000-0000-0000-0000-000000000001","idempotencyKey":"future","kind":"futureKind","woolDelta":0,"createdAt":0}"#.utf8)
        let originJSON = Data(#""future-origin""#.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        XCTAssertEqual(try decoder.decode(FarmTransaction.self, from: transactionJSON).kind, .arrival)
        XCTAssertEqual(try decoder.decode(SheepSearchOrigin.self, from: originJSON), .unspecified)
        XCTAssertEqual(WelcomeRewardLedger.storageKey, "ollie.welcome.rewards")
    }

    private func practiceRun(id: UUID, completed: Bool) -> FocusRun {
        var run = FocusRun(
            id: id,
            plannedDurationSeconds: 5 * 60,
            startedAt: Date(timeIntervalSince1970: 100),
            state: completed ? .completed : .endedEarly,
            guardKind: .honorTimer
        )
        run.isPractice = true
        run.completedSuccessfully = completed
        run.endedAt = Date(timeIntervalSince1970: completed ? 400 : 200)
        run.actualDurationSeconds = completed ? 5 * 60 : 90
        return run
    }

    private func completedPrimaryRun(overnightMinutes: Int) -> FocusRun {
        let bedtime = Date(timeIntervalSince1970: 1_800_000_000)
        let startedAt = bedtime.addingTimeInterval(-30 * 60)
        let wakeTime = bedtime.addingTimeInterval(TimeInterval(overnightMinutes * 60))
        let protectedUntil = wakeTime.addingTimeInterval(30 * 60)
        let plan = NightWatchPlan(
            intendedBedtime: bedtime,
            wakeTime: wakeTime,
            protectedUntil: protectedUntil,
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        var run = FocusRun(
            plannedDurationSeconds: protectedUntil.timeIntervalSince(startedAt),
            startedAt: startedAt,
            state: .completed,
            guardKind: .honorTimer,
            nightWatchPlan: plan
        )
        run.completedSuccessfully = true
        run.endedAt = protectedUntil
        run.actualDurationSeconds = run.plannedDurationSeconds
        return run
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
