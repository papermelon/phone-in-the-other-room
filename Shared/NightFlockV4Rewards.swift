import Foundation

/// v4 grants use party/round identifiers while the existing Farm ledger uses
/// the earlier challenge-shaped grant value. This adapter preserves the server
/// grant UUID—the idempotency key that matters locally—without widening the
/// social payload to Farm state.
enum NightFlockV4GrantAdapter {
    static func legacyGrant(from item: NightFlockV4GrantInboxItem) -> NightFlockRewardGrant? {
        guard item.acknowledgedAt == nil, item.woolAmount >= 0 else { return nil }
        let rewardKind = NightFlockRewardKind(rawValue: item.kind) ?? .wool
        return NightFlockRewardGrant(
            id: item.grantID,
            challengeID: item.partyID,
            memberID: item.partyID,
            milestone: .qualifyingNight(day: 1),
            rewardKind: rewardKind,
            woolAmount: item.woolAmount,
            createdAt: item.issuedAt
        )
    }
}
