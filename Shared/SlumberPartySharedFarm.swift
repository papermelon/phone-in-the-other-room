import Foundation

struct SlumberPartyUpdateCheerReceipt: Identifiable, Codable, Equatable, Sendable {
    var id: UUID { reactionID }
    var reactionID: UUID
    var activityID: UUID
    var senderMemberID: UUID
    var recipientMemberID: UUID
    var cheer: NightFlockV4Cheer
    var acceptedAt: Date
    var receivedByAppAt: Date?
}

/// Only the existing visible update streams are eligible. No local history is scanned.
enum SlumberPartySharedFarmRules {
    static func members(in party: NightFlockV4PartyDetail) -> [NightFlockV4Membership] {
        party.memberships.sorted {
            $0.joinedAt == $1.joinedAt ? $0.memberID.uuidString < $1.memberID.uuidString : $0.joinedAt < $1.joinedAt
        }
    }

    static func updates(for memberID: UUID, in party: NightFlockV4PartyDetail) -> [NightFlockV4SharedActivity] {
        guard let member = party.memberships.first(where: { $0.memberID == memberID }) else { return [] }
        let shared = party.summary.supportsMembershipSharing ? (party.sharedActivities + party.memberUpdates).filter {
            $0.partyID == party.summary.partyID && $0.memberID == memberID && $0.occurredAt >= member.joinedAt
        } : []
        let mirrored = Set(shared.compactMap(\.roundActivityID))
        let legacy = party.activities.filter {
            $0.partyID == party.summary.partyID && $0.memberID == memberID && !mirrored.contains($0.activityID)
                && $0.occurredAt >= member.joinedAt
        }.map {
            NightFlockV4SharedActivity(activityID: $0.activityID, partyID: $0.partyID, memberID: $0.memberID,
                roundID: $0.roundID, day: $0.day, kind: $0.kind, status: $0.status,
                roundedMinutes: $0.roundedMinutes, occurredAt: $0.occurredAt,
                roundActivityID: $0.activityID)
        }
        var seen = Set<UUID>()
        return (shared + legacy).filter { seen.insert($0.id).inserted }.sorted {
            $0.occurredAt == $1.occurredAt ? $0.activityID.uuidString < $1.activityID.uuidString : $0.occurredAt > $1.occurredAt
        }
    }

    static func cheeredUpdatesForMe(in party: NightFlockV4PartyDetail) -> [NightFlockV4SharedActivity] {
        guard let me = party.myMemberID else { return [] }
        return updates(for: me, in: party).filter { update in
            receipts(for: update.id, in: party).contains { $0.recipientMemberID == me }
        }
    }

    static func receipts(for activityID: UUID, in party: NightFlockV4PartyDetail) -> [SlumberPartyUpdateCheerReceipt] {
        let visible = Set(party.memberships.map(\.memberID))
        var seen = Set<String>()
        return party.updateCheerReceipts.filter {
            $0.activityID == activityID && visible.contains($0.senderMemberID) && visible.contains($0.recipientMemberID)
                && (party.myMemberID == $0.senderMemberID || party.myMemberID == $0.recipientMemberID)
        }.sorted {
            $0.acceptedAt == $1.acceptedAt ? $0.id.uuidString < $1.id.uuidString : $0.acceptedAt < $1.acceptedAt
        }.filter { seen.insert("\($0.senderMemberID):\($0.cheer.rawValue)").inserted }
    }
}

struct SlumberPartyQueuedUpdateCheer: Codable, Equatable, Sendable {
    var partyID: UUID
    var activityID: UUID
    var membershipStream: Bool
    var senderMemberID: UUID
    var senderJoinedAt: Date
    var recipientMemberID: UUID
    var recipientJoinedAt: Date
    var cheer: NightFlockV4Cheer
    var createdAt: Date
    var identity: String { "\(partyID):\(activityID):\(senderMemberID):\(cheer.rawValue)" }
    var command: NightFlockV4Command {
        let key = NightFlockV4Idempotency.command(membershipStream ? "membership-cheer-\(cheer.rawValue)" : "cheer-\(cheer.rawValue)", seed: activityID)
        return membershipStream ? .reactMembership(partyID: partyID, activityID: activityID, cheer: cheer, idempotencyKey: key)
            : .react(partyID: partyID, activityID: activityID, cheer: cheer, idempotencyKey: key)
    }
    func isEligible(in party: NightFlockV4PartyDetail, now: Date) -> Bool {
        guard party.summary.partyID == partyID, party.myMemberID == senderMemberID,
              now.timeIntervalSince(createdAt) < 90 * 86400,
              party.memberships.contains(where: { $0.memberID == senderMemberID && $0.joinedAt == senderJoinedAt }),
              party.memberships.contains(where: { $0.memberID == recipientMemberID && $0.joinedAt == recipientJoinedAt }),
              senderMemberID != recipientMemberID else { return false }
        return SlumberPartySharedFarmRules.updates(for: recipientMemberID, in: party).contains { $0.activityID == activityID }
    }
}
