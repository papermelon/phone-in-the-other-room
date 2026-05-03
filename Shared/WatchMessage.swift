import Foundation

enum WatchMessageType: String, Codable {
    case startFocusRun, stopFocusRun, endFocusRunEarly, pingPhone, pingWatch, nearbyDiscoveryToken, proximityStateUpdate, focusRunStateUpdate, rewardEarned, calibrationUpdate, demoDistanceUpdate
}

struct WatchMessage: Codable {
    var type: WatchMessageType
    var run: FocusRun?
    var proximity: ProximityState?
    var reward: RewardItem?
    var tokenData: Data?
    var demoDistance: Double?
    var sentAt: Date

    init(type: WatchMessageType, run: FocusRun? = nil, proximity: ProximityState? = nil, reward: RewardItem? = nil, tokenData: Data? = nil, demoDistance: Double? = nil, sentAt: Date = Date()) {
        self.type = type
        self.run = run
        self.proximity = proximity
        self.reward = reward
        self.tokenData = tokenData
        self.demoDistance = demoDistance
        self.sentAt = sentAt
    }
}

enum WatchMessageCodec {
    static func dictionary(from message: WatchMessage) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(message) else { return [:] }
        return ["payload": data]
    }

    static func message(from dictionary: [String: Any]) -> WatchMessage? {
        guard let data = dictionary["payload"] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchMessage.self, from: data)
    }
}

