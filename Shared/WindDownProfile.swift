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
    case bedtimeDelay
    case automaticReaching
    case morningChecking
    case overnightLocation
    case desiredChange

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
    case messages
    case noDifficulty
    case somethingElse

    var id: String { rawValue }
}

enum WindDownBedtimeDelay: String, Codable, CaseIterable, Identifiable {
    case rarely, sometimes, severalNights, mostNights
    var id: String { rawValue }
}

enum WindDownAutomaticReach: String, Codable, CaseIterable, Identifiable {
    case rarely, sometimes, often, almostAutomatically
    var id: String { rawValue }
}

enum WindDownMorningCheck: String, Codable, CaseIterable, Identifiable {
    case immediately, firstFewMinutes, somewhatLater, afterMorningActivity
    var id: String { rawValue }
}

enum WindDownOvernightLocation: String, Codable, CaseIterable, Identifiable {
    case inBed, withinReach, elsewhereInBedroom, anotherRoom
    var id: String { rawValue }
}

enum WindDownDesiredChange: String, Codable, CaseIterable, Identifiable {
    case finishEveningEarlier, reachLessAutomatically, protectMorning
    case movePhoneFartherAway, flexibleCue, reduceMessagePull
    case allOfThese
    var id: String { rawValue }
}

/// A non-clinical summary of the stated bedtime-screen pattern. This is a
/// Wind Down starting point, never a medical sleep type.
enum WindDownProfileKind: String, Codable, CaseIterable, Identifiable {
    // Legacy raw values remain decodable from stored schema-one recommendations.
    case eveningScreens
    case morningReach
    case bothEdges
    case unevenRhythm
    case automaticReach
    case oneMoreThing
    case messagePull
    case variableNights
    case morningMagnet
    case bedsideDefault
    case gentleBeginning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .eveningScreens: return "Evening screens"
        case .morningReach: return "Morning reach"
        case .bothEdges: return "Both edges of sleep"
        case .unevenRhythm: return "An uneven rhythm"
        case .automaticReach: return "Automatic Reach"
        case .oneMoreThing: return "One More Thing"
        case .messagePull: return "Message Pull"
        case .variableNights: return "Variable Nights"
        case .morningMagnet: return "Morning Magnet"
        case .bedsideDefault: return "Bedside Default"
        case .gentleBeginning: return "A Gentle Beginning"
        }
    }

    var compactMeaning: String {
        switch self {
        case .eveningScreens:
            return "The phone has the strongest pull near bedtime. Start by moving it before the last scroll begins."
        case .morningReach:
            return "The phone returns quickly after waking. Start by leaving a little room for morning first."
        case .bothEdges:
            return "The phone stays close on both sides of sleep. Start with two small, matching quiet windows."
        case .unevenRhythm:
            return "The shape of the night changes. Start with one familiar phone-away cue you can keep."
        case .automaticReach:
            return "Reaching for your phone can happen before you notice."
        case .oneMoreThing:
            return "One more thing can keep the evening going longer than you meant."
        case .messagePull:
            return "Messages or notifications can pull your attention back."
        case .variableNights:
            return "Your evenings don’t always follow the same clock."
        case .morningMagnet:
            return "Your phone often gets your attention soon after waking."
        case .bedsideDefault:
            return "Your phone tends to stay close when it’s time to sleep."
        case .gentleBeginning:
            return "You can begin with one small phone-away moment that feels possible."
        }
    }

    var symbolName: String {
        switch self {
        case .eveningScreens: return "moon.stars.fill"
        case .morningReach: return "sunrise.fill"
        case .bothEdges: return "rectangle.split.3x1.fill"
        case .unevenRhythm: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .automaticReach: return "hand.tap.fill"
        case .oneMoreThing: return "ellipsis.circle.fill"
        case .messagePull: return "message.fill"
        case .variableNights: return "calendar.badge.clock"
        case .morningMagnet: return "sunrise.fill"
        case .bedsideDefault: return "bed.double.fill"
        case .gentleBeginning: return "leaf.fill"
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
        case .automaticReach, .oneMoreThing, .messagePull, .variableNights,
             .morningMagnet, .bedsideDefault, .gentleBeginning:
            return compactMeaning
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

    // Optional fields are the only authority for the new behavioral profiler.
    // Legacy defaults above remain a Codable bridge, never evidence of an answer.
    var bedtimeDelay: WindDownBedtimeDelay?
    var automaticReaching: WindDownAutomaticReach?
    var morningChecking: WindDownMorningCheck?
    var overnightLocation: WindDownOvernightLocation?
    var mainFriction: WindDownAwayFriction?
    var desiredChange: WindDownDesiredChange?

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
        case bedtimeDelay, automaticReaching, morningChecking, overnightLocation
        case mainFriction, desiredChange
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
        desiredWindDownMinutes: Int,
        bedtimeDelay: WindDownBedtimeDelay? = nil,
        automaticReaching: WindDownAutomaticReach? = nil,
        morningChecking: WindDownMorningCheck? = nil,
        overnightLocation: WindDownOvernightLocation? = nil,
        mainFriction: WindDownAwayFriction? = nil,
        desiredChange: WindDownDesiredChange? = nil
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
        self.bedtimeDelay = bedtimeDelay
        self.automaticReaching = automaticReaching
        self.morningChecking = morningChecking
        self.overnightLocation = overnightLocation
        self.mainFriction = mainFriction
        self.desiredChange = desiredChange
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
            desiredWindDownMinutes: try container.decodeIfPresent(Int.self, forKey: .desiredWindDownMinutes) ?? 30,
            bedtimeDelay: try container.decodeIfPresent(WindDownBedtimeDelay.self, forKey: .bedtimeDelay),
            automaticReaching: try container.decodeIfPresent(WindDownAutomaticReach.self, forKey: .automaticReaching),
            morningChecking: try container.decodeIfPresent(WindDownMorningCheck.self, forKey: .morningChecking),
            overnightLocation: try container.decodeIfPresent(WindDownOvernightLocation.self, forKey: .overnightLocation),
            mainFriction: try container.decodeIfPresent(WindDownAwayFriction.self, forKey: .mainFriction),
            desiredChange: try container.decodeIfPresent(WindDownDesiredChange.self, forKey: .desiredChange)
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
    var secondaryKind: WindDownProfileKind?
    var displayName: String
    var summary: String
    var noticed: [String]
    var suggestedStrategy: String
    var guidanceIDs: [String]
    var eveningRoutine: [WindDownRoutineStep]
    var morningRoutine: [WindDownRoutineStep]
    var wearableItemID: String
    var desiredWindDownMinutes: Int
    var bedtimeHour: Int
    var bedtimeMinute: Int
    var wakeHour: Int
    var wakeMinute: Int

    private enum CodingKeys: String, CodingKey {
        case kind, secondaryKind, displayName, summary, noticed, suggestedStrategy
        case guidanceIDs, eveningRoutine, morningRoutine, wearableItemID
        case desiredWindDownMinutes, bedtimeHour, bedtimeMinute, wakeHour, wakeMinute
    }

    init(
        kind: WindDownProfileKind,
        secondaryKind: WindDownProfileKind? = nil,
        displayName: String,
        summary: String,
        noticed: [String] = [],
        suggestedStrategy: String = "Choose one gentle phone-away moment that feels possible.",
        guidanceIDs: [String],
        eveningRoutine: [WindDownRoutineStep],
        morningRoutine: [WindDownRoutineStep],
        wearableItemID: String,
        desiredWindDownMinutes: Int,
        bedtimeHour: Int,
        bedtimeMinute: Int,
        wakeHour: Int,
        wakeMinute: Int
    ) {
        self.kind = kind
        self.secondaryKind = secondaryKind
        self.displayName = displayName
        self.summary = summary
        self.noticed = noticed
        self.suggestedStrategy = suggestedStrategy
        self.guidanceIDs = guidanceIDs
        self.eveningRoutine = eveningRoutine
        self.morningRoutine = morningRoutine
        self.wearableItemID = wearableItemID
        self.desiredWindDownMinutes = desiredWindDownMinutes
        self.bedtimeHour = bedtimeHour
        self.bedtimeMinute = bedtimeMinute
        self.wakeHour = wakeHour
        self.wakeMinute = wakeMinute
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(WindDownProfileKind.self, forKey: .kind)
        self.init(
            kind: kind,
            secondaryKind: try container.decodeIfPresent(WindDownProfileKind.self, forKey: .secondaryKind),
            displayName: try container.decodeIfPresent(String.self, forKey: .displayName) ?? "Wind Down starting point",
            summary: try container.decodeIfPresent(String.self, forKey: .summary) ?? kind.summary,
            noticed: try container.decodeIfPresent([String].self, forKey: .noticed) ?? [],
            suggestedStrategy: try container.decodeIfPresent(String.self, forKey: .suggestedStrategy)
                ?? "Choose one gentle phone-away moment that feels possible.",
            guidanceIDs: try container.decodeIfPresent([String].self, forKey: .guidanceIDs) ?? [],
            eveningRoutine: try container.decodeIfPresent([WindDownRoutineStep].self, forKey: .eveningRoutine) ?? [],
            morningRoutine: try container.decodeIfPresent([WindDownRoutineStep].self, forKey: .morningRoutine) ?? [],
            wearableItemID: try container.decodeIfPresent(String.self, forKey: .wearableItemID)
                ?? WelcomeRewardCatalog.finishedShepherdWearableIDs[0],
            desiredWindDownMinutes: try container.decodeIfPresent(Int.self, forKey: .desiredWindDownMinutes) ?? 30,
            bedtimeHour: try container.decodeIfPresent(Int.self, forKey: .bedtimeHour) ?? 23,
            bedtimeMinute: try container.decodeIfPresent(Int.self, forKey: .bedtimeMinute) ?? 0,
            wakeHour: try container.decodeIfPresent(Int.self, forKey: .wakeHour) ?? 7,
            wakeMinute: try container.decodeIfPresent(Int.self, forKey: .wakeMinute) ?? 0
        )
    }

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
        rankedKinds(for: answers).first ?? .gentleBeginning
    }

    static func recommendation(for answers: WindDownProfileAnswer) -> WindDownProfileRecommendation {
        let ranked = rankedKinds(for: answers)
        let kind = ranked.first ?? .gentleBeginning
        let secondary = ranked.dropFirst().first
        let guidanceIDs = guidanceIDs(for: kind)
        return WindDownProfileRecommendation(
            kind: kind,
            secondaryKind: secondary,
            displayName: "Wind Down starting point",
            summary: combinedSummary(primary: kind, secondary: secondary),
            noticed: observations(for: answers, primary: kind, secondary: secondary),
            suggestedStrategy: strategy(for: kind),
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
            // Kept solely to decode old persisted records and old reward callers.
            // New welcome-gift selection is independent of the behavioral result.
            wearableItemID: WelcomeRewardCatalog.finishedShepherdWearableIDs[0],
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
        case .eveningScreens, .oneMoreThing, .messagePull:
            ids = ["phone-bed", "quiet-hour", "bed-as-cue"]
        case .morningReach, .morningMagnet:
            ids = ["phone-bed", "morning-light", "steady-wake"]
        case .bothEdges, .automaticReach, .bedsideDefault:
            ids = ["phone-bed", "quiet-hour", "morning-light"]
        case .unevenRhythm, .variableNights:
            ids = ["phone-bed", "steady-wake", "daytime-shape"]
        case .gentleBeginning:
            ids = ["phone-bed", "quiet-hour"]
        }
        return ids.filter { id in WindDownGuidanceLibrary.items.contains { $0.id == id } }
    }

    static func wearableItemID(for kind: WindDownProfileKind) -> String {
        _ = kind
        return WelcomeRewardCatalog.finishedShepherdWearableIDs[0]
    }

    private static func defaultEveningActivities(for kind: WindDownProfileKind) -> [PhoneFreeActivity] {
        switch kind {
        case .eveningScreens, .bothEdges, .oneMoreThing, .messagePull:
            return [.read, .makeTea]
        case .morningReach, .morningMagnet, .gentleBeginning: return [.read]
        case .unevenRhythm, .variableNights: return [.journal, .read]
        case .automaticReach, .bedsideDefault: return [.shower, .read]
        }
    }

    private static func defaultMorningActivities(for kind: WindDownProfileKind) -> [PhoneFreeActivity] {
        switch kind {
        case .eveningScreens, .oneMoreThing, .messagePull, .gentleBeginning:
            return [.openCurtains]
        case .morningReach, .bothEdges, .morningMagnet, .automaticReach, .bedsideDefault:
            return [.openCurtains, .morningWalk]
        case .unevenRhythm, .variableNights: return [.openCurtains, .breakfast]
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

    private static let tieOrder: [WindDownProfileKind] = [
        .automaticReach, .oneMoreThing, .messagePull,
        .variableNights, .morningMagnet, .bedsideDefault
    ]

    private static func rankedKinds(for answers: WindDownProfileAnswer) -> [WindDownProfileKind] {
        var weights = Dictionary(uniqueKeysWithValues: tieOrder.map { ($0, 0) })

        switch answers.bedtimeDelay {
        case .sometimes: weights[.oneMoreThing, default: 0] += 1
        case .severalNights: weights[.oneMoreThing, default: 0] += 3
        case .mostNights: weights[.oneMoreThing, default: 0] += 4
        case .rarely, .none: break
        }
        switch answers.automaticReaching {
        case .sometimes: weights[.automaticReach, default: 0] += 1
        case .often: weights[.automaticReach, default: 0] += 3
        case .almostAutomatically: weights[.automaticReach, default: 0] += 4
        case .rarely, .none: break
        }
        switch answers.morningChecking {
        case .immediately: weights[.morningMagnet, default: 0] += 4
        case .firstFewMinutes: weights[.morningMagnet, default: 0] += 3
        case .somewhatLater: weights[.morningMagnet, default: 0] += 1
        case .afterMorningActivity, .none: break
        }
        switch answers.overnightLocation {
        case .inBed: weights[.bedsideDefault, default: 0] += 4
        case .withinReach: weights[.bedsideDefault, default: 0] += 3
        case .elsewhereInBedroom: weights[.bedsideDefault, default: 0] += 2
        case .anotherRoom, .none: break
        }

        let frictionKind = preferredKind(for: answers.mainFriction)
        if let frictionKind { weights[frictionKind, default: 0] += 4 }

        if let preference = preferredKind(for: answers.desiredChange),
           weights[preference, default: 0] > 0 {
            weights[preference, default: 0] += 1
        }

        let supported = tieOrder.filter { weights[$0, default: 0] >= 2 }
        return supported.sorted { left, right in
            let leftWeight = weights[left, default: 0]
            let rightWeight = weights[right, default: 0]
            if leftWeight != rightWeight { return leftWeight > rightWeight }
            if left == frictionKind { return true }
            if right == frictionKind { return false }
            return (tieOrder.firstIndex(of: left) ?? 0) < (tieOrder.firstIndex(of: right) ?? 0)
        }.prefix(2).map { $0 }
    }

    private static func preferredKind(for friction: WindDownAwayFriction?) -> WindDownProfileKind? {
        switch friction {
        case .habitReach: return .automaticReach
        case .unfinishedEvening, .hardToStopFeed: return .oneMoreThing
        case .messages: return .messagePull
        case .irregularDays: return .variableNights
        case .morningCheck: return .morningMagnet
        case .noDifficulty, .somethingElse, .none: return nil
        }
    }

    private static func preferredKind(for desire: WindDownDesiredChange?) -> WindDownProfileKind? {
        switch desire {
        case .finishEveningEarlier: return .oneMoreThing
        case .reachLessAutomatically: return .automaticReach
        case .protectMorning: return .morningMagnet
        case .movePhoneFartherAway: return .bedsideDefault
        case .flexibleCue: return .variableNights
        case .reduceMessagePull: return .messagePull
        case .allOfThese: return nil
        case .none: return nil
        }
    }

    private static func observations(
        for answers: WindDownProfileAnswer,
        primary: WindDownProfileKind,
        secondary: WindDownProfileKind?
    ) -> [String] {
        [primary, secondary].compactMap { kind in
            guard let kind else { return nil }
            switch kind {
            case .automaticReach:
                return "You often reach for your phone without thinking."
            case .oneMoreThing:
                return answers.mainFriction == .unfinishedEvening
                    ? "You’re often not ready to end the day yet."
                    : "One more thing often keeps the evening going."
            case .messagePull:
                return "Messages or notifications often pull you back."
            case .variableNights:
                return "Your schedule changes from night to night."
            case .morningMagnet:
                return "You often check your phone soon after waking."
            case .bedsideDefault:
                return "Your phone usually spends the night nearby."
            case .gentleBeginning:
                return "You can choose a little more room around the edges of your day."
            case .eveningScreens, .morningReach, .bothEdges, .unevenRhythm:
                return kind.compactMeaning
            }
        }
    }

    private static func combinedSummary(primary: WindDownProfileKind, secondary: WindDownProfileKind?) -> String {
        guard let secondary else { return primary.compactMeaning }
        let first = primary.compactMeaning.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let next = secondary.compactMeaning.prefix(1).lowercased() + secondary.compactMeaning.dropFirst()
        return "\(first), and \(next)"
    }

    private static func strategy(for kind: WindDownProfileKind) -> String {
        switch kind {
        case .automaticReach:
            return "When you notice the reach beginning, pause and put the phone in its resting place."
        case .oneMoreThing, .eveningScreens:
            return "Choose one calm thing to do after the phone goes away. Let that be the end of scrolling for tonight."
        case .messagePull:
            return "Choose a stopping point for messages, then let the phone rest somewhere out of reach."
        case .variableNights, .unevenRhythm:
            return "Start with one familiar cue. Even when bedtime moves around, keep one small phone-away moment consistent."
        case .morningMagnet, .morningReach:
            return "Choose one small morning thing—open the curtains, stretch, or make breakfast—before the phone gets your attention."
        case .bedsideDefault:
            return "Give the phone its own resting place outside the bedroom before you get into bed."
        case .bothEdges:
            return "Choose one small phone-away moment before bed and another after waking."
        case .gentleBeginning:
            return "Start with one small phone-away moment that feels easy to repeat."
        }
    }
}
