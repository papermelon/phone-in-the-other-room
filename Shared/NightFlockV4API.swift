import Foundation

struct NightFlockV4ListStateRequest: Encodable, Equatable, Sendable {
    let schemaVersion = NightFlockV4Rules.schemaVersion
    let scope = "list"
}

struct NightFlockV4PartyStateRequest: Encodable, Equatable, Sendable {
    let schemaVersion = NightFlockV4Rules.schemaVersion
    let scope = "party"
    var partyID: UUID
    var cursor: String?
}

enum CountingSheepDisplayNameSelectionKind: String, Codable, Sendable { case initial, migration, change }

/// Decides the metadata carried by a routine profile synchronization. The
/// server remains authoritative for revisions and name-change limits; this
/// merely prevents a cosmetic sync from presenting itself as a rename.
struct NightFlockV4ProfileSyncPlan: Equatable, Sendable {
    var profile: CountingSheepUserProfile
    var nameSelectionKind: CountingSheepDisplayNameSelectionKind
    var avatarID: String?
}

enum NightFlockV4ProfileSyncRules {
    static func routinePlan(
        local: CountingSheepUserProfile,
        server: CountingSheepUserProfile?,
        supportsSocialAvatar: Bool,
        supportsHeadShape: Bool = false
    ) -> NightFlockV4ProfileSyncPlan? {
        let localPresentation = wirePresentation(
            local.presentation,
            supportsSocialAvatar: supportsSocialAvatar,
            supportsHeadShape: supportsHeadShape
        )
        guard server == nil
                || server?.displayName != local.displayName
                || wirePresentation(
                    server?.presentation ?? .defaultValue,
                    supportsSocialAvatar: supportsSocialAvatar,
                    supportsHeadShape: supportsHeadShape
                ) != localPresentation
        else { return nil }

        guard let server else {
            return NightFlockV4ProfileSyncPlan(
                profile: local,
                nameSelectionKind: local.hasEstablishedDisplayName ? .migration : .initial,
                avatarID: supportsSocialAvatar ? local.presentation.avatarID : nil
            )
        }

        var profile = local
        // The server's revision is the conditional-write baseline. An equal
        // name is deliberately copied back so a cosmetic update cannot claim
        // to rename the Shepherd.
        profile.revision = server.revision
        if local.displayName == server.displayName {
            profile.displayName = server.displayName
            return NightFlockV4ProfileSyncPlan(
                profile: profile,
                nameSelectionKind: .migration,
                avatarID: supportsSocialAvatar ? local.presentation.avatarID : nil
            )
        }
        return NightFlockV4ProfileSyncPlan(
            profile: profile,
            nameSelectionKind: .change,
            avatarID: supportsSocialAvatar ? local.presentation.avatarID : nil
        )
    }

    private static func wirePresentation(
        _ presentation: CountingSheepPublicPresentation,
        supportsSocialAvatar: Bool,
        supportsHeadShape: Bool = false
    ) -> CountingSheepPublicPresentation {
        var projected = presentation
        if !supportsHeadShape { projected.headShapeID = nil }
        if !supportsSocialAvatar {
            projected.avatarID = SocialAvatarRules.shepherdID
        }
        return projected
    }
}

enum NightFlockV4Command: Equatable, Sendable {
    case createParty(name: String, timeZoneIdentifier: String, idempotencyKey: String)
    case renameParty(partyID: UUID, name: String, idempotencyKey: String)
    case startRound(partyID: UUID, timeZoneIdentifier: String, idempotencyKey: String)
    case createInvite(partyID: UUID, idempotencyKey: String)
    case replaceInvite(partyID: UUID, expectedInviteID: UUID, idempotencyKey: String)
    case revokeInvite(partyID: UUID, inviteID: UUID, idempotencyKey: String)
    case retrieveInvite(partyID: UUID, idempotencyKey: String)
    case previewInvite(inviteCode: String, idempotencyKey: String)
    case redeemInvite(inviteCode: String, idempotencyKey: String)
    case leaveParty(partyID: UUID, idempotencyKey: String)
    case deleteParty(partyID: UUID, idempotencyKey: String)
    case blockMember(partyID: UUID, memberID: UUID, idempotencyKey: String)
    case reportMember(partyID: UUID, memberID: UUID, reason: NightFlockReportReason, idempotencyKey: String)
    case deleteAccount(idempotencyKey: String)
    case cheerMember(partyID: UUID, memberID: UUID, cheer: NightFlockV4Cheer, idempotencyKey: String)
    case cheerMembershipMember(partyID: UUID, memberID: UUID, statusID: UUID, cheer: NightFlockV4Cheer, idempotencyKey: String)
    case updatePublicProfile(expectedRevision: Int, nameSelectionKind: CountingSheepDisplayNameSelectionKind, displayName: String, presentation: CountingSheepPublicPresentation, avatarID: String? = nil, idempotencyKey: String)
    case publishActivity(NightFlockV4OutboxSourceRecord)
    case publishStatus(sourceEventID: UUID, status: NightFlockV4LiveStatusKind, revision: Int, observedAt: Date, idempotencyKey: String)
    case publishMembershipStatus(sourceEventID: UUID, status: NightFlockV4LiveStatusKind, revision: Int, observedAt: Date, idempotencyKey: String)
    case completeBackfill(partyID: UUID, roundID: UUID, cursor: String, idempotencyKey: String)
    case react(partyID: UUID, activityID: UUID, cheer: NightFlockV4Cheer, idempotencyKey: String)
    case reactMembership(partyID: UUID, activityID: UUID, cheer: NightFlockV4Cheer, idempotencyKey: String)
    case acknowledgeUpdateCheer(partyID: UUID, reactionID: UUID, idempotencyKey: String)
    case acknowledgeGrant(grantID: UUID, idempotencyKey: String)
}

struct NightFlockV4CommandRequest: Encodable, Equatable, Sendable {
    let schemaVersion = NightFlockV4Rules.schemaVersion
    var command: NightFlockV4Command

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, command, partyID, name, timeZoneIdentifier, expectedInviteID, inviteID, inviteCode
        case headShapeID, expectedRevision, nameSelectionKind, displayName, skinToneID, hairStyleID, shepherdOutfitID, shepherdAccessoryID
        case ollieOrnamentID, featuredSheepDefinitionID, pastureThemeID, avatarID, sourceEventID, kind, outcome, startedAt, endedAt
        case windDownMinutes, phoneAwayMinutes, statusRevision, status, revision, observedAt, roundID, cursor
        case reactionID, idempotencyKey, activityID, cheer, grantID, memberID, reason, sharingScope, statusID
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        switch command {
        case let .createParty(name, timeZoneIdentifier, key):
            try c.encode("createParty", forKey: .command); try c.encode(name, forKey: .name); try c.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier); try c.encode(key, forKey: .idempotencyKey)
        case let .renameParty(partyID, name, key):
            try c.encode("renameParty", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(name, forKey: .name); try c.encode(key, forKey: .idempotencyKey)
        case let .startRound(partyID, timeZoneIdentifier, key):
            try c.encode("startRound", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier); try c.encode(key, forKey: .idempotencyKey)
        case let .createInvite(partyID, key): try c.encode("createInvite", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(key, forKey: .idempotencyKey)
        case let .replaceInvite(partyID, expectedInviteID, key): try c.encode("replaceInvite", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(expectedInviteID, forKey: .expectedInviteID); try c.encode(key, forKey: .idempotencyKey)
        case let .revokeInvite(partyID, inviteID, key): try c.encode("revokeInvite", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(inviteID, forKey: .inviteID); try c.encode(key, forKey: .idempotencyKey)
        case let .retrieveInvite(partyID, key): try c.encode("retrieveInvite", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(key, forKey: .idempotencyKey)
        case let .previewInvite(inviteCode, key): try c.encode("previewInvite", forKey: .command); try c.encode(inviteCode, forKey: .inviteCode); try c.encode(key, forKey: .idempotencyKey)
        case let .redeemInvite(inviteCode, key): try c.encode("redeemInvite", forKey: .command); try c.encode(inviteCode, forKey: .inviteCode); try c.encode(key, forKey: .idempotencyKey)
        case let .leaveParty(partyID, key): try c.encode("leaveParty", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(key, forKey: .idempotencyKey)
        case let .deleteParty(partyID, key): try c.encode("deleteParty", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(key, forKey: .idempotencyKey)
        case let .blockMember(partyID, memberID, key): try c.encode("blockMember", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(memberID, forKey: .memberID); try c.encode(key, forKey: .idempotencyKey)
        case let .reportMember(partyID, memberID, reason, key): try c.encode("reportMember", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(memberID, forKey: .memberID); try c.encode(reason, forKey: .reason); try c.encode(key, forKey: .idempotencyKey)
        case let .deleteAccount(key): try c.encode("deleteAccount", forKey: .command); try c.encode(key, forKey: .idempotencyKey)
        case let .cheerMember(partyID, memberID, cheer, key): try c.encode("cheerMember", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(memberID, forKey: .memberID); try c.encode(cheer, forKey: .cheer); try c.encode(key, forKey: .idempotencyKey)
        case let .cheerMembershipMember(partyID, memberID, statusID, cheer, key):
            try c.encode("cheerMember", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(memberID, forKey: .memberID); try c.encode(statusID, forKey: .statusID); try c.encode(cheer, forKey: .cheer); try c.encode(key, forKey: .idempotencyKey)
        case let .updatePublicProfile(expectedRevision, nameSelectionKind, displayName, presentation, avatarID, key):
            try c.encode("updatePublicProfile", forKey: .command); try c.encode(expectedRevision, forKey: .expectedRevision); try c.encode(nameSelectionKind, forKey: .nameSelectionKind); try c.encode(displayName, forKey: .displayName)
            try c.encodeIfPresent(presentation.headShapeID, forKey: .headShapeID)
            try c.encode(presentation.skinToneID, forKey: .skinToneID); try c.encode(presentation.hairStyleID, forKey: .hairStyleID); try c.encode(presentation.shepherdOutfitID, forKey: .shepherdOutfitID); try c.encode(presentation.shepherdAccessoryID, forKey: .shepherdAccessoryID); try c.encode(presentation.ollieOrnamentID, forKey: .ollieOrnamentID); try c.encode(presentation.featuredSheepDefinitionID, forKey: .featuredSheepDefinitionID); try c.encode(presentation.pastureThemeID, forKey: .pastureThemeID); try c.encodeIfPresent(avatarID, forKey: .avatarID); try c.encode(key, forKey: .idempotencyKey)
        case let .publishActivity(record):
            let source = record.source
            try c.encode("publishActivity", forKey: .command); try c.encode(source.sourceEventID, forKey: .sourceEventID); try c.encode(source.kind, forKey: .kind); try c.encode(source.outcome, forKey: .outcome); try c.encode(source.startedAt, forKey: .startedAt); try c.encode(source.endedAt, forKey: .endedAt); try c.encode(source.windDownMinutes, forKey: .windDownMinutes); try c.encode(source.phoneAwayMinutes, forKey: .phoneAwayMinutes); try c.encode(source.statusRevision, forKey: .statusRevision); try c.encode(record.idempotencyKey, forKey: .idempotencyKey)
            try c.encodeIfPresent(record.sharingScope, forKey: .sharingScope)
        case let .publishStatus(sourceEventID, status, revision, observedAt, key):
            try c.encode("publishStatus", forKey: .command); try c.encode(sourceEventID, forKey: .sourceEventID); try c.encode(status, forKey: .status); try c.encode(revision, forKey: .revision); try c.encode(observedAt, forKey: .observedAt); try c.encode(key, forKey: .idempotencyKey)
        case let .publishMembershipStatus(sourceEventID, status, revision, observedAt, key):
            try c.encode("publishStatus", forKey: .command); try c.encode(sourceEventID, forKey: .sourceEventID); try c.encode(status, forKey: .status); try c.encode(revision, forKey: .revision); try c.encode(observedAt, forKey: .observedAt); try c.encode(NightFlockV4SharingScope.membership, forKey: .sharingScope); try c.encode(key, forKey: .idempotencyKey)
        case let .completeBackfill(partyID, roundID, cursor, key):
            try c.encode("completeBackfill", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(roundID, forKey: .roundID); try c.encode(cursor, forKey: .cursor); try c.encode(key, forKey: .idempotencyKey)
        case let .react(partyID, activityID, cheer, key): try c.encode("react", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(activityID, forKey: .activityID); try c.encode(cheer, forKey: .cheer); try c.encode(key, forKey: .idempotencyKey)
        case let .reactMembership(partyID, activityID, cheer, key):
            try c.encode("react", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(activityID, forKey: .activityID); try c.encode(cheer, forKey: .cheer); try c.encode(NightFlockV4SharingScope.membership, forKey: .sharingScope); try c.encode(key, forKey: .idempotencyKey)
        case let .acknowledgeUpdateCheer(partyID, reactionID, key):
            try c.encode("acknowledgeUpdateCheer", forKey: .command); try c.encode(partyID, forKey: .partyID); try c.encode(reactionID, forKey: .reactionID); try c.encode(key, forKey: .idempotencyKey)
        case let .acknowledgeGrant(grantID, key): try c.encode("acknowledgeGrant", forKey: .command); try c.encode(grantID, forKey: .grantID); try c.encode(key, forKey: .idempotencyKey)
        }
    }
}

struct NightFlockV4ListStateResponse: Decodable, Equatable, Sendable {
    var schemaVersion: Int = NightFlockV4Rules.schemaVersion
    var parties: [NightFlockV4PartySummary]
    var profile: CountingSheepUserProfile?
    var grantInbox: [NightFlockV4GrantInboxItem]
    var profileHeadShapeVersion: Int? = nil
    var profileAvatarVersion: Int?
    /// Absent keeps this version on the existing V4 contract. Shared habits
    /// must never be inferred from membership-stream capability alone.
    var sharedHabitsVersion: Int?
    /// Independent plan-instance capability. A v2 habits server may still
    /// omit this while rolling out; the UI keeps plan sharing unavailable.
    var sharedRoutinePlansVersion: Int?
    var retainedSharedHabitParties: [NightFlockRetainedSharedHabitParty]

    private enum CodingKeys: String, CodingKey { case schemaVersion, parties, profile, grantInbox, profileHeadShapeVersion, profileAvatarVersion, sharedHabitsVersion, sharedRoutinePlansVersion, retainedSharedHabitParties }

    init(
        parties: [NightFlockV4PartySummary],
        profile: CountingSheepUserProfile? = nil,
        grantInbox: [NightFlockV4GrantInboxItem] = [],
        profileAvatarVersion: Int? = nil,
        sharedHabitsVersion: Int? = nil,
        sharedRoutinePlansVersion: Int? = nil,
        retainedSharedHabitParties: [NightFlockRetainedSharedHabitParty] = []
    ) {
        self.parties = parties
        self.profile = profile
        self.grantInbox = grantInbox
        self.profileAvatarVersion = profileAvatarVersion
        self.sharedHabitsVersion = sharedHabitsVersion
        self.sharedRoutinePlansVersion = sharedRoutinePlansVersion
        self.retainedSharedHabitParties = retainedSharedHabitParties
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? NightFlockV4Rules.schemaVersion
        parties = try container.decodeIfPresent([NightFlockV4PartySummary].self, forKey: .parties) ?? []
        profile = try container.decodeIfPresent(CountingSheepUserProfile.self, forKey: .profile)
        grantInbox = try container.decodeIfPresent([NightFlockV4GrantInboxItem].self, forKey: .grantInbox) ?? []
        profileHeadShapeVersion = try container.decodeIfPresent(Int.self, forKey: .profileHeadShapeVersion)
        profileAvatarVersion = try container.decodeIfPresent(Int.self, forKey: .profileAvatarVersion)
        sharedHabitsVersion = try container.decodeIfPresent(Int.self, forKey: .sharedHabitsVersion)
        sharedRoutinePlansVersion = try container.decodeIfPresent(Int.self, forKey: .sharedRoutinePlansVersion)
        retainedSharedHabitParties = try container.decodeIfPresent([NightFlockRetainedSharedHabitParty].self, forKey: .retainedSharedHabitParties) ?? []
    }

    var supportsProfileAvatar: Bool { profileAvatarVersion == 1 }
    var supportsSharedHabits: Bool { sharedHabitsVersion == 1 || sharedHabitsVersion == 2 }
    var supportsSharedNightPlans: Bool { sharedHabitsVersion == 2 && sharedRoutinePlansVersion == 1 }
}

/// Transport envelope returned by the state endpoint. The snapshot remains
/// deliberately distinct from command responses and support request IDs.
struct NightFlockV4StateEnvelope<Snapshot: Decodable>: Decodable {
    var schemaVersion: Int
    var requestID: String?
    var snapshot: Snapshot
}

struct NightFlockV4PartyStateResponse: Decodable, Equatable, Sendable {
    var schemaVersion: Int = NightFlockV4Rules.schemaVersion
    var party: NightFlockV4PartyDetail?

    private enum CodingKeys: String, CodingKey { case schemaVersion, party }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? NightFlockV4Rules.schemaVersion
        party = try container.decodeIfPresent(NightFlockV4PartyDetail.self, forKey: .party)
    }
}

struct NightFlockV4InvitePreview: Codable, Equatable, Sendable {
    var partyID: UUID
    var name: String
    var memberCount: Int
    var capacity: Int
}

struct NightFlockV4CommandResponse: Decodable, Equatable, Sendable {
    var schemaVersion: Int
    var accepted: Bool
    var party: NightFlockV4PartyDetail?
    var invitation: NightFlockV4InvitationMetadata?
    var profile: CountingSheepUserProfile?
    var inviteCode: String?
    var inviteID: UUID?
    var invitePreview: NightFlockV4InvitePreview?
    /// Canonical command-bound party identity for successful create/redeem.
    /// Old servers omit it; callers must not infer a party from a list diff.
    var resolvedPartyID: UUID?
    var requestID: String?
    var deleteAccount: Bool?

    init(
        schemaVersion: Int = NightFlockV4Rules.schemaVersion,
        accepted: Bool,
        party: NightFlockV4PartyDetail? = nil,
        invitation: NightFlockV4InvitationMetadata? = nil,
        profile: CountingSheepUserProfile? = nil,
        inviteCode: String? = nil,
        inviteID: UUID? = nil,
        invitePreview: NightFlockV4InvitePreview? = nil,
        resolvedPartyID: UUID? = nil,
        requestID: String? = nil,
        deleteAccount: Bool? = nil
    ) {
        self.schemaVersion = schemaVersion; self.accepted = accepted; self.party = party
        self.invitation = invitation; self.profile = profile; self.inviteCode = inviteCode
        self.inviteID = inviteID; self.invitePreview = invitePreview; self.requestID = requestID
        self.resolvedPartyID = resolvedPartyID
        self.deleteAccount = deleteAccount
    }
}

enum NightFlockV4Idempotency {
    static func command(_ kind: String, seed: UUID = UUID()) -> String {
        NightFlockV3Idempotency.command("v4-\(kind)", seed: seed)
    }
}
