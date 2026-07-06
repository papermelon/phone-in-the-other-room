import Foundation
import SwiftUI

enum MockRarity: String, CaseIterable, Identifiable {
    case common = "Common"
    case uncommon = "Uncommon"
    case rare = "Rare"
    case special = "Special"
    case legendary = "Legendary"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .common: return AppColors.wool
        case .uncommon: return AppColors.grassLight
        case .rare: return AppColors.sky
        case .special: return AppColors.lavender
        case .legendary: return AppColors.amber
        }
    }
}

struct MockFocusSession: Identifiable {
    let id = UUID()
    var title: String
    var focusType: String
    var plannedMinutes: Int
    var completedMinutes: Int
    var outcome: String
    var rewardSummary: String
    var dateLabel: String
}

struct MockSheep: Identifiable {
    let id = UUID()
    var name: String
    var assetName: String
    var rarity: MockRarity
    var source: String
    var isUnlocked: Bool
}

struct MockDogState: Identifiable {
    let id = UUID()
    var name: String
    var assetName: String
    var mood: OllieMood
    var energy: Int
    var bondLevel: Int
    var outfit: String
    var favoriteTreat: String
}

struct MockMission: Identifiable {
    let id = UUID()
    var title: String
    var detail: String
    var icon: String
    var progress: Double
    var progressLabel: String
    var reward: String
    var cadence: String
    var isClaimable: Bool
}

struct MockReward: Identifiable {
    let id = UUID()
    var title: String
    var assetName: String
    var detail: String
    var rarity: MockRarity
    var icon: String
}

struct MockScreenTimeStatistic: Identifiable {
    let id = UUID()
    var title: String
    var value: String
    var detail: String
    var icon: String
    var progress: Double
}

struct MockFarmUnlock: Identifiable {
    let id = UUID()
    var title: String
    var assetName: String
    var detail: String
    var cost: String
    var isUnlocked: Bool
    var icon: String
}

struct MockFriendActivity: Identifiable {
    let id = UUID()
    var name: String
    var detail: String
    var icon: String
    var reaction: String
}

enum MVPMockData {
    static let dog = MockDogState(
        name: "Ollie",
        assetName: AssetSlot.Dog.idle,
        mood: .happy,
        energy: 78,
        bondLevel: 4,
        outfit: "Blue focus bandana",
        favoriteTreat: "Apple oat biscuits"
    )

    static let sessions = [
        MockFocusSession(title: "Morning Study Run", focusType: "Study", plannedMinutes: 25, completedMinutes: 25, outcome: "Completed", rewardSummary: "+2 wool, Common White Sheep", dateLabel: "Today"),
        MockFocusSession(title: "Lunch Reset", focusType: "Be Present", plannedMinutes: 15, completedMinutes: 12, outcome: "Partial", rewardSummary: "+1 wool", dateLabel: "Today"),
        MockFocusSession(title: "Deep Work Sprint", focusType: "Work", plannedMinutes: 45, completedMinutes: 45, outcome: "Completed", rewardSummary: "+4 wool, Blue collar", dateLabel: "Yesterday"),
        MockFocusSession(title: "Evening Wind Down", focusType: "Sleep Better", plannedMinutes: 30, completedMinutes: 30, outcome: "Completed", rewardSummary: "+3 wool, Night Sheep progress", dateLabel: "Yesterday")
    ]

    static let sheep = [
        MockSheep(name: "Common White Sheep", assetName: "sheep_common_white", rarity: .common, source: "Any completed Focus Run", isUnlocked: true),
        MockSheep(name: "Cream Sheep", assetName: "sheep_cream", rarity: .common, source: "Daily focus reward", isUnlocked: true),
        MockSheep(name: "Fluffy Sheep", assetName: "sheep_fluffy", rarity: .common, source: "First 3 sessions", isUnlocked: true),
        MockSheep(name: "Black Sheep", assetName: "sheep_black", rarity: .uncommon, source: "No Peek mission", isUnlocked: true),
        MockSheep(name: "Spotted Sheep", assetName: "sheep_spotted", rarity: .uncommon, source: "Weekly chest", isUnlocked: false),
        MockSheep(name: "Golden Sheep", assetName: "sheep_golden", rarity: .rare, source: "Long session bonus", isUnlocked: false),
        MockSheep(name: "Night Sheep", assetName: "sheep_night", rarity: .special, source: "Evening focus streak", isUnlocked: false),
        MockSheep(name: "Guardian Sheep", assetName: "sheep_guardian", rarity: .legendary, source: "Launch achievement", isUnlocked: false)
    ]

    static let missions = [
        MockMission(title: "Daily Focus", detail: "Complete one 15-minute phone-away session.", icon: "timer", progress: 1.0, progressLabel: "1 / 1", reward: "+2 wool", cadence: "Daily", isClaimable: true),
        MockMission(title: "No Peek", detail: "Finish a session without bringing the phone back early.", icon: "shield.checkered", progress: 0.65, progressLabel: "13 / 20 min", reward: "Black Sheep chance", cadence: "Daily", isClaimable: false),
        MockMission(title: "Streak Starter", detail: "Complete sessions 3 days in a row.", icon: "flame.fill", progress: 0.66, progressLabel: "2 / 3 days", reward: "3-Day Streak badge", cadence: "Weekly", isClaimable: false),
        MockMission(title: "Long Walk Home", detail: "Complete 60 total focus minutes this week.", icon: "figure.walk", progress: 0.83, progressLabel: "50 / 60 min", reward: "+8 wool", cadence: "Weekly", isClaimable: false),
        MockMission(title: "Sheep Finder", detail: "Collect 3 sheep for the farm.", icon: "cloud.fill", progress: 1.0, progressLabel: "3 / 3", reward: "Sheep Finder badge", cadence: "Achievement", isClaimable: true),
        MockMission(title: "Moonlit Pasture", detail: "Complete two evening sessions.", icon: "moon.stars.fill", progress: 0.5, progressLabel: "1 / 2", reward: "Night Sheep", cadence: "Event", isClaimable: false)
    ]

    static let rewards = [
        MockReward(title: "Wool Bundle", assetName: "reward_wool_bundle", detail: "Soft currency for farm upgrades.", rarity: .common, icon: "circle.hexagongrid.fill"),
        MockReward(title: "Blue Focus Bandana", assetName: "dog_bandana_focus_blue", detail: "Ollie cosmetic overlay.", rarity: .uncommon, icon: "tag.fill"),
        MockReward(title: "Sheep Finder Badge", assetName: "badge_sheep_finder", detail: "Achievement badge for collecting 3 sheep.", rarity: .rare, icon: "seal.fill"),
        MockReward(title: "Hay Bale", assetName: "farm_hay_bale", detail: "Farm decoration placeholder.", rarity: .common, icon: "shippingbox.fill")
    ]

    static let statistics = [
        MockScreenTimeStatistic(title: "Focus minutes", value: "50 min", detail: "Mock fallback for today", icon: "timer", progress: 0.83),
        MockScreenTimeStatistic(title: "Phone-away time", value: "72 min", detail: "Includes partial sessions", icon: "iphone.slash", progress: 0.72),
        MockScreenTimeStatistic(title: "Screen time saved", value: "28 min", detail: "Estimated vs baseline", icon: "chart.line.downtrend.xyaxis", progress: 0.46),
        MockScreenTimeStatistic(title: "Current streak", value: "2 days", detail: "Daily session streak", icon: "flame.fill", progress: 0.66),
        MockScreenTimeStatistic(title: "Sheep earned", value: "4 / 13", detail: "MVP collection progress", icon: "cloud.fill", progress: 0.31),
        MockScreenTimeStatistic(title: "Best session", value: "45 min", detail: "Longest completed Focus Run", icon: "checkmark.seal.fill", progress: 0.75)
    ]

    static let farmUnlocks = [
        MockFarmUnlock(title: "Bigger Pasture", assetName: "farm_pasture_upgrade", detail: "Holds more sheep in the overview.", cost: "100 wool", isUnlocked: false, icon: "square.grid.3x3.fill"),
        MockFarmUnlock(title: "Cozy Barn", assetName: AssetSlot.Farm.barn, detail: "Future rare sheep unlock hook.", cost: "3-day streak", isUnlocked: true, icon: "house.fill"),
        MockFarmUnlock(title: "Flower Patch", assetName: "farm_flower_patch", detail: "Weekly mission decoration.", cost: "Weekly chest", isUnlocked: false, icon: "camera.macro"),
        MockFarmUnlock(title: "Training Field", assetName: "farm_training_field", detail: "Future reward multiplier slot.", cost: "5 sessions", isUnlocked: false, icon: "flag.fill")
    ]

    static let friendFeed = [
        MockFriendActivity(name: "Maya", detail: "finished a 25-minute Focus Run.", icon: "timer", reaction: "Cheer"),
        MockFriendActivity(name: "Theo", detail: "unlocked Cream Sheep.", icon: "cloud.fill", reaction: "Send bell"),
        MockFriendActivity(name: "Ari", detail: "kept a 4-day streak.", icon: "flame.fill", reaction: "Celebrate")
    ]
}

