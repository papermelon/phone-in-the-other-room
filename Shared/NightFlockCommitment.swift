import Foundation

/// The bounded goal catalogue keeps a Slumber Party about one small Wind Down
/// promise. App tokens and selections never belong in this model.
enum NightFlockGoalKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case phoneAway
    case quietMinutes
    case shieldInstagram

    var id: String { rawValue }

    var title: String {
        switch self {
        case .phoneAway: return "Put phones away during Wind Down"
        case .quietMinutes: return "Reach an agreed quiet time"
        case .shieldInstagram: return "Shield Instagram during Wind Down"
        }
    }

    var detail: String {
        switch self {
        case .phoneAway: return "Everyone gives the phone a resting place before bed."
        case .quietMinutes: return "Choose the number of quiet minutes that suits your group."
        case .shieldInstagram: return "Each person confirms the app selection on their own iPhone."
        }
    }

    var defaultTargetMinutes: Int? {
        switch self {
        case .phoneAway, .shieldInstagram: return nil
        case .quietMinutes: return 30
        }
    }
}

struct NightFlockSharedGoal: Codable, Equatable, Sendable {
    var kind: NightFlockGoalKind
    var targetMinutes: Int?
    var appDisplayName: String?

    init(
        kind: NightFlockGoalKind,
        targetMinutes: Int? = nil,
        appDisplayName: String? = nil
    ) {
        self.kind = kind
        self.targetMinutes = targetMinutes.map { min(max($0, 5), 180) }
        self.appDisplayName = appDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var title: String { kind == .shieldInstagram ? "Shield Instagram during Wind Down" : kind.title }

    var detail: String {
        if kind == .quietMinutes, let minutes = targetMinutes {
            return "Reach \(minutes) quiet minutes during Wind Down."
        }
        return kind.detail
    }
}

enum NightFlockShieldingEvidence: String, Codable, CaseIterable, Sendable {
    case notRequested
    case unavailable
    case partial
    case observed

    var title: String {
        switch self {
        case .notRequested: return "Shielding not requested"
        case .unavailable: return "Shielding unavailable"
        case .partial: return "Some shielding was observed"
        case .observed: return "App shielding was observed"
        }
    }
}

enum NightFlockMemberNightStatus: String, Codable, CaseIterable, Sendable {
    case goalAccepted
    case setupReady
    case phoneTuckedAway
    case partiallyCompleted
    case sharedGoalCompleted
    case morningQuietCompleted
    case privateNoUpdate

    var title: String {
        switch self {
        case .goalAccepted: return "Goal accepted"
        case .setupReady: return "Setup ready"
        case .phoneTuckedAway: return "Phone tucked away"
        case .partiallyCompleted: return "Partly completed"
        case .sharedGoalCompleted: return "Goal completed"
        case .morningQuietCompleted: return "Morning quiet completed"
        case .privateNoUpdate: return "Private tonight"
        }
    }

    var symbolName: String {
        switch self {
        case .goalAccepted: return "checkmark.circle"
        case .setupReady: return "gearshape.2"
        case .phoneTuckedAway: return "iphone.slash"
        case .partiallyCompleted: return "circle.lefthalf.filled"
        case .sharedGoalCompleted: return "checkmark.circle.fill"
        case .morningQuietCompleted: return "sun.max.fill"
        case .privateNoUpdate: return "lock"
        }
    }
}

struct NightFlockMemberSetup: Codable, Equatable, Identifiable, Sendable {
    var memberID: UUID
    var goalAccepted: Bool
    var setupReady: Bool
    var sharingEnabled: Bool
    var shareRoutineIdeas: Bool
    var shieldingEvidence: NightFlockShieldingEvidence

    var id: UUID { memberID }
}

struct NightFlockMemberNightProgress: Codable, Equatable, Identifiable, Sendable {
    var memberID: UUID
    var day: Int
    var status: NightFlockMemberNightStatus
    var shieldingEvidence: NightFlockShieldingEvidence

    var id: String { "\(memberID.uuidString)-\(day)" }
}

struct NightFlockSharedRoutineIdea: Codable, Equatable, Identifiable, Sendable {
    var memberID: UUID
    var guidanceID: String

    var id: String { "\(memberID.uuidString)-\(guidanceID)" }
}

struct NightFlockSharingPreferences: Codable, Equatable, Sendable {
    var shareGoalProgress: Bool
    var shareRoutineIdeas: Bool

    init(shareGoalProgress: Bool = true, shareRoutineIdeas: Bool = false) {
        self.shareGoalProgress = shareGoalProgress
        self.shareRoutineIdeas = shareRoutineIdeas
    }
}

struct NightFlockCommitmentDraft: Equatable, Sendable {
    var goal = NightFlockSharedGoal(kind: .phoneAway)
    var identity: NightFlockIdentity = .moonlitMeadow
    var sharing = NightFlockSharingPreferences()
    var sharedRoutineIDs: [String] = []
    var shieldingEvidence: NightFlockShieldingEvidence = .notRequested
}

struct NightFlockInvitePreview: Codable, Equatable, Sendable {
    var goal: NightFlockSharedGoal
    var memberCount: Int
    var capacity: Int
    var isReusable: Bool
}
