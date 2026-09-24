import XCTest

final class CampfireTests: XCTestCase {

    func testRefreshingKeepsOnlyCurrentlyAuthorizedPresence() {
        XCTAssertEqual(CampfireScenePhase.resolve(hasCurrentSnapshot: true, isRefreshing: true, hasPeople: true), .refreshing)
        XCTAssertTrue(CampfireScenePhase.refreshing.showsPeople)
        for refreshing in [false, true] {
            let stale = CampfireScenePhase.resolve(hasCurrentSnapshot: false, isRefreshing: refreshing, hasPeople: true)
            XCTAssertFalse(stale.showsPeople)
            XCTAssertEqual(stale.isUpdating, refreshing)
        }
        XCTAssertEqual(CampfireScenePhase.resolve(hasCurrentSnapshot: true, isRefreshing: false, hasPeople: false), .empty)
        XCTAssertEqual(CampfireScenePhase.resolve(hasCurrentSnapshot: true, isRefreshing: false, hasPeople: true), .populated)
    }
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

extension CampfireTests {
    func bedtimeSession() -> CampfireSession {
        var row = session()
        row.kind = .windDown; row.activity = nil; row.intendedBedtime = now
        return row
    }

    func testFrozenBedtimeBoundaryAndTerminalPrecedence() {
        var row = bedtimeSession()
        XCTAssertEqual(row.pose(at: now.addingTimeInterval(-0.001)), .awake)
        XCTAssertEqual(row.pose(at: now), .bedtime)
        XCTAssertEqual(row.pose(at: now.addingTimeInterval(1)), .bedtime)
        XCTAssertEqual(row.pose(at: row.expiresAt), .awake)
        row.ended = true; row.revision = 2
        XCTAssertEqual(row.pose(at: now), .awake)
        XCTAssertTrue(CampfireRules.currentSessions(.init(sessions: [row]), members: [row.memberID], isFresh: true, at: now).isEmpty)
    }

    func testLateStartAndLateSharingUseOriginalBedtime() {
        var row = bedtimeSession()
        row.startedAt = now; row.observedAt = now
        row.intendedBedtime = now.addingTimeInterval(-3600)
        XCTAssertEqual(row.pose(at: now), .bedtime)
        XCTAssertEqual(row.pose(at: now.addingTimeInterval(-1)), .awake)
        row.intendedBedtime = row.expiresAt
        XCTAssertEqual(row.pose(at: row.expiresAt), .awake)
    }

    func testPhoneAwayAndMissingOrInvalidMetadataStayAwake() {
        var row = bedtimeSession()
        for activity in CampfireActivity.allCases {
            row.kind = .phoneAway; row.activity = activity
            XCTAssertEqual(row.pose(at: now), .awake)
        }
        row.kind = .windDown; row.activity = nil
        for bedtime in [nil, row.expiresAt.addingTimeInterval(1), Date(timeIntervalSince1970: .infinity)] {
            row.intendedBedtime = bedtime
            XCTAssertEqual(row.pose(at: now), .awake)
        }
    }

    func testLegacyAndMalformedOptionalBedtimeDoNotBreakPartyDecoding() throws {
        let row = bedtimeSession()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(row)) as? [String: Any])
        for value in [nil, NSNull(), "not-a-date"] as [Any?] {
            object["intendedBedtime"] = value
            let data = try JSONSerialization.data(withJSONObject: object)
            let decoded = try JSONDecoder().decode(CampfireSession.self, from: data)
            XCTAssertNil(decoded.intendedBedtime)
            XCTAssertEqual(decoded.pose(at: now), .awake)
        }
        let legacy = try JSONDecoder().decode(CampfireState.self, from: Data(#"{"version":1,"sessions":[]}"#.utf8))
        XCTAssertFalse(legacy.supportsIntendedBedtime)
        XCTAssertEqual(try JSONDecoder().decode(CampfireSession.self, from: JSONEncoder().encode(row)), row)
        object.removeValue(forKey: "memberID")
        XCTAssertThrowsError(try JSONDecoder().decode(CampfireSession.self, from: JSONSerialization.data(withJSONObject: object)))
    }

    func testClockDatesAreSortedUniqueAndRetainFutureStartAndExpiry() {
        var row = bedtimeSession()
        row.startedAt = now.addingTimeInterval(10); row.observedAt = row.startedAt
        row.intendedBedtime = now.addingTimeInterval(20)
        let state = CampfireState(sessions: [row, row])
        XCTAssertEqual(CampfireRules.displayInvalidationDates(in: state, at: now), [row.startedAt, row.intendedBedtime!, row.expiresAt].map { $0.addingTimeInterval(0.001) })
        XCTAssertEqual(CampfireRules.displayInvalidationDates(in: state, at: row.intendedBedtime!), [row.expiresAt.addingTimeInterval(0.001)])
        XCTAssertTrue(CampfireRules.displayInvalidationDates(in: state, at: row.expiresAt).isEmpty)
        for tick in CampfireRules.displayInvalidationDates(in: state, at: now) {
            // Even if the framework rounds down by less than a millisecond, the
            // delivered tick remains on the far side of its semantic boundary.
            let delivered = tick.addingTimeInterval(-0.0005)
            if delivered > row.expiresAt { XCTAssertFalse(row.isCurrent(at: delivered)) }
            else if delivered > row.intendedBedtime! { XCTAssertEqual(row.pose(at: delivered), .bedtime) }
        }
        var ended = row; ended.ended = true; ended.revision = 2
        XCTAssertTrue(CampfireRules.displayInvalidationDates(in: .init(sessions: [ended]), at: now).isEmpty)
        XCTAssertTrue(CampfireRules.displayInvalidationDates(in: .init(version: 2, sessions: [row]), at: now).isEmpty)
        let buddy = CampfireBuddySession(sourceID: row.id, memberID: row.memberID, publicIntention: "", asksForBuddy: false,
            encouragementMemberIDs: [], checkInRequested: false, startedAt: row.startedAt, expiresAt: row.expiresAt,
            checkInAfter: row.expiresAt.addingTimeInterval(3600), ended: false, kind: .windDown)
        let dates = CampfireRules.displayInvalidationDates(in: .init(sessions: [row], buddies: .init(version: 1, startAlerts: false, sessions: [buddy])), at: now)
        XCTAssertTrue(dates.contains(buddy.checkInAfter.addingTimeInterval(0.001)))
    }

    func testPublicationUsesAdmittedPlanNotChangedSettingsOrSharingStart() throws {
        var schedule = NightWatchPlan(intendedBedtime: now, wakeTime: now.addingTimeInterval(8 * 3600),
            protectedUntil: now.addingTimeInterval(9 * 3600), windDownMinutes: 30, morningQuietMinutes: 60,
            eveningActivity: .read, morningActivity: .openCurtains)
        let run = FocusRun(plannedDurationSeconds: 9 * 3600, startedAt: now.addingTimeInterval(60), nightWatchPlan: schedule)
        schedule.intendedBedtime = now.addingTimeInterval(3600)
        XCTAssertEqual(CampfireRules.intendedBedtime(for: run, supported: true), now)
        XCTAssertNil(CampfireRules.intendedBedtime(for: run, supported: false))
        var privateRun = run; privateRun.isPractice = true
        XCTAssertNil(CampfireRules.intendedBedtime(for: privateRun, supported: true))
        privateRun.isPractice = false; privateRun.nightWatchPlan?.role = .additionalQuiet
        XCTAssertNil(CampfireRules.intendedBedtime(for: privateRun, supported: true))
        let restored = try JSONDecoder().decode(FocusRun.self, from: JSONEncoder().encode(run))
        XCTAssertEqual(CampfireRules.intendedBedtime(for: restored, supported: true), now)
    }

    func testBedtimeUsesAbsoluteInstantAcrossDSTAndMidnight() throws {
        let formatter = ISO8601DateFormatter()
        var row = bedtimeSession()
        row.intendedBedtime = try XCTUnwrap(formatter.date(from: "2026-11-01T01:30:00-04:00"))
        row.startedAt = row.intendedBedtime!.addingTimeInterval(-7200); row.observedAt = row.startedAt
        row.expiresAt = row.intendedBedtime!.addingTimeInterval(8 * 3600)
        XCTAssertEqual(row.pose(at: try XCTUnwrap(formatter.date(from: "2026-11-01T05:30:00Z"))), .bedtime)
        XCTAssertEqual(row.pose(at: try XCTUnwrap(formatter.date(from: "2026-11-01T13:30:00+08:00"))), .bedtime)
    }

    @MainActor func testBedtimeOutboxReplayNeverEnrichesQueuedLegacyStart() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let outbox = SharedPastureOutboxService(directory: dir), owner = UUID()
        var start = SharedPastureCommand(command: "publishCampfireSession", partyID: UUID(), memberEpochID: UUID())
        start.sourceID = UUID(); start.revision = 1; start.ended = false
        try outbox.enqueue(start, owner: owner)
        var enriched = start; enriched.intendedBedtime = now
        try outbox.enqueue(enriched, owner: owner)
        XCTAssertNil(try outbox.commands(owner: owner).first?.intendedBedtime)
        var end = enriched; end.revision = 2; end.ended = true; end.idempotencyKey = "end"
        try outbox.enqueue(end, owner: owner)
        let restored = SharedPastureOutboxService(directory: dir)
        XCTAssertEqual(try restored.commands(owner: owner), [end])
        try restored.enqueue(start, owner: owner)
        XCTAssertEqual(try restored.commands(owner: owner), [end])
        let wire = try XCTUnwrap(String(data: JSONEncoder().encode(end), encoding: .utf8))
        XCTAssertTrue(wire.contains("intendedBedtime"))
        XCTAssertFalse(wire.contains("cueText"))
    }
}


extension CampfireTests {
    func testExplicitTimelineIncludesNowAndAnEntryBeyondFinalExpiry() {
        let row = bedtimeSession()
        var party = NightFlockV4PartyDetail(summary: .init(partyID: UUID(), name: "Test", memberCount: 0,
            myRole: .host, currentRound: nil, revision: 1), memberships: [])
        party.pasture = .init(memberEpochID: UUID(), entities: [], visits: [],
            lantern: .init(contributions: 0, requiredContributions: 12), campfire: .init(sessions: [row]))
        let dates = NightFlockV4Presentation.timelineDates(in: party, at: now)
        XCTAssertEqual(dates.first, now)
        XCTAssertEqual(dates, [now, row.expiresAt.addingTimeInterval(0.001), row.expiresAt.addingTimeInterval(1.001)])
        XCTAssertEqual(NightFlockV4Presentation.timelineDates(in: party, at: row.expiresAt), [row.expiresAt])
        XCTAssertEqual(NightFlockV4Presentation.timelineDates(in: nil, at: now), [now])
    }
}

extension CampfireTests {
    func testCampfirePlanDisplayKeepsCompleteUnicodeTextAndRejectsBlankPlans() {
        XCTAssertNil(CampfirePlanText.normalized(nil))
        XCTAssertNil(CampfirePlanText.normalized(" \n\t"))
        XCTAssertEqual(CampfirePlanText.normalized("  Read\n one   chapter  "), "Read one chapter")
        let longPlan = String(repeating: "👩🏽‍💻 café 阅读 العربية ", count: 100).trimmingCharacters(in: .whitespaces)
        XCTAssertEqual(CampfirePlanText.normalized(longPlan), longPlan)
    }

    func testComposedSeatsReserveSpaceForBubblesAndFireOnSmallPhone() {
        // 320-point phone minus the panel's two 16-point insets.
        let width = 288.0, height = 800.0, bubbleWidth = width * 0.4, personHeight = 146.0
        let points = CampfireSeating.anchors.map { PastureScenePoint(x: $0.x * width, y: $0.y * height) }
        for (index, point) in points.enumerated() {
            XCTAssertGreaterThanOrEqual(point.x - bubbleWidth / 2, 0)
            XCTAssertLessThanOrEqual(point.x + bubbleWidth / 2, width)
            XCTAssertGreaterThanOrEqual(point.y - personHeight / 2, 60)
            XCTAssertLessThanOrEqual(point.y + personHeight / 2, height)
            for other in points.dropFirst(index + 1) {
                XCTAssertTrue(abs(point.x - other.x) >= bubbleWidth || abs(point.y - other.y) >= personHeight)
            }
            XCTAssertTrue(abs(point.x - width / 2) >= bubbleWidth / 2 + 42 || abs(point.y - height * 0.345) >= personHeight / 2 + 42)
        }
    }

    func testCampfireSeatsStayStableAndSwapWithoutOverlap() {
        let ids = (0..<8).map { _ in UUID() }
        var seating = CampfireSeating()
        seating.reconcile(Array(ids.prefix(3)))
        let initial = seating.slots
        seating.reconcile(Array(ids.reversed()))
        for id in ids.prefix(3) { XCTAssertEqual(seating.slots[id], initial[id]) }
        XCTAssertEqual(Set(seating.slots.values).count, 8)
        let first = seating.position(ids[0]), second = seating.position(ids[1])
        seating.move(ids[0], to: second)
        XCTAssertEqual(seating.position(ids[0]), second)
        XCTAssertEqual(seating.position(ids[1]), first)
        let snapshot = seating.slots
        seating.move(ids[0], to: .init(x: .nan, y: 0))
        XCTAssertEqual(seating.slots, snapshot)
        seating.reconcile(Array(ids.dropFirst()))
        XCTAssertNil(seating.slots[ids[0]])
        for id in ids.dropFirst() { XCTAssertEqual(seating.slots[id], snapshot[id]) }
        XCTAssertTrue(seating.slots.values.allSatisfy {
            let point = CampfireSeating.point(for: $0)
            return (0.22...0.78).contains(point.x) && (0.14...0.92).contains(point.y)
                && point.distance(to: .init(x: 0.5, y: 0.345)) > 0.22
        })
    }

    func testGlobalAvailabilityDistinguishesMissingServiceFromConnectionAndAuthentication() {
        XCTAssertEqual(GlobalCampfireIssue.forHTTPStatus(404), .unavailable)
        XCTAssertEqual(GlobalCampfireIssue.forHTTPStatus(401), .signIn)
        XCTAssertEqual(GlobalCampfireIssue.forHTTPStatus(403), .signIn)
        XCTAssertEqual(GlobalCampfireIssue.forHTTPStatus(503), .connection)
        XCTAssertEqual(GlobalCampfireIssue.forHTTPStatus(0), .connection)
        XCTAssertFalse(GlobalCampfireIssue.unavailable.permitsAutomaticRetry)
        XCTAssertTrue(GlobalCampfireIssue.connection.permitsAutomaticRetry)
    }
}
