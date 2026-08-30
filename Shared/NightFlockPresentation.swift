import Foundation

/// Keeps canonical party reads monotonic from the client's point of view.
/// Receipt time is presentation metadata; it cannot decide which overlapping
/// request began later.
enum NightFlockV4PartyDetailReconciliation {
    static func accepts(
        requestSequence: UInt64,
        after latestAcceptedRequestSequence: UInt64?
    ) -> Bool {
        guard let latestAcceptedRequestSequence else { return true }
        return requestSequence > latestAcceptedRequestSequence
    }
}

enum NightFlockV4BackfillEligibility {
    static func accepts(
        _ record: NightWatchRecord,
        knownPracticeRunID: UUID?
    ) -> Bool {
        guard record.id != knownPracticeRunID, record.isPractice != true else { return false }
        // Legacy additional-quiet records may be onboarding practice. Their
        // missing provenance is not proof of an ordinary session.
        return record.isPractice == false || record.role == .primarySleepBookend
    }
}

struct NightFlockAggregatePresentation: Equatable, Sendable {
    var title: String
    var detail: String

    static func nighttime(positiveCount: Int, memberCount: Int) -> Self {
        presentation(
            positiveCount: positiveCount,
            memberCount: memberCount,
            allTitle: "The whole flock has tucked in.",
            someTitle: "Someone in the flock has tucked in.",
            countTitle: { "\($0) phones are resting away." },
            emptyDetail: "Your group’s shared progress will appear here when someone chooses to share an update.",
            positiveDetail: "Named progress is shown only inside this invited group."
        )
    }

    static func morning(positiveCount: Int, memberCount: Int) -> Self {
        presentation(
            positiveCount: positiveCount,
            memberCount: memberCount,
            allTitle: "The whole flock kept the morning quiet.",
            someTitle: "A quiet morning reached the pasture.",
            countTitle: { "\($0) quiet mornings reached the pasture." },
            emptyDetail: "Your group’s morning progress will appear here when someone chooses to share an update.",
            positiveDetail: "No update shared is not counted as completion."
        )
    }

    private static func presentation(
        positiveCount: Int,
        memberCount: Int,
        allTitle: String,
        someTitle: String,
        countTitle: (Int) -> String,
        emptyDetail: String,
        positiveDetail: String
    ) -> Self {
        let count = max(0, min(positiveCount, memberCount))
        guard count > 0 else {
            return Self(title: "Your group is getting ready.", detail: emptyDetail)
        }
        if count == memberCount {
            return Self(title: allTitle, detail: positiveDetail)
        }
        if memberCount <= 3 {
            return Self(title: someTitle, detail: positiveDetail)
        }
        return Self(title: countTitle(count), detail: positiveDetail)
    }
}

enum NightFlockPrivacyPresentation {
    static func pastureEntries(
        _ entries: [NightFlockPastureEntry],
        memberCount: Int
    ) -> [NightFlockPastureEntry] {
        memberCount <= 3 ? Array(entries.prefix(1)) : entries
    }
}

struct NightFlockHomeSummary: Equatable, Sendable {
    var title: String
    var detail: String
    var challengeDay: Int?
    var lifecycle: NightFlockV4PresentationLifecycle = .none
    var partyCount: Int = 0
    var memberCount: Int? = nil
    var destinationPartyID: UUID? = nil

    static let invitation = Self(
        title: "Choose a Wind Down goal together",
        detail: "Invite people you know, share what helps, and keep one another going for seven nights.",
        challengeDay: nil
    )

    static func make(from snapshot: NightFlockSnapshot, at date: Date = Date()) -> Self {
        let day = NightFlockChallengeDayRules.challengeDay(at: date, challenge: snapshot.challenge)
        if let goal = snapshot.challenge.sharedGoal {
            let detail: String
            if snapshot.challenge.status == .pending {
                detail = "Everyone can keep their own bedtime and routine while the lobby gets ready."
            } else if snapshot.challenge.status == .completed {
                detail = "Your invited group completed the seven-night Wind Down commitment."
            } else {
                detail = "Your group is following one shared Wind Down goal."
            }
            return Self(title: goal.title, detail: detail, challengeDay: day)
        }
        let summary = day.flatMap { value in snapshot.days.first(where: { $0.day == value }) }
        let presentation = NightFlockAggregatePresentation.nighttime(
            positiveCount: summary?.phoneTuckedCount ?? 0,
            memberCount: snapshot.members.count
        )
        return Self(title: presentation.title, detail: presentation.detail, challengeDay: day)
    }

    /// Schema four is a list of independent parties, not a single shared goal
    /// or lobby. Keep the home card explicit about that distinction.
    static func make(
        from parties: [NightFlockV4PartySummary],
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> Self {
        guard !parties.isEmpty else {
            return Self(
                title: "Your Slumber Parties",
                detail: "Create a party or join one with an invitation.",
                challengeDay: nil,
                lifecycle: .none,
                partyCount: 0,
                memberCount: nil,
                destinationPartyID: nil
            )
        }
        guard parties.count == 1, let party = parties.first else {
            return Self(
                title: "\(parties.count) Slumber Parties",
                detail: "Choose a party to see its members and seven-night round.",
                challengeDay: nil,
                lifecycle: .multiple,
                partyCount: parties.count,
                memberCount: nil,
                destinationPartyID: nil
            )
        }
        let lifecycle = NightFlockV4Presentation.lifecycle(
            for: party,
            at: date,
            calendar: calendar
        )
        let day = lifecycle.activeNight
        let role = party.myRole == .host ? "Host" : "Member"
        let memberWord = party.memberCount == 1 ? "member" : "members"
        let round = lifecycle.listStateTitle
        return Self(
            title: party.name,
            detail: "\(role) • \(party.memberCount) \(memberWord) • \(round)",
            challengeDay: day,
            lifecycle: lifecycle,
            partyCount: 1,
            memberCount: party.memberCount,
            destinationPartyID: party.partyID
        )
    }
}

/// Keeps feature discovery independent from account linking and the first V4
/// list response. Passive Home/Farm rendering must not create an account or
/// start transport; it only decides whether the local entry point is visible.
enum NightFlockHomeDiscoveryPolicy {
    static func summary(
        featureEnabled: Bool,
        v4Parties: [NightFlockV4PartySummary]?
    ) -> NightFlockHomeSummary? {
        guard featureEnabled else { return nil }
        return NightFlockHomeSummary.make(from: v4Parties ?? [])
    }
}

enum NightFlockHomeCardContext: Equatable, Sendable {
    case home
    case farm
}

struct NightFlockV4BridgePresentation: Equatable, Sendable {
    var eyebrow: String
    var title: String
    var detail: String

    static func make(
        from summary: NightFlockHomeSummary,
        context: NightFlockHomeCardContext
    ) -> Self {
        switch context {
        case .home:
            let title: String
            let detail: String
            switch summary.lifecycle {
            case .none:
                title = "Start or join a private group"
                detail = "Share quiet nights with family, a partner, or close friends."
            case .needsInvite:
                title = summary.title
                detail = "Invite someone, then start 7 nights together."
            case .readyHost:
                title = summary.title
                detail = "Ready to start 7 nights together."
            case .readyMember:
                title = summary.title
                detail = "Waiting for the host to start 7 nights."
            case let .active(night):
                title = summary.title
                detail = "\(summary.memberCount ?? 0) people · Your Wind Down or Phone Away can become a shared moment."
                return Self(eyebrow: "SLUMBER PARTY · NIGHT \(night) OF 7", title: title, detail: detail)
            case .elapsedHost:
                title = summary.title
                detail = "These 7 nights are complete · Ready for another."
            case .elapsedMember:
                title = summary.title
                detail = "These 7 nights are complete · Waiting for the host."
            case .multiple:
                title = "\(summary.partyCount) Slumber Parties"
                detail = "Choose a party to see its current 7 nights."
            }
            return Self(eyebrow: "SLUMBER PARTY", title: title, detail: detail)
        case .farm:
            if summary.lifecycle == .none {
                return Self(
                    eyebrow: "SLUMBER PARTY · YOUR FARM",
                    title: "Start or join a private group",
                    detail: "Bring your chosen Farm look. Your Farm stays yours."
                )
            }
            return Self(
                eyebrow: "SLUMBER PARTY · YOUR FARM",
                title: "Your Farm look travels with you",
                detail: "Your curated Farm look appears in your parties. Completed shared moments can bring wool home."
            )
        }
    }
}

// MARK: - V4 presentation

/// Presentation-only lifecycle for the long-lived V4 party. This is derived
/// from the server projection and never changes the persisted round model.
enum NightFlockV4PresentationLifecycle: Equatable, Sendable {
    case none
    case needsInvite
    case readyHost
    case readyMember
    case active(night: Int)
    case elapsedHost
    case elapsedMember
    case multiple

    var activeNight: Int? {
        guard case let .active(night) = self else { return nil }
        return night
    }

    var isElapsed: Bool {
        switch self {
        case .elapsedHost, .elapsedMember: return true
        default: return false
        }
    }

    var listStateTitle: String {
        switch self {
        case .needsInvite: return "Invite someone to begin"
        case .readyHost, .readyMember, .elapsedHost, .elapsedMember, .none, .multiple:
            return "Ready for the next 7 nights"
        case let .active(night): return "Night \(night) of 7"
        }
    }
}

struct NightFlockV4PartyCardPresentation: Equatable, Sendable {
    var lifecycle: NightFlockV4PresentationLifecycle
    var roleTitle: String
    var memberCountTitle: String
    var stateTitle: String

    static func make(
        from party: NightFlockV4PartySummary,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> Self {
        let lifecycle = NightFlockV4Presentation.lifecycle(
            for: party,
            at: date,
            calendar: calendar
        )
        return Self(
            lifecycle: lifecycle,
            roleTitle: party.myRole == .host ? "Host" : "Member",
            memberCountTitle: party.memberCount == 1
                ? "1 person"
                : "\(party.memberCount) people",
            stateTitle: lifecycle.listStateTitle
        )
    }
}

struct NightFlockV4ActivityPresentation: Equatable, Sendable {
    var modeTitle: String
    var minutesTitle: String
    var nightTitle: String
    var outcomeTitle: String
    var latestMemberLine: String

    var cardSummary: String { "\(modeTitle) · \(minutesTitle)" }
    var cardState: String { "\(nightTitle) · \(outcomeTitle)" }
}

struct NightFlockV4MemberPresentation: Equatable, Sendable {
    var liveStatus: NightFlockV4LiveStatus?
    var sharedLiveStatus: NightFlockV4SharedLiveStatus?
    var liveStatusTitle: String?
    var latestActivity: NightFlockV4Activity?
    var latestSharedActivity: NightFlockV4SharedActivity?
    var latestActivityLine: String?
    var liveCheerCount: Int

    var liveStatusID: UUID? { sharedLiveStatus?.statusID }
    var liveStatusObservedAt: Date? { sharedLiveStatus?.observedAt ?? liveStatus?.observedAt }
    var hasSharedUpdate: Bool { liveStatus != nil || sharedLiveStatus != nil || latestActivity != nil || latestSharedActivity != nil }
    var noUpdateTitle: String { "No shared update yet" }
    var canSendLiveCheer: Bool {
        let status = sharedLiveStatus?.status ?? liveStatus?.status
        return status == .windDownStarting || status == .phoneAwayActive
    }
}

/// Reconciliation deliberately starts from the canonical membership list. A
/// cached detail may be stale or no longer authorized, so callers must never
/// use it to choose which party IDs can be refreshed.
enum NightFlockV4ObservedPartyRefreshPolicy {
    static func eligiblePartyIDs(from parties: [NightFlockV4PartySummary]) -> Set<UUID> {
        Set(parties.map(\.partyID))
    }
}

struct NightFlockV4DetailPresentation: Equatable, Sendable {
    var lifecycle: NightFlockV4PresentationLifecycle
    var memberCount: Int
    var headerStateTitle: String
    var contextTitle: String
    var contextDetail: String
    var hostActionTitle: String?
    var sharedMomentCount: Int
    var sharedMomentRecap: String

    var showsContextCard: Bool {
        switch lifecycle {
        case .active: return false
        default: return true
        }
    }
}

enum NightFlockV4Presentation {
    static func lifecycle(
        for party: NightFlockV4PartySummary,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> NightFlockV4PresentationLifecycle {
        lifecycle(
            memberCount: party.memberCount,
            role: party.myRole,
            round: party.currentRound,
            at: date,
            calendar: calendar
        )
    }

    static func lifecycle(
        for party: NightFlockV4PartyDetail,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> NightFlockV4PresentationLifecycle {
        lifecycle(
            memberCount: party.memberships.count,
            role: party.summary.myRole,
            round: party.summary.currentRound,
            at: date,
            calendar: calendar
        )
    }

    static func detail(
        for party: NightFlockV4PartyDetail,
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> NightFlockV4DetailPresentation {
        let lifecycle = lifecycle(for: party, at: date, calendar: calendar)
        // This recap remains the original round ledger. Membership moments
        // are rendered separately and never imply a reward or round credit.
        let count = currentRoundActivities(in: party).count
        let recap = sharedMomentRecap(count)
        switch lifecycle {
        case .needsInvite:
            return NightFlockV4DetailPresentation(
                lifecycle: lifecycle,
                memberCount: party.memberships.count,
                headerStateTitle: "1 person · You’re hosting",
                contextTitle: party.summary.supportsMembershipSharing ? "Invite someone to share with" : "Invite someone to begin",
                contextDetail: party.summary.supportsMembershipSharing ? "Slumber Party is ready when someone you trust joins. Seven-night rounds need 2 people; sharing itself is not held for a round." : "Slumber Party starts with 2 people. Your group stays together after these 7 nights.",
                hostActionTitle: nil,
                sharedMomentCount: count,
                sharedMomentRecap: recap
            )
        case .readyHost:
            return NightFlockV4DetailPresentation(
                lifecycle: lifecycle,
                memberCount: party.memberships.count,
                headerStateTitle: "\(party.memberships.count) people · You’re hosting",
                contextTitle: "Ready to start 7 nights together",
                contextDetail: party.summary.supportsMembershipSharing ? "People can share Wind Down and Phone Away moments now. Starting seven nights organizes progress and rewards." : "Shared sessions appear here after you start these 7 nights. Each person uses their own Wind Down or Phone Away.",
                hostActionTitle: "Start 7 nights",
                sharedMomentCount: count,
                sharedMomentRecap: recap
            )
        case .readyMember:
            return NightFlockV4DetailPresentation(
                lifecycle: lifecycle,
                memberCount: party.memberships.count,
                headerStateTitle: "\(party.memberships.count) people · You’re a member",
                contextTitle: party.summary.supportsMembershipSharing ? "Choose the next seven nights when ready" : "Waiting for the host to begin",
                contextDetail: party.summary.supportsMembershipSharing ? "People can share Wind Down and Phone Away moments now. The next seven nights organize progress and rewards." : "Shared sessions appear here after the host starts seven nights. You’ll still use your own Wind Down or Phone Away.",
                hostActionTitle: nil,
                sharedMomentCount: count,
                sharedMomentRecap: recap
            )
        case let .active(night):
            return NightFlockV4DetailPresentation(
                lifecycle: lifecycle,
                memberCount: party.memberships.count,
                headerStateTitle: "Night \(night) of 7 · \(party.memberships.count) people",
                contextTitle: "Night \(night) of 7",
                contextDetail: "Shared Wind Down and Phone Away moments from these 7 nights appear below.",
                hostActionTitle: nil,
                sharedMomentCount: count,
                sharedMomentRecap: recap
            )
        case .elapsedHost:
            return NightFlockV4DetailPresentation(
                lifecycle: lifecycle,
                memberCount: party.memberships.count,
                headerStateTitle: "These 7 nights are complete · \(party.memberships.count) people · You’re hosting",
                contextTitle: "These 7 nights are complete",
                contextDetail: recap,
                hostActionTitle: "Start another 7 nights",
                sharedMomentCount: count,
                sharedMomentRecap: recap
            )
        case .elapsedMember:
            return NightFlockV4DetailPresentation(
                lifecycle: lifecycle,
                memberCount: party.memberships.count,
                headerStateTitle: "These 7 nights are complete · \(party.memberships.count) people · You’re a member",
                contextTitle: "These 7 nights are complete",
                contextDetail: recap,
                hostActionTitle: nil,
                sharedMomentCount: count,
                sharedMomentRecap: recap
            )
        case .none, .multiple:
            return NightFlockV4DetailPresentation(
                lifecycle: lifecycle,
                memberCount: party.memberships.count,
                headerStateTitle: "\(party.memberships.count) people",
                contextTitle: "Ready for the next 7 nights",
                contextDetail: "Each person uses their own Wind Down or Phone Away.",
                hostActionTitle: nil,
                sharedMomentCount: count,
                sharedMomentRecap: recap
            )
        }
    }

    static func member(
        _ member: NightFlockV4Membership,
        in party: NightFlockV4PartyDetail,
        at date: Date = Date()
    ) -> NightFlockV4MemberPresentation {
        let roundID = party.summary.currentRound?.roundID
        let legacyLiveStatus = roundID.flatMap { currentLiveStatus(for: member.memberID, in: party, roundID: $0, at: date) }
        let legacyActivity = roundID.flatMap { roundID in
            currentRoundActivities(in: party)
                .filter { $0.roundID == roundID && $0.memberID == member.memberID }
                .first
        }
        let sharedLiveStatus = party.summary.supportsMembershipSharing
            ? currentSharedLiveStatus(for: member.memberID, in: party, at: date)
            : nil
        let sharedActivity = party.summary.supportsMembershipSharing
            ? recentSharedActivities(in: party, at: date).first(where: { $0.memberID == member.memberID })
            : nil
        let presentedLegacyLiveStatus = party.summary.supportsMembershipSharing
            ? membershipLegacyLiveStatus(
                legacyLiveStatus,
                streamLiveStatus: sharedLiveStatus,
                streamActivity: sharedActivity
            )
            : legacyLiveStatus
        let presentedLegacyActivity = party.summary.supportsMembershipSharing && sharedActivity != nil
            ? nil
            : legacyActivity
        let liveCheerCount: Int
        if let statusID = sharedLiveStatus?.statusID {
            liveCheerCount = party.sharedLiveCheers
                .filter { $0.statusID == statusID && $0.memberID == member.memberID }
                .reduce(0) { $0 + max(0, $1.count) }
        } else if presentedLegacyLiveStatus != nil {
            liveCheerCount = party.liveCheers.filter { $0.memberID == member.memberID }.reduce(0) { $0 + max(0, $1.count) }
        } else { liveCheerCount = 0 }
        return NightFlockV4MemberPresentation(
            liveStatus: presentedLegacyLiveStatus,
            sharedLiveStatus: sharedLiveStatus,
            liveStatusTitle: (sharedLiveStatus?.status ?? presentedLegacyLiveStatus?.status).map(liveStatusTitle),
            latestActivity: presentedLegacyActivity,
            latestSharedActivity: sharedActivity,
            latestActivityLine: sharedActivity.map { activityPresentation(for: $0).latestMemberLine } ?? presentedLegacyActivity.map { activityPresentation(for: $0).latestMemberLine },
            liveCheerCount: liveCheerCount
        )
    }

    /// A one-shot local invalidation lets an already-open view remove an
    /// expired status without treating time passage as a reason to poll.
    static func nextDisplayInvalidation(
        in party: NightFlockV4PartyDetail,
        at date: Date = Date()
    ) -> Date? {
        displayInvalidationDates(in: party, at: date).first
    }

    /// These dates drive local rendering only. They deliberately include no
    /// refresh or transport work: expiring a status changes what can be shown,
    /// not what needs to be requested.
    static func displayInvalidationDates(
        in party: NightFlockV4PartyDetail,
        at date: Date = Date()
    ) -> [Date] {
        if party.summary.supportsMembershipSharing {
            let streamExpiries = party.sharedLiveStatuses
                .filter { $0.partyID == party.summary.partyID }
                .map(\.expiresAt)
                .filter { $0 > date }
            guard let roundID = party.summary.currentRound?.roundID else {
                return streamExpiries.sorted()
            }
            let streamActivities = recentSharedActivities(in: party, at: date)
            let legacyFallbackExpiries = party.memberships.compactMap { member -> Date? in
                let legacyStatus = currentLiveStatus(
                    for: member.memberID,
                    in: party,
                    roundID: roundID,
                    at: date
                )
                let streamLiveStatus = currentSharedLiveStatus(
                    for: member.memberID,
                    in: party,
                    at: date
                )
                let streamActivity = streamActivities.first { $0.memberID == member.memberID }
                return membershipLegacyLiveStatus(
                    legacyStatus,
                    streamLiveStatus: streamLiveStatus,
                    streamActivity: streamActivity
                )?.expiresAt
            }
            return Array(Set(streamExpiries + legacyFallbackExpiries)).sorted()
        }
        guard let roundID = party.summary.currentRound?.roundID else { return [] }
        return party.liveStatuses
            .filter {
                $0.partyID == party.summary.partyID
                    && $0.roundID == roundID
            }
            .map(\.expiresAt)
            .filter { $0 > date }
            .sorted()
    }

    static func currentRoundActivities(in party: NightFlockV4PartyDetail) -> [NightFlockV4Activity] {
        guard let roundID = party.summary.currentRound?.roundID else { return [] }
        return party.activities
            .filter {
                $0.partyID == party.summary.partyID
                    && $0.roundID == roundID
                    && (1...NightFlockV4Rules.roundNightCount).contains($0.day)
            }
            .sorted(by: activityOrdering)
    }

    static func earlierActivities(in party: NightFlockV4PartyDetail) -> [NightFlockV4Activity] {
        guard let roundID = party.summary.currentRound?.roundID else {
            return party.activities
                .filter { $0.partyID == party.summary.partyID }
                .sorted(by: activityOrdering)
        }
        return party.activities
            .filter {
                $0.partyID == party.summary.partyID
                    && $0.roundID != roundID
                    && (1...NightFlockV4Rules.roundNightCount).contains($0.day)
            }
            .sorted(by: activityOrdering)
    }

    static func activityPresentation(for activity: NightFlockV4Activity) -> NightFlockV4ActivityPresentation {
        let mode = activity.kind == .windDown ? "Wind Down" : "Phone Away"
        let outcome = activity.status == .completed ? "Completed" : "Ended early"
        let latestMode = activity.status == .completed ? mode : "\(mode) ended early"
        return NightFlockV4ActivityPresentation(
            modeTitle: mode,
            minutesTitle: "\(max(0, activity.roundedMinutes)) quiet min",
            nightTitle: "Night \(activity.day)",
            outcomeTitle: outcome,
            latestMemberLine: "Latest shared · \(latestMode) · \(max(0, activity.roundedMinutes)) min · Night \(activity.day)"
        )
    }

    static func activityPresentation(for activity: NightFlockV4SharedActivity) -> NightFlockV4ActivityPresentation {
        let mode = activity.kind == .windDown ? "Wind Down" : "Phone Away"
        let outcome = activity.status == .completed ? "Completed" : "Ended early"
        let latestMode = activity.status == .completed ? mode : "\(mode) ended early"
        let association = activity.day.map { "Night \($0)" } ?? "Recent shared moment"
        return NightFlockV4ActivityPresentation(modeTitle: mode, minutesTitle: "\(max(0, activity.roundedMinutes)) quiet min", nightTitle: association, outcomeTitle: outcome, latestMemberLine: "Latest shared · \(latestMode) · \(max(0, activity.roundedMinutes)) min")
    }

    static func recentSharedActivities(in party: NightFlockV4PartyDetail, at date: Date = Date()) -> [NightFlockV4SharedActivity] {
        guard party.summary.supportsMembershipSharing else { return [] }
        let cutoff = date.addingTimeInterval(-90 * 24 * 60 * 60)
        return party.sharedActivities.filter { $0.partyID == party.summary.partyID && $0.occurredAt >= cutoff && $0.occurredAt <= date }.sorted { lhs, rhs in
            if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
            return lhs.activityID.uuidString > rhs.activityID.uuidString
        }.prefix(100).map { $0 }
    }

    /// Membership remains the primary activity stream. A public round row and
    /// a membership row can represent one factual source, but presentation
    /// never hides the membership row (including its received cheers).
    static func membershipActivitiesForPresentation(
        in party: NightFlockV4PartyDetail,
        at date: Date = Date()
    ) -> [NightFlockV4SharedActivity] {
        recentSharedActivities(in: party, at: date)
    }

    /// Keep legacy round/backfill records visible during the additive rollout.
    static func legacyRoundHistoryActivities(in party: NightFlockV4PartyDetail) -> [NightFlockV4Activity] {
        let streamRowsForParty = party.sharedActivities.filter { $0.partyID == party.summary.partyID }
        let representedLegacyIDs = Set(streamRowsForParty.compactMap(\.roundActivityID))
            .union(Set(streamRowsForParty.map(\.activityID)))
        return party.activities
            .filter { $0.partyID == party.summary.partyID && !representedLegacyIDs.contains($0.activityID) }
            .sorted(by: activityOrdering)
    }

    static func sharedMomentRecap(_ count: Int) -> String {
        count == 1
            ? "1 shared moment reached the party."
            : "\(max(0, count)) shared moments reached the party."
    }

    private static func lifecycle(
        memberCount: Int,
        role: NightFlockV4Role,
        round: NightFlockV4Round?,
        at date: Date,
        calendar: Calendar
    ) -> NightFlockV4PresentationLifecycle {
        guard memberCount > 1 else { return .needsInvite }
        guard let round else { return readyLifecycle(for: role) }
        switch round.status {
        case .pending:
            return readyLifecycle(for: role)
        case .completed:
            return elapsedLifecycle(for: role)
        case .active:
            if let night = NightFlockV4RoundRules.day(at: date, round: round, calendar: calendar) {
                return .active(night: night)
            }
            if isAfterFinalLocalNight(date, round: round, calendar: calendar) {
                return elapsedLifecycle(for: role)
            }
            return readyLifecycle(for: role)
        }
    }

    private static func readyLifecycle(for role: NightFlockV4Role) -> NightFlockV4PresentationLifecycle {
        role == .host ? .readyHost : .readyMember
    }

    private static func elapsedLifecycle(for role: NightFlockV4Role) -> NightFlockV4PresentationLifecycle {
        role == .host ? .elapsedHost : .elapsedMember
    }

    private static func isAfterFinalLocalNight(
        _ date: Date,
        round: NightFlockV4Round,
        calendar source: Calendar
    ) -> Bool {
        guard let zone = TimeZone(identifier: round.timeZoneIdentifier),
              let start = round.startsOn.date(in: round.timeZoneIdentifier, calendar: source)
        else { return false }
        var calendar = source
        calendar.timeZone = zone
        let localDay = calendar.startOfDay(for: date)
        let finalNight = calendar.date(
            byAdding: .day,
            value: NightFlockV4Rules.roundNightCount - 1,
            to: calendar.startOfDay(for: start)
        )
        guard let finalNight else { return false }
        return localDay > finalNight
    }

    private static func currentLiveStatus(
        for memberID: UUID,
        in party: NightFlockV4PartyDetail,
        roundID: UUID,
        at date: Date
    ) -> NightFlockV4LiveStatus? {
        party.liveStatuses
            .filter {
                $0.partyID == party.summary.partyID
                    && $0.roundID == roundID
                    && $0.memberID == memberID
                    && $0.expiresAt > date
            }
            .sorted {
                if $0.revision != $1.revision { return $0.revision > $1.revision }
                if $0.expiresAt != $1.expiresAt { return $0.expiresAt > $1.expiresAt }
                return $0.observedAt > $1.observedAt
            }
            .first(where: { status in
                // v4 does not carry a source-session identifier on a live
                // status. A newer factual terminal record is therefore the
                // safest available evidence that this older live label is no
                // longer current. Future-dated activity is ignored so clock
                // skew cannot hide a real current status.
                !currentRoundActivities(in: party).contains {
                    $0.memberID == memberID
                        && $0.occurredAt <= date
                        && $0.occurredAt >= status.observedAt
                }
            })
    }

    private static func currentSharedLiveStatus(
        for memberID: UUID,
        in party: NightFlockV4PartyDetail,
        at date: Date
    ) -> NightFlockV4SharedLiveStatus? {
        party.sharedLiveStatuses
            .filter { $0.partyID == party.summary.partyID && $0.memberID == memberID && $0.isCurrent(at: date) }
            .sorted {
                if $0.revision != $1.revision { return $0.revision > $1.revision }
                if $0.expiresAt != $1.expiresAt { return $0.expiresAt > $1.expiresAt }
                return $0.observedAt > $1.observedAt
            }
            .first(where: { status in
                !recentSharedActivities(in: party, at: date).contains { $0.memberID == memberID && $0.occurredAt <= date && $0.occurredAt >= status.observedAt }
            })
    }

    /// Older clients can continue publishing round-scoped live status after
    /// the membership stream is advertised. A stream terminal only supersedes
    /// it when it is for the same member and is at least as recent.
    private static func membershipLegacyLiveStatus(
        _ legacyStatus: NightFlockV4LiveStatus?,
        streamLiveStatus: NightFlockV4SharedLiveStatus?,
        streamActivity: NightFlockV4SharedActivity?
    ) -> NightFlockV4LiveStatus? {
        guard let legacyStatus, streamLiveStatus == nil else { return nil }
        guard let streamActivity else { return legacyStatus }
        return streamActivity.occurredAt >= legacyStatus.observedAt ? nil : legacyStatus
    }

    private static func liveStatusTitle(_ status: NightFlockV4LiveStatus) -> String {
        liveStatusTitle(status.status)
    }

    private static func liveStatusTitle(_ status: NightFlockV4LiveStatusKind) -> String {
        switch status {
        case .windDownStarting: return "Wind Down is starting"
        case .phoneAwayActive: return "Phone is away"
        case .windDownCompleted: return "Wind Down completed"
        case .phoneAwayCompleted: return "Phone Away completed"
        }
    }

    private static func activityOrdering(
        _ lhs: NightFlockV4Activity,
        _ rhs: NightFlockV4Activity
    ) -> Bool {
        if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt > rhs.occurredAt }
        return lhs.activityID.uuidString > rhs.activityID.uuidString
    }
}

struct NightFlockV4MembershipCheerFeedbackDelta: Equatable, Sendable {
    var targetID: UUID
    var cheer: NightFlockV4Cheer
    var count: Int
    var sourceEventID: UUID
}

/// Produces only new cheers for the current member. Durable terminal and
/// expired status rows remain eligible so an offline recipient can reconcile a
/// cheer that arrived after the session ended; only their UI/action treatment
/// is limited to the current live status.
enum NightFlockV4MembershipCheerFeedbackRules {
    static func deltas(
        previous: NightFlockV4PartyDetail,
        current: NightFlockV4PartyDetail,
        at date: Date = Date()
    ) -> [NightFlockV4MembershipCheerFeedbackDelta] {
        guard current.summary.supportsMembershipSharing,
              previous.summary.supportsMembershipSharing,
              previous.summary.partyID == current.summary.partyID,
              let myMemberID = current.myMemberID,
              current.memberships.contains(where: { $0.memberID == myMemberID })
        else { return [] }
        let prior = sourceCheerCounts(in: previous, memberID: myMemberID, at: date)
        let incoming = sourceCheerCounts(in: current, memberID: myMemberID, at: date)
        return incoming.compactMap { entry in
            let value = entry.value
            guard value.count > (prior[entry.key]?.count ?? 0) else { return nil }
            return .init(targetID: value.targetID, cheer: value.cheer, count: value.count, sourceEventID: value.sourceEventID)
        }
    }

    private static func sourceCheerCounts(
        in party: NightFlockV4PartyDetail,
        memberID: UUID,
        at date: Date
    ) -> [String: (targetID: UUID, cheer: NightFlockV4Cheer, count: Int, sourceEventID: UUID)] {
        let ownActivities = Dictionary(uniqueKeysWithValues: NightFlockV4Presentation.recentSharedActivities(in: party, at: date)
            .compactMap { activity -> (UUID, UUID)? in
                guard activity.memberID == memberID, let sourceEventID = activity.mySourceEventID else { return nil }
                return (activity.activityID, sourceEventID)
            })
        var counts: [String: (targetID: UUID, cheer: NightFlockV4Cheer, count: Int, sourceEventID: UUID)] = [:]
        func merge(targetID: UUID, cheer: NightFlockV4Cheer, count: Int, sourceEventID: UUID) {
            let key = "\(sourceEventID.uuidString.lowercased()):\(cheer.rawValue)"
            guard count > (counts[key]?.count ?? 0) else { return }
            counts[key] = (targetID, cheer, count, sourceEventID)
        }
        for summary in party.sharedCheers {
            guard let sourceEventID = ownActivities[summary.activityID] else { continue }
            merge(targetID: summary.activityID, cheer: summary.cheer, count: summary.count, sourceEventID: sourceEventID)
        }
        for summary in party.sharedLiveCheers {
            guard summary.memberID == memberID, let sourceEventID = summary.mySourceEventID else { continue }
            merge(targetID: summary.statusID, cheer: summary.cheer, count: summary.count, sourceEventID: sourceEventID)
        }
        return counts
    }
}

struct NightFlockMemberBoardRow: Identifiable, Equatable, Sendable {
    var memberID: UUID
    var alias: String
    var ready: Bool
    var tonightStatus: NightFlockMemberNightStatus
    var qualifyingNights: Int
    var windDownMinutes: Int
    var phoneAwayMinutes: Int
    var shieldingTitle: String?
    var sleepMinutes: Int?
    var restfulnessTitle: String?
    var sharedRoutineTitles: [String]

    var id: UUID { memberID }
}

enum NightFlockMemberBoard {
    static func rows(
        from snapshot: NightFlockSnapshot,
        at date: Date = Date(),
        guidanceTitles: (String) -> String = { $0 }
    ) -> [NightFlockMemberBoardRow] {
        let day = NightFlockChallengeDayRules.challengeDay(at: date, challenge: snapshot.challenge)
        let tonight = day.flatMap { value in snapshot.days.first(where: { $0.day == value }) }
        return snapshot.members.map { member in
            let setup = snapshot.memberSetups.first(where: { $0.memberID == member.id })
            let sharing = setup?.sharing ?? NightFlockSharingPreferences(
                shareGoalProgress: setup?.sharingEnabled ?? true,
                shareRoutineIdeas: setup?.shareRoutineIdeas ?? false
            )
            let progress = snapshot.allMemberProgress.filter { $0.memberID == member.id }
            let tonightProgress = tonight?.memberProgress.first(where: { $0.memberID == member.id })
            let projectedTonight = tonightProgress.map {
                NightFlockProjectionRules.projectedProgress($0, sharing: sharing)
            }
            let routines = snapshot.sharedRoutineIdeas
                .filter { $0.memberID == member.id }
                .map { guidanceTitles($0.guidanceID) }
            return NightFlockMemberBoardRow(
                memberID: member.id,
                alias: member.alias,
                ready: setup?.goalAccepted == true && setup?.setupReady == true,
                tonightStatus: projectedTonight?.status ?? .privateNoUpdate,
                qualifyingNights: NightFlockRewardRules.qualifyingNightCount(
                    in: progress,
                    memberID: member.id
                ),
                windDownMinutes: progress.compactMap(\.windDownMinutes).reduce(0, +),
                phoneAwayMinutes: progress.compactMap(\.phoneAwayMinutes).reduce(0, +),
                shieldingTitle: sharing.shareShieldingStatus
                    ? projectedTonight?.shieldingEvidence.title
                    : nil,
                sleepMinutes: projectedTonight?.sleepDurationMinutes,
                restfulnessTitle: projectedTonight?.restfulness?.title,
                sharedRoutineTitles: sharing.shareRoutineIdeas ? routines : []
            )
        }
    }
}
