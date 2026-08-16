import Foundation

enum NightFlockOrientationTip: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case sharedGoal
    case mySetup
    case groupProgress
    case sharedRoutineIdeas
    case evidenceAndSources
    case invitingPeople
    case sharingControls

    var id: String { rawValue }
}

struct NightFlockOrientationState: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var hasSeenIntro: Bool
    var isDismissed: Bool
    var seenTips: Set<NightFlockOrientationTip>

    static let fresh = Self(
        schemaVersion: currentSchemaVersion,
        hasSeenIntro: false,
        isDismissed: false,
        seenTips: []
    )

    var shouldShowIntro: Bool { !hasSeenIntro && !isDismissed }

    mutating func finishIntro() {
        hasSeenIntro = true
        isDismissed = false
    }

    mutating func dismissIntro() {
        isDismissed = true
    }

    mutating func markTipSeen(_ tip: NightFlockOrientationTip) {
        seenTips.insert(tip)
    }

    mutating func replay() {
        self = .fresh
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, hasSeenIntro, isDismissed, seenTips
    }

    init(
        schemaVersion: Int = currentSchemaVersion,
        hasSeenIntro: Bool = false,
        isDismissed: Bool = false,
        seenTips: Set<NightFlockOrientationTip> = []
    ) {
        self.schemaVersion = max(schemaVersion, Self.currentSchemaVersion)
        self.hasSeenIntro = hasSeenIntro
        self.isDismissed = isDismissed
        self.seenTips = seenTips
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0,
            hasSeenIntro: try container.decodeIfPresent(Bool.self, forKey: .hasSeenIntro) ?? false,
            isDismissed: try container.decodeIfPresent(Bool.self, forKey: .isDismissed) ?? false,
            seenTips: try container.decodeIfPresent(Set<NightFlockOrientationTip>.self, forKey: .seenTips) ?? []
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(hasSeenIntro, forKey: .hasSeenIntro)
        try container.encode(isDismissed, forKey: .isDismissed)
        try container.encode(seenTips, forKey: .seenTips)
    }
}

final class NightFlockOrientationStore: @unchecked Sendable {
    static let key = "ollie.nightFlock.orientation"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> NightFlockOrientationState {
        guard let data = defaults.data(forKey: Self.key),
              let value = try? decoder.decode(NightFlockOrientationState.self, from: data) else {
            return .fresh
        }
        return value
    }

    func save(_ value: NightFlockOrientationState) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
