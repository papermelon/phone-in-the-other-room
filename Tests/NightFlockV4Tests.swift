import XCTest

final class NightFlockV4Tests: XCTestCase {
    private let utc = "UTC"

    func testReleasePresentationGateRequiresExactCapabilitiesAndAcceptedAgreement() {
        let v1 = NightFlockV4ListStateResponse(
            parties: [],
            profileAvatarVersion: 1,
            sharedHabitsVersion: 1
        )
        let v2 = NightFlockV4ListStateResponse(
            parties: [],
            profileAvatarVersion: 1,
            sharedHabitsVersion: 2,
            sharedRoutinePlansVersion: 1
        )
        let unknown = NightFlockV4ListStateResponse(
            parties: [],
            profileAvatarVersion: 2,
            sharedHabitsVersion: 3,
            sharedRoutinePlansVersion: 2
        )

        func partyState(agreementVersion: Int?) -> NightFlockSharedHabitsStateResponse {
            let agreement = agreementVersion.map {
                NightFlockSharedHabitsAgreementReceipt(
                    agreementID: UUID(),
                    memberEpochID: UUID(),
                    acceptedAt: Date(timeIntervalSince1970: 100),
                    timeZoneIdentifier: utc,
                    firstEligibleSleepNight: nil,
                    agreementVersion: $0
                )
            }
            return NightFlockSharedHabitsStateResponse(
                agreement: agreement,
                records: [],
                nextCursor: nil,
                snapshotRevision: 1,
                periods: []
            )
        }

        let noAgreement = partyState(agreementVersion: nil)
        let agreementV1 = partyState(agreementVersion: 1)
        let agreementV2 = partyState(agreementVersion: 2)
        let unknownAgreement = partyState(agreementVersion: 3)

        XCTAssertFalse(SlumberPartyReleasePresentationGate.showsSharedHabits(listState: v1, partyState: noAgreement))
        XCTAssertTrue(SlumberPartyReleasePresentationGate.showsSharedHabits(listState: v1, partyState: agreementV1))
        XCTAssertFalse(SlumberPartyReleasePresentationGate.showsSharedHabits(listState: v1, partyState: agreementV2))
        XCTAssertFalse(SlumberPartyReleasePresentationGate.showsSharedNightPlans(listState: v2, partyState: agreementV1))
        XCTAssertTrue(SlumberPartyReleasePresentationGate.showsSharedNightPlans(listState: v2, partyState: agreementV2))
        XCTAssertTrue(SlumberPartyReleasePresentationGate.showsSocialAvatar(listState: v2, partyState: agreementV2))
        XCTAssertEqual(
            SlumberPartyReleasePresentationGate.avatarID(
                requested: "sheep:juniper",
                listState: v2,
                partyState: noAgreement
            ),
            SocialAvatarRules.shepherdID
        )
        XCTAssertFalse(SlumberPartyReleasePresentationGate.showsSharedHabits(listState: unknown, partyState: agreementV1))
        XCTAssertFalse(SlumberPartyReleasePresentationGate.showsSharedNightPlans(listState: unknown, partyState: agreementV2))
        XCTAssertFalse(SlumberPartyReleasePresentationGate.showsSocialAvatar(listState: v2, partyState: unknownAgreement))
    }


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
        XCTAssertNil(profile["avatarID"])
        XCTAssertNil(profile["presentation"])

        let avatarProfile = try object(NightFlockV4CommandRequest(command: .updatePublicProfile(expectedRevision: 4, nameSelectionKind: .change, displayName: "Moss", presentation: .defaultValue, avatarID: "sheep:juniper", idempotencyKey: "profile-avatar")))
        XCTAssertEqual(avatarProfile["avatarID"] as? String, "sheep:juniper")

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
        XCTAssertNil(result.profileAvatarVersion)
        XCTAssertTrue(result.retainedSharedHabitParties.isEmpty)
    }

    func testListDecodesRetainedSharedHabitPartiesAndDefaultsForOldServers() throws {
        let partyID = UUID()
        let current = try JSONDecoder.nightFlockISO8601.decode(
            NightFlockV4ListStateResponse.self,
            from: Data("""
            { "parties": [], "grantInbox": [], "sharedHabitsVersion": 1,
              "retainedSharedHabitParties": [{ "partyID": "\(partyID)",
                "partyName": "Moonfield", "recordCount": 3 }] }
            """.utf8)
        )
        XCTAssertTrue(current.supportsSharedHabits)
        XCTAssertEqual(current.retainedSharedHabitParties, [
            NightFlockRetainedSharedHabitParty(
                partyID: partyID,
                partyName: "Moonfield",
                recordCount: 3
            )
        ])

        let legacy = try JSONDecoder.nightFlockISO8601.decode(
            NightFlockV4ListStateResponse.self,
            from: Data(#"{"parties":[],"grantInbox":[]}"#.utf8)
        )
        XCTAssertFalse(legacy.supportsSharedHabits)
        XCTAssertTrue(legacy.retainedSharedHabitParties.isEmpty)
    }

    func testCommandResponseUsesOnlyCommandBoundResolvedPartyID() throws {
        let partyID = UUID()
        let resolved = try JSONDecoder.nightFlockISO8601.decode(
            NightFlockV4CommandResponse.self,
            from: Data("{\"schemaVersion\":4,\"accepted\":true,\"resolvedPartyID\":\"\(partyID)\"}".utf8)
        )
        XCTAssertEqual(resolved.resolvedPartyID, partyID)

        let legacy = try JSONDecoder.nightFlockISO8601.decode(
            NightFlockV4CommandResponse.self,
            from: Data(#"{"schemaVersion":4,"accepted":true}"#.utf8)
        )
        XCTAssertNil(legacy.resolvedPartyID)
    }

    func testAvatarCapabilityPreventsOldServerSyncLoopButUsesKnownNewCapability() {
        var local = CountingSheepUserProfile(displayName: "Moss", revision: 3, hasEstablishedDisplayName: true)
        local.presentation.avatarID = "sheep:juniper"
        var server = local
        server.presentation.avatarID = SocialAvatarRules.shepherdID
        server.revision = 8

        XCTAssertNil(
            NightFlockV4ProfileSyncRules.routinePlan(
                local: local,
                server: server,
                supportsSocialAvatar: false
            )
        )
        let plan = NightFlockV4ProfileSyncRules.routinePlan(
            local: local,
            server: server,
            supportsSocialAvatar: true
        )
        XCTAssertEqual(plan?.avatarID, "sheep:juniper")
        XCTAssertEqual(plan?.profile.revision, 8)
    }

    func testListAvatarCapabilityDecodesWithNoParties() throws {
        let result = try JSONDecoder.nightFlockISO8601.decode(
            NightFlockV4ListStateResponse.self,
            from: Data(#"{"parties":[],"grantInbox":[],"profileAvatarVersion":1}"#.utf8)
        )
        XCTAssertTrue(result.supportsProfileAvatar)
        XCTAssertTrue(result.parties.isEmpty)
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

    func testStatusAcknowledgementOnlyRemovesTheSentIdentityAcrossRestart() throws {
        let sourceID = UUID()
        let first = NightFlockV4StatusOutboxRecord(
            sourceEventID: sourceID,
            status: .windDownStarting,
            revision: 1,
            observedAt: Date(timeIntervalSince1970: 10),
            idempotencyKey: "status-1"
        )
        let newer = NightFlockV4StatusOutboxRecord(
            sourceEventID: sourceID,
            status: .phoneAwayActive,
            revision: 2,
            observedAt: Date(timeIntervalSince1970: 20),
            idempotencyKey: "status-2"
        )

        var persisted = NightFlockV4StatusOutboxRules.merge(first, into: [])
        let sent = try XCTUnwrap(persisted.first)

        // A newer revision may arrive after transport has taken a snapshot of
        // the older record. Acknowledging that sent snapshot must not remove
        // the newer record from the durable queue.
        persisted = NightFlockV4StatusOutboxRules.merge(newer, into: persisted)
        persisted.removeAll { $0.identity == sent.identity }
        XCTAssertEqual(persisted, [newer])

        let restarted = try JSONDecoder().decode(
            [NightFlockV4StatusOutboxRecord].self,
            from: try JSONEncoder().encode(persisted)
        )
        XCTAssertEqual(restarted, [newer])
    }

    func testFailedOlderStatusAttemptDoesNotIncrementNewerRevision() throws {
        let sourceID = UUID()
        let first = NightFlockV4StatusOutboxRecord(
            sourceEventID: sourceID,
            status: .windDownStarting,
            revision: 1,
            observedAt: Date(timeIntervalSince1970: 10),
            idempotencyKey: "status-1"
        )
        let newer = NightFlockV4StatusOutboxRecord(
            sourceEventID: sourceID,
            status: .phoneAwayActive,
            revision: 2,
            observedAt: Date(timeIntervalSince1970: 20),
            idempotencyKey: "status-2"
        )

        var queuedRecords = NightFlockV4StatusOutboxRules.merge(first, into: [])
        let sent = try XCTUnwrap(queuedRecords.first)
        queuedRecords = NightFlockV4StatusOutboxRules.merge(newer, into: queuedRecords)

        // The failure acknowledgement belongs to the old identity, so the
        // replacement revision remains untouched.
        if let index = queuedRecords.firstIndex(where: { $0.identity == sent.identity }) {
            queuedRecords[index].attemptCount += 1
        }
        let queued = try XCTUnwrap(queuedRecords.first)
        XCTAssertEqual(queued.revision, newer.revision)
        XCTAssertEqual(queued.attemptCount, newer.attemptCount)
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
            NightFlockV4ProfileSyncRules.routinePlan(
                local: initial,
                server: nil,
                supportsSocialAvatar: false
            )?.nameSelectionKind,
            .initial
        )
        let migrated = CountingSheepUserProfile(displayName: "Clover", hasEstablishedDisplayName: true)
        XCTAssertEqual(
            NightFlockV4ProfileSyncRules.routinePlan(
                local: migrated,
                server: nil,
                supportsSocialAvatar: false
            )?.nameSelectionKind,
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
        let plan = NightFlockV4ProfileSyncRules.routinePlan(
            local: local,
            server: server,
            supportsSocialAvatar: false
        )
        XCTAssertEqual(plan?.nameSelectionKind, .migration)
        XCTAssertEqual(plan?.profile.displayName, "Clover")
        XCTAssertEqual(plan?.profile.revision, 4)

        local.displayName = "Moss"
        XCTAssertEqual(
            NightFlockV4ProfileSyncRules.routinePlan(
                local: local,
                server: server,
                supportsSocialAvatar: false
            )?.nameSelectionKind,
            .change
        )
    }

    func testHomeSummaryUsesV4PartyListRatherThanLegacyGoalCopy() throws {
        let empty = NightFlockHomeSummary.make(from: [] as [NightFlockV4PartySummary])
        XCTAssertEqual(empty.title, "Your Slumber Parties")
        XCTAssertFalse(empty.detail.localizedCaseInsensitiveContains("goal"))
        XCTAssertEqual(empty.lifecycle, .none)
        XCTAssertNil(empty.destinationPartyID)

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
        XCTAssertEqual(one.lifecycle, .active(night: 2))
        XCTAssertEqual(one.memberCount, 2)
        XCTAssertEqual(one.destinationPartyID, solo.partyID)

        let many = NightFlockHomeSummary.make(from: [solo, solo])
        XCTAssertEqual(many.title, "2 Slumber Parties")
        XCTAssertFalse(many.detail.localizedCaseInsensitiveContains("lobby"))
        XCTAssertEqual(many.lifecycle, .multiple)
        XCTAssertNil(many.destinationPartyID)
    }

    func testDiscoveryPolicyShowsEnabledNonMemberBeforeListLoadAndHidesDisabledFeature() throws {
        XCTAssertNil(
            NightFlockHomeDiscoveryPolicy.summary(
                featureEnabled: false,
                v4Parties: nil
            )
        )

        let beforeListLoad = try XCTUnwrap(
            NightFlockHomeDiscoveryPolicy.summary(
                featureEnabled: true,
                v4Parties: nil
            )
        )
        XCTAssertEqual(beforeListLoad.lifecycle, .none)
        XCTAssertEqual(beforeListLoad.partyCount, 0)
        XCTAssertNil(beforeListLoad.destinationPartyID)

        let loadedEmpty = try XCTUnwrap(
            NightFlockHomeDiscoveryPolicy.summary(
                featureEnabled: true,
                v4Parties: []
            )
        )
        XCTAssertEqual(loadedEmpty, beforeListLoad)
    }

    func testHomeAndFarmBridgeCopyUsesOnlyListFacts() throws {
        let empty = NightFlockHomeSummary.make(from: [] as [NightFlockV4PartySummary])
        let homeEmpty = NightFlockV4BridgePresentation.make(from: empty, context: .home)
        XCTAssertEqual(homeEmpty.title, "Start or join a private group")
        XCTAssertEqual(homeEmpty.detail, "Share quiet nights with family, a partner, or close friends.")
        let farmEmpty = NightFlockV4BridgePresentation.make(from: empty, context: .farm)
        XCTAssertEqual(farmEmpty.eyebrow, "SLUMBER PARTY · YOUR FARM")
        XCTAssertEqual(farmEmpty.title, "Start or join a private group")

        let party = NightFlockV4PartySummary(
            partyID: UUID(), name: "Moonfield", memberCount: 2, myRole: .member,
            currentRound: nil, revision: 1
        )
        let summary = NightFlockHomeSummary.make(from: [party])
        let home = NightFlockV4BridgePresentation.make(from: summary, context: .home)
        XCTAssertEqual(home.title, "Moonfield")
        XCTAssertEqual(home.detail, "Waiting for the host to start 7 nights.")
        let farm = NightFlockV4BridgePresentation.make(from: summary, context: .farm)
        XCTAssertEqual(farm.detail, "Your curated Farm look appears in your parties. Completed shared moments can bring wool home.")
        XCTAssertEqual(summary.destinationPartyID, party.partyID)
    }

    func testV4LifecycleDistinguishesInviteReadyActiveAndElapsedStates() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = NightFlockLocalDate(year: 2026, month: 8, day: 20)
        let activeRound = NightFlockV4Round(
            roundID: UUID(), number: 4, timeZoneIdentifier: utc,
            startsOn: start, status: .active
        )
        let startDate = try XCTUnwrap(start.date(in: utc, calendar: calendar))
        let solo = NightFlockV4PartySummary(
            partyID: UUID(), name: "Moonfield", memberCount: 1,
            myRole: .host, currentRound: nil, revision: 1
        )
        let readyHost = NightFlockV4PartySummary(
            partyID: UUID(), name: "Moonfield", memberCount: 2,
            myRole: .host, currentRound: nil, revision: 1
        )
        let readyMember = NightFlockV4PartySummary(
            partyID: UUID(), name: "Moonfield", memberCount: 2,
            myRole: .member, currentRound: activeRound, revision: 1
        )
        let elapsed = NightFlockV4PartySummary(
            partyID: UUID(), name: "Moonfield", memberCount: 2,
            myRole: .host, currentRound: activeRound, revision: 1
        )

        XCTAssertEqual(NightFlockV4Presentation.lifecycle(for: solo), .needsInvite)
        XCTAssertEqual(NightFlockV4Presentation.lifecycle(for: readyHost), .readyHost)
        XCTAssertEqual(
            NightFlockV4Presentation.lifecycle(for: readyMember, at: startDate.addingTimeInterval(-60), calendar: calendar),
            .readyMember
        )
        XCTAssertEqual(
            NightFlockV4Presentation.lifecycle(for: readyMember, at: startDate.addingTimeInterval(2 * 86_400), calendar: calendar),
            .active(night: 3)
        )
        XCTAssertEqual(
            NightFlockV4Presentation.lifecycle(for: elapsed, at: startDate.addingTimeInterval(7 * 86_400), calendar: calendar),
            .elapsedHost
        )
        let completed = NightFlockV4PartySummary(
            partyID: UUID(), name: "Moonfield", memberCount: 2,
            myRole: .member,
            currentRound: NightFlockV4Round(
                roundID: UUID(), number: 4, timeZoneIdentifier: utc,
                startsOn: start, status: .completed
            ),
            revision: 1
        )
        XCTAssertEqual(NightFlockV4Presentation.lifecycle(for: completed), .elapsedMember)
    }

    func testV4LifecycleUsesStoredTimezoneCalendarAcrossDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let start = NightFlockLocalDate(year: 2026, month: 3, day: 8)
        let round = NightFlockV4Round(
            roundID: UUID(), number: 1, timeZoneIdentifier: "America/Los_Angeles",
            startsOn: start, status: .active
        )
        let startDate = try XCTUnwrap(start.date(in: round.timeZoneIdentifier, calendar: calendar))
        let daySeven = try XCTUnwrap(calendar.date(byAdding: .day, value: 6, to: startDate))
        let dayEight = try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: startDate))
        let party = NightFlockV4PartySummary(
            partyID: UUID(), name: "Moonfield", memberCount: 2,
            myRole: .member, currentRound: round, revision: 1
        )

        XCTAssertEqual(
            NightFlockV4Presentation.lifecycle(for: party, at: daySeven, calendar: calendar),
            .active(night: 7)
        )
        XCTAssertEqual(
            NightFlockV4Presentation.lifecycle(for: party, at: dayEight, calendar: calendar),
            .elapsedMember
        )
    }

    func testV4DetailFiltersExpiredWrongRoundAndWrongPartyData() throws {
        let partyID = UUID()
        let roundID = UUID()
        let oldRoundID = UUID()
        let memberID = UUID()
        let now = Date(timeIntervalSince1970: 10_000)
        let round = NightFlockV4Round(
            roundID: roundID, number: 1, timeZoneIdentifier: utc,
            startsOn: NightFlockLocalDate(year: 2026, month: 8, day: 20), status: .active
        )
        let member = NightFlockV4Membership(
            memberID: memberID, profile: .init(displayName: "Moss"), role: .member,
            joinedAt: now.addingTimeInterval(-60)
        )
        func activity(roundID: UUID, partyID: UUID, minutes: Int, at date: Date) -> NightFlockV4Activity {
            NightFlockV4Activity(
                activityID: UUID(), partyID: partyID, roundID: roundID, memberID: memberID,
                day: 2, kind: .windDown, status: .completed, roundedMinutes: minutes, occurredAt: date
            )
        }
        let latest = activity(roundID: roundID, partyID: partyID, minutes: 30, at: now)
        let earlier = activity(roundID: roundID, partyID: partyID, minutes: 20, at: now.addingTimeInterval(-60))
        let old = activity(roundID: oldRoundID, partyID: partyID, minutes: 90, at: now.addingTimeInterval(60))
        let foreign = activity(roundID: roundID, partyID: UUID(), minutes: 120, at: now.addingTimeInterval(120))
        let detail = NightFlockV4PartyDetail(
            summary: NightFlockV4PartySummary(
                partyID: partyID, name: "Moonfield", memberCount: 2,
                myRole: .host, currentRound: round, revision: 1
            ),
            myMemberID: UUID(), memberships: [member],
            activities: [earlier, latest, old, foreign],
            liveStatuses: [
                NightFlockV4LiveStatus(
                    partyID: partyID, roundID: roundID, memberID: memberID,
                    status: .phoneAwayActive, revision: 1, observedAt: now,
                    expiresAt: now.addingTimeInterval(-1)
                ),
                NightFlockV4LiveStatus(
                    partyID: partyID, roundID: oldRoundID, memberID: memberID,
                    status: .windDownStarting, revision: 4, observedAt: now,
                    expiresAt: now.addingTimeInterval(120)
                )
            ]
        )

        XCTAssertEqual(NightFlockV4Presentation.currentRoundActivities(in: detail).map(\.activityID), [latest.activityID, earlier.activityID])
        XCTAssertEqual(NightFlockV4Presentation.earlierActivities(in: detail).map(\.activityID), [old.activityID])
        let memberPresentation = NightFlockV4Presentation.member(member, in: detail, at: now)
        XCTAssertNil(memberPresentation.liveStatus)
        XCTAssertEqual(memberPresentation.latestActivity?.activityID, latest.activityID)
        XCTAssertEqual(memberPresentation.latestActivityLine, "App-recorded/self-reported · Wind Down · 30 min (rounded) · Night 2")
    }

    func testV4PresentationUsesModeNeutralPhoneAwayCopyAndCountsPartialMoments() {
        let partyID = UUID()
        let roundID = UUID()
        let memberID = UUID()
        let now = Date(timeIntervalSince1970: 20_000)
        let round = NightFlockV4Round(
            roundID: roundID, number: 1, timeZoneIdentifier: utc,
            startsOn: NightFlockLocalDate(year: 2026, month: 8, day: 20), status: .active
        )
        let member = NightFlockV4Membership(
            memberID: memberID, profile: .init(displayName: "Moss"), role: .member,
            joinedAt: now.addingTimeInterval(-60)
        )
        let partial = NightFlockV4Activity(
            activityID: UUID(), partyID: partyID, roundID: roundID, memberID: memberID,
            day: 3, kind: .phoneAway, status: .partlyCompleted, roundedMinutes: 15,
            occurredAt: now.addingTimeInterval(-1)
        )
        let detail = NightFlockV4PartyDetail(
            summary: NightFlockV4PartySummary(
                partyID: partyID, name: "Moonfield", memberCount: 2,
                myRole: .member, currentRound: round, revision: 1
            ),
            myMemberID: UUID(), memberships: [member], activities: [partial]
        )
        let memberPresentation = NightFlockV4Presentation.member(member, in: detail, at: now)
        let activityPresentation = NightFlockV4Presentation.activityPresentation(for: partial)

        XCTAssertEqual(activityPresentation.cardSummary, "Phone Away · 15 min · rounded")
        XCTAssertEqual(activityPresentation.cardState, "Night 3 · Ended early")
        XCTAssertEqual(memberPresentation.latestActivityLine, "App-recorded/self-reported · Phone Away ended early · 15 min (rounded) · Night 3")
        XCTAssertEqual(NightFlockV4Presentation.detail(for: detail, at: now).sharedMomentCount, 1)

        var liveDetail = detail
        liveDetail.liveStatuses = [NightFlockV4LiveStatus(
            partyID: partyID, roundID: roundID, memberID: memberID,
            status: .phoneAwayActive, revision: 2, observedAt: now,
            expiresAt: now.addingTimeInterval(60)
        )]
        liveDetail.liveCheers = [NightFlockV4LiveCheerSummary(
            memberID: memberID, cheer: .pawPrint, count: 2, sentByMe: false
        )]
        let livePresentation = NightFlockV4Presentation.member(member, in: liveDetail, at: now)
        XCTAssertEqual(livePresentation.liveStatusTitle, "Phone is away")
        XCTAssertTrue(livePresentation.canSendLiveCheer)
        XCTAssertEqual(livePresentation.liveCheerCount, 2)
    }

    func testV4NewerTerminalActivitySuppressesOlderLiveStatusButOlderTerminalDoesNot() {
        let partyID = UUID()
        let roundID = UUID()
        let memberID = UUID()
        let now = Date(timeIntervalSince1970: 30_000)
        let round = NightFlockV4Round(
            roundID: roundID, number: 1, timeZoneIdentifier: utc,
            startsOn: NightFlockLocalDate(year: 2026, month: 8, day: 20), status: .active
        )
        let member = NightFlockV4Membership(
            memberID: memberID, profile: .init(displayName: "Moss"), role: .member,
            joinedAt: now.addingTimeInterval(-600)
        )
        let live = NightFlockV4LiveStatus(
            partyID: partyID, roundID: roundID, memberID: memberID,
            status: .phoneAwayActive, revision: 2,
            observedAt: now.addingTimeInterval(-60), expiresAt: now.addingTimeInterval(600)
        )
        let newerTerminal = NightFlockV4Activity(
            activityID: UUID(), partyID: partyID, roundID: roundID, memberID: memberID,
            day: 1, kind: .phoneAway, status: .partlyCompleted,
            roundedMinutes: 12, occurredAt: now
        )
        let detail = NightFlockV4PartyDetail(
            summary: .init(partyID: partyID, name: "Moonfield", memberCount: 2,
                           myRole: .member, currentRound: round, revision: 1),
            memberships: [member], activities: [newerTerminal], liveStatuses: [live],
            liveCheers: [.init(memberID: memberID, cheer: .warmWave, count: 3, sentByMe: false)]
        )
        let beforeTerminal = NightFlockV4Presentation.member(
            member,
            in: detail,
            at: now.addingTimeInterval(-30)
        )
        XCTAssertEqual(beforeTerminal.liveStatus?.status, .phoneAwayActive)
        let suppressed = NightFlockV4Presentation.member(member, in: detail, at: now)
        XCTAssertNil(suppressed.liveStatus)
        XCTAssertFalse(suppressed.canSendLiveCheer)
        XCTAssertEqual(suppressed.liveCheerCount, 0)
        XCTAssertEqual(suppressed.latestActivityLine, "App-recorded/self-reported · Phone Away ended early · 12 min (rounded) · Night 1")

        var newerLiveDetail = detail
        newerLiveDetail.activities[0].occurredAt = now.addingTimeInterval(-120)
        newerLiveDetail.liveStatuses[0].observedAt = now.addingTimeInterval(-30)
        let current = NightFlockV4Presentation.member(member, in: newerLiveDetail, at: now)
        XCTAssertEqual(current.liveStatus?.status, .phoneAwayActive)
        XCTAssertTrue(current.canSendLiveCheer)
    }

    func testV4DetailRequestReconciliationKeepsTheLaterStartedReadInEitherResponseOrder() {
        // A starts first and B starts second. Whether A or B returns first,
        // B remains the cache authority; receipt time is deliberately absent.
        XCTAssertTrue(NightFlockV4PartyDetailReconciliation.accepts(requestSequence: 1, after: nil))
        XCTAssertTrue(NightFlockV4PartyDetailReconciliation.accepts(requestSequence: 2, after: 1))
        XCTAssertFalse(NightFlockV4PartyDetailReconciliation.accepts(requestSequence: 1, after: 2))

        XCTAssertTrue(NightFlockV4PartyDetailReconciliation.accepts(requestSequence: 2, after: nil))
        XCTAssertFalse(NightFlockV4PartyDetailReconciliation.accepts(requestSequence: 1, after: 2))
    }

    func testV4LateJoinBackfillExcludesEveryKnownPracticeAndAmbiguousLegacyPhoneAway() {
        let start = Date(timeIntervalSince1970: 50_000)
        let plan = NightWatchPlan.additionalQuiet(
            start: start,
            end: start.addingTimeInterval(15 * 60)
        )
        let firstPractice = NightWatchRecord(
            id: UUID(), plan: plan, startedAt: start, endedAt: plan.protectedUntil,
            startMethod: .honorTimer, outcome: .endedEarly, role: .additionalQuiet,
            isPractice: true
        )
        let secondPractice = NightWatchRecord(
            id: UUID(), plan: plan, startedAt: start, endedAt: plan.protectedUntil,
            startMethod: .honorTimer, outcome: .endedEarly, role: .additionalQuiet,
            isPractice: true
        )
        let legacyPhoneAway = NightWatchRecord(
            id: UUID(), plan: plan, startedAt: start, endedAt: plan.protectedUntil,
            startMethod: .honorTimer, outcome: .endedEarly, role: .additionalQuiet
        )
        let ordinaryPhoneAway = NightWatchRecord(
            id: UUID(), plan: plan, startedAt: start, endedAt: plan.protectedUntil,
            startMethod: .honorTimer, outcome: .endedEarly, role: .additionalQuiet,
            isPractice: false
        )

        XCTAssertFalse(NightFlockV4BackfillEligibility.accepts(firstPractice, knownPracticeRunID: secondPractice.id))
        XCTAssertFalse(NightFlockV4BackfillEligibility.accepts(secondPractice, knownPracticeRunID: secondPractice.id))
        XCTAssertFalse(NightFlockV4BackfillEligibility.accepts(legacyPhoneAway, knownPracticeRunID: nil))
        XCTAssertTrue(NightFlockV4BackfillEligibility.accepts(ordinaryPhoneAway, knownPracticeRunID: nil))
    }

    func testV4DisplayInvalidationUsesEarliestFutureExpiryAndRefreshPolicyUsesMembershipOnly() {
        let partyID = UUID()
        let otherPartyID = UUID()
        let roundID = UUID()
        let memberID = UUID()
        let now = Date(timeIntervalSince1970: 40_000)
        let party = NightFlockV4PartyDetail(
            summary: .init(
                partyID: partyID, name: "Moonfield", memberCount: 2, myRole: .member,
                currentRound: .init(roundID: roundID, number: 1, timeZoneIdentifier: utc,
                                    startsOn: .init(year: 2026, month: 8, day: 20), status: .active),
                revision: 1
            ),
            liveStatuses: [
                .init(partyID: partyID, roundID: roundID, memberID: memberID,
                      status: .windDownStarting, revision: 1, observedAt: now,
                      expiresAt: now.addingTimeInterval(90)),
                .init(partyID: partyID, roundID: roundID, memberID: UUID(),
                      status: .phoneAwayActive, revision: 1, observedAt: now,
                      expiresAt: now.addingTimeInterval(30)),
                .init(partyID: partyID, roundID: UUID(), memberID: UUID(),
                      status: .phoneAwayActive, revision: 1, observedAt: now,
                      expiresAt: now.addingTimeInterval(15)),
                .init(partyID: otherPartyID, roundID: roundID, memberID: UUID(),
                      status: .phoneAwayActive, revision: 1, observedAt: now,
                      expiresAt: now.addingTimeInterval(10))
            ]
        )
        XCTAssertEqual(NightFlockV4Presentation.nextDisplayInvalidation(in: party, at: now), now.addingTimeInterval(30))
        XCTAssertEqual(
            NightFlockV4Presentation.displayInvalidationDates(in: party, at: now),
            [now.addingTimeInterval(30), now.addingTimeInterval(90)]
        )
        XCTAssertNil(NightFlockV4Presentation.nextDisplayInvalidation(in: party, at: now.addingTimeInterval(100)))
        let eligible = NightFlockV4ObservedPartyRefreshPolicy.eligiblePartyIDs(from: [
            party.summary,
            .init(partyID: otherPartyID, name: "Second", memberCount: 2, myRole: .host, currentRound: nil, revision: 1)
        ])
        XCTAssertEqual(eligible, Set([partyID, otherPartyID]))
    }

    func testV4PublicationPolicyExcludesPracticeAndAllowsOnlyApprovedRoles() {
        for event in [NightFlockV4PublicationEvent.starting, .active, .terminal] {
            XCTAssertFalse(NightFlockV4PublicationPolicy.allows(event, role: .primarySleepBookend, isPractice: true))
            XCTAssertFalse(NightFlockV4PublicationPolicy.allows(event, role: .additionalQuiet, isPractice: true))
            XCTAssertFalse(NightFlockV4PublicationPolicy.allows(event, role: nil, isPractice: false))
        }
        XCTAssertTrue(NightFlockV4PublicationPolicy.allows(.starting, role: .primarySleepBookend, isPractice: false))
        XCTAssertFalse(NightFlockV4PublicationPolicy.allows(.starting, role: .additionalQuiet, isPractice: false))
        XCTAssertTrue(NightFlockV4PublicationPolicy.allows(.active, role: .primarySleepBookend, isPractice: false))
        XCTAssertTrue(NightFlockV4PublicationPolicy.allows(.active, role: .additionalQuiet, isPractice: false))
        XCTAssertTrue(NightFlockV4PublicationPolicy.allows(.terminal, role: .primarySleepBookend, isPractice: false))
        XCTAssertTrue(NightFlockV4PublicationPolicy.allows(.terminal, role: .additionalQuiet, isPractice: false))
    }

    func testMembershipWireDecodesAdditivelyAndLegacyPayloadRemainsRoundOnly() throws {
        let partyID = UUID(), memberID = UUID(), activityID = UUID(), statusID = UUID(), sourceID = UUID(), roundActivityID = UUID()
        let legacy = try JSONDecoder.nightFlockISO8601.decode(NightFlockV4PartyDetail.self, from: try XCTUnwrap("""
        {"summary":{"partyID":"\(partyID)","name":"Moonfield","memberCount":2,"myRole":"member","revision":1,"currentRound":null},"memberships":[],"activities":[],"liveStatuses":[],"cheers":[],"liveCheers":[],"grantInbox":[]}
        """.data(using: .utf8)))
        XCTAssertFalse(legacy.summary.supportsMembershipSharing)
        XCTAssertTrue(legacy.sharedActivities.isEmpty)
        let unknownScope = try JSONDecoder.nightFlockISO8601.decode(NightFlockV4PartySummary.self, from: try XCTUnwrap("""
        {"partyID":"\(partyID)","name":"Moonfield","memberCount":2,"myRole":"member","revision":1,"sharingScope":"future-scope","currentRound":null}
        """.data(using: .utf8)))
        XCTAssertFalse(unknownScope.supportsMembershipSharing)

        let membership = try JSONDecoder.nightFlockISO8601.decode(NightFlockV4PartyDetail.self, from: try XCTUnwrap("""
        {"summary":{"partyID":"\(partyID)","name":"Moonfield","memberCount":2,"myRole":"member","revision":1,"sharingScope":"membership","currentRound":null},"memberships":[],"activities":[],"liveStatuses":[],"cheers":[],"liveCheers":[],"sharedActivities":[{"activityID":"\(activityID)","partyID":"\(partyID)","memberID":"\(memberID)","kind":"phoneAway","status":"completed","roundedMinutes":30,"occurredAt":"2026-08-27T00:00:00Z","roundActivityID":"\(roundActivityID)","mySourceEventID":"\(sourceID)"}],"sharedLiveStatuses":[{"statusID":"\(statusID)","partyID":"\(partyID)","memberID":"\(memberID)","status":"phoneAwayActive","revision":2,"observedAt":"2026-08-27T00:00:00Z","expiresAt":"2026-08-27T00:15:00Z"}],"sharedCheers":[],"sharedLiveCheers":[],"grantInbox":[]}
        """.data(using: .utf8)))
        XCTAssertTrue(membership.summary.supportsMembershipSharing)
        XCTAssertNil(membership.sharedActivities.first?.roundID)
        XCTAssertNil(membership.sharedActivities.first?.day)
        XCTAssertEqual(membership.sharedActivities.first?.mySourceEventID, sourceID)
        XCTAssertEqual(membership.sharedActivities.first?.roundActivityID, roundActivityID)
        XCTAssertEqual(membership.sharedLiveStatuses.first?.statusID, statusID)
    }

    func testMembershipRequestsStayOmittedUntilAdvertisedAndUseScopeSpecificRetryKeys() throws {
        let sourceID = UUID(), partyID = UUID(), now = Date(timeIntervalSince1970: 100)
        let source = NightFlockV4SourceActivityRecord(sourceEventID: sourceID, kind: .windDown, outcome: .completed, startedAt: now, endedAt: now, windDownMinutes: 15, phoneAwayMinutes: 0, statusRevision: 1)
        let queued = NightFlockV4OutboxSourceRecord(source: source, origin: .live, idempotencyKey: "legacy-key")
        let legacy = try object(NightFlockV4CommandRequest(command: .publishActivity(queued)))
        XCTAssertNil(legacy["sharingScope"])
        let membershipRecord = queued.publishing(toMembershipStream: true)
        let membership = try object(NightFlockV4CommandRequest(command: .publishActivity(membershipRecord)))
        XCTAssertEqual(membership["sharingScope"] as? String, "membership")
        XCTAssertNotEqual(membership["idempotencyKey"] as? String, legacy["idempotencyKey"] as? String)
        let backfill = NightFlockV4OutboxSourceRecord(
            source: source,
            origin: .backfill,
            idempotencyKey: "backfill"
        ).publishing(toMembershipStream: true)
        let backfillRequest = try object(NightFlockV4CommandRequest(command: .publishActivity(backfill)))
        XCTAssertNil(backfillRequest["sharingScope"])

        let status = try object(NightFlockV4CommandRequest(command: .publishMembershipStatus(sourceEventID: sourceID, status: .windDownStarting, revision: 1, observedAt: now, idempotencyKey: "membership-status")))
        XCTAssertEqual(status["sharingScope"] as? String, "membership")
        let cheer = try object(NightFlockV4CommandRequest(command: .cheerMembershipMember(partyID: partyID, memberID: UUID(), statusID: UUID(), cheer: .warmWave, idempotencyKey: "status-cheer")))
        XCTAssertNotNil(cheer["statusID"])
        let react = try object(NightFlockV4CommandRequest(command: .reactMembership(partyID: partyID, activityID: UUID(), cheer: .pawPrint, idempotencyKey: "moment-cheer")))
        XCTAssertEqual(react["sharingScope"] as? String, "membership")
    }

    func testMembershipPresentationShowsNoRoundAndBoundsRecentHistory() {
        let now = Date(timeIntervalSince1970: 1_800_000_000), partyID = UUID(), memberID = UUID()
        let member = NightFlockV4Membership(memberID: memberID, profile: .init(displayName: "Moss"), role: .member, joinedAt: now.addingTimeInterval(-100))
        let host = NightFlockV4Membership(memberID: UUID(), profile: .init(displayName: "Clover"), role: .host, joinedAt: now.addingTimeInterval(-100))
        let recent = NightFlockV4SharedActivity(activityID: UUID(), partyID: partyID, memberID: memberID, roundID: nil, day: nil, kind: .phoneAway, status: .completed, roundedMinutes: 30, occurredAt: now.addingTimeInterval(-60))
        let stale = NightFlockV4SharedActivity(activityID: UUID(), partyID: partyID, memberID: memberID, roundID: nil, day: nil, kind: .windDown, status: .completed, roundedMinutes: 20, occurredAt: now.addingTimeInterval(-91 * 86_400))
        let party = NightFlockV4PartyDetail(summary: .init(partyID: partyID, name: "Moonfield", memberCount: 2, myRole: .member, currentRound: nil, revision: 1, sharingScope: .membership), myMemberID: memberID, memberships: [host, member], sharedActivities: [stale, recent])
        XCTAssertEqual(NightFlockV4Presentation.lifecycle(for: party, at: now), .readyMember)
        XCTAssertEqual(NightFlockV4Presentation.recentSharedActivities(in: party, at: now).map(\.activityID), [recent.activityID])
        XCTAssertEqual(NightFlockV4Presentation.member(member, in: party, at: now).latestActivityLine, "App-recorded/self-reported · Phone Away · 30 min (rounded)")
        XCTAssertEqual(NightFlockV4Presentation.detail(for: party, at: now).sharedMomentCount, 0)
    }

    func testMembershipLiveCheerUsesExactCurrentStatusAndTerminalSuppressesIt() {
        let now = Date(timeIntervalSince1970: 1_800_000_000), partyID = UUID(), memberID = UUID()
        let member = NightFlockV4Membership(memberID: memberID, profile: .init(displayName: "Moss"), role: .member, joinedAt: now.addingTimeInterval(-100))
        let currentID = UUID(), replacedID = UUID()
        var party = NightFlockV4PartyDetail(
            summary: .init(partyID: partyID, name: "Moonfield", memberCount: 2, myRole: .member, currentRound: nil, revision: 1, sharingScope: .membership),
            memberships: [member],
            sharedLiveStatuses: [
                .init(statusID: replacedID, partyID: partyID, memberID: memberID, roundID: nil, status: .phoneAwayActive, revision: 1, observedAt: now.addingTimeInterval(-20), expiresAt: now.addingTimeInterval(60)),
                .init(statusID: currentID, partyID: partyID, memberID: memberID, roundID: nil, status: .phoneAwayActive, revision: 2, observedAt: now.addingTimeInterval(-10), expiresAt: now.addingTimeInterval(60))
            ],
            sharedLiveCheers: [
                .init(statusID: replacedID, memberID: memberID, cheer: .warmWave, count: 9, sentByMe: false),
                .init(statusID: currentID, memberID: memberID, cheer: .warmWave, count: 2, sentByMe: true)
            ]
        )
        let current = NightFlockV4Presentation.member(member, in: party, at: now)
        XCTAssertEqual(current.liveStatusID, currentID)
        XCTAssertEqual(current.liveCheerCount, 2)
        party.sharedActivities = [.init(activityID: UUID(), partyID: partyID, memberID: memberID, roundID: nil, day: nil, kind: .phoneAway, status: .completed, roundedMinutes: 20, occurredAt: now)]
        let terminal = NightFlockV4Presentation.member(member, in: party, at: now)
        XCTAssertNil(terminal.liveStatusID)
        XCTAssertEqual(terminal.liveCheerCount, 0)
    }

    func testMembershipPresentationFallsBackToOldClientLiveStatusUntilItExpires() {
        let now = Date(timeIntervalSince1970: 1_800_000_000), partyID = UUID(), memberID = UUID()
        let roundID = UUID(), expiry = now.addingTimeInterval(60)
        let member = NightFlockV4Membership(memberID: memberID, profile: .init(displayName: "Moss"), role: .member, joinedAt: now.addingTimeInterval(-100))
        let round = NightFlockV4Round(
            roundID: roundID,
            number: 1,
            timeZoneIdentifier: utc,
            startsOn: .init(year: 2027, month: 1, day: 1),
            status: .active
        )
        var party = NightFlockV4PartyDetail(
            summary: .init(partyID: partyID, name: "Moonfield", memberCount: 2, myRole: .member, currentRound: round, revision: 1, sharingScope: .membership),
            memberships: [member],
            liveStatuses: [.init(partyID: partyID, roundID: roundID, memberID: memberID, status: .phoneAwayActive, revision: 1, observedAt: now, expiresAt: expiry)]
        )

        let fallback = NightFlockV4Presentation.member(member, in: party, at: now)
        XCTAssertEqual(fallback.liveStatus?.status, .phoneAwayActive)
        XCTAssertEqual(fallback.liveStatusTitle, "Phone is away")
        XCTAssertTrue(fallback.hasSharedUpdate)
        XCTAssertEqual(NightFlockV4Presentation.displayInvalidationDates(in: party, at: now), [expiry])

        party.sharedActivities = [.init(activityID: UUID(), partyID: partyID, memberID: memberID, roundID: nil, day: nil, kind: .phoneAway, status: .completed, roundedMinutes: 20, occurredAt: now.addingTimeInterval(-120))]
        XCTAssertEqual(NightFlockV4Presentation.member(member, in: party, at: now).liveStatus?.status, .phoneAwayActive)
        XCTAssertEqual(NightFlockV4Presentation.displayInvalidationDates(in: party, at: now), [expiry])

        party.sharedActivities = [.init(activityID: UUID(), partyID: partyID, memberID: memberID, roundID: nil, day: nil, kind: .phoneAway, status: .completed, roundedMinutes: 20, occurredAt: now.addingTimeInterval(1))]
        XCTAssertNil(NightFlockV4Presentation.member(member, in: party, at: now.addingTimeInterval(1)).liveStatus)
        XCTAssertTrue(NightFlockV4Presentation.displayInvalidationDates(in: party, at: now.addingTimeInterval(1)).isEmpty)
        XCTAssertNil(NightFlockV4Presentation.member(member, in: party, at: expiry).liveStatus)
    }

    func testMembershipPresentationKeepsStreamPrimaryAndPreservesUnmatchedRoundHistory() {
        let now = Date(timeIntervalSince1970: 1_800_000_000), partyID = UUID(), memberID = UUID()
        let matchedRoundID = UUID(), backfillRoundID = UUID()
        let matched = NightFlockV4Activity(activityID: matchedRoundID, partyID: partyID, roundID: UUID(), memberID: memberID, day: 1, kind: .windDown, status: .completed, roundedMinutes: 20, occurredAt: now)
        let backfill = NightFlockV4Activity(activityID: backfillRoundID, partyID: partyID, roundID: UUID(), memberID: memberID, day: 2, kind: .phoneAway, status: .completed, roundedMinutes: 30, occurredAt: now.addingTimeInterval(-60))
        let streamMatched = NightFlockV4SharedActivity(activityID: UUID(), partyID: partyID, memberID: memberID, roundID: matched.roundID, day: 1, kind: .windDown, status: .completed, roundedMinutes: 20, occurredAt: now, roundActivityID: matchedRoundID)
        let streamMembershipOnly = NightFlockV4SharedActivity(activityID: UUID(), partyID: partyID, memberID: memberID, roundID: nil, day: nil, kind: .phoneAway, status: .partlyCompleted, roundedMinutes: 10, occurredAt: now.addingTimeInterval(-30))
        let party = NightFlockV4PartyDetail(summary: .init(partyID: partyID, name: "Moonfield", memberCount: 2, myRole: .member, currentRound: nil, revision: 1, sharingScope: .membership), activities: [matched, backfill], sharedActivities: [streamMatched, streamMembershipOnly])
        XCTAssertEqual(NightFlockV4Presentation.membershipActivitiesForPresentation(in: party, at: now).map(\.activityID), [streamMatched.activityID, streamMembershipOnly.activityID])
        XCTAssertEqual(NightFlockV4Presentation.legacyRoundHistoryActivities(in: party).map(\.activityID), [backfillRoundID])
    }

    func testMembershipFeedbackOnlyEmitsNewCheerForCurrentExactTarget() {
        let now = Date(timeIntervalSince1970: 1_800_000_000), partyID = UUID(), mine = UUID()
        let summary = NightFlockV4PartySummary(partyID: partyID, name: "Moonfield", memberCount: 2, myRole: .member, currentRound: nil, revision: 1, sharingScope: .membership)
        let membership = NightFlockV4Membership(memberID: mine, profile: .init(displayName: "Moss"), role: .member, joinedAt: now.addingTimeInterval(-100))
        let statusID = UUID(), staleStatusID = UUID(), sourceID = UUID()
        let activity = NightFlockV4SharedActivity(activityID: UUID(), partyID: partyID, memberID: mine, roundID: nil, day: nil, kind: .windDown, status: .completed, roundedMinutes: 20, occurredAt: now.addingTimeInterval(-5), mySourceEventID: sourceID)
        let previous = NightFlockV4PartyDetail(summary: summary, myMemberID: mine, memberships: [membership], sharedActivities: [activity], sharedLiveStatuses: [.init(statusID: statusID, partyID: partyID, memberID: mine, roundID: nil, status: .windDownStarting, revision: 1, observedAt: now, expiresAt: now.addingTimeInterval(60))], sharedLiveCheers: [.init(statusID: statusID, memberID: mine, cheer: .warmWave, count: 1, sentByMe: false, mySourceEventID: sourceID)])
        // The new snapshot has no live status because it has ended, but the
        // durable exact-status ledger still brings the offline cheer through.
        let current = NightFlockV4PartyDetail(summary: summary, myMemberID: mine, memberships: [membership], sharedActivities: [activity], sharedCheers: [.init(activityID: activity.activityID, cheer: .warmWave, count: 2, sentByMe: false)], sharedLiveCheers: [.init(statusID: statusID, memberID: mine, cheer: .warmWave, count: 2, sentByMe: false, mySourceEventID: sourceID), .init(statusID: staleStatusID, memberID: mine, cheer: .pawPrint, count: 9, sentByMe: false)])
        let deltas = NightFlockV4MembershipCheerFeedbackRules.deltas(previous: previous, current: current, at: now)
        XCTAssertEqual(deltas.count, 1)
        XCTAssertEqual(deltas.first?.cheer, .warmWave)
        XCTAssertEqual(deltas.first?.count, 2)
        XCTAssertEqual(deltas.first?.sourceEventID, sourceID)
        XCTAssertTrue(NightFlockV4MembershipCheerFeedbackRules.deltas(previous: current, current: current, at: now).isEmpty)

        var missingIdentity = current
        missingIdentity.sharedLiveCheers[0].mySourceEventID = nil
        missingIdentity.sharedActivities[0].mySourceEventID = nil
        XCTAssertTrue(NightFlockV4MembershipCheerFeedbackRules.deltas(previous: previous, current: missingIdentity, at: now).isEmpty)
    }

    func testSharedNightPlanIdentityAndOutboxReplacementAreEpochScoped() {
        let partyID = UUID()
        let agreementID = UUID()
        let firstEpoch = UUID()
        let rejoinedEpoch = UUID()
        let night = NightFlockLocalDate(year: 2026, month: 9, day: 1)
        func plan(epoch: UUID, revision: Int64) -> SharedNightPlan {
            SharedNightPlan(
                planID: SharedNightPlanRules.stablePlanID(partyID: partyID, memberEpochID: epoch, nightEndingDate: night),
                partyID: partyID, memberID: UUID(), memberEpochID: epoch, agreementID: agreementID, revision: revision,
                nightEndingDate: night, timeZoneIdentifier: utc, plannedWindDownStart: .now, intendedBedtime: .now,
                intendedWakeTime: .now, morningQuietEnd: .now, beforeBedMinutes: 30, afterWakingMinutes: 30,
                eveningSuggestionIDs: [], morningSuggestionIDs: []
            )
        }
        let original = NightFlockSharedNightOutboxRecord(id: UUID(), payload: .plan(plan(epoch: firstEpoch, revision: 1)), partyID: partyID, agreementID: agreementID, memberEpochID: firstEpoch, idempotencyKey: "one", attemptCount: 0, createdAt: .now)
        let resaved = NightFlockSharedNightOutboxRecord(id: UUID(), payload: .plan(plan(epoch: firstEpoch, revision: 2)), partyID: partyID, agreementID: agreementID, memberEpochID: firstEpoch, idempotencyKey: "two", attemptCount: 0, createdAt: .now)
        let rejoined = NightFlockSharedNightOutboxRecord(id: UUID(), payload: .plan(plan(epoch: rejoinedEpoch, revision: 1)), partyID: partyID, agreementID: agreementID, memberEpochID: rejoinedEpoch, idempotencyKey: "three", attemptCount: 0, createdAt: .now)
        let replaced = NightFlockSharedNightOutboxRules.merge(resaved, into: [original])
        XCTAssertEqual(replaced?.map(\.idempotencyKey), ["two"])
        XCTAssertEqual(NightFlockSharedNightOutboxRules.merge(rejoined, into: replaced ?? [])?.count, 2)
        XCTAssertNotEqual(plan(epoch: firstEpoch, revision: 1).planID, plan(epoch: rejoinedEpoch, revision: 1).planID)
    }

    func testSharedNightCapabilitiesKeepV1ConsentSeparateFromV2() {
        let v1 = NightFlockV4ListStateResponse(parties: [], sharedHabitsVersion: 1)
        let v2 = NightFlockV4ListStateResponse(parties: [], sharedHabitsVersion: 2, sharedRoutinePlansVersion: 1)
        XCTAssertTrue(v1.supportsSharedHabits)
        XCTAssertFalse(v1.supportsSharedNightPlans)
        XCTAssertTrue(v2.supportsSharedNightPlans)
    }

    func testSharedNightPlanContentSkipsEqualSaveAndVersionsChangedSave() {
        let partyID = UUID(), epochID = UUID(), agreementID = UUID()
        let night = NightFlockLocalDate(year: 2026, month: 9, day: 1)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        func make(revision: Int64, bedtimeOffset: TimeInterval = 30 * 60) -> SharedNightPlan {
            .init(planID: SharedNightPlanRules.versionedPlanID(partyID: partyID, memberEpochID: epochID, nightEndingDate: night, revision: revision), partyID: partyID, memberID: UUID(), memberEpochID: epochID, agreementID: agreementID, revision: revision, nightEndingDate: night, timeZoneIdentifier: utc, plannedWindDownStart: start, intendedBedtime: start.addingTimeInterval(bedtimeOffset), intendedWakeTime: start.addingTimeInterval(8 * 60 * 60), morningQuietEnd: start.addingTimeInterval(8.5 * 60 * 60), beforeBedMinutes: Int(bedtimeOffset / 60), afterWakingMinutes: 30, eveningSuggestionIDs: ["read"], morningSuggestionIDs: [])
        }
        let original = make(revision: 1)
        XCTAssertTrue(SharedNightPlanRules.hasSamePublishedContent(original, make(revision: 2)))
        let changed = make(revision: 2, bedtimeOffset: 35 * 60)
        XCTAssertFalse(SharedNightPlanRules.hasSamePublishedContent(original, changed))
        XCTAssertNotEqual(original.planID, changed.planID)
    }

    func testFrozenReceiptRetainsSupersededPlanIdentity() {
        let partyID = UUID(), epochID = UUID(), agreementID = UUID(), memberID = UUID()
        let night = NightFlockLocalDate(year: 2026, month: 9, day: 1)
        let oldID = SharedNightPlanRules.versionedPlanID(partyID: partyID, memberEpochID: epochID, nightEndingDate: night, revision: 1)
        let newID = SharedNightPlanRules.versionedPlanID(partyID: partyID, memberEpochID: epochID, nightEndingDate: night, revision: 2)
        let receipt = SharedNightReceipt(receiptID: UUID(), partyID: partyID, memberID: memberID, memberEpochID: epochID, agreementID: agreementID, planID: oldID, planRevision: 1, sourceID: UUID(), revision: 1, nightEndingDate: night, timeZoneIdentifier: utc, actualStart: nil, terminalAt: nil, outcome: .unknown, windDownMinutes: nil, protectionMinutes: nil, protectionEvidence: .unknown, emergencyExitUsed: nil, profileSnapshot: .init(displayName: "Moss", avatarID: nil))
        XCTAssertEqual(receipt.planID, oldID)
        XCTAssertNotEqual(receipt.planID, newID)
        XCTAssertEqual(receipt.planRevision, 1)
    }

    func testSharedNightAnchorStaysInAcceptedTimezoneAcrossTravelAndDST() {
        let instant = ISO8601DateFormatter().date(from: "2026-03-08T03:30:00Z")!
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = try! XCTUnwrap(TimeZone(identifier: "America/New_York"))
        var singapore = Calendar(identifier: .gregorian)
        singapore.timeZone = try! XCTUnwrap(TimeZone(identifier: "Asia/Singapore"))
        let accepted = try! XCTUnwrap(NightFlockLocalDate(date: instant, timeZoneIdentifier: "America/New_York", calendar: newYork))
        let travelled = try! XCTUnwrap(NightFlockLocalDate(date: instant, timeZoneIdentifier: "Asia/Singapore", calendar: singapore))
        XCTAssertNotEqual(accepted, travelled)
        XCTAssertEqual(accepted, NightFlockLocalDate(date: instant, timeZoneIdentifier: "America/New_York", calendar: newYork))
    }

    func testSharedNightBindingLedgerRoundTripsFrozenVersionAndSeparatesEpochs() throws {
        let partyID = UUID(), epochID = UUID(), agreementID = UUID()
        let night = NightFlockLocalDate(year: 2026, month: 9, day: 1)
        let plan = SharedNightPlan(planID: SharedNightPlanRules.versionedPlanID(partyID: partyID, memberEpochID: epochID, nightEndingDate: night, revision: 2), partyID: partyID, memberID: UUID(), memberEpochID: epochID, agreementID: agreementID, revision: 2, nightEndingDate: night, timeZoneIdentifier: utc, plannedWindDownStart: .now, intendedBedtime: .now, intendedWakeTime: .now.addingTimeInterval(60), morningQuietEnd: .now.addingTimeInterval(120), beforeBedMinutes: 0, afterWakingMinutes: 1, eveningSuggestionIDs: [], morningSuggestionIDs: [])
        let entry = NightFlockSharedNightPlanBindingLedgerEntry(plan: plan, updatedAt: .now)
        let restored = try JSONDecoder().decode(NightFlockSharedNightPlanBindingLedgerEntry.self, from: JSONEncoder().encode(entry))
        XCTAssertEqual(restored.plan.planID, plan.planID)
        XCTAssertEqual(restored.plan.revision, 2)
        var nextEpochPlan = plan
        nextEpochPlan.memberEpochID = UUID()
        XCTAssertNotEqual(entry.identity, NightFlockSharedNightPlanBindingLedgerEntry(plan: nextEpochPlan, updatedAt: .now).identity)
    }

    func testPrimaryRunSharingHandoffKeepsPrivateSelectionUntilPrepareResetsIt() {
        XCTAssertFalse(NightFlockPrimaryRunSharingHandoffRules.capturedShareSelection(false))
        XCTAssertTrue(NightFlockPrimaryRunSharingHandoffRules.capturedShareSelection(true))
    }

    func testPrimaryValidationDefersOnlyDuringPrimaryAdmissionAndPublishesOnlyForSharedRun() {
        XCTAssertTrue(NightFlockPrimaryRunValidationAdmissionRules.shouldDeferValidation(
            isPrimaryWindDown: true,
            sharingAdmissionIsPending: true
        ))
        XCTAssertFalse(NightFlockPrimaryRunValidationAdmissionRules.shouldDeferValidation(
            isPrimaryWindDown: false,
            sharingAdmissionIsPending: true
        ))
        XCTAssertFalse(NightFlockPrimaryRunValidationAdmissionRules.shouldDeferValidation(
            isPrimaryWindDown: true,
            sharingAdmissionIsPending: false
        ))
        XCTAssertTrue(NightFlockPrimaryRunValidationAdmissionRules
            .shouldPublishValidatedStatusAfterAdmission(
                sharesRun: true,
                wasValidatedDuringAdmission: true
            ))
        XCTAssertFalse(NightFlockPrimaryRunValidationAdmissionRules
            .shouldPublishValidatedStatusAfterAdmission(
                sharesRun: false,
                wasValidatedDuringAdmission: true
            ))
        XCTAssertFalse(NightFlockPrimaryRunValidationAdmissionRules
            .shouldPublishValidatedStatusAfterAdmission(
                sharesRun: true,
                wasValidatedDuringAdmission: false
            ))
    }

    func testPrimaryRunPrivacyDecisionFailsClosedForModernMissingRecordsAndKeepsLegacyExplicit() {
        let runID = UUID()
        let requiredAfter = Date(timeIntervalSince1970: 1_800_000_000)
        let privateDecision = NightFlockPrimaryRunSharingDecision(runID: runID, allowsSharing: false, capturedAt: requiredAfter)
        let sharedDecision = NightFlockPrimaryRunSharingDecision(runID: runID, allowsSharing: true, capturedAt: requiredAfter)
        XCTAssertFalse(NightFlockPrimaryRunSharingPolicy.mayShare(runID: runID, startedAt: requiredAfter, decision: privateDecision, requiredAfter: requiredAfter))
        XCTAssertTrue(NightFlockPrimaryRunSharingPolicy.mayShare(runID: runID, startedAt: requiredAfter, decision: sharedDecision, requiredAfter: requiredAfter))
        XCTAssertFalse(NightFlockPrimaryRunSharingPolicy.mayShare(runID: runID, startedAt: requiredAfter, decision: nil, requiredAfter: requiredAfter))
        XCTAssertTrue(NightFlockPrimaryRunSharingPolicy.mayShare(runID: runID, startedAt: requiredAfter.addingTimeInterval(-1), decision: nil, requiredAfter: requiredAfter))
        XCTAssertFalse(NightFlockPrimaryRunSharingPolicy.mayShare(runID: runID, startedAt: requiredAfter, decision: nil, requiredAfter: nil))
    }

    func testPrimaryRunPolicyMarkerSurvivesAccountScopedDecisionClearAndFailsClosedAfterRelaunch() {
        let runID = UUID()
        let installedMarker = Date(timeIntervalSince1970: 1_800_000_000)
        // Account cleanup intentionally removes per-run decisions. The
        // install-wide marker remains, so a surviving modern history record
        // cannot become shareable merely because its account queues cleared.
        let restoredMarker = installedMarker
        XCTAssertFalse(NightFlockPrimaryRunSharingPolicy.mayShare(
            runID: runID,
            startedAt: installedMarker.addingTimeInterval(60),
            decision: nil,
            requiredAfter: restoredMarker
        ))
        XCTAssertTrue(NightFlockPrimaryRunSharingPolicy.mayShare(
            runID: runID,
            startedAt: installedMarker.addingTimeInterval(-60),
            decision: nil,
            requiredAfter: restoredMarker
        ))
    }

    func testSharedNightEmergencyExitUsesOnlyExplicitTerminalReason() {
        XCTAssertEqual(SharedNightEmergencyExitPresentationRules.emergencyExitUsed(completedSuccessfully: false, endedEarlyReason: .emergencyBypass), true)
        XCTAssertEqual(SharedNightEmergencyExitPresentationRules.emergencyExitUsed(completedSuccessfully: true, endedEarlyReason: nil), false)
        XCTAssertEqual(SharedNightEmergencyExitPresentationRules.emergencyExitUsed(completedSuccessfully: false, endedEarlyReason: .userEnded), false)
        XCTAssertNil(SharedNightEmergencyExitPresentationRules.emergencyExitUsed(completedSuccessfully: false, endedEarlyReason: nil))
    }

    func testPrimaryStatusOutboxProvenanceRoundTripsAndReplaysFailClosed() throws {
        let runID = UUID()
        let marker = Date(timeIntervalSince1970: 1_800_000_000)
        let privateDecision = NightFlockPrimaryRunSharingDecision(runID: runID, allowsSharing: false, capturedAt: marker)
        let record = NightFlockV4StatusOutboxRecord(
            sourceEventID: runID, status: .phoneAwayActive, revision: 2,
            observedAt: marker.addingTimeInterval(60), idempotencyKey: "status",
            requiresPrimaryRunDecision: true, originStartedAt: marker
        )
        let restored = try JSONDecoder().decode(NightFlockV4StatusOutboxRecord.self, from: JSONEncoder().encode(record))
        XCTAssertEqual(restored.requiresPrimaryRunDecision, true)
        XCTAssertEqual(restored.originStartedAt, marker)
        let legacyJSON = """
        {"sourceEventID":"\(runID.uuidString)","status":"phoneAwayActive","revision":2,"observedAt":\(marker.timeIntervalSinceReferenceDate),"idempotencyKey":"status","attemptCount":0}
        """
        let legacyDecoder = JSONDecoder()
        legacyDecoder.dateDecodingStrategy = .deferredToDate
        let legacy = try legacyDecoder.decode(NightFlockV4StatusOutboxRecord.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(legacy.requiresPrimaryRunDecision)
        XCTAssertFalse(NightFlockPrimaryRunStatusPublicationRules.mayShare(
            requiresPrimaryRunDecision: restored.requiresPrimaryRunDecision, runID: runID,
            originStartedAt: restored.originStartedAt, observedAt: restored.observedAt,
            decision: privateDecision, requiredAfter: marker
        ))
        XCTAssertTrue(NightFlockPrimaryRunStatusPublicationRules.mayShare(
            requiresPrimaryRunDecision: false, runID: runID, originStartedAt: nil,
            observedAt: marker, decision: nil, requiredAfter: marker
        ))
        XCTAssertFalse(NightFlockPrimaryRunStatusPublicationRules.mayShare(
            requiresPrimaryRunDecision: nil, runID: runID, originStartedAt: nil,
            observedAt: marker, decision: nil, requiredAfter: marker
        ))
    }

    func testPrivatePrimaryNightBlocksSleepWindowButNoRunAndLegacyRemainExplicit() {
        let night = NightFlockLocalDate(year: 2026, month: 9, day: 1)
        XCTAssertFalse(NightFlockSharedHabitSleepReconciliationPolicy.permitsSleepWindow(
            nightEndingDate: night, timeZoneIdentifier: "UTC",
            primaryRuns: [.init(nightEndingDate: night, timeZoneIdentifier: "UTC", mayShare: false)]
        ))
        XCTAssertTrue(NightFlockSharedHabitSleepReconciliationPolicy.permitsSleepWindow(
            nightEndingDate: night, timeZoneIdentifier: "UTC", primaryRuns: []
        ))
        XCTAssertTrue(NightFlockSharedHabitSleepReconciliationPolicy.permitsSleepWindow(
            nightEndingDate: night, timeZoneIdentifier: "UTC",
            primaryRuns: [.init(nightEndingDate: night, timeZoneIdentifier: "UTC", mayShare: true)]
        ))
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
