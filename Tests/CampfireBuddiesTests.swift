import XCTest

final class CampfireBuddiesTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func session(kind: NightFlockV4ActivityKind = .phoneAway) -> CampfireBuddySession {
        .init(sourceID: UUID(), memberID: UUID(), publicIntention: "Read one chapter", asksForBuddy: true,
              encouragementMemberIDs: [], checkInRequested: false, startedAt: now.addingTimeInterval(-1800),
              expiresAt: now.addingTimeInterval(1800), checkInAfter: now.addingTimeInterval(3600), ended: false, kind: kind)
    }
    func testParticipationCueFollowsTheSharedBuddyRequest() {
        var value = session()
        XCTAssertEqual(value.participationCue, "Buddy welcome")
        value.buddyMemberID = UUID()
        XCTAssertEqual(value.participationCue, "Buddy paired")
        value.buddyMemberID = nil; value.asksForBuddy = false
        XCTAssertNil(value.participationCue)
    }
    func testVersionTwoAgreementIsExplicitAndOlderStateRemainsReadable() throws {
        XCTAssertTrue(CampfireAgreement(id: UUID(), version: 2, revision: 1, enabled: true, acceptedAt: now).permitsSharing)
        XCTAssertFalse(CampfireAgreement(id: UUID(), version: 3, revision: 1, enabled: true, acceptedAt: now).permitsSharing)
        let old = try JSONDecoder().decode(CampfireState.self, from: Data(#"{"version":1,"sessions":[]}"#.utf8))
        XCTAssertNil(old.buddies)
        XCTAssertTrue(old.isSupported)
    }
    func testUnknownBuddiesSchemaDoesNotBreakLegacyPresence() throws {
        let state = try JSONDecoder().decode(CampfireState.self, from: Data(#"{"version":1,"sessions":[],"buddies":{"version":8,"sessions":{"future":true}}}"#.utf8))
        XCTAssertTrue(state.isSupported)
        XCTAssertFalse(state.buddies?.isSupported ?? true)
    }
    func testPlanPersistsOnlyExplicitPartyIntentionsAndLegacyPlansStayPrivate() throws {
        var plan = NightWatchPlan.additionalQuiet(start: now, end: now.addingTimeInterval(1800), cueText: "Private task")
        let old = try JSONDecoder().decode(NightWatchPlan.self, from: JSONEncoder().encode(plan))
        XCTAssertNil(old.campfireIntentions)
        XCTAssertNil(old.campfirePartyIDs)
        let party = UUID(), agreement = UUID()
        plan.campfirePartyIDs = [party]
        plan.campfireIntentions = [.init(partyID: party, agreementID: agreement, text: "Read a chapter", announceStart: true, asksForBuddy: true)]
        let restored = try JSONDecoder().decode(NightWatchPlan.self, from: JSONEncoder().encode(plan))
        XCTAssertEqual(restored, plan)
        XCTAssertEqual(restored.campfireIntentions?.first?.text, "Read a chapter")
    }
    func testPublicTextIsBoundedAndCollapsesLineBreaks() {
        XCTAssertEqual(CampfireBuddiesRules.publicText("  Read\n one\t chapter  "), "Read one chapter")
        XCTAssertEqual(CampfireBuddiesRules.publicText(String(repeating: "a", count: 90)).count, 80)
        XCTAssertEqual(CampfireBuddiesRules.publicText("one\u{0000}two"), "onetwo")
    }
    func testPhoneAwayEarlyReturnCanReflectButActiveTimerCannot() {
        var value = session()
        XCTAssertFalse(value.mayReflect(at: now))
        value.ended = true
        XCTAssertTrue(value.mayReflect(at: now))
    }
    func testWindDownWaitsForMorningQuietEvenAfterEarlyEnd() {
        var value = session(kind: .windDown); value.ended = true
        XCTAssertFalse(value.mayReflect(at: now))
        XCTAssertFalse(value.mayReflect(at: value.expiresAt))
        XCTAssertTrue(value.mayReflect(at: value.checkInAfter))
    }
    func testSupportDoesNotCreatePresenceOrAllowSelfBuddy() {
        let value = session(), me = UUID()
        XCTAssertFalse(CampfireBuddiesRules.canAccept(value, me: value.memberID, active: true))
        XCTAssertFalse(CampfireBuddiesRules.canAccept(value, me: me, active: false))
        XCTAssertTrue(CampfireBuddiesRules.canAccept(value, me: me, active: true))
        XCTAssertFalse(CampfireBuddiesRules.canAccept(value, me: nil, active: true))
        var accepted = value; accepted.buddyMemberID = me
        XCTAssertFalse(CampfireBuddiesRules.canAccept(accepted, me: UUID(), active: true))
    }
    func testRetentionMembershipAndUnknownCapabilityHideDetails() {
        let value = session()
        let state = CampfireBuddiesState(version: 1, startAlerts: true, sessions: [value])
        XCTAssertEqual(CampfireBuddiesRules.visible(state, members: [value.memberID], now: now).count, 1)
        XCTAssertTrue(CampfireBuddiesRules.visible(state, members: [], now: now).isEmpty)
        XCTAssertTrue(CampfireBuddiesRules.visible(state, members: [value.memberID], now: now.addingTimeInterval(7 * 86400)).isEmpty)
        XCTAssertFalse(value.mayReflect(at: now.addingTimeInterval(7 * 86400)))
        var future = state; future.version = 2
        XCTAssertTrue(CampfireBuddiesRules.visible(future, members: [value.memberID], now: now).isEmpty)
    }
    @MainActor
    func testWithdrawalRemovesQueuedSupportAsWellAsStarts() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let outbox = SharedPastureOutboxService(directory: directory)
        let owner = UUID(), party = UUID(), epoch = UUID()
        var support = SharedPastureCommand(command: "campfireBuddyAction", partyID: party, memberEpochID: epoch)
        support.buddyAction = "encourage"
        try outbox.enqueue(support, owner: owner)
        var withdrawal = SharedPastureCommand(command: "setCampfireSharing", partyID: party, memberEpochID: epoch)
        withdrawal.enabled = false
        try outbox.enqueue(withdrawal, owner: owner)
        XCTAssertEqual(try outbox.commands(owner: owner).map(\.command), ["setCampfireSharing"])
    }
}
