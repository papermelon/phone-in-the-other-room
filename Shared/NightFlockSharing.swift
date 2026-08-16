import Foundation

/// Independently controlled Slumber Party sharing. Default-on fields are the
/// join-consent baseline. Sleep and restfulness stay explicit opt-ins and never
/// reuse impact/research consent.
struct NightFlockSharingPreferences: Codable, Equatable, Sendable {
    var shareGoalProgress: Bool
    var shareWindDownCompletion: Bool
    var shareWindDownMinutes: Bool
    var sharePhoneAwayMinutes: Bool
    var sharePhoneTuckedAway: Bool
    var shareShieldingStatus: Bool
    var shareRoutineIdeas: Bool
    var shareSleepDuration: Bool
    var shareRestfulness: Bool

    static let joinDefaults = NightFlockSharingPreferences()

    init(
        shareGoalProgress: Bool = true,
        shareWindDownCompletion: Bool = true,
        shareWindDownMinutes: Bool = true,
        sharePhoneAwayMinutes: Bool = true,
        sharePhoneTuckedAway: Bool = true,
        shareShieldingStatus: Bool = true,
        shareRoutineIdeas: Bool = false,
        shareSleepDuration: Bool = false,
        shareRestfulness: Bool = false
    ) {
        self.shareGoalProgress = shareGoalProgress
        self.shareWindDownCompletion = shareWindDownCompletion
        self.shareWindDownMinutes = shareWindDownMinutes
        self.sharePhoneAwayMinutes = sharePhoneAwayMinutes
        self.sharePhoneTuckedAway = sharePhoneTuckedAway
        self.shareShieldingStatus = shareShieldingStatus
        self.shareRoutineIdeas = shareRoutineIdeas
        self.shareSleepDuration = shareSleepDuration
        self.shareRestfulness = shareRestfulness
    }

    private enum CodingKeys: String, CodingKey {
        case shareGoalProgress, shareWindDownCompletion, shareWindDownMinutes
        case sharePhoneAwayMinutes, sharePhoneTuckedAway, shareShieldingStatus
        case shareRoutineIdeas, shareSleepDuration, shareRestfulness
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let goalProgress = try container.decodeIfPresent(Bool.self, forKey: .shareGoalProgress) ?? true
        self.init(
            shareGoalProgress: goalProgress,
            shareWindDownCompletion: try container.decodeIfPresent(Bool.self, forKey: .shareWindDownCompletion) ?? goalProgress,
            shareWindDownMinutes: try container.decodeIfPresent(Bool.self, forKey: .shareWindDownMinutes) ?? goalProgress,
            sharePhoneAwayMinutes: try container.decodeIfPresent(Bool.self, forKey: .sharePhoneAwayMinutes) ?? goalProgress,
            sharePhoneTuckedAway: try container.decodeIfPresent(Bool.self, forKey: .sharePhoneTuckedAway) ?? goalProgress,
            shareShieldingStatus: try container.decodeIfPresent(Bool.self, forKey: .shareShieldingStatus) ?? goalProgress,
            shareRoutineIdeas: try container.decodeIfPresent(Bool.self, forKey: .shareRoutineIdeas) ?? false,
            shareSleepDuration: try container.decodeIfPresent(Bool.self, forKey: .shareSleepDuration) ?? false,
            shareRestfulness: try container.decodeIfPresent(Bool.self, forKey: .shareRestfulness) ?? false
        )
    }
}

enum NightFlockSharedMetricRules {
    static let windDownMinuteStep = 5
    static let windDownMinuteMaximum = 180
    static let phoneAwayMinuteStep = 5
    static let phoneAwayMinuteMaximum = 240
    static let sleepMinuteStep = 15
    static let sleepMinuteMaximum = 720

    static func roundWindDownMinutes(_ minutes: Int) -> Int? {
        roundIfValid(minutes, step: windDownMinuteStep, maximum: windDownMinuteMaximum)
    }

    static func roundPhoneAwayMinutes(_ minutes: Int) -> Int? {
        roundIfValid(minutes, step: phoneAwayMinuteStep, maximum: phoneAwayMinuteMaximum)
    }

    static func roundSleepMinutes(_ minutes: Int) -> Int? {
        roundIfValid(minutes, step: sleepMinuteStep, maximum: sleepMinuteMaximum)
    }

    /// Values outside `0...maximum` are rejected, not clamped-and-accepted.
    static func roundIfValid(_ minutes: Int, step: Int, maximum: Int) -> Int? {
        guard (0...maximum).contains(minutes) else { return nil }
        guard step > 0 else { return minutes }
        let rounded = Int((Double(minutes) / Double(step)).rounded()) * step
        return min(max(0, rounded), maximum)
    }
}

enum NightFlockProgressRules {
    static func isQualifying(_ status: NightFlockMemberNightStatus) -> Bool {
        status == .sharedGoalCompleted || status == .morningQuietCompleted
    }

    static func statusRank(_ status: NightFlockMemberNightStatus) -> Int {
        switch status {
        case .privateNoUpdate: return 0
        case .goalAccepted: return 1
        case .setupReady: return 2
        case .phoneTuckedAway: return 3
        case .partiallyCompleted: return 4
        case .sharedGoalCompleted: return 5
        case .morningQuietCompleted: return 6
        }
    }

    static func monotonicStatus(
        current: NightFlockMemberNightStatus?,
        proposed: NightFlockMemberNightStatus
    ) -> NightFlockMemberNightStatus {
        guard let current else { return proposed }
        return statusRank(proposed) >= statusRank(current) ? proposed : current
    }

    static func status(
        for goal: NightFlockSharedGoal?,
        tuckedAway: Bool,
        completedSuccessfully: Bool,
        quietMinutes: Int,
        shielding: NightFlockShieldingEvidence
    ) -> NightFlockMemberNightStatus {
        guard tuckedAway || completedSuccessfully else { return .privateNoUpdate }
        if completedSuccessfully {
            switch goal?.kind {
            case .quietMinutes:
                let target = goal?.targetMinutes ?? 30
                return quietMinutes >= target ? .morningQuietCompleted : .partiallyCompleted
            case .shieldInstagram:
                return shielding == .observed ? .morningQuietCompleted : .partiallyCompleted
            case .phoneAway, .none:
                return .morningQuietCompleted
            }
        }
        if tuckedAway {
            switch goal?.kind {
            case .quietMinutes:
                let target = goal?.targetMinutes ?? 30
                return quietMinutes >= target ? .sharedGoalCompleted : .phoneTuckedAway
            case .shieldInstagram:
                return shielding == .observed ? .sharedGoalCompleted : .phoneTuckedAway
            case .phoneAway, .none:
                return .phoneTuckedAway
            }
        }
        return .privateNoUpdate
    }
}

struct NightFlockLocalNightMetrics: Equatable, Sendable {
    var windDownMinutes: Int
    var phoneAwayMinutes: Int
    var shieldingEvidence: NightFlockShieldingEvidence
    var tuckedAway: Bool
    var completedSuccessfully: Bool
    var sleepDurationMinutes: Int?
    var restfulness: MorningRestfulness?

    var roundedWindDownMinutes: Int? {
        NightFlockSharedMetricRules.roundWindDownMinutes(windDownMinutes)
    }

    var roundedPhoneAwayMinutes: Int? {
        NightFlockSharedMetricRules.roundPhoneAwayMinutes(phoneAwayMinutes)
    }

    var roundedSleepMinutes: Int? {
        sleepDurationMinutes.flatMap(NightFlockSharedMetricRules.roundSleepMinutes)
    }
}

enum NightFlockProjectionRules {
    static func projectedStatus(
        _ status: NightFlockMemberNightStatus,
        sharing: NightFlockSharingPreferences
    ) -> NightFlockMemberNightStatus {
        switch status {
        case .privateNoUpdate:
            return .privateNoUpdate
        case .goalAccepted, .setupReady:
            return sharing.shareGoalProgress ? status : .privateNoUpdate
        case .phoneTuckedAway:
            return sharing.sharePhoneTuckedAway ? .phoneTuckedAway : .privateNoUpdate
        case .partiallyCompleted, .sharedGoalCompleted, .morningQuietCompleted:
            if sharing.shareWindDownCompletion { return status }
            if sharing.sharePhoneTuckedAway { return .phoneTuckedAway }
            return .privateNoUpdate
        }
    }

    static func projectedProgress(
        _ progress: NightFlockMemberNightProgress,
        sharing: NightFlockSharingPreferences
    ) -> NightFlockMemberNightProgress {
        var projected = progress
        projected.status = projectedStatus(progress.status, sharing: sharing)
        if !sharing.shareShieldingStatus {
            projected.shieldingEvidence = .notRequested
        }
        if !sharing.shareWindDownMinutes {
            projected.windDownMinutes = nil
        }
        if !sharing.sharePhoneAwayMinutes {
            projected.phoneAwayMinutes = nil
        }
        if !sharing.shareSleepDuration {
            projected.sleepDurationMinutes = nil
        }
        if !sharing.shareRestfulness {
            projected.restfulness = nil
        }
        return projected
    }
}

enum NightFlockSharingConsentCopy {
    static let joinDisclosure = "By joining, this group can see your name, whether you followed through, rounded Wind Down and Phone Away minutes, and whether your phone was tucked away. Sleep duration and how rested you felt stay off unless you turn them on."
}

enum NightFlockRunShareContextResolver {
    static func resolve(
        runID: UUID,
        memory: [UUID: NightFlockRunShareContext],
        persisted: [NightFlockRunShareContext]
    ) -> NightFlockRunShareContext? {
        memory[runID] ?? persisted.first { $0.runID == runID }
    }
}
