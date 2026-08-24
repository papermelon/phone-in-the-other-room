import Foundation

enum WatchMessageType: String, Codable {
    case startFocusRun, stopFocusRun, endFocusRunEarly, pingPhone, pingWatch
    case nearbyDiscoveryToken, nearbyDiscoveryTokenAcknowledged
    case distanceCheckRequest, distanceCheckEnded
    case watchDistanceReading
    case proximityStateUpdate, focusRunStateUpdate, rewardEarned, calibrationUpdate
}

struct WatchMessage: Codable {
    var type: WatchMessageType
    var run: FocusRun?
    var proximity: ProximityState?
    var reward: RewardItem?
    /// A bounded, reward-free projection. Missing on older phone/watch pairs.
    var screenFreeMorning: ScreenFreeMorningPresentation?
    var tokenData: Data?
    var distanceMeters: Double?
    var sentAt: Date

    init(type: WatchMessageType, run: FocusRun? = nil, proximity: ProximityState? = nil, reward: RewardItem? = nil, screenFreeMorning: ScreenFreeMorningPresentation? = nil, tokenData: Data? = nil, distanceMeters: Double? = nil, sentAt: Date = Date()) {
        self.type = type
        self.run = run
        self.proximity = proximity
        self.reward = reward
        self.screenFreeMorning = screenFreeMorning
        self.tokenData = tokenData
        self.distanceMeters = distanceMeters
        self.sentAt = sentAt
    }
}

extension WatchMessage {
    func isFreshRealtimeMessage(for currentRun: FocusRun?, now: Date = Date()) -> Bool {
        guard let currentRun, run?.id == currentRun.id else { return false }
        guard sentAt <= now.addingTimeInterval(5) else { return false }
        return now.timeIntervalSince(sentAt) <= FocusRunRules.realtimeWatchMessageFreshnessSeconds
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
