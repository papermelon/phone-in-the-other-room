import Foundation

enum NightFlockAccountState: String, Codable, CaseIterable, Sendable {
    case anonymous
    case linking
    case linked
    case unavailable
}

enum NightFlockIdentity: String, Codable, CaseIterable, Identifiable, Sendable {
    case moonlitMeadow
    case orchardGate
    case starlightHill

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moonlitMeadow: return "Moonlit Meadow"
        case .orchardGate: return "Orchard Gate"
        case .starlightHill: return "Starlight Hill"
        }
    }

    var symbolName: String {
        switch self {
        case .moonlitMeadow: return "moon.stars.fill"
        case .orchardGate: return "leaf.fill"
        case .starlightHill: return "sparkles"
        }
    }
}

enum NightFlockMemberRole: String, Codable, Sendable {
    case keeper
    case member
}

struct NightFlockProfile: Codable, Equatable, Sendable {
    var alias: String
}

struct NightFlockMember: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var alias: String
    var role: NightFlockMemberRole
}

struct NightFlockLocalDate: Codable, Equatable, Hashable, Comparable, Sendable {
    var year: Int
    var month: Int
    var day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init?(date: Date, timeZoneIdentifier: String, calendar source: Calendar = .current) {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return nil }
        var calendar = source
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }
        self.init(year: year, month: month, day: day)
    }

    static func < (lhs: NightFlockLocalDate, rhs: NightFlockLocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    func date(in timeZoneIdentifier: String, calendar source: Calendar = .current) -> Date? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return nil }
        var calendar = source
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: year,
            month: month,
            day: day
        ))
    }
}

struct NightFlockChallenge: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var timeZoneIdentifier: String
    var startsOn: NightFlockLocalDate
    var status: Status
    var sharedGoal: NightFlockSharedGoal?
    var hostStartedAt: Date?

    enum Status: String, Codable, Sendable {
        case pending
        case active
        case completed
    }

    init(
        id: UUID,
        timeZoneIdentifier: String,
        startsOn: NightFlockLocalDate,
        status: Status,
        sharedGoal: NightFlockSharedGoal? = nil,
        hostStartedAt: Date? = nil
    ) {
        self.id = id
        self.timeZoneIdentifier = timeZoneIdentifier
        self.startsOn = startsOn
        self.status = status
        self.sharedGoal = sharedGoal
        self.hostStartedAt = hostStartedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, timeZoneIdentifier, startsOn, status, sharedGoal, hostStartedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timeZoneIdentifier = try container.decode(String.self, forKey: .timeZoneIdentifier)
        startsOn = try container.decode(NightFlockLocalDate.self, forKey: .startsOn)
        status = try container.decode(Status.self, forKey: .status)
        sharedGoal = try container.decodeIfPresent(NightFlockSharedGoal.self, forKey: .sharedGoal)
        hostStartedAt = try container.decodeIfPresent(Date.self, forKey: .hostStartedAt)
    }
}

enum NightFlockCheckInState: String, Codable, CaseIterable, Comparable, Sendable {
    case none
    case phoneTucked
    case morningQuietCompleted

    private var rank: Int {
        switch self {
        case .none: return 0
        case .phoneTucked: return 1
        case .morningQuietCompleted: return 2
        }
    }

    static func < (lhs: NightFlockCheckInState, rhs: NightFlockCheckInState) -> Bool {
        lhs.rank < rhs.rank
    }
}

enum NightFlockReactionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case warmWave
    case moonGlow
    case pawPrint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warmWave: return "Warm wave"
        case .moonGlow: return "Moon glow"
        case .pawPrint: return "Paw print"
        }
    }

    var symbolName: String {
        switch self {
        case .warmWave: return "hand.wave.fill"
        case .moonGlow: return "moon.fill"
        case .pawPrint: return "pawprint.fill"
        }
    }
}

enum NightFlockReportReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case unwantedContact
    case harmfulConduct
    case impersonation
    case otherSafetyConcern

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unwantedContact: return "Unwanted contact"
        case .harmfulConduct: return "Harmful conduct"
        case .impersonation: return "Misleading identity"
        case .otherSafetyConcern: return "Another safety concern"
        }
    }
}

struct NightFlockReactionSummary: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var kind: NightFlockReactionKind
    var count: Int
    var reactedByMe: Bool
}

struct NightFlockPastureEntry: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var state: NightFlockCheckInState
    var reactions: [NightFlockReactionSummary]

    private enum CodingKeys: String, CodingKey {
        case id
        case state
        case reactions
    }

    init(
        id: UUID,
        state: NightFlockCheckInState,
        reactions: [NightFlockReactionSummary]
    ) {
        self.id = id
        self.state = state
        self.reactions = reactions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        state = try container.decode(NightFlockCheckInState.self, forKey: .state)
        reactions = try container.decodeIfPresent(
            [NightFlockReactionSummary].self,
            forKey: .reactions
        ) ?? []
    }
}

struct NightFlockDaySummary: Identifiable, Codable, Equatable, Sendable {
    var day: Int
    var phoneTuckedCount: Int
    var morningQuietCompletedCount: Int
    var pasture: [NightFlockPastureEntry]
    var memberProgress: [NightFlockMemberNightProgress]

    var id: Int { day }

    private enum CodingKeys: String, CodingKey {
        case day
        case phoneTuckedCount
        case morningQuietCompletedCount
        case pasture
        case memberProgress
    }

    init(
        day: Int,
        phoneTuckedCount: Int,
        morningQuietCompletedCount: Int,
        pasture: [NightFlockPastureEntry],
        memberProgress: [NightFlockMemberNightProgress] = []
    ) {
        self.day = day
        self.phoneTuckedCount = phoneTuckedCount
        self.morningQuietCompletedCount = morningQuietCompletedCount
        self.pasture = pasture
        self.memberProgress = memberProgress
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(Int.self, forKey: .day)
        phoneTuckedCount = try container.decode(Int.self, forKey: .phoneTuckedCount)
        morningQuietCompletedCount = try container.decode(Int.self, forKey: .morningQuietCompletedCount)
        pasture = try container.decodeIfPresent(
            [NightFlockPastureEntry].self,
            forKey: .pasture
        ) ?? []
        memberProgress = try container.decodeIfPresent(
            [NightFlockMemberNightProgress].self,
            forKey: .memberProgress
        ) ?? []
    }
}

struct NightFlockSnapshot: Codable, Equatable, Sendable {
    var profile: NightFlockProfile
    var flockID: UUID
    var identity: NightFlockIdentity
    var myMemberID: UUID
    var members: [NightFlockMember]
    var challenge: NightFlockChallenge
    var days: [NightFlockDaySummary]
    var sharingEnabled: Bool
    var memberSetups: [NightFlockMemberSetup]
    var sharedRoutineIdeas: [NightFlockSharedRoutineIdea]
    var invitePreview: NightFlockInvitePreview?

    var currentDay: NightFlockDaySummary? {
        days.last(where: { !$0.pasture.isEmpty }) ?? days.last
    }

    private enum CodingKeys: String, CodingKey {
        case profile
        case flockID
        case identity
        case myMemberID
        case members
        case challenge
        case days
        case sharingEnabled
        case memberSetups
        case sharedRoutineIdeas
        case invitePreview
    }

    init(
        profile: NightFlockProfile,
        flockID: UUID,
        identity: NightFlockIdentity,
        myMemberID: UUID,
        members: [NightFlockMember],
        challenge: NightFlockChallenge,
        days: [NightFlockDaySummary],
        sharingEnabled: Bool,
        memberSetups: [NightFlockMemberSetup] = [],
        sharedRoutineIdeas: [NightFlockSharedRoutineIdea] = [],
        invitePreview: NightFlockInvitePreview? = nil
    ) {
        self.profile = profile
        self.flockID = flockID
        self.identity = identity
        self.myMemberID = myMemberID
        self.members = members
        self.challenge = challenge
        self.days = days
        self.sharingEnabled = sharingEnabled
        self.memberSetups = memberSetups
        self.sharedRoutineIdeas = sharedRoutineIdeas
        self.invitePreview = invitePreview
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decode(NightFlockProfile.self, forKey: .profile)
        flockID = try container.decode(UUID.self, forKey: .flockID)
        identity = try container.decode(NightFlockIdentity.self, forKey: .identity)
        myMemberID = try container.decode(UUID.self, forKey: .myMemberID)
        members = try container.decodeIfPresent([NightFlockMember].self, forKey: .members) ?? []
        challenge = try container.decode(NightFlockChallenge.self, forKey: .challenge)
        days = try container.decodeIfPresent([NightFlockDaySummary].self, forKey: .days) ?? []
        sharingEnabled = try container.decodeIfPresent(Bool.self, forKey: .sharingEnabled) ?? true
        memberSetups = try container.decodeIfPresent([NightFlockMemberSetup].self, forKey: .memberSetups) ?? []
        sharedRoutineIdeas = try container.decodeIfPresent(
            [NightFlockSharedRoutineIdea].self,
            forKey: .sharedRoutineIdeas
        ) ?? []
        invitePreview = try container.decodeIfPresent(NightFlockInvitePreview.self, forKey: .invitePreview)
    }
}

enum NightFlockChallengeDayRules {
    static let dayCount = 7

    static func challengeDay(
        at date: Date,
        challenge: NightFlockChallenge,
        calendar source: Calendar = .current
    ) -> Int? {
        guard challenge.status == .active,
              let timeZone = TimeZone(identifier: challenge.timeZoneIdentifier),
              let start = challenge.startsOn.date(
                in: challenge.timeZoneIdentifier,
                calendar: source
              ) else { return nil }
        var calendar = source
        calendar.timeZone = timeZone
        let localDay = calendar.startOfDay(for: date)
        guard let offset = calendar.dateComponents([.day], from: start, to: localDay).day,
              (0..<dayCount).contains(offset) else { return nil }
        return offset + 1
    }
}

enum NightFlockRetention {
    static let inviteValidityDays = 7
    static let invitePurgeDays = 30
    static let rawActivityDays = 90
    static let completedSummaryMonths = 12
}
