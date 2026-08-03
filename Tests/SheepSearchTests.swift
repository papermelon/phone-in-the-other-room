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

    func testCatalogueIncludesDistinctFarmBreeds() {
        let breeds = Set(SheepCatalog.all.map(\.breed))

        XCTAssertTrue(breeds.contains(.fluffy))
        XCTAssertTrue(breeds.contains(.spotted))
        XCTAssertTrue(breeds.contains(.merino))
        XCTAssertTrue(breeds.contains(.night))
        XCTAssertTrue(breeds.contains(.guardian))
        XCTAssertEqual(SheepCatalog.definition(for: "oat")?.assetName, "sheep/sheep_merino")
        XCTAssertEqual(SheepCatalog.definition(for: "wisp")?.assetName, "sheep/sheep_night")
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
}
