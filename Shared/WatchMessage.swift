import Foundation

enum WatchMessageType: String, Codable {
    case startFocusRun, stopFocusRun, endFocusRunEarly, pingPhone, pingWatch
    case nearbyDiscoveryToken, nearbyDiscoveryTokenAcknowledged
    case distanceCheckRequest, distanceCheckEnded
    case watchDistanceReading
    case proximityStateUpdate, focusRunStateUpdate, rewardEarned, calibrationUpdate
    case slumberPartyCheer
}

struct WatchMessage: Codable {
    var type: WatchMessageType
    var run: FocusRun?
    var proximity: ProximityState?
    var reward: RewardItem?
    /// A bounded, reward-free projection. Missing on older phone/watch pairs.
    var screenFreeMorning: ScreenFreeMorningPresentation?
    /// Brief, silent social encouragement. Missing on older phone/watch pairs.
    var slumberPartyCheer: SlumberPartyCheerFeedback?
    var tokenData: Data?
    var distanceMeters: Double?
    var sentAt: Date

    init(type: WatchMessageType, run: FocusRun? = nil, proximity: ProximityState? = nil, reward: RewardItem? = nil, screenFreeMorning: ScreenFreeMorningPresentation? = nil, slumberPartyCheer: SlumberPartyCheerFeedback? = nil, tokenData: Data? = nil, distanceMeters: Double? = nil, sentAt: Date = Date()) {
        self.type = type
        self.run = run
        self.proximity = proximity
        self.reward = reward
        self.screenFreeMorning = screenFreeMorning
        self.slumberPartyCheer = slumberPartyCheer
        self.tokenData = tokenData
        self.distanceMeters = distanceMeters
        self.sentAt = sentAt
    }
}

extension WatchMessage {
    /// Normalizes persisted compatibility data before either device presents
    /// or acts on it. Raw decoding remains backwards-compatible.
    var normalizedForCurrentRelease: Self {
        var normalized = self
        normalized.run = run?.normalizedForCurrentRelease
        return normalized
    }

    /// One routing boundary shared by phone and Watch. Retired Nearby
    /// Interaction messages remain decodable but never reach either device's
    /// current-release action switch.
    var routedForCurrentRelease: Self? {
        let normalized = normalizedForCurrentRelease
        return normalized.isRetiredNearbyInteractionMessage ? nil : normalized
    }

    /// Nearby Interaction transport remains decodable for old installations,
    /// but current release flows must never act on it.
    var isRetiredNearbyInteractionMessage: Bool {
        switch type {
        case .nearbyDiscoveryToken,
             .nearbyDiscoveryTokenAcknowledged,
             .distanceCheckRequest,
             .distanceCheckEnded,
             .watchDistanceReading,
             .proximityStateUpdate,
             .calibrationUpdate:
            return true
        default:
            return false
        }
    }

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
