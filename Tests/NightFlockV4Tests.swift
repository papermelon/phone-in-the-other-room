import XCTest

final class NightFlockV4Tests: XCTestCase {
    private let utc = "UTC"

    func testRoundBoundariesAndLateJoinCurrentWindow() throws {
        let round = NightFlockV4Round(roundID: UUID(), number: 1, timeZoneIdentifier: utc, startsOn: NightFlockLocalDate(year: 2026, month: 8, day: 20), status: .active)
        let dayOne = try XCTUnwrap(round.startsOn.date(in: utc, calendar: .init(identifier: .gregorian)))
        XCTAssertEqual(NightFlockV4RoundRules.day(at: dayOne, round: round), 1)
        XCTAssertEqual(NightFlockV4RoundRules.day(at: dayOne.addingTimeInterval(6 * 86_400), round: round), 7)
        XCTAssertNil(NightFlockV4RoundRules.day(at: dayOne.addingTimeInterval(7 * 86_400), round: round))
        let member = NightFlockV4Membership(memberID: UUID(), profile: .init(displayName: "Clover"), role: .member, joinedAt: dayOne.addingTimeInterval(3 * 86_400))
        XCTAssertTrue(NightFlockV4RoundRules.canParticipate(member, in: round, at: dayOne.addingTimeInterval(4 * 86_400)))
        XCTAssertFalse(NightFlockV4RoundRules.canParticipate(member, in: round, at: dayOne.addingTimeInterval(2 * 86_400)))
    }

    func testPartyCapAndServerFanOutAcceptanceFactAreCentralized() {
        XCTAssertEqual(NightFlockV4Rules.maximumConcurrentParties, 5)
        XCTAssertEqual(NightFlockV4Rules.maximumSourceFanOut, 5)
        XCTAssertEqual(NightFlockV4Rules.minimumMembers, 2)
        XCTAssertEqual(NightFlockV4Rules.maximumMembers, 8)
    }

    func testStateRequestsUseExactScopePartyIDAndCursorFields() throws {
        let list = try object(NightFlockV4ListStateRequest())
        XCTAssertEqual(list["schemaVersion"] as? Int, 4); XCTAssertEqual(list["scope"] as? String, "list")
        XCTAssertNil(list["request"]); XCTAssertNil(list["partyID"])
        let partyID = UUID(); let detail = try object(NightFlockV4PartyStateRequest(partyID: partyID, cursor: "next"))
        XCTAssertEqual(detail["scope"] as? String, "party")
        XCTAssertEqual(detail["partyID"] as? String, partyID.uuidString.uppercased())
        XCTAssertEqual(detail["cursor"] as? String, "next")
        XCTAssertNil(detail["activityCursor"])
    }

    func testCommandsUseExactProfileActivityStatusAndBackfillFields() throws {
        let partyID = UUID(); let sourceID = UUID(); let now = Date(timeIntervalSince1970: 100)
        let source = NightFlockV4SourceActivityRecord(sourceEventID: sourceID, kind: .windDown, outcome: .completed, startedAt: now, endedAt: now.addingTimeInterval(60), windDownMinutes: 45, phoneAwayMinutes: 0, statusRevision: 3)
        let record = NightFlockV4OutboxSourceRecord(source: source, origin: .live, idempotencyKey: "publish")
        let activity = try object(NightFlockV4CommandRequest(command: .publishActivity(record)))
        XCTAssertEqual(activity["command"] as? String, "publishActivity")
        XCTAssertEqual(activity["sourceEventID"] as? String, sourceID.uuidString.uppercased())
        XCTAssertEqual(activity["outcome"] as? String, "completed"); XCTAssertEqual(activity["windDownMinutes"] as? Int, 45); XCTAssertEqual(activity["statusRevision"] as? Int, 3)
        XCTAssertNil(activity["partyID"]); XCTAssertNil(activity["roundID"]); XCTAssertNil(activity["sourceActivityID"])

        let profile = try object(NightFlockV4CommandRequest(command: .updatePublicProfile(expectedRevision: 4, nameSelectionKind: .change, displayName: "Moss", presentation: .defaultValue, idempotencyKey: "profile")))
        XCTAssertEqual(profile["nameSelectionKind"] as? String, "change")
        for key in ["skinToneID", "hairStyleID", "shepherdOutfitID", "shepherdAccessoryID", "ollieOrnamentID", "featuredSheepDefinitionID", "pastureThemeID"] { XCTAssertNotNil(profile[key]) }
        XCTAssertNil(profile["presentation"])

        let start = try object(NightFlockV4CommandRequest(command: .startRound(partyID: partyID, timeZoneIdentifier: "UTC", idempotencyKey: "start")))
        XCTAssertEqual(start["timeZoneIdentifier"] as? String, "UTC")
        let status = try object(NightFlockV4CommandRequest(command: .publishStatus(sourceEventID: sourceID, status: .windDownStarting, revision: 2, observedAt: now, idempotencyKey: "status")))
        XCTAssertEqual(status["status"] as? String, "windDownStarting"); XCTAssertEqual(status["revision"] as? Int, 2); XCTAssertNotNil(status["observedAt"])
        let backfill = try object(NightFlockV4CommandRequest(command: .completeBackfill(partyID: partyID, roundID: UUID(), cursor: "cursor-1", idempotencyKey: "backfill")))
        XCTAssertEqual(backfill["cursor"] as? String, "cursor-1"); XCTAssertNil(backfill["sourceActivityIDs"])
        let safety = try object(NightFlockV4CommandRequest(command: .blockMember(partyID: partyID, memberID: sourceID, idempotencyKey: "block")))
        XCTAssertEqual(safety["command"] as? String, "blockMember")
        XCTAssertEqual(safety["memberID"] as? String, sourceID.uuidString.uppercased())
        let activeCheer = try object(NightFlockV4CommandRequest(command: .cheerMember(partyID: partyID, memberID: sourceID, cheer: .moonGlow, idempotencyKey: "cheer")))
        XCTAssertEqual(activeCheer["command"] as? String, "cheerMember")
        XCTAssertEqual(activeCheer["cheer"] as? String, "moonGlow")
    }

    func testLiveStatusOrdersRevisionAndExpires() {
        let partyID = UUID(); let roundID = UUID(); let memberID = UUID(); let now = Date(timeIntervalSince1970: 10_000)
        let current = NightFlockV4LiveStatus(partyID: partyID, roundID: roundID, memberID: memberID, status: .windDownCompleted, revision: 3, observedAt: now, expiresAt: now.addingTimeInterval(60))
        let older = NightFlockV4LiveStatus(partyID: partyID, roundID: roundID, memberID: memberID, status: .windDownStarting, revision: 2, observedAt: now, expiresAt: now.addingTimeInterval(90))
        XCTAssertEqual(NightFlockV4LiveStatusRules.merge(older, into: [current], now: now), [current])
        XCTAssertTrue(NightFlockV4LiveStatusRules.merge(current, into: [current], now: now.addingTimeInterval(61)).isEmpty)
    }

    func testLiveAndBackfillConvergeToOneServerFannedSourceEvent() {
        let now = Date(timeIntervalSince1970: 5)
        let source = NightFlockV4SourceActivityRecord(sourceEventID: UUID(), kind: .phoneAway, outcome: .completed, startedAt: now, endedAt: now.addingTimeInterval(100), windDownMinutes: 0, phoneAwayMinutes: 100, statusRevision: 1)
        let live = NightFlockV4OutboxSourceRecord(source: source, origin: .live, idempotencyKey: "live")
        let updated = NightFlockV4SourceActivityRecord(sourceEventID: source.sourceEventID, kind: .phoneAway, outcome: .completed, startedAt: now, endedAt: now.addingTimeInterval(120), windDownMinutes: 0, phoneAwayMinutes: 100, statusRevision: 2)
        let backfill = NightFlockV4OutboxSourceRecord(source: updated, origin: .backfill, idempotencyKey: "backfill")
        let merged = NightFlockV4OutboxRules.merge(backfill, into: [live])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].source.statusRevision, 2)
        XCTAssertNil(Mirror(reflecting: merged[0]).children.first { $0.label == "publications" })
    }

    func testStateSnapshotDecodesListGrantInboxAndNestedPublicProfile() throws {
        let partyID = UUID()
        let roundID = UUID()
        let grantID = UUID()
        let json = """
        {
          "parties": [{
            "partyID": "\(partyID.uuidString)", "name": "Moonfield", "memberCount": 2,
            "myRole": "host", "revision": 3,
            "currentRound": { "roundID": "\(roundID.uuidString)", "number": 1,
              "timeZoneIdentifier": "UTC", "startsOn": "2026-08-25", "status": "active" }
          }],
          "profile": { "displayName": "Moss", "revision": 2,
            "presentation": { "skinToneID": "warm", "hairStyleID": "waves",
              "shepherdOutfitID": "none", "shepherdAccessoryID": "none",
              "ollieOrnamentID": "none", "featuredSheepDefinitionID": "none", "pastureThemeID": "pasture_meadow" } },
          "grantInbox": [{ "grantID": "\(grantID.uuidString)", "partyID": "\(partyID.uuidString)",
            "roundID": "\(roundID.uuidString)", "kind": "wool", "woolAmount": 1,
            "issuedAt": "2026-08-25T00:00:00Z", "acknowledgedAt": null }]
        }
        """
        let result = try JSONDecoder.nightFlockISO8601.decode(
            NightFlockV4ListStateResponse.self,
            from: try XCTUnwrap(json.data(using: .utf8))
        )
        XCTAssertEqual(result.schemaVersion, 4)
        XCTAssertEqual(result.parties.first?.partyID, partyID)
        XCTAssertEqual(result.profile?.displayName, "Moss")
        XCTAssertEqual(result.grantInbox.map(\.grantID), [grantID])
    }

    func testStateEnvelopeKeepsRequestIDOutsideSnapshot() throws {
        let requestID = UUID().uuidString.lowercased()
        let envelope = try JSONDecoder.nightFlockISO8601.decode(
            NightFlockV4StateEnvelope<NightFlockV4ListStateResponse>.self,
            from: try XCTUnwrap("""
            { "schemaVersion": 4, "requestID": "\(requestID)",
              "snapshot": { "parties": [], "grantInbox": [] } }
            """.data(using: .utf8))
        )
        XCTAssertEqual(envelope.schemaVersion, 4)
        XCTAssertEqual(envelope.requestID, requestID)
        XCTAssertTrue(envelope.snapshot.parties.isEmpty)
    }

    func testPartyStateEnvelopeDecodesSnapshotWithoutNestedSchemaVersion() throws {
        let partyID = UUID()
        let memberID = UUID()
        let envelope = try JSONDecoder.nightFlockISO8601.decode(
            NightFlockV4StateEnvelope<NightFlockV4PartyStateResponse>.self,
            from: try XCTUnwrap("""
            { "schemaVersion": 4, "requestID": "support-only",
              "snapshot": { "party": {
                "summary": { "partyID": "\(partyID)", "name": "Moonfield", "memberCount": 1,
                  "myRole": "host", "revision": 1, "currentRound": null },
                "myMemberID": "\(memberID)", "memberships": [], "activities": [],
                "liveStatuses": [], "cheers": [], "grantInbox": []
              } } }
            """.data(using: .utf8))
        )
        XCTAssertEqual(envelope.snapshot.schemaVersion, 4)
        XCTAssertEqual(envelope.snapshot.party?.summary.partyID, partyID)
        XCTAssertEqual(envelope.snapshot.party?.myMemberID, memberID)
    }

    func testStatusOutboxConvergesToLatestRevisionForSource() {
        let sourceID = UUID()
        let now = Date(timeIntervalSince1970: 20)
        let first = NightFlockV4StatusOutboxRecord(
            sourceEventID: sourceID, status: .windDownStarting, revision: 1,
            observedAt: now, idempotencyKey: "first"
        )
        let latest = NightFlockV4StatusOutboxRecord(
            sourceEventID: sourceID, status: .windDownCompleted, revision: 2,
            observedAt: now.addingTimeInterval(60), idempotencyKey: "latest"
        )
        let merged = NightFlockV4StatusOutboxRules.merge(latest, into: [first])
        XCTAssertEqual(merged, [latest])
    }

    func testV4GrantAdapterPreservesServerGrantIDForExistingLedger() {
        let grantID = UUID()
        let item = NightFlockV4GrantInboxItem(
            grantID: grantID, partyID: UUID(), roundID: UUID(), kind: "wool",
            woolAmount: 2, issuedAt: Date(timeIntervalSince1970: 1), acknowledgedAt: nil
        )
        let grant = NightFlockV4GrantAdapter.legacyGrant(from: item)
        XCTAssertEqual(grant?.id, grantID)
        XCTAssertEqual(grant?.rewardKind, .wool)
        XCTAssertEqual(grant?.woolAmount, 2)
    }

    func testRoutineProfileSyncUsesInitialOrMigrationBeforeServerProfile() {
        let initial = CountingSheepUserProfile(displayName: "Clover")
        XCTAssertEqual(
            NightFlockV4ProfileSyncRules.routinePlan(local: initial, server: nil)?.nameSelectionKind,
            .initial
        )
        let migrated = CountingSheepUserProfile(displayName: "Clover", hasEstablishedDisplayName: true)
        XCTAssertEqual(
            NightFlockV4ProfileSyncRules.routinePlan(local: migrated, server: nil)?.nameSelectionKind,
            .migration
        )
    }

    func testRoutineCosmeticProfileSyncDoesNotClaimANameChange() {
        let server = CountingSheepUserProfile(
            displayName: "Clover",
            presentation: .defaultValue,
            revision: 4,
            hasEstablishedDisplayName: true
        )
        var local = server
        local.presentation.pastureThemeID = "pasture_moonlit"
        let plan = NightFlockV4ProfileSyncRules.routinePlan(local: local, server: server)
        XCTAssertEqual(plan?.nameSelectionKind, .migration)
        XCTAssertEqual(plan?.profile.displayName, "Clover")
        XCTAssertEqual(plan?.profile.revision, 4)

        local.displayName = "Moss"
        XCTAssertEqual(
            NightFlockV4ProfileSyncRules.routinePlan(local: local, server: server)?.nameSelectionKind,
            .change
        )
    }

    func testHomeSummaryUsesV4PartyListRatherThanLegacyGoalCopy() throws {
        let empty = NightFlockHomeSummary.make(from: [] as [NightFlockV4PartySummary])
        XCTAssertEqual(empty.title, "Your Slumber Parties")
        XCTAssertFalse(empty.detail.localizedCaseInsensitiveContains("goal"))

        let round = NightFlockV4Round(
            roundID: UUID(), number: 1, timeZoneIdentifier: utc,
            startsOn: NightFlockLocalDate(year: 2026, month: 8, day: 20), status: .active
        )
        let solo = NightFlockV4PartySummary(
            partyID: UUID(), name: "Moonfield", memberCount: 2, myRole: .host,
            currentRound: round, revision: 1
        )
        let secondNight = try XCTUnwrap(round.startsOn.date(in: utc, calendar: .init(identifier: .gregorian)))
            .addingTimeInterval(86_400)
        let one = NightFlockHomeSummary.make(from: [solo], at: secondNight)
        XCTAssertEqual(one.title, "Moonfield")
        XCTAssertEqual(one.detail, "Host • 2 members • Night 2 of 7")
        XCTAssertEqual(one.challengeDay, 2)

        let many = NightFlockHomeSummary.make(from: [solo, solo])
        XCTAssertEqual(many.title, "2 Slumber Parties")
        XCTAssertFalse(many.detail.localizedCaseInsensitiveContains("lobby"))
    }

    private func object(_ value: Encodable) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    }
}

private extension JSONDecoder {
    static var nightFlockISO8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
