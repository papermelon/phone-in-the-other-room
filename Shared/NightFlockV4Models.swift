import Foundation

enum NightFlockV4Rules {
    static let schemaVersion = 4
    static let minimumMembers = 2
    static let maximumMembers = 8
    static let maximumConcurrentParties = 5
    static let roundNightCount = 7
    static let maximumSourceFanOut = 5
    static let maximumOutboxSources = 64
}

enum NightFlockV4Role: String, Codable, Sendable { case host, member }
enum NightFlockV4SharingScope: String, Codable, Sendable { case membership }

struct NightFlockV4Capabilities: Codable, Equatable, Sendable {
    var canRenameParty: Bool
    var canStartRound: Bool
    var canManageInvites: Bool
    var canDeleteParty: Bool
    var canLeaveParty: Bool

    static func make(role: NightFlockV4Role) -> Self {
        let host = role == .host
        return Self(canRenameParty: host, canStartRound: host, canManageInvites: host, canDeleteParty: host, canLeaveParty: !host)
    }
}

struct NightFlockV4Membership: Identifiable, Codable, Equatable, Sendable {
    var id: UUID { memberID }
    var memberID: UUID
    var profile: CountingSheepUserProfile
    var role: NightFlockV4Role
    var joinedAt: Date
    var capabilities: NightFlockV4Capabilities

    init(memberID: UUID, profile: CountingSheepUserProfile, role: NightFlockV4Role, joinedAt: Date, capabilities: NightFlockV4Capabilities? = nil) {
        self.memberID = memberID
        self.profile = profile
        self.role = role
        self.joinedAt = joinedAt
        self.capabilities = capabilities ?? .make(role: role)
    }
}

enum NightFlockV4RoundStatus: String, Codable, Sendable { case pending, active, completed }

struct NightFlockV4Round: Identifiable, Codable, Equatable, Sendable {
    var id: UUID { roundID }
    var roundID: UUID
    var number: Int
    var timeZoneIdentifier: String
    var startsOn: NightFlockLocalDate
    var status: NightFlockV4RoundStatus

    init(roundID: UUID, number: Int, timeZoneIdentifier: String, startsOn: NightFlockLocalDate, status: NightFlockV4RoundStatus) {
        self.roundID = roundID
        self.number = max(1, number)
        self.timeZoneIdentifier = timeZoneIdentifier
        self.startsOn = startsOn
        self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case roundID, number, timeZoneIdentifier, startsOn, status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roundID = try container.decode(UUID.self, forKey: .roundID)
        number = max(1, try container.decode(Int.self, forKey: .number))
        timeZoneIdentifier = try container.decode(String.self, forKey: .timeZoneIdentifier)
        status = try container.decode(NightFlockV4RoundStatus.self, forKey: .status)
        if let localDate = try? container.decode(NightFlockLocalDate.self, forKey: .startsOn) {
            startsOn = localDate
            return
        }
        let wireDate = try container.decode(String.self, forKey: .startsOn)
        let parts = wireDate.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .startsOn,
                in: container,
                debugDescription: "Expected a YYYY-MM-DD Slumber Party round date."
            )
        }
        startsOn = NightFlockLocalDate(year: year, month: month, day: day)
    }
}

enum NightFlockV4RoundRules {
    static func day(at date: Date, round: NightFlockV4Round, calendar source: Calendar = .current) -> Int? {
        guard round.status == .active,
              let zone = TimeZone(identifier: round.timeZoneIdentifier),
              let start = round.startsOn.date(in: round.timeZoneIdentifier, calendar: source) else { return nil }
        var calendar = source
        calendar.timeZone = zone
        let localDay = calendar.startOfDay(for: date)
        guard let offset = calendar.dateComponents([.day], from: start, to: localDay).day,
              (0..<NightFlockV4Rules.roundNightCount).contains(offset) else { return nil }
        return offset + 1
    }

    static func isCurrent(_ round: NightFlockV4Round, at date: Date, calendar: Calendar = .current) -> Bool {
        day(at: date, round: round, calendar: calendar) != nil
    }

    static func canParticipate(_ membership: NightFlockV4Membership, in round: NightFlockV4Round, at date: Date, calendar: Calendar = .current) -> Bool {
        membership.joinedAt <= date && isCurrent(round, at: date, calendar: calendar)
    }
}

struct NightFlockV4PartySummary: Identifiable, Codable, Equatable, Sendable {
    var id: UUID { partyID }
    var partyID: UUID
    var name: String
    var memberCount: Int
    var myRole: NightFlockV4Role
    var currentRound: NightFlockV4Round?
    var revision: Int
    /// Missing means the server is still using the original round-only wire.
    var sharingScope: NightFlockV4SharingScope?

    var supportsMembershipSharing: Bool { sharingScope == .membership }

    init(
        partyID: UUID,
        name: String,
        memberCount: Int,
        myRole: NightFlockV4Role,
        currentRound: NightFlockV4Round?,
        revision: Int,
        sharingScope: NightFlockV4SharingScope? = nil
    ) {
        self.partyID = partyID
        self.name = name
        self.memberCount = memberCount
        self.myRole = myRole
        self.currentRound = currentRound
        self.revision = revision
        self.sharingScope = sharingScope
    }

    private enum CodingKeys: String, CodingKey {
        case partyID, name, memberCount, myRole, currentRound, revision, sharingScope
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        partyID = try container.decode(UUID.self, forKey: .partyID)
        name = try container.decode(String.self, forKey: .name)
        memberCount = try container.decode(Int.self, forKey: .memberCount)
        myRole = try container.decode(NightFlockV4Role.self, forKey: .myRole)
        currentRound = try container.decodeIfPresent(NightFlockV4Round.self, forKey: .currentRound)
        revision = try container.decode(Int.self, forKey: .revision)
        // Capability values can be introduced by a newer backend. Treat an
        // unrecognized value exactly like absence until this app understands it.
        sharingScope = try container.decodeIfPresent(String.self, forKey: .sharingScope)
            .flatMap(NightFlockV4SharingScope.init(rawValue:))
    }
}

struct NightFlockV4InvitationMetadata: Identifiable, Codable, Equatable, Sendable {
    enum Status: String, Codable, Sendable { case active, revoked, expired }
    var id: UUID { inviteID }
    var inviteID: UUID
    var partyID: UUID
    var createdAt: Date
    var expiresAt: Date
    var status: Status
}

enum NightFlockV4ActivityKind: String, Codable, Sendable { case windDown, phoneAway }
enum NightFlockV4ActivityStatus: String, Codable, Sendable { case completed, partlyCompleted }
enum NightFlockV4LiveStatusKind: String, Codable, Sendable {
    case windDownStarting, phoneAwayActive, windDownCompleted, phoneAwayCompleted
}
enum NightFlockV4Cheer: String, Codable, CaseIterable, Sendable { case warmWave, moonGlow, pawPrint }

/// A locally derived, silent feedback signal. It excludes sender identity and
/// raw Realtime data; a refreshed party projection remains authoritative.
struct SlumberPartyCheerFeedback: Codable, Hashable, Sendable {
    var partyID: UUID
    var cheer: NightFlockV4Cheer
    var count: Int
    var observedAt: Date
    /// Membership-stream feedback can identify only this device's already
    /// uploaded source event. Legacy feedback intentionally remains unscoped.
    var sourceEventID: UUID? = nil
}

struct NightFlockV4Activity: Identifiable, Codable, Equatable, Sendable {
    var id: UUID { activityID }
    var activityID: UUID
    var partyID: UUID
    var roundID: UUID
    var memberID: UUID
    var day: Int
    var kind: NightFlockV4ActivityKind
    var status: NightFlockV4ActivityStatus
    var roundedMinutes: Int
    var occurredAt: Date
}

struct NightFlockV4LiveStatus: Codable, Equatable, Sendable {
    var partyID: UUID
    var roundID: UUID
    var memberID: UUID
    var status: NightFlockV4LiveStatusKind
    var revision: Int
    var observedAt: Date
    var expiresAt: Date

    func isCurrent(at date: Date) -> Bool { expiresAt > date }
}

enum NightFlockV4LiveStatusRules {
    static func merge(_ incoming: NightFlockV4LiveStatus, into statuses: [NightFlockV4LiveStatus], now: Date = Date()) -> [NightFlockV4LiveStatus] {
        var current = statuses.filter { $0.isCurrent(at: now) }
        guard incoming.isCurrent(at: now) else { return current }
        let identity: (NightFlockV4LiveStatus) -> Bool = {
            $0.partyID == incoming.partyID && $0.roundID == incoming.roundID && $0.memberID == incoming.memberID
        }
        if let index = current.firstIndex(where: identity) {
            let existing = current[index]
            if incoming.revision > existing.revision || (incoming.revision == existing.revision && incoming.expiresAt > existing.expiresAt) {
                current[index] = incoming
            }
        } else { current.append(incoming) }
        return current
    }
}

struct NightFlockV4CheerSummary: Codable, Equatable, Sendable {
    var activityID: UUID
    var cheer: NightFlockV4Cheer
    var count: Int
    var sentByMe: Bool
}

struct NightFlockV4LiveCheerSummary: Codable, Equatable, Sendable {
    var memberID: UUID
    var cheer: NightFlockV4Cheer
    var count: Int
    var sentByMe: Bool
}

/// Membership-scoped history stays separate from the original round ledger so
/// old round payloads never acquire invented associations.
struct NightFlockV4SharedActivity: Identifiable, Codable, Equatable, Sendable {
    var id: UUID { activityID }
    var activityID: UUID
    var partyID: UUID
    var memberID: UUID
    var roundID: UUID?
    var day: Int?
    var kind: NightFlockV4ActivityKind
    var status: NightFlockV4ActivityStatus
    var roundedMinutes: Int
    var occurredAt: Date
    /// The matching legacy round projection when this same source also earned
    /// round credit. It is absent for membership-only moments.
    var roundActivityID: UUID?
    /// Returned only to the member who owns this source activity.
    var mySourceEventID: UUID?
}

struct NightFlockV4SharedLiveStatus: Identifiable, Codable, Equatable, Sendable {
    var id: UUID { statusID }
    var statusID: UUID
    var partyID: UUID
    var memberID: UUID
    var roundID: UUID?
    var status: NightFlockV4LiveStatusKind
    var revision: Int
    var observedAt: Date
    var expiresAt: Date

    func isCurrent(at date: Date) -> Bool { expiresAt > date }
}

struct NightFlockV4SharedLiveCheerSummary: Codable, Equatable, Sendable {
    var statusID: UUID
    var memberID: UUID
    var cheer: NightFlockV4Cheer
    var count: Int
    var sentByMe: Bool
    /// Returned only to the member whose live source received this cheer.
    var mySourceEventID: UUID?
}

struct NightFlockV4GrantInboxItem: Identifiable, Codable, Equatable, Sendable {
    var id: UUID { grantID }
    var grantID: UUID
    var partyID: UUID
    var roundID: UUID
    var kind: String
    var woolAmount: Int
    var issuedAt: Date
    var acknowledgedAt: Date?
}

typealias NightFlockV4PaginationCursor = String

struct NightFlockV4PartyDetail: Codable, Equatable, Sendable {
    var summary: NightFlockV4PartySummary
    /// The server supplies this opaque membership identifier so presentation
    /// never infers “me” from a display name.
    var myMemberID: UUID?
    var memberships: [NightFlockV4Membership]
    var invitation: NightFlockV4InvitationMetadata?
    var activities: [NightFlockV4Activity]
    var cursor: NightFlockV4PaginationCursor?
    var liveStatuses: [NightFlockV4LiveStatus]
    var cheers: [NightFlockV4CheerSummary]
    var liveCheers: [NightFlockV4LiveCheerSummary]
    var sharedActivities: [NightFlockV4SharedActivity]
    var sharedLiveStatuses: [NightFlockV4SharedLiveStatus]
    var sharedCheers: [NightFlockV4CheerSummary]
    var sharedLiveCheers: [NightFlockV4SharedLiveCheerSummary]
    var grantInbox: [NightFlockV4GrantInboxItem]

    private enum CodingKeys: String, CodingKey {
        case summary, myMemberID, memberships, invitation, activities, cursor, liveStatuses, cheers, liveCheers, sharedActivities, sharedLiveStatuses, sharedCheers, sharedLiveCheers, grantInbox
    }

    init(summary: NightFlockV4PartySummary, myMemberID: UUID? = nil, memberships: [NightFlockV4Membership] = [], invitation: NightFlockV4InvitationMetadata? = nil, activities: [NightFlockV4Activity] = [], cursor: NightFlockV4PaginationCursor? = nil, liveStatuses: [NightFlockV4LiveStatus] = [], cheers: [NightFlockV4CheerSummary] = [], liveCheers: [NightFlockV4LiveCheerSummary] = [], sharedActivities: [NightFlockV4SharedActivity] = [], sharedLiveStatuses: [NightFlockV4SharedLiveStatus] = [], sharedCheers: [NightFlockV4CheerSummary] = [], sharedLiveCheers: [NightFlockV4SharedLiveCheerSummary] = [], grantInbox: [NightFlockV4GrantInboxItem] = []) {
        self.summary = summary; self.memberships = memberships; self.invitation = invitation; self.activities = activities
        self.myMemberID = myMemberID
        self.cursor = cursor; self.liveStatuses = liveStatuses; self.cheers = cheers; self.liveCheers = liveCheers
        self.sharedActivities = sharedActivities; self.sharedLiveStatuses = sharedLiveStatuses; self.sharedCheers = sharedCheers; self.sharedLiveCheers = sharedLiveCheers; self.grantInbox = grantInbox
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(summary: try c.decode(NightFlockV4PartySummary.self, forKey: .summary), myMemberID: try c.decodeIfPresent(UUID.self, forKey: .myMemberID), memberships: try c.decodeIfPresent([NightFlockV4Membership].self, forKey: .memberships) ?? [], invitation: try c.decodeIfPresent(NightFlockV4InvitationMetadata.self, forKey: .invitation), activities: try c.decodeIfPresent([NightFlockV4Activity].self, forKey: .activities) ?? [], cursor: try c.decodeIfPresent(NightFlockV4PaginationCursor.self, forKey: .cursor), liveStatuses: try c.decodeIfPresent([NightFlockV4LiveStatus].self, forKey: .liveStatuses) ?? [], cheers: try c.decodeIfPresent([NightFlockV4CheerSummary].self, forKey: .cheers) ?? [], liveCheers: try c.decodeIfPresent([NightFlockV4LiveCheerSummary].self, forKey: .liveCheers) ?? [], sharedActivities: try c.decodeIfPresent([NightFlockV4SharedActivity].self, forKey: .sharedActivities) ?? [], sharedLiveStatuses: try c.decodeIfPresent([NightFlockV4SharedLiveStatus].self, forKey: .sharedLiveStatuses) ?? [], sharedCheers: try c.decodeIfPresent([NightFlockV4CheerSummary].self, forKey: .sharedCheers) ?? [], sharedLiveCheers: try c.decodeIfPresent([NightFlockV4SharedLiveCheerSummary].self, forKey: .sharedLiveCheers) ?? [], grantInbox: try c.decodeIfPresent([NightFlockV4GrantInboxItem].self, forKey: .grantInbox) ?? [])
    }
}
