import Foundation

final class PersistenceService {
    static let shared = PersistenceService()

    private let defaults = UserDefaults.standard
    private let progressKey = "ollie.progress"
    private let rewardsKey = "ollie.rewards"
    private let thresholdKey = "ollie.thresholds"
    private let lastRunKey = "ollie.lastRun"

    var progress: UserProgress {
        get { load(UserProgress.self, key: progressKey) ?? .empty }
        set { save(newValue, key: progressKey) }
    }

    var rewards: [RewardItem] {
        get { load([RewardItem].self, key: rewardsKey) ?? [] }
        set { save(newValue, key: rewardsKey) }
    }

    var thresholds: ThresholdProfile {
        get { load(ThresholdProfile.self, key: thresholdKey) ?? .defaults }
        set { save(newValue, key: thresholdKey) }
    }

    var lastRun: FocusRun? {
        get { load(FocusRun.self, key: lastRunKey) }
        set { save(newValue, key: lastRunKey) }
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T?, key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }
}

