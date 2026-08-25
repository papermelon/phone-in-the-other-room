import XCTest

final class PastureSceneTests: XCTestCase {
    private let sheepA = UUID(uuidString: "A0000000-0000-0000-0000-000000000001")!
    private let sheepB = UUID(uuidString: "B0000000-0000-0000-0000-000000000002")!

    func testClampingKeepsNormalizedPointInsideGroundBounds() {
        let point = PastureSceneLayout.clamped(
            PastureScenePoint(x: -2, y: 2),
            footprint: .sheep
        )

        XCTAssertEqual(point.x, PastureSceneLayout.groundMinimum.x + PastureSceneFootprint.sheep.halfWidth)
        XCTAssertEqual(point.y, PastureSceneLayout.groundMaximum.y - PastureSceneFootprint.sheep.halfHeight)
    }

    func testFootprintAwareBoundsKeepLargeCharacterAwayFromEdge() {
        let sheep = PastureSceneLayout.clamped(
            PastureScenePoint(x: 0, y: 0),
            footprint: .sheep
        )
        let ollie = PastureSceneLayout.clamped(
            PastureScenePoint(x: 0, y: 0),
            footprint: .ollie
        )

        XCTAssertGreaterThan(ollie.x, sheep.x)
        XCTAssertGreaterThan(ollie.y, sheep.y)
    }

    func testSettleSeparatesOverlappingCharactersWhereGroundAllows() {
        let first = PastureSceneEntityID.sheep(sheepA, pastureIndex: 0)
        let second = PastureSceneEntityID.sheep(sheepB, pastureIndex: 0)
        let firstPoint = PastureScenePoint(x: 0.50, y: 0.70)
        let settled = PastureSceneLayout.settledPosition(
            proposed: firstPoint,
            for: second,
            among: [first: firstPoint]
        )

        XCTAssertGreaterThanOrEqual(
            settled.distance(to: firstPoint),
            PastureSceneFootprint.sheep.halfWidth * 2 - 0.000_1
        )
    }

    func testOrdinarySettlementIgnoresHiddenPastureCharacters() {
        let moving = PastureSceneEntityID.sheep(sheepA, pastureIndex: 0)
        let hidden = PastureSceneEntityID.sheep(sheepB, pastureIndex: 1)
        let proposed = PastureScenePoint(x: 0.50, y: 0.70)

        // `finishDrag` uses this shared settling helper for ordinary and
        // Reduce Motion placement, so another page cannot repel this drop.
        XCTAssertEqual(
            PastureSceneLayout.settledPosition(
                proposed: proposed,
                for: moving,
                among: [hidden: proposed]
            ),
            proposed
        )
    }

    func testSnapshotDecodeFailsSafelyForOlderEmptyAndCorruptData() throws {
        let oldData = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 0,
            "positions": []
        ])
        let emptyData = try JSONEncoder().encode(PastureSceneSnapshot(positions: []))

        XCTAssertNil(PastureSceneSnapshot.decodeSafely(from: oldData))
        XCTAssertNotNil(PastureSceneSnapshot.decodeSafely(from: emptyData))
        XCTAssertNil(PastureSceneSnapshot.decodeSafely(from: Data([0x00, 0xFF, 0x12])))
        XCTAssertNil(PastureSceneSnapshot.decodeSafely(from: nil))
    }

    func testPruningRemovesStaleEntitiesAndClampsStoredPositions() {
        let current = PastureSceneEntityID.sheep(sheepA, pastureIndex: 0)
        let stale = PastureSceneEntityID.sheep(sheepB, pastureIndex: 0)
        let snapshot = PastureSceneSnapshot(positions: [
            PastureSceneStoredPosition(entityID: current, point: PastureScenePoint(x: 4, y: -1)),
            PastureSceneStoredPosition(entityID: stale, point: PastureScenePoint(x: 0.7, y: 0.7))
        ])

        let pruned = PastureSceneLayout.pruned(snapshot, keeping: [current])

        XCTAssertEqual(Set(pruned.keys), [current])
        XCTAssertEqual(
            pruned[current]?.x,
            PastureSceneLayout.groundMaximum.x - PastureSceneFootprint.sheep.halfWidth
        )
    }

    func testScamperAndChasePlanningAreDeterministic() {
        let ollie = PastureSceneEntityID.ollie(pastureIndex: 0)
        let sheep = PastureSceneEntityID.sheep(sheepA, pastureIndex: 0)
        let positions = [
            ollie: PastureScenePoint(x: 0.25, y: 0.72),
            sheep: PastureScenePoint(x: 0.42, y: 0.72)
        ]

        XCTAssertEqual(
            PastureSceneLayout.scamperTarget(for: sheep, from: positions[sheep]!, seed: 77, among: positions),
            PastureSceneLayout.scamperTarget(for: sheep, from: positions[sheep]!, seed: 77, among: positions)
        )
        XCTAssertEqual(
            PastureSceneLayout.chasePlan(ollieID: ollie, sheep: [sheep], positions: positions, seed: 99),
            PastureSceneLayout.chasePlan(ollieID: ollie, sheep: [sheep], positions: positions, seed: 99)
        )
    }

    func testChaseRejectsOtherPasturesAndSelectsOnlyVisiblePastureSheep() {
        let ollie = PastureSceneEntityID.ollie(pastureIndex: 0)
        let samePasture = PastureSceneEntityID.sheep(sheepA, pastureIndex: 0)
        let otherPasture = PastureSceneEntityID.sheep(sheepB, pastureIndex: 1)
        let positions = [
            ollie: PastureScenePoint(x: 0.25, y: 0.72),
            samePasture: PastureScenePoint(x: 0.42, y: 0.72),
            otherPasture: PastureScenePoint(x: 0.27, y: 0.72)
        ]

        XCTAssertNil(PastureSceneLayout.chasePlan(
            ollieID: ollie,
            sheep: [otherPasture],
            positions: positions,
            seed: 1
        ))
        XCTAssertEqual(
            PastureSceneLayout.chasePlan(
                ollieID: ollie,
                sheep: [otherPasture, samePasture],
                positions: positions,
                seed: 1
            )?.sheepID,
            samePasture
        )

        XCTAssertNil(PastureSceneLayout.chasePlan(
            ollieID: ollie,
            sheep: [samePasture],
            positions: [
                ollie: PastureScenePoint(x: 0.15, y: 0.55),
                samePasture: PastureScenePoint(x: 0.83, y: 0.88)
            ],
            seed: 1
        ))
    }

    func testCataloguePersonalitiesUseExplicitIdentityGroupsAndGentleFallback() {
        XCTAssertEqual(PastureSceneInteractionRules.personality(for: "mabel"), .gentle)
        XCTAssertEqual(PastureSceneInteractionRules.personality(for: "pippin"), .curious)
        XCTAssertEqual(PastureSceneInteractionRules.personality(for: "marigold"), .bouncy)
        XCTAssertEqual(PastureSceneInteractionRules.personality(for: "ramsey"), .brave)
        XCTAssertEqual(PastureSceneInteractionRules.personality(for: "wisp"), .dreamy)
        XCTAssertEqual(PastureSceneInteractionRules.personality(for: "retired-sheep"), .gentle)
    }

    func testTossCapsMomentumAndKeepsLandingInsideFootprintBounds() {
        let sheep = PastureSceneEntityID.sheep(sheepA, pastureIndex: 0)
        let origin = PastureScenePoint(x: 0.50, y: 0.70)
        let target = PastureSceneInteractionRules.tossTarget(
            for: sheep,
            from: origin,
            predictedTranslation: PastureScenePoint(x: 3, y: 4),
            among: [sheep: origin]
        )

        XCTAssertLessThanOrEqual(
            target.distance(to: origin),
            PastureSceneInteractionRules.maximumTossDistance + 0.000_1
        )
        XCTAssertGreaterThanOrEqual(target.x, PastureSceneLayout.groundMinimum.x + PastureSceneFootprint.sheep.halfWidth)
        XCTAssertLessThanOrEqual(target.y, PastureSceneLayout.groundMaximum.y - PastureSceneFootprint.sheep.halfHeight)
    }

    func testSamePastureCollisionStillHonorsHardTossDistanceCap() {
        let moving = PastureSceneEntityID.sheep(sheepA, pastureIndex: 0)
        let visible = PastureSceneEntityID.sheep(sheepB, pastureIndex: 0)
        let otherPasture = PastureSceneEntityID.ollie(pastureIndex: 1)
        let origin = PastureScenePoint(x: 0.42, y: 0.70)
        let blocker = PastureScenePoint(x: 0.57, y: 0.70)
        let target = PastureSceneInteractionRules.tossTarget(
            for: moving,
            from: origin,
            predictedTranslation: PastureScenePoint(x: 0.15, y: 0),
            among: [
                moving: origin,
                visible: blocker,
                otherPasture: PastureScenePoint(x: 0.57, y: 0.70)
            ]
        )

        XCTAssertLessThanOrEqual(
            target.distance(to: origin),
            PastureSceneInteractionRules.maximumTossDistance + 0.000_1
        )
        XCTAssertGreaterThanOrEqual(target.x, PastureSceneLayout.groundMinimum.x + PastureSceneFootprint.sheep.halfWidth)
        XCTAssertLessThanOrEqual(target.x, PastureSceneLayout.groundMaximum.x - PastureSceneFootprint.sheep.halfWidth)
    }

    func testTossHandlesHugeFinitePredictionWithoutOverflowingItsCap() {
        let sheep = PastureSceneEntityID.sheep(sheepA, pastureIndex: 0)
        let origin = PastureScenePoint(x: 0.50, y: 0.70)
        let target = PastureSceneInteractionRules.tossTarget(
            for: sheep,
            from: origin,
            predictedTranslation: PastureScenePoint(
                x: .greatestFiniteMagnitude,
                y: .greatestFiniteMagnitude
            ),
            among: [sheep: origin]
        )

        XCTAssertTrue(target.x.isFinite)
        XCTAssertTrue(target.y.isFinite)
        XCTAssertLessThanOrEqual(
            target.distance(to: origin),
            PastureSceneInteractionRules.maximumTossDistance + 0.000_1
        )
    }

    func testTossSanitizesNonFiniteInputsAndSettlesInPlace() {
        let sheep = PastureSceneEntityID.sheep(sheepA, pastureIndex: 0)
        let stored = PastureScenePoint(x: 0.47, y: 0.72)
        let target = PastureSceneInteractionRules.tossTarget(
            for: sheep,
            from: PastureScenePoint(x: .infinity, y: .nan),
            predictedTranslation: PastureScenePoint(x: .nan, y: -.infinity),
            among: [sheep: stored]
        )

        XCTAssertEqual(target, stored)
        XCTAssertTrue(target.x.isFinite)
        XCTAssertTrue(target.y.isFinite)
    }

    func testResetStorageIncludesStandalonePastureSnapshot() {
        XCTAssertTrue(CountingSheepOwnedStorage.standardKeys.contains("ollie.farm.pastureScene"))
    }
}
