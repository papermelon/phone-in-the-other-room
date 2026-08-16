import XCTest

final class SheepSearchTests: XCTestCase {
    private let runIDs = [
        UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    ]

    func testFirstThreeCompletedNightsAlwaysFindASheep() {
        var state = SheepSearchState.empty
        for (index, runID) in runIDs.enumerated() {
            let result = SheepSearchEngine.calculate(
                runID: runID,
                protectedNightNumber: index + 1,
                evidence: .empty,
                state: state,
                seed: 0
            )
            XCTAssertEqual(result.outcome.result, .found)
            XCTAssertNotNil(result.outcome.sheepID)
            state.append(result.outcome)
        }
    }

    func testOptionalSignalsOnlyIncreaseOdds() {
        let runID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
        var evidence = SheepSearchEvidence.empty
        evidence.windDownMinutes = 30
        evidence.morningQuietMinutes = 30
        let withoutOptional = SheepSearchEngine.calculate(
            runID: runID,
            protectedNightNumber: 8,
            evidence: evidence,
            state: .empty,
            seed: 123
        )
        evidence.optionalBonusPoints = 5
        let withOptional = SheepSearchEngine.calculate(
            runID: runID,
            protectedNightNumber: 8,
            evidence: evidence,
            state: .empty,
            seed: 123
        )

        XCTAssertGreaterThan(withOptional.outcome.encounterOdds, withoutOptional.outcome.encounterOdds)
        XCTAssertGreaterThanOrEqual(withOptional.score, withoutOptional.score)
    }

    func testBadLuckProtectionGuaranteesTheNextSearch() {
        var state = SheepSearchState.empty
        for index in 0..<SheepSearchEngine.hardGuaranteeAfterNoFinds {
            state.append(
                SheepSearchOutcome(
                    id: UUID(),
                    runID: UUID(),
                    protectedNightNumber: index + 4,
                    result: .trailOnly,
                    sheepID: nil,
                    rarity: nil,
                    habitat: nil,
                    trailStrength: 20,
                    encounterOdds: 0.2,
                    trailDistance: 1,
                    consecutiveNoFinds: index,
                    bonusPoints: 0,
                    createdAt: Date()
                )
            )
        }
        let calculation = SheepSearchEngine.calculate(
            runID: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
            protectedNightNumber: 8,
            evidence: .empty,
            state: state,
            seed: 0
        )

        XCTAssertEqual(calculation.outcome.result, .found)
        XCTAssertEqual(calculation.outcome.encounterOdds, 1)
    }

    func testSearchStateDoesNotDuplicateTheSameRun() {
        var state = SheepSearchState.empty
        let outcome = SheepSearchOutcome(
            id: UUID(),
            runID: runIDs[0],
            protectedNightNumber: 1,
            result: .found,
            sheepID: "mabel",
            rarity: .common,
            habitat: .starterPasture,
            trailStrength: 60,
            encounterOdds: 1,
            trailDistance: 2,
            consecutiveNoFinds: 0,
            bonusPoints: 0,
            createdAt: Date()
        )
        state.append(outcome)
        state.append(outcome)

        XCTAssertEqual(state.outcomes.count, 1)
        XCTAssertEqual(state.foundSheepIDs, ["mabel"])
    }

    func testSearchCalculationReusesThePersistedOutcomeForTheSameRun() {
        let runID = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
        var state = SheepSearchState.empty
        let first = SheepSearchEngine.calculate(
            runID: runID,
            protectedNightNumber: 4,
            evidence: .empty,
            state: state,
            now: Date(timeIntervalSince1970: 100),
            seed: 1
        ).outcome
        state.append(first)

        let reopened = SheepSearchEngine.calculate(
            runID: runID,
            protectedNightNumber: 4,
            evidence: .empty,
            state: state,
            now: Date(timeIntervalSince1970: 200),
            seed: 999
        ).outcome

        XCTAssertEqual(reopened, first)
        XCTAssertEqual(first.id, runID)
        XCTAssertEqual(state.outcomes.count, 1)
    }

    func testCatalogueIncludesDistinctFarmBreeds() {
        let breeds = Set(SheepCatalog.all.map(\.breed))

        XCTAssertTrue(breeds.contains(.fluffy))
        XCTAssertTrue(breeds.contains(.spotted))
        XCTAssertTrue(breeds.contains(.merino))
        XCTAssertTrue(breeds.contains(.night))
        XCTAssertTrue(breeds.contains(.guardian))
        XCTAssertEqual(SheepCatalog.definition(for: "oat")?.assetName, "sheep/sheep_oat_wool_ready")
        XCTAssertEqual(SheepCatalog.definition(for: "wisp")?.assetName, "sheep/sheep_wisp_wool_ready")
        XCTAssertEqual(Set(SheepCatalog.all.map(\.assetName)).count, SheepCatalog.all.count)
    }

    func testPosterArrivalNightsKeepStarterPostersAvailableAndLaterPostersGated() {
        XCTAssertEqual(SheepCatalog.arrivalNight(for: SheepCatalog.all[0]), 1)
        XCTAssertTrue(SheepCatalog.eligible(for: 1).contains { $0.id == "mabel" })
        XCTAssertFalse(SheepCatalog.eligible(for: 1).contains { $0.id == "juniper" })
        XCTAssertTrue(SheepCatalog.eligible(for: 4).contains { $0.id == "juniper" })
    }

    func testPosterBoardFiltersUsePersistedFoundIDsAndKeepCatalogueOrder() {
        var state = SheepSearchState.empty
        state.foundSheepIDs = ["pippin"]

        let missing = SheepPosterSelection.posters(
            for: state,
            protectedNightNumber: 1,
            filter: .missing
        )
        let home = SheepPosterSelection.posters(
            for: state,
            protectedNightNumber: 1,
            filter: .home
        )
        let all = SheepPosterSelection.posters(
            for: state,
            protectedNightNumber: 1,
            filter: .all
        )

        XCTAssertEqual(home.map(\.id), ["pippin"])
        XCTAssertEqual(all.map(\.id), ["mabel", "pippin", "bramble", "clementine", "oat"])
        XCTAssertEqual(missing.map(\.id), ["mabel", "bramble", "clementine", "oat"])
    }

    func testPosterBoardNeverShowsAFoundPosterBeforeItsArrivalNight() {
        var state = SheepSearchState.empty
        state.foundSheepIDs = ["juniper"]

        let home = SheepPosterSelection.posters(
            for: state,
            protectedNightNumber: 1,
            filter: .home
        )

        XCTAssertTrue(home.isEmpty)
    }

    func testTrailBoardFilterTitlesUseSearchLanguage() {
        XCTAssertEqual(SheepPosterFilter.missing.title, "Still searching")
        XCTAssertEqual(SheepPosterFilter.home.title, "Home")
        XCTAssertEqual(SheepPosterFilter.all.title, "All sheep")
    }

    func testTrackedTrailChangesSelectionWeightButNotEncounterOdds() {
        var trackedFinds = 0
        var untrackedFinds = 0
        for seed in 1...300 {
            let runID = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", seed))!
            let untracked = SheepSearchEngine.calculate(
                runID: runID,
                protectedNightNumber: 1,
                evidence: .empty,
                state: .empty,
                seed: UInt64(seed)
            ).outcome
            let tracked = SheepSearchEngine.calculate(
                runID: runID,
                protectedNightNumber: 1,
                evidence: .empty,
                state: .empty,
                trackedSheepID: "oat",
                seed: UInt64(seed)
            ).outcome
            XCTAssertEqual(tracked.encounterOdds, untracked.encounterOdds)
            if untracked.sheepID == "oat" { untrackedFinds += 1 }
            if tracked.sheepID == "oat" { trackedFinds += 1 }
        }
        XCTAssertGreaterThan(trackedFinds, untrackedFinds)
    }

    func testTrailMapAccumulatesPhoneBreakMinutesAndCarriesRemainder() {
        let cases = [(14, 0), (15, 1), (30, 2), (99, 5), (100, 5), (220, 5)]
        for (minutes, expectedPoints) in cases {
            var map = SheepTrailMapState()
            map.credit(runID: UUID(), minutes: minutes)
            XCTAssertEqual(map.pendingMappedMinutes, min(SheepTrailMapState.maximumPendingMinutes, minutes))
            XCTAssertEqual(map.availableBonusPercentagePoints, expectedPoints)
        }

        var map = SheepTrailMapState(pendingMappedMinutes: 60)
        map.credit(runID: UUID(), minutes: 100)
        XCTAssertEqual(map.pendingMappedMinutes, 160)
        map.consumeBonusSearchMeter()
        XCTAssertEqual(map.pendingMappedMinutes, 60)
    }

    func testTrailMapHomeCopyExplainsTheRealMechanic() throws {
        XCTAssertNil(SheepTrailMapPresentation.home(availableBonusPercentagePoints: 0))
        let presentation = try XCTUnwrap(
            SheepTrailMapPresentation.home(pendingMappedMinutes: SheepTrailMapState.maximumMappedMinutes)
        )
        XCTAssertEqual(presentation.title, "Extra search progress · 100 / 100 minutes")
        XCTAssertTrue(presentation.detail.contains("Complete another Phone Away"))
    }

    func testLockedTrailMapBanksOnlyOneFullMeter() {
        var map = SheepTrailMapState()
        map.credit(runID: UUID(), minutes: 100, pendingCap: SheepTrailMapState.maximumMappedMinutes)
        map.credit(runID: UUID(), minutes: 100, pendingCap: SheepTrailMapState.maximumMappedMinutes)
        XCTAssertEqual(map.pendingMappedMinutes, SheepTrailMapState.maximumMappedMinutes)

        map.credit(runID: UUID(), minutes: 100, pendingCap: SheepTrailMapState.maximumPendingMinutes)
        XCTAssertEqual(map.pendingMappedMinutes, SheepTrailMapState.maximumPendingMinutes)
        map.consumeBonusSearchMeter()
        XCTAssertEqual(map.pendingMappedMinutes, SheepTrailMapState.maximumMappedMinutes)
    }

    func testTrailMapRejectsDuplicateRuns() {
        var map = SheepTrailMapState()
        let runID = UUID()
        XCTAssertEqual(map.credit(runID: runID, minutes: 30), 30)
        XCTAssertEqual(map.credit(runID: runID, minutes: 30), 0)
        XCTAssertEqual(map.pendingMappedMinutes, 30)
    }

    func testPhoneAwayMeterPreservesLegacyPendingMinutesAndCapsOverflow() throws {
        let decoder = JSONDecoder()
        let legacy = """
        {"schemaVersion":2,"pendingMappedMinutes":150,"creditedAdHocRunIDs":[]}
        """.data(using: .utf8)!
        let map = try decoder.decode(SheepTrailMapState.self, from: legacy)
        XCTAssertEqual(map.pendingMappedMinutes, 150)
        XCTAssertEqual(SheepTrailMapState.maximumMappedMinutes, 100)

        var overflow = SheepTrailMapState()
        XCTAssertEqual(
            overflow.credit(runID: UUID(), minutes: 500),
            SheepTrailMapState.maximumPendingMinutes
        )
        XCTAssertEqual(overflow.pendingMappedMinutes, SheepTrailMapState.maximumPendingMinutes)
    }

    func testPhoneAwaySearchKeepsTheDeterministicLadderSeparate() {
        var state = SheepSearchState.empty
        let odds: [(Int, Double)] = [(0, 0.20), (1, 0.30), (2, 0.40), (3, 0.50)]
        for (noFinds, expected) in odds {
            state.phoneBreakConsecutiveNoFinds = noFinds
            let result = SheepSearchEngine.calculatePhoneBreak(
                runID: UUID(),
                protectedNightNumber: 4,
                state: state,
                seed: 999
            )
            XCTAssertEqual(result.outcome.encounterOdds, expected)
        }
        state.phoneBreakConsecutiveNoFinds = 4
        XCTAssertEqual(
            SheepSearchEngine.calculatePhoneBreak(
                runID: UUID(),
                protectedNightNumber: 4,
                state: state,
                seed: 999
            ).outcome.encounterOdds,
            1
        )
    }

    func testGuaranteedSearchRetainsMappedMinutes() {
        var state = SheepSearchState.empty
        state.trailMap.credit(runID: UUID(), minutes: 45)
        var evidence = SheepSearchEvidence.empty
        evidence.trailMapBonusPercentagePoints = 3
        let result = SheepSearchEngine.calculate(
            runID: runIDs[0], protectedNightNumber: 1, evidence: evidence, state: state, seed: 0
        )
        XCTAssertEqual(result.outcome.trailMapBonusPercentagePoints, 0)
        state.append(result.outcome)
        XCTAssertEqual(state.trailMap.pendingMappedMinutes, 45)
    }

    func testNewWindDownSearchDoesNotConsumePhoneBreakMeter() {
        var state = SheepSearchState.empty
        state.trailMap.credit(runID: UUID(), minutes: 100)
        var evidence = SheepSearchEvidence.empty
        evidence.windDownMinutes = 30
        evidence.morningQuietMinutes = 30
        evidence.startedNearSchedule = true
        evidence.shieldingObserved = true
        evidence.placementConfirmed = true
        evidence.recentProtectedNights = 12
        evidence.optionalBonusPoints = 10
        evidence.trailMapBonusPercentagePoints = 5
        let result = SheepSearchEngine.calculate(
            runID: UUID(), protectedNightNumber: 8, evidence: evidence, state: state, seed: 5
        )
        XCTAssertLessThanOrEqual(result.outcome.encounterOdds, 0.92)
        state.append(result.outcome)
        XCTAssertEqual(state.trailMap.pendingMappedMinutes, 100)
    }

    func testPhoneBreakSearchUsesSeparateOriginAndDroughtCounter() {
        var state = SheepSearchState.empty
        state.phoneBreakConsecutiveNoFinds = 2
        let runID = UUID()
        let result = SheepSearchEngine.calculatePhoneBreak(
            runID: runID,
            protectedNightNumber: 1,
            state: state,
            seed: 0
        )
        XCTAssertEqual(result.outcome.origin, .phoneBreak)
        XCTAssertEqual(result.outcome.encounterOdds, 0.40)
        state.append(result.outcome)
        XCTAssertEqual(state.consecutiveNoFinds, 0)
        XCTAssertEqual(state.phoneBreakConsecutiveNoFinds, result.outcome.result == .found ? 0 : 3)
    }

    func testPhoneBreakSearchIsGuaranteedAfterFourCluesAndIdempotent() {
        var state = SheepSearchState.empty
        state.phoneBreakConsecutiveNoFinds = 4
        let runID = UUID()
        let first = SheepSearchEngine.calculatePhoneBreak(runID: runID, protectedNightNumber: 1, state: state, seed: 12)
        XCTAssertEqual(first.outcome.encounterOdds, 1)
        state.append(first.outcome)
        let replay = SheepSearchEngine.calculatePhoneBreak(runID: runID, protectedNightNumber: 1, state: state, seed: 999)
        XCTAssertEqual(first.outcome, replay.outcome)
    }

    func testLegacyOutcomeAndStateDecodeWithoutTrailMapFields() throws {
        let outcomeJSON = """
        {"id":"00000000-0000-0000-0000-000000000001","runID":"00000000-0000-0000-0000-000000000002","protectedNightNumber":4,"result":"trailOnly","trailStrength":20,"encounterOdds":0.3,"trailDistance":1.0,"consecutiveNoFinds":0,"bonusPoints":0,"createdAt":0}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let outcome = try decoder.decode(SheepSearchOutcome.self, from: outcomeJSON)
        XCTAssertEqual(outcome.trailMapBonusPercentagePoints, 0)
        XCTAssertEqual(outcome.origin, .windDown)

        let stateJSON = """
        {"schemaVersion":1,"outcomes":[],"foundSheepIDs":[],"consecutiveNoFinds":0,"totalTrailDistance":0,"showExactOdds":false}
        """.data(using: .utf8)!
        let state = try decoder.decode(SheepSearchState.self, from: stateJSON)
        XCTAssertEqual(state.trailMap, SheepTrailMapState())
        XCTAssertEqual(state.schemaVersion, SheepSearchState.currentSchemaVersion)
    }
}
