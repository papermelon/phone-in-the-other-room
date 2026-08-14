import Foundation

enum OllieMood: String, Codable, CaseIterable {
    case waiting, excited, running, guarding, alert, proud, happy, sad, sleepy
}

enum ProximityBucket: String, Codable, CaseIterable {
    case waitingForDistance, withYou, sameRoom, doorway, probablyOtherRoom, signalLost, unsupported, demo

    var label: String {
        switch self {
        case .waitingForDistance: return "Waiting for distance"
        case .withYou: return "Phone is with you"
        case .sameRoom: return "Phone is nearby"
        case .doorway: return "Phone is drifting away"
        case .probablyOtherRoom: return "Phone is resting in the other room"
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
        case .setup: return "Set up Wind Down"
        case .placementGrace: return "Put your phone in the other room"
        case .waitingForPhoneAway: return "Ollie is waiting for the phone to reach its bed"
        case .running: return "Ollie is guarding Wind Down"
        case .warningPhoneTooClose: return "Phone is getting too close"
        case .completed: return "Wind Down is complete"
        case .endedEarly: return "Wind Down ended early"
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

    static let initial = ProximityState(bucket: .waitingForDistance, distanceMeters: nil, confidence: .low, source: .fallback, lastUpdated: Date(), statusText: ProximityBucket.waitingForDistance.label, detailText: "Phone distance appears during the optional Watch check.")
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
    var guardKind: SessionGuardKind
    var placementStatus: PlacementStatus
    var placementEvidence: PlacementEvidence
    var nightWatchPlan: NightWatchPlan?
    var briefAccessUseCount: Int
    /// The optional five-minute orientation practice is a real recorded run,
    /// but it must never earn Phone Away search credit.
    var isPractice: Bool
    /// A per-run choice. This prevents "start without app limits" from
    /// changing the person's saved shielding preference.
    var appShieldingRequested: Bool
    /// Whether this specific run was allowed to create a Live Activity. This
    /// remains separate from the Settings default so a relaunch cannot surprise
    /// someone by creating an activity they declined at start time.
    var liveActivityRequested: Bool

    init(
        id: UUID = UUID(),
        plannedDurationSeconds: TimeInterval,
        startedAt: Date = Date(),
        state: FocusRunState = .placementGrace,
        guardKind: SessionGuardKind = .honorTimer,
        nightWatchPlan: NightWatchPlan? = nil,
        appShieldingRequested: Bool = true,
        liveActivityRequested: Bool = true
    ) {
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
        self.guardKind = guardKind
        self.placementStatus = guardKind.needsPlacementConfirmation ? .awaitingConfirmation : .notRequired
        self.placementEvidence = .notRequired(for: guardKind)
        self.nightWatchPlan = nightWatchPlan
        self.briefAccessUseCount = 0
        self.isPractice = false
        self.appShieldingRequested = appShieldingRequested
        self.liveActivityRequested = liveActivityRequested
    }

    enum CodingKeys: String, CodingKey {
        case id, plannedDurationSeconds, actualDurationSeconds, startedAt, plannedEndAt, endedAt
        case state, phoneAwayValidatedAt, proximityHistory, warningCount, completedSuccessfully
        case endedEarlyReason, earnedRewardIDs, guardKind, placementStatus, placementEvidence, nightWatchPlan
        case briefAccessUseCount, isPractice, appShieldingRequested, liveActivityRequested
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        plannedDurationSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .plannedDurationSeconds) ?? 25 * 60
        actualDurationSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .actualDurationSeconds) ?? 0
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        plannedEndAt = try container.decodeIfPresent(Date.self, forKey: .plannedEndAt) ?? startedAt.addingTimeInterval(plannedDurationSeconds)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        state = try container.decodeIfPresent(FocusRunState.self, forKey: .state) ?? .setup
        phoneAwayValidatedAt = try container.decodeIfPresent(Date.self, forKey: .phoneAwayValidatedAt)
        proximityHistory = try container.decodeIfPresent([ProximityReading].self, forKey: .proximityHistory) ?? []
        warningCount = try container.decodeIfPresent(Int.self, forKey: .warningCount) ?? 0
        completedSuccessfully = try container.decodeIfPresent(Bool.self, forKey: .completedSuccessfully) ?? false
        endedEarlyReason = try container.decodeIfPresent(EarlyEndReason.self, forKey: .endedEarlyReason)
        earnedRewardIDs = try container.decodeIfPresent([UUID].self, forKey: .earnedRewardIDs) ?? []
        guardKind = try container.decodeIfPresent(SessionGuardKind.self, forKey: .guardKind) ?? .watchPlacement
        placementStatus = try container.decodeIfPresent(PlacementStatus.self, forKey: .placementStatus)
            ?? (guardKind.needsPlacementConfirmation ? .awaitingConfirmation : .notRequired)
        placementEvidence = try container.decodeIfPresent(PlacementEvidence.self, forKey: .placementEvidence)
            ?? .notRequired(for: guardKind)
        nightWatchPlan = try container.decodeIfPresent(NightWatchPlan.self, forKey: .nightWatchPlan)
        briefAccessUseCount = max(0, try container.decodeIfPresent(Int.self, forKey: .briefAccessUseCount) ?? 0)
        isPractice = try container.decodeIfPresent(Bool.self, forKey: .isPractice) ?? false
        appShieldingRequested = try container.decodeIfPresent(Bool.self, forKey: .appShieldingRequested) ?? true
        liveActivityRequested = try container.decodeIfPresent(Bool.self, forKey: .liveActivityRequested) ?? true
    }
}

enum EarlyEndReason: String, Codable {
    case userEnded
    case nfcTagAuthenticated
    case emergencyBypass
    case phoneReturnedTooSoon
    case signalLostTooLong
    case appInterrupted
    case unsupported
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

enum FocusStarTier: String, Codable, CaseIterable, Identifiable {
    case silver, gold, diamond, rainbow

    var id: String { rawValue }

    var thresholdMinutes: Int {
        switch self {
        case .silver: return 15
        case .gold: return 30
        case .diamond: return 60
        case .rainbow: return 120
        }
    }

    var title: String {
        switch self {
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .diamond: return "Diamond"
        case .rainbow: return "Rainbow"
        }
    }
}

struct DailyFocusRecord: Codable, Identifiable, Equatable {
    var day: Date
    var completedFocusMinutes: Int
    var successfulRuns: Int
    var warnings: Int
    var rewardsEarned: Int

    var id: Date { day }

    init(day: Date, completedFocusMinutes: Int = 0, successfulRuns: Int = 0, warnings: Int = 0, rewardsEarned: Int = 0, calendar: Calendar = .current) {
        self.day = calendar.startOfDay(for: day)
        self.completedFocusMinutes = completedFocusMinutes
        self.successfulRuns = successfulRuns
        self.warnings = warnings
        self.rewardsEarned = rewardsEarned
    }

    var earnedStars: [FocusStarTier] {
        FocusStarTier.allCases.filter { completedFocusMinutes >= $0.thresholdMinutes }
    }

    var bestStar: FocusStarTier? {
        earnedStars.last
    }
}

enum OllieDailyStatus: String, Codable, CaseIterable {
    case waiting, warmedUp, steady, bright

    var mood: OllieMood {
        switch self {
        case .waiting: return .waiting
        case .warmedUp: return .happy
        case .steady: return .proud
        case .bright: return .excited
        }
    }

    var label: String {
        switch self {
        case .waiting: return "Ollie is ready for tonight's Wind Down."
        case .warmedUp: return "Ollie is warmed up by a little phone-free time."
        case .steady: return "Ollie is steady after a protected night."
        case .bright: return "Ollie is bright after a phone-free night."
        }
    }
}

struct UserProgress: Codable, Equatable {
    var totalCompletedRuns: Int
    var totalFocusMinutes: Int
    var currentStreak: Int
    var longestStreak: Int
    var rewardsCollected: Int
    var ollieLevel: Int
    var dailyFocusRecords: [DailyFocusRecord]
    var sheepBalance: Int
    var coinBalance: Int
    var totalSheepEarned: Int
    var totalCoinsEarned: Int

    static let empty = UserProgress(totalCompletedRuns: 0, totalFocusMinutes: 0, currentStreak: 0, longestStreak: 0, rewardsCollected: 0, ollieLevel: 1, dailyFocusRecords: [], sheepBalance: 0, coinBalance: 0, totalSheepEarned: 0, totalCoinsEarned: 0)

    init(totalCompletedRuns: Int, totalFocusMinutes: Int, currentStreak: Int, longestStreak: Int, rewardsCollected: Int, ollieLevel: Int, dailyFocusRecords: [DailyFocusRecord] = [], sheepBalance: Int = 0, coinBalance: Int = 0, totalSheepEarned: Int = 0, totalCoinsEarned: Int = 0) {
        self.totalCompletedRuns = totalCompletedRuns
        self.totalFocusMinutes = totalFocusMinutes
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.rewardsCollected = rewardsCollected
        self.ollieLevel = ollieLevel
        self.dailyFocusRecords = dailyFocusRecords.sorted { $0.day > $1.day }
        self.sheepBalance = sheepBalance
        self.coinBalance = coinBalance
        self.totalSheepEarned = totalSheepEarned
        self.totalCoinsEarned = totalCoinsEarned
    }

    enum CodingKeys: String, CodingKey {
        case totalCompletedRuns, totalFocusMinutes, currentStreak, longestStreak, rewardsCollected, ollieLevel, dailyFocusRecords, sheepBalance, coinBalance, totalSheepEarned, totalCoinsEarned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalCompletedRuns = try container.decodeIfPresent(Int.self, forKey: .totalCompletedRuns) ?? 0
        totalFocusMinutes = try container.decodeIfPresent(Int.self, forKey: .totalFocusMinutes) ?? 0
        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        longestStreak = try container.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        rewardsCollected = try container.decodeIfPresent(Int.self, forKey: .rewardsCollected) ?? 0
        ollieLevel = try container.decodeIfPresent(Int.self, forKey: .ollieLevel) ?? 1
        dailyFocusRecords = try container.decodeIfPresent([DailyFocusRecord].self, forKey: .dailyFocusRecords) ?? []
        dailyFocusRecords.sort { $0.day > $1.day }
        sheepBalance = try container.decodeIfPresent(Int.self, forKey: .sheepBalance) ?? 0
        coinBalance = try container.decodeIfPresent(Int.self, forKey: .coinBalance) ?? 0
        totalSheepEarned = try container.decodeIfPresent(Int.self, forKey: .totalSheepEarned) ?? sheepBalance
        totalCoinsEarned = try container.decodeIfPresent(Int.self, forKey: .totalCoinsEarned) ?? coinBalance
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalCompletedRuns, forKey: .totalCompletedRuns)
        try container.encode(totalFocusMinutes, forKey: .totalFocusMinutes)
        try container.encode(currentStreak, forKey: .currentStreak)
        try container.encode(longestStreak, forKey: .longestStreak)
        try container.encode(rewardsCollected, forKey: .rewardsCollected)
        try container.encode(ollieLevel, forKey: .ollieLevel)
        try container.encode(dailyFocusRecords, forKey: .dailyFocusRecords)
        try container.encode(sheepBalance, forKey: .sheepBalance)
        try container.encode(coinBalance, forKey: .coinBalance)
        try container.encode(totalSheepEarned, forKey: .totalSheepEarned)
        try container.encode(totalCoinsEarned, forKey: .totalCoinsEarned)
    }

    var todayRecord: DailyFocusRecord {
        record(for: Date()) ?? DailyFocusRecord(day: Date())
    }

    var recentFocusRecords: [DailyFocusRecord] {
        Array(dailyFocusRecords.prefix(14))
    }

    var totalFocusStars: Int {
        dailyFocusRecords.reduce(0) { $0 + $1.earnedStars.count }
    }

    var ollieDailyStatus: OllieDailyStatus {
        let todayMinutes = todayRecord.completedFocusMinutes
        if todayMinutes >= FocusStarTier.rainbow.thresholdMinutes { return .bright }
        if todayMinutes >= FocusStarTier.gold.thresholdMinutes || currentStreak >= 3 { return .steady }
        if todayMinutes >= FocusStarTier.silver.thresholdMinutes { return .warmedUp }
        return .waiting
    }

    func record(for date: Date, calendar: Calendar = .current) -> DailyFocusRecord? {
        let day = calendar.startOfDay(for: date)
        return dailyFocusRecords.first { calendar.isDate($0.day, inSameDayAs: day) }
    }

    func starCount(for tier: FocusStarTier) -> Int {
        dailyFocusRecords.filter { $0.completedFocusMinutes >= tier.thresholdMinutes }.count
    }

    mutating func recordCompletedRun(minutes: Int, warnings: Int, rewardEarned: Bool, at date: Date, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: date)
        if let index = dailyFocusRecords.firstIndex(where: { calendar.isDate($0.day, inSameDayAs: day) }) {
            dailyFocusRecords[index].completedFocusMinutes += minutes
            dailyFocusRecords[index].successfulRuns += 1
            dailyFocusRecords[index].warnings += warnings
            if rewardEarned { dailyFocusRecords[index].rewardsEarned += 1 }
        } else {
            dailyFocusRecords.append(
                DailyFocusRecord(
                    day: day,
                    completedFocusMinutes: minutes,
                    successfulRuns: 1,
                    warnings: warnings,
                    rewardsEarned: rewardEarned ? 1 : 0,
                    calendar: calendar
                )
            )
        }
        dailyFocusRecords.sort { $0.day > $1.day }
        dailyFocusRecords = Array(dailyFocusRecords.prefix(45))
    }

    mutating func addFocusEconomy(forCompletedMinutes minutes: Int) {
        let sheepEarned = max(1, minutes / 15)
        let coinsEarned = max(5, sheepEarned * 5)
        sheepBalance += sheepEarned
        coinBalance += coinsEarned
        totalSheepEarned += sheepEarned
        totalCoinsEarned += coinsEarned
    }

    var levelTitle: String {
        switch ollieLevel {
        case 1: return "Pup Ollie"
        case 2: return "Yard Runner"
        case 3: return "Field Scout"
        case 4: return "Sheep Herder"
        default: return "Night Guardian"
        }
    }
}
