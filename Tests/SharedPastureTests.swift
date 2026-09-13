import XCTest

final class SharedPastureTests: XCTestCase {
    func testWalkableBoundsRejectNonFiniteAndScenery() {
        for point in [PastureScenePoint(x: .nan, y: 0.6), .init(x: .infinity, y: 0.7), .init(x: 0.2, y: 0.85), .init(x: 0.6, y: 0.2)] {
            XCTAssertFalse(SharedPastureRules.isWalkable(point))
            XCTAssertTrue(SharedPastureRules.isWalkable(SharedPastureRules.bounded(point)))
        }
    }
    func testCommandsRoundTripRetainsOriginalConflictBaseAndIdentity() throws {
        var command = SharedPastureCommand(command: "movePastureEntity", partyID: UUID(), memberEpochID: UUID())
        command.entityID = "member-\(UUID())"; command.expectedRevision = 9; command.x = 0.5; command.y = 0.7
        let restored = try JSONDecoder().decode(SharedPastureCommand.self, from: JSONEncoder().encode(command))
        XCTAssertEqual(restored, command)
        XCTAssertEqual(restored.idempotencyKey.count, 64)
        XCTAssertEqual(restored.expectedRevision, 9)
    }
    func testOnlyMovedEntityProducesCommandAndInvalidAnchorIsBounded() {
        let member = UUID()
        let entity = SharedPastureEntity(id: "member-\(UUID())", kind: "shepherd", referenceID: member, revision: 4, x: 0.5, y: 0.7)
        let state = SharedPastureState(memberEpochID: UUID(), entities: [entity], visits: [], lantern: .init(contributions: 0, requiredContributions: 12))
        XCTAssertTrue(SharedPastureRules.changedEntities(in: state.arrangement, from: state).isEmpty)
        var arrangement = state.arrangement
        arrangement.positions[SharedMeadowOccupant.member(member).key] = .init(x: 0.2, y: 0.9)
        let changes = SharedPastureRules.changedEntities(in: arrangement, from: state)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].revision, 4)
        XCTAssertTrue(SharedPastureRules.isWalkable(changes[0].point))
    }
    func testNewVisitDoesNotContainExpiryOrPrivateInventory() throws {
        let visit = SharedPastureVisit(id: UUID(), memberID: UUID(), sheepDefinitionID: "bramble", sheepDisplayName: "Bramble", sentAt: Date())
        let wire = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(visit)) as? [String: Any])
        XCTAssertNil(wire["expiresAt"])
        XCTAssertNil(wire["ownedSheepID"])
        XCTAssertNil(wire["farm"])
    }
    func testResponseSettlesAndReduceMotionHasNoBounce() {
        for tick in 0...90 {
            let t = Double(tick) / 60
            let value = PasturePlay.response(elapsed: t, reduceMotion: false)
            XCTAssertLessThanOrEqual(value.lift, 7)
            XCTAssertLessThanOrEqual(abs(value.tilt), 3)
            XCTAssertTrue((0.95...1.05).contains(value.squash))
            XCTAssertEqual(PasturePlay.response(elapsed: t, reduceMotion: true).lift, 0)
        }
        XCTAssertEqual(PasturePlay.response(elapsed: 1, reduceMotion: false).lift, 0)
        XCTAssertEqual(PasturePlay.response(elapsed: .infinity, reduceMotion: false).squash, 1)
    }
    func testFetchAndGatherStayBoundedAtCapacity() {
        for origin in [PastureScenePoint(x: 0.1, y: 0.89), .init(x: 0.9, y: 0.5)] {
            XCTAssertTrue(SharedPastureRules.isWalkable(PasturePlay.fetchTarget(from: origin)))
            let points = PasturePlay.gatheringPoints(around: origin, count: 100)
            XCTAssertEqual(points.count, 12)
            XCTAssertTrue(points.allSatisfy(SharedPastureRules.isWalkable))
        }
    }
    @MainActor func testOutboxRecoveryAndAccountIsolation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SharedPastureOutboxService(directory: directory)
        let a = UUID(), b = UUID()
        let command = SharedPastureCommand(command: "recallPastureSheep", partyID: UUID(), memberEpochID: UUID())
        try store.enqueue(command, owner: a); try store.enqueue(command, owner: a)
        XCTAssertEqual(try store.commands(owner: a).count, 1)
        XCTAssertTrue(try store.commands(owner: b).isEmpty)
        try Data("broken".utf8).write(to: directory.appendingPathComponent(a.uuidString.lowercased()+".json"))
        XCTAssertEqual(try store.commands(owner: a).first, command)
        try store.remove(command.id, owner: a)
        XCTAssertTrue(try store.commands(owner: a).isEmpty)
    }
    @MainActor func testVisitIndexSurvivesRelaunchAndNeverCrossesAccounts() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let a = UUID(), b = UUID(), party = UUID(), sheep = UUID()
        let store = SharedPastureOutboxService(directory: directory)
        try store.saveVisitIndex([party: [sheep]], owner: a)
        let reopened = SharedPastureOutboxService(directory: directory)
        XCTAssertEqual(try reopened.visitIndex(owner: a), [party: [sheep]])
        XCTAssertTrue(try reopened.visitIndex(owner: b).isEmpty)
        try reopened.saveVisitIndex([:], owner: a)
        XCTAssertTrue(try store.visitIndex(owner: a).isEmpty)
    }

    @MainActor func testCorruptRecoveryWithoutPrimaryIsNotAnEmptyQueue() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let owner = UUID()
        try Data("broken".utf8).write(to: directory.appendingPathComponent(owner.uuidString.lowercased()+".json.recovery"))
        XCTAssertThrowsError(try SharedPastureOutboxService(directory: directory).commands(owner: owner))
    }

    func testLanternUsesTheSameRevisionCheckedPlacementPath() {
        let id = UUID()
        let entity = SharedPastureEntity(id: "lantern-\(id)", kind: "lantern", referenceID: id, revision: 3, x: 0.32, y: 0.60)
        let state = SharedPastureState(memberEpochID: UUID(), entities: [entity], visits: [], lantern: .init(contributions: 12, requiredContributions: 12, completedAt: Date()))
        var arrangement = state.arrangement
        arrangement.positions[SharedMeadowOccupant.lantern(id).key] = .init(x: 0.7, y: 0.8)
        let changed = SharedPastureRules.changedEntities(in: arrangement, from: state)
        XCTAssertEqual(changed.first?.revision, 3)
        XCTAssertEqual(changed.first?.id, entity.id)
        var future = state; future.sceneRevision = 2
        XCTAssertFalse(future.isSupported)
    }

}
