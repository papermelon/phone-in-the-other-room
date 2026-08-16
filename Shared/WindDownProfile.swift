import Foundation

/// Finite questionnaire answers that produce a non-clinical Wind Down starting point.
/// Answers stay local and never collect a diagnosis, medication history, or free text.
enum WindDownProfileQuestion: String, Codable, CaseIterable, Identifiable {
    case usualSchedule
    case phoneUsePattern
    case awayFriction
    case eveningActivities
    case morningActivities
    case desiredWindDownLength

    var id: String { rawValue }
}

enum WindDownPhoneUsePattern: String, Codable, CaseIterable, Identifiable {
    case beforeBed
    case afterWaking
    case bothEdges
    case irregular

    var id: String { rawValue }
}

enum WindDownAwayFriction: String, Codable, CaseIterable, Identifiable {
    case habitReach
    case unfinishedEvening
    case morningCheck
    case irregularDays
    case hardToStopFeed

    var id: String { rawValue }
}

/// A non-clinical summary of the stated bedtime-screen pattern. This is a
/// Wind Down starting point, never a medical sleep type.
enum WindDownProfileKind: String, Codable, CaseIterable, Identifiable {
    case eveningScreens
    case morningReach
    case bothEdges
    case unevenRhythm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eveningScreens: return "Evening screens"
        case .morningReach: return "Morning reach"
        case .bothEdges: return "Both edges of sleep"
        case .unevenRhythm: return "An uneven rhythm"
        }
    }

    var summary: String {
        switch self {
        case .eveningScreens:
            return "Your Wind Down starting point focuses on putting the phone to bed before the last stretch of the evening."
        case .morningReach:
            return "Your Wind Down starting point keeps a little room after waking before the phone comes back."
        case .bothEdges:
            return "Your Wind Down starting point looks after both the last hour before bed and the first quiet part of morning."
        case .unevenRhythm:
            return "Your Wind Down starting point keeps a familiar wake shape even when nights do not look the same."
        }
    }
}

struct WindDownProfileAnswer: Codable, Equatable {
    var bedtimeHour: Int
    var bedtimeMinute: Int
    var wakeHour: Int
    var wakeMinute: Int
    var phoneUsePattern: WindDownPhoneUsePattern
    var awayFriction: WindDownAwayFriction
    var eveningActivities: [PhoneFreeActivity]
    var morningActivities: [PhoneFreeActivity]
    var desiredWindDownMinutes: Int

    static let defaults = WindDownProfileAnswer(
        bedtimeHour: 23,
        bedtimeMinute: 0,
        wakeHour: 7,
        wakeMinute: 0,
        phoneUsePattern: .beforeBed,
        awayFriction: .habitReach,
        eveningActivities: [.read],
        morningActivities: [.openCurtains],
        desiredWindDownMinutes: 30
    )

    private enum CodingKeys: String, CodingKey {
        case bedtimeHour, bedtimeMinute, wakeHour, wakeMinute
        case phoneUsePattern, awayFriction, eveningActivities, morningActivities
        case desiredWindDownMinutes
    }

    init(
        bedtimeHour: Int,
        bedtimeMinute: Int,
        wakeHour: Int,
        wakeMinute: Int,
        phoneUsePattern: WindDownPhoneUsePattern,
        awayFriction: WindDownAwayFriction,
        eveningActivities: [PhoneFreeActivity],
        morningActivities: [PhoneFreeActivity],
        desiredWindDownMinutes: Int
    ) {
        self.bedtimeHour = min(23, max(0, bedtimeHour))
        self.bedtimeMinute = min(59, max(0, bedtimeMinute))
        self.wakeHour = min(23, max(0, wakeHour))
        self.wakeMinute = min(59, max(0, wakeMinute))
        self.phoneUsePattern = phoneUsePattern
        self.awayFriction = awayFriction
        self.eveningActivities = Self.normalized(
            eveningActivities,
            allowed: PhoneFreeActivity.eveningChoices,
            fallback: .read,
            limit: WindDownRoutineStep.maximumEveningCount
        )
        self.morningActivities = Self.normalized(
            morningActivities,
            allowed: PhoneFreeActivity.morningChoices,
            fallback: .openCurtains,
            limit: WindDownRoutineStep.maximumMorningCount
        )
        self.desiredWindDownMinutes = Self.clampedWindDownMinutes(desiredWindDownMinutes)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            bedtimeHour: try container.decodeIfPresent(Int.self, forKey: .bedtimeHour) ?? 23,
            bedtimeMinute: try container.decodeIfPresent(Int.self, forKey: .bedtimeMinute) ?? 0,
            wakeHour: try container.decodeIfPresent(Int.self, forKey: .wakeHour) ?? 7,
            wakeMinute: try container.decodeIfPresent(Int.self, forKey: .wakeMinute) ?? 0,
            phoneUsePattern: try container.decodeIfPresent(WindDownPhoneUsePattern.self, forKey: .phoneUsePattern) ?? .beforeBed,
            awayFriction: try container.decodeIfPresent(WindDownAwayFriction.self, forKey: .awayFriction) ?? .habitReach,
            eveningActivities: try container.decodeIfPresent([PhoneFreeActivity].self, forKey: .eveningActivities) ?? [.read],
            morningActivities: try container.decodeIfPresent([PhoneFreeActivity].self, forKey: .morningActivities) ?? [.openCurtains],
            desiredWindDownMinutes: try container.decodeIfPresent(Int.self, forKey: .desiredWindDownMinutes) ?? 30
        )
    }

    static let allowedWindDownMinutes = [15, 30, 45, 60]

    static func clampedWindDownMinutes(_ minutes: Int) -> Int {
        allowedWindDownMinutes.min(by: { abs($0 - minutes) < abs($1 - minutes) }) ?? 30
    }

    private static func normalized(
        _ activities: [PhoneFreeActivity],
        allowed: [PhoneFreeActivity],
        fallback: PhoneFreeActivity,
        limit: Int
    ) -> [PhoneFreeActivity] {
        var seen = Set<PhoneFreeActivity>()
        var result: [PhoneFreeActivity] = []
        for activity in activities where allowed.contains(activity) && seen.insert(activity).inserted {
            result.append(activity)
            if result.count == limit { break }
        }
        return result.isEmpty ? [fallback] : result
    }
}

struct WindDownProfileRecommendation: Codable, Equatable {
    var kind: WindDownProfileKind
    var displayName: String
    var summary: String
    var guidanceIDs: [String]
    var eveningRoutine: [WindDownRoutineStep]
    var morningRoutine: [WindDownRoutineStep]
    var wearableItemID: String
    var desiredWindDownMinutes: Int
    var bedtimeHour: Int
    var bedtimeMinute: Int
    var wakeHour: Int
    var wakeMinute: Int

    var wearableItem: FarmShopItem? {
        FarmShopCatalog.item(for: wearableItemID)
    }
}

struct WindDownProfileRecord: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let storageKey = "ollie.windDown.profile"

    var schemaVersion: Int
    var answers: WindDownProfileAnswer
    var recommendation: WindDownProfileRecommendation
    var createdAt: Date
    var updatedAt: Date

    init(
        schemaVersion: Int = currentSchemaVersion,
        answers: WindDownProfileAnswer,
        recommendation: WindDownProfileRecommendation,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.schemaVersion = max(schemaVersion, Self.currentSchemaVersion)
        self.answers = answers
        self.recommendation = recommendation
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum WindDownProfileMapper {
    static func kind(for answers: WindDownProfileAnswer) -> WindDownProfileKind {
        switch answers.phoneUsePattern {
        case .beforeBed: return .eveningScreens
        case .afterWaking: return .morningReach
        case .bothEdges: return .bothEdges
        case .irregular: return .unevenRhythm
        }
    }

    static func recommendation(for answers: WindDownProfileAnswer) -> WindDownProfileRecommendation {
        let kind = kind(for: answers)
        let guidanceIDs = guidanceIDs(for: kind)
        return WindDownProfileRecommendation(
            kind: kind,
            displayName: "Wind Down starting point",
            summary: kind.summary,
            guidanceIDs: guidanceIDs,
            eveningRoutine: routine(
                from: answers.eveningActivities,
                fallback: defaultEveningActivities(for: kind),
                phase: .evening,
                limit: WindDownRoutineStep.maximumEveningCount
            ),
            morningRoutine: routine(
                from: answers.morningActivities,
                fallback: defaultMorningActivities(for: kind),
                phase: .morning,
                limit: WindDownRoutineStep.maximumMorningCount
            ),
            wearableItemID: wearableItemID(for: kind),
            desiredWindDownMinutes: answers.desiredWindDownMinutes,
            bedtimeHour: answers.bedtimeHour,
            bedtimeMinute: answers.bedtimeMinute,
            wakeHour: answers.wakeHour,
            wakeMinute: answers.wakeMinute
        )
    }

    static func guidanceIDs(for kind: WindDownProfileKind) -> [String] {
        let ids: [String]
        switch kind {
        case .eveningScreens:
            ids = ["phone-bed", "quiet-hour", "bed-as-cue"]
        case .morningReach:
            ids = ["phone-bed", "morning-light", "steady-wake"]
        case .bothEdges:
            ids = ["phone-bed", "quiet-hour", "morning-light"]
        case .unevenRhythm:
            ids = ["phone-bed", "steady-wake", "daytime-shape"]
        }
        return ids.filter { id in WindDownGuidanceLibrary.items.contains { $0.id == id } }
    }

    static func wearableItemID(for kind: WindDownProfileKind) -> String {
        switch kind {
        case .eveningScreens: return "shepherd_moon_coat"
        case .morningReach: return "shepherd_wool_hat"
        case .bothEdges: return "shepherd_moss_coat"
        case .unevenRhythm: return "shepherd_moon_coat"
        }
    }

    private static func defaultEveningActivities(for kind: WindDownProfileKind) -> [PhoneFreeActivity] {
        switch kind {
        case .eveningScreens, .bothEdges: return [.read, .makeTea]
        case .morningReach: return [.read]
        case .unevenRhythm: return [.journal, .read]
        }
    }

    private static func defaultMorningActivities(for kind: WindDownProfileKind) -> [PhoneFreeActivity] {
        switch kind {
        case .eveningScreens: return [.openCurtains]
        case .morningReach, .bothEdges: return [.openCurtains, .morningWalk]
        case .unevenRhythm: return [.openCurtains, .breakfast]
        }
    }

    private static func routine(
        from preferred: [PhoneFreeActivity],
        fallback: [PhoneFreeActivity],
        phase: WindDownRoutinePhase,
        limit: Int
    ) -> [WindDownRoutineStep] {
        var seen = Set<PhoneFreeActivity>()
        var activities: [PhoneFreeActivity] = []
        for activity in preferred + fallback where seen.insert(activity).inserted {
            activities.append(activity)
            if activities.count == limit { break }
        }
        return activities.map { activity in
            WindDownRoutineStep.suggested(
                activity,
                phase: phase,
                id: stableStepID(phase: phase, activity: activity)
            )
        }
    }

    private static func stableStepID(phase: WindDownRoutinePhase, activity: PhoneFreeActivity) -> UUID {
        WelcomeRewardCatalog.stableUUID(from: "profile-step:\(phase.rawValue):\(activity.rawValue)")
    }
}
