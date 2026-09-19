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
    func testUnconfirmedAndFailedObservationsDoNotImplyLivePresence() {
        XCTAssertFalse(NightFlockV4PartyObservationState.notRequested.permitsLivePresence)
        XCTAssertFalse(NightFlockV4PartyObservationState.refreshing(lastReceivedAt: nil).permitsLivePresence)
        XCTAssertFalse(NightFlockV4PartyObservationState.stale(lastReceivedAt: now).permitsLivePresence)
        XCTAssertTrue(NightFlockV4PartyObservationState.current(lastReceivedAt: now).permitsLivePresence)
        XCTAssertTrue(NightFlockV4PartyObservationState.refreshing(lastReceivedAt: now).permitsLivePresence)
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
        XCTAssertEqual(Set(positions.map { "\($0.x):\($0.y)" }).count, 8)
        let id = UUID()
        let pasture = SharedPastureState(memberEpochID: UUID(), entities: [.init(id: "member-\(id)", kind: "shepherd", referenceID: id, revision: 8, x: 0.6, y: 0.7)], visits: [], lantern: .init(contributions: 5, requiredContributions: 12))
        XCTAssertTrue(SharedPastureRules.changedEntities(in: pasture.arrangement, from: pasture).isEmpty)
    }
    func testLiveParticipantsExcludeIdleMembersAndDisappearAtEnd() {
        let members = [NightFlockV4Membership(memberID: UUID(), profile: .init(displayName: "Active"), role: .host, joinedAt: now),
                       NightFlockV4Membership(memberID: UUID(), profile: .init(displayName: "Idle"), role: .member, joinedAt: now)]
        let active = session(member: members[0].memberID)
        let state = CampfireState(sessions: [active])
        let current = CampfireRules.currentSessions(state, members: Set(members.map(\.memberID)), isFresh: true, at: now)
        XCTAssertEqual(CampfireRules.participants(in: members, sessions: current).map(\.memberID), [active.memberID])
        let expired = CampfireRules.currentSessions(state, members: Set(members.map(\.memberID)), isFresh: true, at: active.expiresAt)
        XCTAssertTrue(CampfireRules.participants(in: members, sessions: expired).isEmpty)
        let unavailable = CampfireRules.currentSessions(state, members: Set(members.map(\.memberID)), isFresh: false, at: now)
        XCTAssertTrue(CampfireRules.participants(in: members, sessions: unavailable).isEmpty)
    }
    func testWindDownAndPhoneAwayShareTheFireRegardlessOfInputOrder() {
        let members = [NightFlockV4Membership(memberID: UUID(), profile: .init(displayName: "Wind Down"), role: .host, joinedAt: now),
                       NightFlockV4Membership(memberID: UUID(), profile: .init(displayName: "Phone Away"), role: .member, joinedAt: now)]
        var windDown = session(member: members[0].memberID)
        windDown.kind = .windDown; windDown.activity = nil
        let phoneAway = session(member: members[1].memberID)
        let memberIDs = Set(members.map(\.memberID))
        for rows in [[windDown, phoneAway], [phoneAway, windDown]] {
            let current = CampfireRules.currentSessions(.init(sessions: rows), members: memberIDs, isFresh: true, at: now)
            XCTAssertEqual(Set(current.map(\.kind)), [.windDown, .phoneAway])
            XCTAssertEqual(Set(CampfireRules.participants(in: members, sessions: current).map(\.memberID)), memberIDs)
        }
        var ended = phoneAway; ended.ended = true; ended.revision = 2
        let remaining = CampfireRules.currentSessions(.init(sessions: [windDown, phoneAway, ended]), members: memberIDs, isFresh: true, at: now)
        XCTAssertEqual(remaining, [windDown])
    }

    func testPhoneAwayValidityUsesItsOwnPlannedEnd() {
        let plan = NightWatchPlan.additionalQuiet(start: now, end: now.addingTimeInterval(1800), cueText: "Private task")
        let run = FocusRun(plannedDurationSeconds: 1800, startedAt: now, nightWatchPlan: plan)
        XCTAssertEqual(CampfireRules.end(for: run), now.addingTimeInterval(1800))
    }
    func testParticipantFramesDoNotOverlapFromOneThroughEight() {
        for count in 1...8 {
            let width = count > 4 ? 680.0 : 320.0
            let height = count > 4 ? 360.0 : 280.0
            let size = (3...4).contains(count) ? 64.0 : 82.0
            let points = (0..<count).map { CampfireRules.seat(index: $0, count: count) }
            for a in 0..<count {
                for b in (a+1)..<count {
                    let dx = abs(points[a].x-points[b].x)*width
                    let dy = abs(points[a].y-points[b].y)*height
                    XCTAssertTrue(dx >= size || dy >= size+26, "Overlapping participants at count \(count)")
                }
            }
        }
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
