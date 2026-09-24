import XCTest

final class PastureFetchPracticeTests: XCTestCase {
    func testFiveLandingsScoreOnceAndOnlyCompletedPracticeImprovesBest() {
        var practice = PastureFetchPractice()
        var farm = FarmState.empty
        farm.recordFetchPractice(practice)
        XCTAssertNil(farm.fetchPracticeBest)
        for target in PastureFetchPractice.targets { practice.record(landing: target.point) }
        XCTAssertEqual(practice.score, 15)
        XCTAssertTrue(practice.isComplete)
        practice.record(landing: .init(x: 0, y: 0))
        XCTAssertEqual(practice.scores.count, 5)
        farm.recordFetchPractice(practice)
        farm.recordFetchPractice(practice)
        var missed = PastureFetchPractice()
        for _ in 0..<5 { missed.record(landing: .init(x: 0, y: 0)) }
        farm.recordFetchPractice(missed)
        XCTAssertEqual(farm.fetchPracticeBest, 15)
        farm.fetchPracticeBest = nil
        XCTAssertEqual(farm, .empty, "Practice changes neither rewards nor session credit")
    }

    func testRingsAndAccessibleAimCoverAllTargetsWithSameThrowProjection() throws {
        let origin = PastureScenePoint(x: 0.5, y: 0.76)
        for target in PastureFetchPractice.targets {
            XCTAssertEqual(target.points(for: target.point), 3)
            XCTAssertEqual(target.points(for: .init(x: target.point.x + target.radius * 0.7, y: target.point.y)), 1)
            XCTAssertEqual(target.points(for: .init(x: target.point.x + target.radius * 1.1, y: target.point.y)), 0)
            XCTAssertEqual(target.points(for: .init(x: .nan, y: 0)), 0)
            var canReachCenter = false
            for heading in stride(from: -180.0, through: 180, by: 5) {
                for strength in 1...100 {
                    let travel = try XCTUnwrap(PastureFetchPractice.translation(heading: heading, strength: Double(strength)))
                    let landing = try XCTUnwrap(PastureFetchRound.throwTarget(origin: origin, translation: travel, predictedTranslation: travel))
                    if target.points(for: landing) == 3 { canReachCenter = true }
                }
            }
            XCTAssertTrue(canReachCenter, target.description)
        }
        XCTAssertNil(PastureFetchPractice.translation(heading: .infinity, strength: 50))
        XCTAssertNil(PastureFetchPractice.translation(heading: 0, strength: 101))
    }

    func testBallPurchaseEquipAndFailuresPreserveInventoryAndWool() throws {
        var farm = FarmState.empty
        XCTAssertThrowsError(try farm.purchase(itemID: "fetch_ball_moss"))
        XCTAssertEqual(farm, .empty)
        farm.woolBalance = 7
        try farm.purchase(itemID: "fetch_ball_moss")
        try farm.purchase(itemID: "fetch_ball_sunset")
        XCTAssertEqual(farm.woolBalance, 0)
        XCTAssertEqual(farm.equipment.fetchBallItemID, "fetch_ball_sunset")
        let purchased = farm
        XCTAssertThrowsError(try farm.purchase(itemID: "fetch_ball_sunset"))
        XCTAssertEqual(farm, purchased)
        try farm.equip(itemID: "fetch_ball_moss")
        XCTAssertEqual(farm.equipment.fetchBallItemID, "fetch_ball_moss")
        XCTAssertNil(farm.equipment.ollieAccessoryItemID)
        XCTAssertEqual(farm.transactions.count, 2)
        var unowned = FarmState.empty
        XCTAssertThrowsError(try unowned.equip(itemID: "fetch_ball_moss"))
    }

    func testLegacySaveDefaultsAndPrivateRestorePreserveBestAndUnknownBall() throws {
        let legacy = try JSONDecoder().decode(FarmState.self, from: Data("{}".utf8))
        XCTAssertNil(legacy.fetchPracticeBest)
        XCTAssertNil(legacy.equipment.fetchBallItemID)
        var farm = legacy
        farm.migrateCumulativeCredit(records: [], searchState: .empty, protectedNightCount: 0)
        farm.fetchPracticeBest = 12
        farm.equipment.fetchBallItemID = "future_ball"
        farm.ownedShopItemIDs = ["future_ball"]
        let doc = FarmSaveDocument(lineageID: UUID(), generation: 1,
            values: ["ollie.farm.state": try JSONEncoder().encode(farm)])
        let local = try FarmSaveDocument.decode(doc.encoded())
        let payload = try FarmBackupPayload(document: local)
        let remote = try FarmBackupPayload.decodeRemote(JSONEncoder().encode(payload))
        XCTAssertEqual(remote.farm, farm)
        let restored = try remote.restoredValues(preservingLocalProgress: .empty)
        XCTAssertEqual(try JSONDecoder().decode(FarmState.self, from: XCTUnwrap(restored["ollie.farm.state"])), farm)
        XCTAssertEqual(try remote.fingerprint(), try payload.fingerprint())
        for invalid in [-1, 16] {
            XCTAssertThrowsError(try JSONDecoder().decode(FarmState.self, from: Data("{\"fetchPracticeBest\":\(invalid)}".utf8)))
        }
    }
}
