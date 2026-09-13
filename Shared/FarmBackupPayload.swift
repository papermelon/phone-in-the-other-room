import Foundation

/// Explicit private backup projection. Keeping this
/// separate from FarmSaveDocument prevents the account transport from accidentally
/// sending daily history, active runs or the device's authorization journal.
struct FarmBackupPayload: Codable, Equatable {
    static let currentSchemaVersion = 1
    let schemaVersion: Int
    let economyVersion: Int
    let lineageID: UUID
    let farm: FarmState
    let search: SheepSearchState
    let welcome: WelcomeRewardLedger
    let socialRewards: NightFlockRewardLedger
    let sunrise: SunriseTrailState
    let completedWindDownCount: Int
    let keepsakes: [FarmBackupKeepsake]
    let deliveredWindDownRunIDs: [UUID]
    let deliveredEffectIDs: [String]
    let pasture: PastureSceneSnapshot?
    let appearance: CountingSheepPublicPresentation?

    init(document: FarmSaveDocument, pasture: PastureSceneSnapshot? = nil,
         appearance: CountingSheepPublicPresentation? = nil) throws {
        _ = try document.validated()
        func value<T: Decodable>(_ type: T.Type, _ key: String, fallback: T) throws -> T {
            guard let data = document.values[key] else { return fallback }
            return try JSONDecoder().decode(type, from: data)
        }
        let farm = try value(FarmState.self, "ollie.farm.state", fallback: .empty)
        // Upload eligibility requires local migration and settlement first;
        // otherwise a restored old history could be credited again later.
        guard farm.cumulativeCredit?.migrationCompleted == true else { throw FarmSaveError.unavailable }
        self.schemaVersion = Self.currentSchemaVersion
        self.economyVersion = 1
        self.lineageID = document.lineageID
        self.farm = farm
        self.search = try value(SheepSearchState.self, "ollie.sheepSearch.state", fallback: .empty)
        self.welcome = try value(WelcomeRewardLedger.self, WelcomeRewardLedger.storageKey, fallback: .empty)
        self.socialRewards = try value(NightFlockRewardLedger.self, NightFlockRewardLedger.storageKey, fallback: .empty)
        let journal = try value(WindDownMorningSettlementJournal.self,
                                WindDownMorningSettlementJournal.storageKey,
                                fallback: WindDownMorningSettlementJournal())
        self.sunrise = journal.sunriseTrail
        self.completedWindDownCount = try value(UserProgress.self, "ollie.progress", fallback: .empty).farmCompletedRuns
        self.keepsakes = try value([RewardItem].self, "ollie.rewards", fallback: []).map(FarmBackupKeepsake.init)
        self.deliveredWindDownRunIDs = Array(Set(journal.windDownBenefits.filter(\.isDelivered).map(\.runID)
            + (journal.restoredDeliveredWindDownRunIDs ?? []))).sorted { $0.uuidString < $1.uuidString }
        self.deliveredEffectIDs = journal.deliveredEffectIDs
        self.pasture = pasture
        self.appearance = appearance
    }
}

struct FarmBackupKeepsake: Codable, Equatable {
    let id: UUID
    let type: RewardType
    let rarity: RewardRarity
    let title: String
    let earnedAt: Date
    let isDemoReward: Bool

    init(_ reward: RewardItem) {
        id = reward.id
        type = reward.type
        rarity = reward.rarity
        title = reward.title
        earnedAt = reward.earnedAt
        isDemoReward = reward.isDemoReward
    }
}
