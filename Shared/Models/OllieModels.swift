import Foundation

enum OllieMood: String, Codable, CaseIterable {
    case waiting, excited, running, guarding, alert, proud, happy, sad, sleepy
}

enum ProximityBucket: String, Codable, CaseIterable {
    case withYou, sameRoom, doorway, probablyOtherRoom, signalLost, unsupported, demo

    var label: String {
        switch self {
        case .withYou: return "Phone is with you"
        case .sameRoom: return "Phone is nearby"
        case .doorway: return "Phone is drifting away"
        case .probablyOtherRoom: return "Phone is in the focus pasture"
        case .signalLost: return "Phone signal lost"
        case .unsupported: return "Phone distance unsupported"
        case .demo: return "Demo Shepherding Run"
        }
    }
}

enum FocusRunState: String, Codable, CaseIterable {
    case setup, placementGrace, waitingForPhoneAway, running, warningPhoneTooClose, completed, endedEarly, signalLost, unsupported, demo

    var label: String {
        switch self {
        case .setup: return "Set up Ollie's run"
        case .placementGrace: return "Put your phone in the other room"
        case .waitingForPhoneAway: return "Ollie is waiting for the phone to reach the pasture"
        case .running: return "Ollie is guarding your focus"
        case .warningPhoneTooClose: return "Phone is getting too close"
        case .completed: return "Ollie completed the run"
        case .endedEarly: return "Ollie came back early"
        case .signalLost: return "Ollie lost the trail"
        case .unsupported: return "Phone distance unavailable"
        case .demo: return "Demo run active"
        }
    }

    var ollieMood: OllieMood {
        switch self {
        case .setup: return .waiting
        case .placementGrace: return .excited
        case .waitingForPhoneAway: return .running
        case .running, .demo: return .guarding
        case .warningPhoneTooClose, .signalLost, .unsupported: return .alert
        case .completed: return .proud
        case .endedEarly: return .sad
        }
    }
}

enum ProximityConfidence: String, Codable, CaseIterable {
    case low, medium, high
}

enum ProximityReadingSource: String, Codable {
    case nearbyInteraction, watchConnectivity, demo, fallback
}

struct ProximityReading: Codable, Identifiable, Equatable {
    let id: UUID
    let distanceMeters: Double?
    let timestamp: Date
    let source: ProximityReadingSource
    let directionAvailable: Bool
    let confidence: ProximityConfidence

    init(id: UUID = UUID(), distanceMeters: Double?, timestamp: Date = Date(), source: ProximityReadingSource, directionAvailable: Bool = false, confidence: ProximityConfidence = .medium) {
        self.id = id
        self.distanceMeters = distanceMeters
        self.timestamp = timestamp
        self.source = source
        self.directionAvailable = directionAvailable
        self.confidence = confidence
    }
}

struct ProximityState: Codable, Equatable {
    var bucket: ProximityBucket
    var distanceMeters: Double?
    var confidence: ProximityConfidence
    var source: ProximityReadingSource
    var lastUpdated: Date
    var statusText: String
    var detailText: String

    static let initial = ProximityState(bucket: .unsupported, distanceMeters: nil, confidence: .low, source: .fallback, lastUpdated: Date(), statusText: ProximityBucket.unsupported.label, detailText: "Phone distance appears after a Focus Run starts and a supported iPhone/Watch pair is available.")
}

struct ThresholdProfile: Codable, Equatable {
    var withYouMaxMeters: Double
    var sameRoomMaxMeters: Double
    var otherRoomMinMeters: Double
    var staleAfterSeconds: Double
    var sustainedSamples: Int
    var placementGraceSeconds: Double
    var warningGraceSeconds: Double
    var signalLostGraceSeconds: Double

    static let defaults = ThresholdProfile(withYouMaxMeters: 1.5, sameRoomMaxMeters: 5.0, otherRoomMinMeters: 8.0, staleAfterSeconds: 8.0, sustainedSamples: 3, placementGraceSeconds: 60.0, warningGraceSeconds: 60.0, signalLostGraceSeconds: 20.0)
}

struct FocusRun: Codable, Identifiable, Equatable {
    let id: UUID
    var plannedDurationSeconds: TimeInterval
    var actualDurationSeconds: TimeInterval
    var startedAt: Date
    var plannedEndAt: Date
    var endedAt: Date?
    var state: FocusRunState
    var phoneAwayValidatedAt: Date?
    var proximityHistory: [ProximityReading]
    var warningCount: Int
    var completedSuccessfully: Bool
    var endedEarlyReason: EarlyEndReason?
    var earnedRewardIDs: [UUID]

    init(id: UUID = UUID(), plannedDurationSeconds: TimeInterval, startedAt: Date = Date(), state: FocusRunState = .placementGrace) {
        self.id = id
        self.plannedDurationSeconds = plannedDurationSeconds
        self.actualDurationSeconds = 0
        self.startedAt = startedAt
        self.plannedEndAt = startedAt.addingTimeInterval(plannedDurationSeconds)
        self.endedAt = nil
        self.state = state
        self.phoneAwayValidatedAt = nil
        self.proximityHistory = []
        self.warningCount = 0
        self.completedSuccessfully = false
        self.endedEarlyReason = nil
        self.earnedRewardIDs = []
    }
}

enum EarlyEndReason: String, Codable {
    case userEnded, phoneReturnedTooSoon, signalLostTooLong, appInterrupted, unsupported
}

struct SessionEvent: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let title: String
    let detail: String?
    let severity: EventSeverity

    init(id: UUID = UUID(), timestamp: Date = Date(), title: String, detail: String? = nil, severity: EventSeverity = .info) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.detail = detail
        self.severity = severity
    }
}

enum EventSeverity: String, Codable {
    case info, success, warning, critical
}

enum RewardType: String, Codable, CaseIterable {
    case ollieMail, letter, ribbon, trophy, tennisBall, stick, postcard, sheepBadge, fieldMap, muddyPaw
}

enum RewardRarity: String, Codable, CaseIterable {
    case common, uncommon, rare, legendary, consolation, demo
}

struct RewardItem: Codable, Identifiable, Equatable {
    let id: UUID
    let type: RewardType
    let rarity: RewardRarity
    let title: String
    let description: String
    let earnedAt: Date
    let runDurationMinutes: Int
    let isDemoReward: Bool
}

struct UserProgress: Codable, Equatable {
    var totalCompletedRuns: Int
    var totalFocusMinutes: Int
    var currentStreak: Int
    var longestStreak: Int
    var rewardsCollected: Int
    var ollieLevel: Int

    static let empty = UserProgress(totalCompletedRuns: 0, totalFocusMinutes: 0, currentStreak: 0, longestStreak: 0, rewardsCollected: 0, ollieLevel: 1)

    var levelTitle: String {
        switch ollieLevel {
        case 1: return "Pup Ollie"
        case 2: return "Yard Runner"
        case 3: return "Field Scout"
        case 4: return "Sheep Herder"
        default: return "Focus Guardian"
        }
    }
}
