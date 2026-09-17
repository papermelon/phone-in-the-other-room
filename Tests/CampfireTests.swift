import XCTest

final class CampfireTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func session(member: UUID = UUID(), revision: Int = 1, ended: Bool = false) -> CampfireSession {
        .init(id: UUID(), memberID: member, kind: .phoneAway, activity: .reading,
              startedAt: now.addingTimeInterval(-60), observedAt: now.addingTimeInterval(-60),
              expiresAt: now.addingTimeInterval(1800), ended: ended, revision: revision)
    }
    func testExpiryStaleAndUnknownCapabilityNeverSeatMembers() {
        let row = session(), members = Set([session().memberID])
        let state = CampfireState(sessions: [row])
        XCTAssertTrue(CampfireRules.currentSessions(state, members: members, isFresh: true, at: now).isEmpty)
        XCTAssertTrue(CampfireRules.currentSessions(state, members: [row.memberID], isFresh: false, at: now).isEmpty)
        XCTAssertTrue(CampfireRules.currentSessions(.init(version: 2, sessions: [row]), members: [row.memberID], isFresh: true, at: now).isEmpty)
        XCTAssertFalse(row.isCurrent(at: row.expiresAt))
        XCTAssertEqual(CampfireRules.currentSessions(state, members: [row.memberID], isFresh: true, at: now), [row])
    }
    func testRestoredSessionNeverInheritsAnotherAccount() {
        let a = UUID(), b = UUID()
        XCTAssertTrue(CampfireRules.permitsOwner(captured: a, current: a))
        XCTAssertFalse(CampfireRules.permitsOwner(captured: a, current: b))
        XCTAssertFalse(CampfireRules.permitsOwner(captured: nil, current: b))
        XCTAssertFalse(CampfireRules.permitsOwner(captured: a, current: nil))
    }
    func testFutureCapabilityPayloadDoesNotBreakTheParty() throws {
        let data = Data(#"{"version":2,"agreement":{"newConsent":true},"sessions":[{"futureKind":"newActivity"}]}"#.utf8)
        let state = try JSONDecoder().decode(CampfireState.self, from: data)
        XCTAssertFalse(state.isSupported)
        XCTAssertNil(state.agreement)
        XCTAssertTrue(state.sessions.isEmpty)
    }
    func testTerminalRevisionWinsAndOldSessionCannotResurrect() {
        let start = session()
        var end = start; end.ended = true; end.revision = 2
        XCTAssertTrue(CampfireRules.currentSessions(.init(sessions: [end,start]), members: [start.memberID], isFresh: true, at: now).isEmpty)
        var earlier = start; earlier.id = UUID(); earlier.startedAt = now.addingTimeInterval(-600)
        XCTAssertTrue(CampfireRules.currentSessions(.init(sessions: [end,earlier]), members: [start.memberID], isFresh: true, at: now).isEmpty)
    }
    func testSeatingIsStableBoundedAndNeverChangesArrangement() {
        let positions = (0..<8).map { CampfireRules.seat(index: $0, count: 8) }
        XCTAssertTrue(positions.allSatisfy(SharedPastureRules.isWalkable))
        for index in 0..<8 {
            let visitor = CampfireRules.visitorSeat(index: index, count: 8)
            XCTAssertTrue(SharedPastureRules.isWalkable(visitor))
            XCTAssertGreaterThan(visitor.distance(to: CampfireRules.fire), 0.15)
        }
        XCTAssertEqual(Set(positions.map { "\($0.x):\($0.y)" }).count, 8)
        let id = UUID()
        let pasture = SharedPastureState(memberEpochID: UUID(), entities: [.init(id: "member-\(id)", kind: "shepherd", referenceID: id, revision: 8, x: 0.6, y: 0.7)], visits: [], lantern: .init(contributions: 5, requiredContributions: 12))
        XCTAssertTrue(SharedPastureRules.changedEntities(in: pasture.arrangement, from: pasture).isEmpty)
    }
    func testLegacyPlanAndPastureDecodeWithoutCampfireConsentOrActivity() throws {
        let plan = NightWatchPlan.additionalQuiet(start: now, end: now.addingTimeInterval(1800), cueText: "Private task title")
        let data = try JSONEncoder().encode(plan)
        let restored = try JSONDecoder().decode(NightWatchPlan.self, from: data)
        XCTAssertNil(restored.campfireActivity)
        XCTAssertNil(restored.campfireOwnerID)
        var selected = plan; selected.campfireActivity = .studying; selected.campfireOwnerID = UUID()
        XCTAssertEqual(try JSONDecoder().decode(NightWatchPlan.self, from: JSONEncoder().encode(selected)), selected)
        let state = SharedPastureState(memberEpochID: UUID(), entities: [], visits: [], lantern: .init(contributions: 0, requiredContributions: 12))
        XCTAssertNil(try JSONDecoder().decode(SharedPastureState.self, from: JSONEncoder().encode(state)).campfire)
    }
    @MainActor func testTerminalReplacesQueuedStartAndRevocationSurvivesRelaunch() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let outbox = SharedPastureOutboxService(directory: dir), owner = UUID(), other = UUID()
        var start = SharedPastureCommand(command: "publishCampfireSession", partyID: UUID(), memberEpochID: UUID())
        start.sourceID = UUID(); start.revision = 1; start.ended = false
        try outbox.enqueue(start, owner: owner)
        var end = start; end.revision = 2; end.ended = true; end.idempotencyKey = "end"
        try outbox.enqueue(end, owner: owner); try outbox.enqueue(start, owner: owner)
        XCTAssertEqual(try outbox.commands(owner: owner), [end])
        XCTAssertTrue(try outbox.commands(owner: other).isEmpty)
        var revoke = SharedPastureCommand(command: "setCampfireSharing", partyID: start.partyID, memberEpochID: start.memberEpochID)
        revoke.enabled = false; revoke.expectedRevision = 1
        try outbox.enqueue(revoke, owner: owner)
        let restored = SharedPastureOutboxService(directory: dir)
        try restored.enqueue(start, owner: owner)
        XCTAssertEqual(try restored.commands(owner: owner), [revoke])
    }
    func testWireHasNoPrivateTaskTextAndWindDownEndsAtWake() throws {
        var command = SharedPastureCommand(command: "publishCampfireSession", partyID: UUID(), memberEpochID: UUID())
        command.activity = .reading
        let wire = String(decoding: try JSONEncoder().encode(command), as: UTF8.self)
        XCTAssertFalse(wire.contains("cueText")); XCTAssertFalse(wire.contains("routine"))
        let plan = NightWatchPlan(intendedBedtime: now.addingTimeInterval(1800), wakeTime: now.addingTimeInterval(8*3600), protectedUntil: now.addingTimeInterval(9*3600), windDownMinutes: 30, morningQuietMinutes: 60, eveningActivity: .read, morningActivity: .openCurtains)
        var run = FocusRun(plannedDurationSeconds: 9*3600, startedAt: now, nightWatchPlan: plan)
        XCTAssertEqual(CampfireRules.end(for: run), plan.wakeTime)
        run.isPractice = true
        XCTAssertNil(CampfireRules.end(for: run))
    }
}
