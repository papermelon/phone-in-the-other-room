import XCTest

final class SlumberPartySharedFarmTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 100_000)
    private func fixture() -> NightFlockV4PartyDetail {
        let partyID = UUID(), me = UUID(), friend = UUID()
        return .init(summary: .init(partyID: partyID, name: "Meadow", memberCount: 2, myRole: .host,
            currentRound: nil, revision: 1, sharingScope: .membership), myMemberID: me,
            memberships: [.init(memberID: me, profile: .init(displayName: "Clover"), role: .host, joinedAt: now.addingTimeInterval(-100)),
                .init(memberID: friend, profile: .init(displayName: "Moss"), role: .member, joinedAt: now.addingTimeInterval(-50))])
    }
    private func update(_ party: NightFlockV4PartyDetail, id: UUID = UUID(), date: Date? = nil) -> NightFlockV4SharedActivity {
        .init(activityID: id, partyID: party.summary.partyID, memberID: party.memberships[1].id,
            kind: .windDown, status: .completed, roundedMinutes: 30, occurredAt: date ?? now)
    }
    func testLatestUsesDateThenStableIDAndRejectsOtherMemberOrParty() {
        var p = fixture()
        let low = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let high = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        p.sharedActivities = [update(p, id: high), update(p, date: now.addingTimeInterval(-1)), update(p, id: low)]
        var unrelated = update(p); unrelated.partyID = UUID(); p.sharedActivities.append(unrelated)
        XCTAssertEqual(SlumberPartySharedFarmRules.updates(for: p.memberships[1].id, in: p).map(\.id).first, low)
        XCTAssertTrue(SlumberPartySharedFarmRules.updates(for: UUID(), in: p).isEmpty)
        XCTAssertTrue(SlumberPartySharedFarmRules.updates(for: p.myMemberID!, in: p).isEmpty)
    }
    func testRoundMirrorIsDeduplicatedAndPreJoinRecordExcluded() {
        var p = fixture(); let roundID = UUID(); let legacyID = UUID()
        var shared = update(p); shared.roundActivityID = legacyID
        p.sharedActivities = [shared, update(p, date: now.addingTimeInterval(-60))]
        p.activities = [.init(activityID: legacyID, partyID: p.summary.partyID, roundID: roundID,
            memberID: p.memberships[1].id, day: 1, kind: .windDown, status: .completed, roundedMinutes: 30, occurredAt: now)]
        XCTAssertEqual(SlumberPartySharedFarmRules.updates(for: p.memberships[1].id, in: p).map(\.id), [shared.id])
        p.summary.sharingScope = nil
        XCTAssertEqual(SlumberPartySharedFarmRules.updates(for: p.memberships[1].id, in: p).map(\.id), [legacyID])
    }
    func testDedicatedMemberProjectionKeepsUpdatesOutsideGlobalFeedReachable() {
        var p = fixture()
        let earlier = update(p, date: now.addingTimeInterval(-20))
        let newest = update(p)
        p.memberUpdates = [newest, earlier]
        p.sharedActivities = [newest]
        XCTAssertEqual(SlumberPartySharedFarmRules.updates(for: p.memberships[1].id, in: p).map(\.id), [newest.id, earlier.id])
    }

    func testPlacementSurvivesNameChangeAndInputReordering() {
        var p = fixture(); let ids = SlumberPartySharedFarmRules.members(in: p).map(\.id)
        p.memberships.reverse(); p.memberships[0].profile.displayName = "Another name"
        XCTAssertEqual(SlumberPartySharedFarmRules.members(in: p).map(\.id), ids)
    }
    func testLegacyAndUnknownAppearanceDecodesWithoutLosingOutfit() throws {
        var appearance = CountingSheepPublicPresentation.defaultValue
        appearance.shepherdOutfitID = "shepherd_moon_coat"
        let legacy = try JSONDecoder().decode(CountingSheepPublicPresentation.self, from: JSONEncoder().encode(appearance))
        XCTAssertNil(legacy.headShapeID)
        appearance.headShapeID = "future-shape"
        let future = try JSONDecoder().decode(CountingSheepPublicPresentation.self, from: JSONEncoder().encode(appearance))
        XCTAssertEqual(future.shepherdOutfitID, "shepherd_moon_coat")
        XCTAssertTrue(future.isAllowlisted())
        var mixed = future; mixed.hairStyleID = "future-hair"
        XCTAssertEqual(mixed.renderableAppearance.shepherdOutfitID, "shepherd_moon_coat")
        XCTAssertEqual(mixed.renderableAppearance.hairStyleID, CountingSheepPublicPresentation.defaultValue.hairStyleID)
    }
    func testHeadShapeComparisonIsCapabilityGated() {
        var local = CountingSheepUserProfile(displayName: "Clover", hasEstablishedDisplayName: true)
        let server = local
        local.presentation.headShapeID = "boxy"
        XCTAssertNil(NightFlockV4ProfileSyncRules.routinePlan(local: local, server: server, supportsSocialAvatar: true))
        XCTAssertNotNil(NightFlockV4ProfileSyncRules.routinePlan(local: local, server: server, supportsSocialAvatar: true, supportsHeadShape: true))
    }
    func testReceiptRoundTripAndParticipantDeduplication() throws {
        var p = fixture(); let activity = UUID()
        let receipt = SlumberPartyUpdateCheerReceipt(reactionID: UUID(), activityID: activity,
            senderMemberID: p.memberships[1].id, recipientMemberID: p.myMemberID!, cheer: .warmWave, acceptedAt: now)
        var duplicate = receipt; duplicate.reactionID = UUID()
        p.updateCheerReceiptVersion = 1; p.updateCheerReceipts = [receipt, duplicate]
        let decoded = try JSONDecoder().decode(NightFlockV4PartyDetail.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(SlumberPartySharedFarmRules.receipts(for: activity, in: decoded).count, 1)
        XCTAssertNil(decoded.updateCheerReceipts[0].receivedByAppAt)
        var ownUpdate = update(p, id: activity); ownUpdate.memberID = p.myMemberID!
        p.memberUpdates = [ownUpdate]
        XCTAssertEqual(SlumberPartySharedFarmRules.cheeredUpdatesForMe(in: p).map(\.id), [activity])
        p.myMemberID = UUID()
        XCTAssertTrue(SlumberPartySharedFarmRules.receipts(for: activity, in: p).isEmpty)
        p.myMemberID = receipt.recipientMemberID; p.memberships.removeLast()
        XCTAssertTrue(SlumberPartySharedFarmRules.receipts(for: activity, in: p).isEmpty)
    }
    func testQueueRecoveryRejectsAccountSwitchRejoinAndMissingTarget() throws {
        var p = fixture(); let a = update(p); p.sharedActivities = [a]
        let queued = SlumberPartyQueuedUpdateCheer(partyID: p.summary.partyID, activityID: a.id, membershipStream: true,
            senderMemberID: p.myMemberID!, senderJoinedAt: p.memberships[0].joinedAt,
            recipientMemberID: p.memberships[1].id, recipientJoinedAt: p.memberships[1].joinedAt, cheer: .moonGlow, createdAt: now)
        let restored = try JSONDecoder().decode(SlumberPartyQueuedUpdateCheer.self, from: JSONEncoder().encode(queued))
        XCTAssertTrue(restored.isEligible(in: p, now: now))
        XCTAssertEqual(restored.command, queued.command)
        p.myMemberID = UUID(); XCTAssertFalse(restored.isEligible(in: p, now: now))
        p.myMemberID = queued.senderMemberID
        p.memberships[1].joinedAt = now; XCTAssertFalse(restored.isEligible(in: p, now: now))
        p.memberships[1].joinedAt = queued.recipientJoinedAt; p.sharedActivities = []
        XCTAssertFalse(restored.isEligible(in: p, now: now))
    }
    func testDurableQueueDeduplicatesAndClearsWithAccountEpoch() async throws {
        let suite = "SlumberPartyQueueTests.\(UUID())"; let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let p = fixture(); let a = update(p)
        let record = SlumberPartyQueuedUpdateCheer(partyID: p.summary.partyID, activityID: a.id, membershipStream: true,
            senderMemberID: p.myMemberID!, senderJoinedAt: p.memberships[0].joinedAt,
            recipientMemberID: p.memberships[1].id, recipientJoinedAt: p.memberships[1].joinedAt, cheer: .pawPrint, createdAt: now)
        let outbox = NightFlockOutboxService(defaults: defaults)
        let first = await outbox.enqueueUpdateCheer(record, epoch: 0)
        let second = await outbox.enqueueUpdateCheer(record, epoch: 0)
        XCTAssertTrue(first && second)
        let reopened = NightFlockOutboxService(defaults: defaults)
        let rows = await reopened.updateCheers(); XCTAssertEqual(rows, [record])
        _ = await reopened.clear(epoch: 1)
        let late = await reopened.enqueueUpdateCheer(record, epoch: 0); XCTAssertFalse(late)
        let empty = await reopened.updateCheers(); XCTAssertTrue(empty.isEmpty)
    }
}
