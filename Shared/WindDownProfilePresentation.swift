import Foundation

extension WindDownProfileQuestion {
    var title: String {
        switch self {
        case .usualSchedule: return "When does the night usually begin and end?"
        case .phoneUsePattern: return "When does the phone tend to stay nearby?"
        case .awayFriction: return "What most often keeps you on your phone when you’d rather stop?"
        case .eveningActivities: return "What might the evening quiet hold?"
        case .morningActivities: return "What might the morning quiet hold?"
        case .desiredWindDownLength: return "How long should the quiet before bed be?"
        case .bedtimeDelay: return "Does your phone ever keep you up later than you meant?"
        case .automaticReaching: return "How often do you reach for it without really deciding to?"
        case .morningChecking: return "After waking, when do you usually first check your phone?"
        case .overnightLocation: return "Where does your phone usually spend the night?"
        case .desiredChange: return "What would feel most different if Counting Sheep worked for you?"
        }
    }

    var detail: String {
        switch self {
        case .usualSchedule:
            return "A familiar bedtime and wake time give Wind Down a shape. You can change this later."
        case .phoneUsePattern:
            return "Choose the closest fit. This is not a diagnosis."
        case .awayFriction:
            return "Choose the closest fit for the moment that keeps going."
        case .eveningActivities:
            return "Pick up to three ideas. They stay private and optional."
        case .morningActivities:
            return "Pick up to two ideas. They stay private and optional."
        case .desiredWindDownLength:
            return "Thirty minutes is a gentle place to begin."
        case .bedtimeDelay, .automaticReaching, .morningChecking, .overnightLocation:
            return "Choose the closest fit."
        case .desiredChange:
            return "Choose the change you would notice most."
        }
    }
}

extension WindDownPhoneUsePattern {
    var title: String {
        switch self {
        case .beforeBed: return "Mostly before bed"
        case .afterWaking: return "Mostly after waking"
        case .bothEdges: return "Both edges of sleep"
        case .irregular: return "It changes from night to night"
        }
    }

    var detail: String {
        switch self {
        case .beforeBed: return "The last stretch of the evening is when the phone stays close."
        case .afterWaking: return "The first quiet part of morning is when the phone comes back."
        case .bothEdges: return "The phone is nearby before bed and again after waking."
        case .irregular: return "Some nights are late, some mornings start on the phone, and it varies."
        }
    }
}

extension WindDownAwayFriction {
    var title: String {
        switch self {
        case .habitReach: return "I reach for it without thinking"
        case .unfinishedEvening: return "I’m not ready to end the day yet"
        case .morningCheck: return "The first morning check"
        case .irregularDays: return "My schedule changes too much for a routine"
        case .hardToStopFeed: return "There’s always one more thing to watch or read"
        case .messages: return "Messages or notifications pull me back"
        case .noDifficulty: return "No particular difficulty"
        case .somethingElse: return "Something else"
        }
    }

    var detail: String {
        switch self {
        case .habitReach: return "The phone is simply nearby, so the hand goes there."
        case .unfinishedEvening: return "There is still one more thing to look at."
        case .morningCheck: return "Waking up and opening the phone happen together."
        case .irregularDays: return "Bedtime and wake time move around."
        case .hardToStopFeed: return "A stream of posts keeps the evening going."
        case .messages: return "A message can make the phone feel hard to leave."
        case .noDifficulty: return "There is not one particular thing that pulls you back."
        case .somethingElse: return "Another reason fits better."
        }
    }

    static let questionnaireChoices: [Self] = [
        .habitReach, .hardToStopFeed, .messages, .unfinishedEvening,
        .irregularDays, .somethingElse
    ]
}

extension WindDownBedtimeDelay {
    var title: String {
        switch self {
        case .rarely: return "Rarely"
        case .sometimes: return "Sometimes"
        case .severalNights: return "Several nights a week"
        case .mostNights: return "Most nights"
        }
    }
}

extension WindDownAutomaticReach {
    var title: String {
        switch self {
        case .rarely: return "Rarely"
        case .sometimes: return "Sometimes"
        case .often: return "Often"
        case .almostAutomatically: return "Almost automatically"
        }
    }
}

extension WindDownMorningCheck {
    var title: String {
        switch self {
        case .immediately: return "Within 5 minutes"
        case .firstFewMinutes: return "Within 15 minutes"
        case .somewhatLater: return "Within 30 minutes"
        case .afterMorningActivity: return "Later than that"
        }
    }
}

extension WindDownOvernightLocation {
    var title: String {
        switch self {
        case .inBed: return "In bed with me"
        case .withinReach: return "Within arm’s reach"
        case .elsewhereInBedroom: return "Elsewhere in my room"
        case .anotherRoom: return "Outside my room"
        }
    }
}

extension WindDownDesiredChange {
    var title: String {
        switch self {
        case .finishEveningEarlier: return "I stop scrolling earlier"
        case .reachLessAutomatically: return "I feel more in control of when I’m online"
        case .protectMorning: return "I wake without checking it immediately"
        case .movePhoneFartherAway: return "My phone stops coming to bed with me"
        case .flexibleCue: return "Find a more flexible cue"
        case .reduceMessagePull: return "Feel less pulled by messages"
        case .allOfThese: return "All of these, really"
        }
    }

    static let questionnaireChoices: [Self] = [
        .finishEveningEarlier,
        .movePhoneFartherAway,
        .protectMorning,
        .reachLessAutomatically,
        .allOfThese
    ]
}

extension WindDownProfileKind {
    var nonClinicalDescription: String { summary }

    var onboardingIllustrationAssetName: String {
        let leaf = switch self {
        case .eveningScreens, .oneMoreThing: "onboarding_pattern_one_more_thing"
        case .morningReach, .morningMagnet: "onboarding_pattern_morning_magnet"
        case .bothEdges, .automaticReach: "onboarding_pattern_automatic_reach"
        case .unevenRhythm, .variableNights: "onboarding_pattern_variable_nights"
        case .messagePull: "onboarding_pattern_message_pull"
        case .bedsideDefault: "onboarding_pattern_bedside_default"
        case .gentleBeginning: "onboarding_pattern_gentle_beginning"
        }
        return "onboarding/\(leaf)"
    }
}

enum WindDownGuidanceSourcePresentation {
    static func title(for sourceID: String) -> String? {
        switch sourceID {
        case "nhlbi-healthy-sleep": return "NHLBI healthy sleep habits"
        case "nhlbi-sleep-wake-cycle": return "NHLBI sleep/wake cycle"
        case "nhlbi-circadian-treatment": return "NHLBI circadian guidance"
        case "va-stimulus-control": return "VA stimulus-control guidance"
        case "aasm-cbt-i": return "AASM behavioral sleep guidance"
        case "counting-sheep-principles": return "Counting Sheep product principles"
        case "counting-sheep-booklet": return "Counting Sheep wellness booklet"
        default: return nil
        }
    }

    static func combinedLabel(for item: WindDownGuidanceItem) -> String {
        let labels = item.sourceIDs.compactMap(title(for:))
        return labels.isEmpty ? "Counting Sheep guidance" : labels.joined(separator: " · ")
    }
}
