import Foundation

enum RewardType: String, Codable, CaseIterable {
    case ollieMail, letter, ribbon, trophy, tennisBall, stick, postcard, sheepBadge, fieldMap, muddyPaw
}

enum RewardRarity: String, Codable, CaseIterable {
    case common, uncommon, rare, legendary, consolation, demo
}

enum RewardFamily: String, Codable, CaseIterable {
    case ollieNote
    case pastureFind
    case nightMarker
    case freshStart

    var title: String {
        switch self {
        case .ollieNote: return "Ollie's note"
        case .pastureFind: return "Pasture find"
        case .nightMarker: return "Night marker"
        case .freshStart: return "Fresh-start keepsake"
        }
    }
}

struct RewardContext: Codable, Equatable {
    let windDownMinutes: Int
    let morningQuietMinutes: Int
    let eveningActivity: PhoneFreeActivity?
    let morningActivity: PhoneFreeActivity?
    let protectedNightNumber: Int

    var quietMinutes: Int {
        windDownMinutes + morningQuietMinutes
    }

    var bookendSummary: String {
        "\(windDownMinutes) min before bed · \(morningQuietMinutes) min after waking"
    }

    var activitySummary: String? {
        guard let eveningActivity, let morningActivity else { return nil }
        return "\(eveningActivity.shortTitle) · \(morningActivity.shortTitle)"
    }
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
    let context: RewardContext?

    init(
        id: UUID,
        type: RewardType,
        rarity: RewardRarity,
        title: String,
        description: String,
        earnedAt: Date,
        runDurationMinutes: Int,
        isDemoReward: Bool,
        context: RewardContext? = nil
    ) {
        self.id = id
        self.type = type
        self.rarity = rarity
        self.title = title
        self.description = description
        self.earnedAt = earnedAt
        self.runDurationMinutes = runDurationMinutes
        self.isDemoReward = isDemoReward
        self.context = context
    }

    var family: RewardFamily {
        if rarity == .consolation { return .freshStart }

        switch type {
        case .ollieMail, .letter, .postcard:
            return .ollieNote
        case .tennisBall, .stick, .fieldMap:
            return .pastureFind
        case .ribbon, .trophy, .sheepBadge:
            return .nightMarker
        case .muddyPaw:
            return .freshStart
        }
    }

    var gentleReflection: String? {
        guard context != nil else { return nil }

        switch family {
        case .ollieNote:
            return "A familiar wind-down can make putting the phone to bed feel easier to repeat."
        case .pastureFind:
            return "The time away from the screen left a little more room for the evening and morning you chose."
        case .nightMarker:
            return "Quiet nights gather one at a time. A gap never takes the earlier ones away."
        case .freshStart:
            return "Even a shorter quiet window can help the phone-away ritual feel more familiar."
        }
    }
}
