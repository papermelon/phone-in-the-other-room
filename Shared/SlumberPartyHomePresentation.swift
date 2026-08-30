import Foundation

/// The compact Home surface has a deliberately narrower contract than party
/// detail: current expiring statuses make members recognizable, while one
/// separate highlight carries a recent factual completion or encouragement.
enum SlumberPartyHomePresentation {
    static let recentHighlightInterval: TimeInterval = 48 * 60 * 60
    static let maximumMemberPreviews = 3

    static func memberPreviews(
        in party: NightFlockV4PartyDetail,
        at date: Date = Date()
    ) -> [SlumberPartyHomeMemberPreview] {
        let members = party.memberships.sorted { lhs, rhs in
            let lhsIsMe = lhs.memberID == party.myMemberID
            let rhsIsMe = rhs.memberID == party.myMemberID
            if lhsIsMe != rhsIsMe { return lhsIsMe }
            if lhs.joinedAt != rhs.joinedAt { return lhs.joinedAt < rhs.joinedAt }
            return lhs.memberID.uuidString < rhs.memberID.uuidString
        }
        return members.prefix(maximumMemberPreviews).map { member in
            let status = NightFlockV4Presentation.member(member, in: party, at: date).liveStatusTitle
            return SlumberPartyHomeMemberPreview(
                memberID: member.memberID,
                displayName: displayName(for: member),
                isCurrentUser: member.memberID == party.myMemberID,
                liveStatusTitle: status
            )
        }
    }

    static func highlightCandidates(
        in party: NightFlockV4PartyDetail,
        at date: Date = Date()
    ) -> [SlumberPartyHomeHighlight] {
        let currentMemberIDs = Set(party.memberships.map(\.memberID))
        let shared = freshSharedActivities(in: party, at: date)
        let encouragements = shared.compactMap { activity -> SlumberPartyHomeHighlight? in
            guard activity.memberID == party.myMemberID,
                  activity.mySourceEventID != nil
            else { return nil }
            let count = party.sharedCheers
                .filter { $0.activityID == activity.activityID && !$0.sentByMe }
                .reduce(0) { $0 + max(0, $1.count) }
            guard count > 0 else { return nil }
            return SlumberPartyHomeHighlight(
                id: .receivedEncouragement(activity.activityID),
                title: count == 1 ? "1 warm cheer for your \(modeTitle(activity.kind))." : "\(count) warm cheers for your \(modeTitle(activity.kind)).",
                detail: "A recent shared moment from this party.",
                occurredAt: activity.occurredAt,
                expiresAt: activity.occurredAt.addingTimeInterval(recentHighlightInterval)
            )
        }
        let sharedCompletions = shared.compactMap { completionHighlight(for: $0, in: party) }
        let representedLegacyIDs = Set(party.sharedActivities.compactMap(\.roundActivityID))
            .union(Set(party.sharedActivities.map(\.activityID)))
        let legacyCompletions = party.activities
            .filter {
                $0.partyID == party.summary.partyID
                    && currentMemberIDs.contains($0.memberID)
                    && !representedLegacyIDs.contains($0.activityID)
                    && isFresh($0.occurredAt, at: date)
                    && $0.status == .completed
            }
            .map { completionHighlight(for: $0, in: party) }

        var candidates = encouragements.sorted(by: mostRecent)
        candidates += (sharedCompletions + legacyCompletions).sorted(by: mostRecent)
        if let round = party.summary.currentRound,
           let completedRound = completedRoundHighlight(for: round, at: date) {
            candidates.append(completedRound)
        }
        return candidates
    }

    /// Preserve a visible highlight for the current visit unless its factual
    /// source is no longer eligible. This prevents refreshes from becoming a
    /// carousel while still admitting the first meaningful arriving update.
    static func highlight(
        in party: NightFlockV4PartyDetail,
        preserving id: SlumberPartyHomeHighlightID?,
        at date: Date = Date()
    ) -> SlumberPartyHomeHighlight? {
        let candidates = highlightCandidates(in: party, at: date)
        return candidates.first(where: { $0.id == id }) ?? candidates.first
    }

    static func nextHighlightInvalidation(
        in party: NightFlockV4PartyDetail,
        at date: Date = Date()
    ) -> Date? {
        highlightCandidates(in: party, at: date)
            .compactMap(\.expiresAt)
            .filter { $0 > date }
            .min()
    }

    private static func freshSharedActivities(
        in party: NightFlockV4PartyDetail,
        at date: Date
    ) -> [NightFlockV4SharedActivity] {
        guard party.summary.supportsMembershipSharing else { return [] }
        let currentMemberIDs = Set(party.memberships.map(\.memberID))
        return party.sharedActivities.filter {
            $0.partyID == party.summary.partyID
                && currentMemberIDs.contains($0.memberID)
                && isFresh($0.occurredAt, at: date)
        }
    }

    private static func completionHighlight(
        for activity: NightFlockV4SharedActivity,
        in party: NightFlockV4PartyDetail
    ) -> SlumberPartyHomeHighlight? {
        guard activity.status == .completed else { return nil }
        return SlumberPartyHomeHighlight(
            id: .completedActivity(activity.activityID),
            title: "\(memberName(for: activity.memberID, in: party)) completed \(modeTitle(activity.kind)).",
            detail: "\(max(0, activity.roundedMinutes)) quiet min · Recent shared moment",
            occurredAt: activity.occurredAt,
            expiresAt: activity.occurredAt.addingTimeInterval(recentHighlightInterval)
        )
    }

    private static func completionHighlight(
        for activity: NightFlockV4Activity,
        in party: NightFlockV4PartyDetail
    ) -> SlumberPartyHomeHighlight {
        SlumberPartyHomeHighlight(
            id: .completedActivity(activity.activityID),
            title: "\(memberName(for: activity.memberID, in: party)) completed \(modeTitle(activity.kind)).",
            detail: "\(max(0, activity.roundedMinutes)) quiet min · Recent shared moment",
            occurredAt: activity.occurredAt,
            expiresAt: activity.occurredAt.addingTimeInterval(recentHighlightInterval)
        )
    }

    private static func isFresh(_ date: Date, at now: Date) -> Bool {
        date <= now && date > now.addingTimeInterval(-recentHighlightInterval)
    }

    private static func completedRoundHighlight(
        for round: NightFlockV4Round,
        at date: Date
    ) -> SlumberPartyHomeHighlight? {
        guard round.status == .completed,
              let timeZone = TimeZone(identifier: round.timeZoneIdentifier),
              let start = round.startsOn.date(in: round.timeZoneIdentifier)
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let completedAt = calendar.date(
            byAdding: .day,
            value: NightFlockV4Rules.roundNightCount,
            to: start
        ), isFresh(completedAt, at: date) else { return nil }
        return SlumberPartyHomeHighlight(
            id: .completedRound(round.roundID),
            title: "This seven-night round is complete.",
            detail: "Open the group for its shared history.",
            occurredAt: completedAt,
            expiresAt: completedAt.addingTimeInterval(recentHighlightInterval)
        )
    }

    private static func mostRecent(_ lhs: SlumberPartyHomeHighlight, _ rhs: SlumberPartyHomeHighlight) -> Bool {
        switch (lhs.occurredAt, rhs.occurredAt) {
        case let (lhs?, rhs?) where lhs != rhs: return lhs > rhs
        default: return lhs.id.sortKey > rhs.id.sortKey
        }
    }

    private static func displayName(for member: NightFlockV4Membership) -> String {
        member.profile.displayName.isEmpty ? "A group member" : member.profile.displayName
    }

    private static func memberName(for memberID: UUID, in party: NightFlockV4PartyDetail) -> String {
        party.memberships.first(where: { $0.memberID == memberID }).map(displayName(for:)) ?? "A group member"
    }

    private static func modeTitle(_ kind: NightFlockV4ActivityKind) -> String {
        kind == .windDown ? "Wind Down" : "Phone Away"
    }
}

struct SlumberPartyHomeMemberPreview: Identifiable, Equatable, Sendable {
    var id: UUID { memberID }
    var memberID: UUID
    var displayName: String
    var isCurrentUser: Bool
    var liveStatusTitle: String?

    var statusTitle: String { liveStatusTitle ?? "No current status" }
}

enum SlumberPartyHomeHighlightID: Hashable, Sendable {
    case receivedEncouragement(UUID)
    case completedActivity(UUID)
    case completedRound(UUID)

    fileprivate var sortKey: String {
        switch self {
        case let .receivedEncouragement(id): return "encouragement:\(id.uuidString)"
        case let .completedActivity(id): return "activity:\(id.uuidString)"
        case let .completedRound(id): return "round:\(id.uuidString)"
        }
    }
}

struct SlumberPartyHomeHighlight: Identifiable, Equatable, Sendable {
    var id: SlumberPartyHomeHighlightID
    var title: String
    var detail: String
    var occurredAt: Date?
    var expiresAt: Date?
}
