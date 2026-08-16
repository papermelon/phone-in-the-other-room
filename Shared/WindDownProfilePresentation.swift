import Foundation

extension WindDownProfileQuestion {
    var title: String {
        switch self {
        case .usualSchedule: return "When does the night usually begin and end?"
        case .phoneUsePattern: return "When does the phone tend to stay nearby?"
        case .awayFriction: return "What makes putting it away feel hard?"
        case .eveningActivities: return "What might the evening quiet hold?"
        case .morningActivities: return "What might the morning quiet hold?"
        case .desiredWindDownLength: return "How long should the quiet before bed be?"
        }
    }

    var detail: String {
        switch self {
        case .usualSchedule:
            return "A familiar bedtime and wake time give Wind Down a shape. You can change this later."
        case .phoneUsePattern:
            return "This is about the edges of sleep, not a diagnosis."
        case .awayFriction:
            return "Choose the closest fit. There is no wrong answer."
        case .eveningActivities:
            return "Pick up to three ideas. They stay private and optional."
        case .morningActivities:
            return "Pick up to two ideas. They stay private and optional."
        case .desiredWindDownLength:
            return "Thirty minutes is a gentle place to begin."
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
        case .habitReach: return "Reaching for it is a habit"
        case .unfinishedEvening: return "The evening still feels unfinished"
        case .morningCheck: return "Morning starts with a check"
        case .irregularDays: return "Days do not keep the same shape"
        case .hardToStopFeed: return "A feed is hard to put down"
        }
    }

    var detail: String {
        switch self {
        case .habitReach: return "The phone is simply nearby, so the hand goes there."
        case .unfinishedEvening: return "There is still one more thing to look at."
        case .morningCheck: return "Waking up and opening the phone happen together."
        case .irregularDays: return "Bedtime and wake time move around."
        case .hardToStopFeed: return "A stream of posts keeps the evening going."
        }
    }
}

extension WindDownProfileKind {
    var nonClinicalDescription: String { summary }
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
