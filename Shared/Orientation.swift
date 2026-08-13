import Foundation

enum CountingSheepOrientationStatus: String, Codable, Equatable {
    case notStarted
    case inProgress
    case dismissed
    case skipped
    case completed
}

enum CountingSheepOrientationStep: String, Codable, Equatable {
    case home
    case start
    case navigation

    var number: Int {
        switch self {
        case .home: return 1
        case .start: return 2
        case .navigation: return 3
        }
    }

    static let count = 3
}

enum CountingSheepContextualTip: String, Codable, CaseIterable, Hashable, Identifiable {
    case nights
    case farm
    case settings
    case phoneBreak
    case trailNote
    case barnCapacity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nights: return "Your nights, kept together"
        case .farm: return "Ollie’s trails lead here"
        case .settings: return "Your plan lives here"
        case .phoneBreak: return "A break outside bedtime"
        case .trailNote: return "A clue leaves a trail"
        case .barnCapacity: return "The discovery stays safe"
        }
    }

    var message: String {
        switch self {
        case .nights:
            return "Wind Down is your nightly ritual.\nPhone Away stays here as a smaller, separate record."
        case .farm:
            return "Wind Down moves Ollie’s main trail.\nPhone Away minutes wait as extra search progress."
        case .settings:
            return "Change Wind Down, connections, and guidance here.\nYou can replay this guide whenever you like."
        case .phoneBreak:
            return "Start one now or save one for later.\nEvery \(PhoneAwaySearchMeter.maximumMinutes) completed minutes can open a bonus search after three Wind Downs."
        case .trailNote:
            return "A homecoming means Ollie found a sheep.\nA clue means he has more trail to follow."
        case .barnCapacity:
            return "If The Barn is full, make room or open a new pasture.\nThe discovery stays in the Search Journal."
        }
    }
}

enum CountingSheepOrientationMilestone: String, Codable, CaseIterable, Hashable {
    case homeExplained
    case nightsExplored
    case farmExplored
    case settingsExplored
    case windDownSaved
    case practiceStarted
    case practiceCompleted
    case practiceRecordViewed
}

/// The small, resumable app tour is separate from the Wind Down state machine.
/// Legacy milestones remain decodable because practice records and development
/// installs may still refer to them, but they no longer gate finishing the tour.
struct CountingSheepOrientationState: Codable, Equatable {
    static let currentSchemaVersion = 4

    var schemaVersion: Int
    var status: CountingSheepOrientationStatus
    var currentStep: CountingSheepOrientationStep
    var milestones: Set<CountingSheepOrientationMilestone>
    var practicePeriodID: UUID?
    var practiceRunID: UUID?
    var seenContextualTips: Set<CountingSheepContextualTip>
    var contextualTipsDisabled: Bool

    static let fresh = Self(
        schemaVersion: currentSchemaVersion,
        status: .notStarted,
        currentStep: .home,
        milestones: [],
        practicePeriodID: nil,
        practiceRunID: nil,
        seenContextualTips: [],
        contextualTipsDisabled: false
    )

    init(
        schemaVersion: Int = currentSchemaVersion,
        status: CountingSheepOrientationStatus = .notStarted,
        currentStep: CountingSheepOrientationStep = .home,
        milestones: Set<CountingSheepOrientationMilestone> = [],
        practicePeriodID: UUID? = nil,
        practiceRunID: UUID? = nil,
        seenContextualTips: Set<CountingSheepContextualTip> = [],
        contextualTipsDisabled: Bool = false
    ) {
        self.schemaVersion = max(schemaVersion, Self.currentSchemaVersion)
        self.status = status
        self.currentStep = currentStep
        self.milestones = milestones
        self.practicePeriodID = practicePeriodID
        self.practiceRunID = practiceRunID
        self.seenContextualTips = seenContextualTips
        self.contextualTipsDisabled = contextualTipsDisabled
    }

    var isVisibleOnHome: Bool {
        status == .notStarted || status == .inProgress
    }

    var canResume: Bool { status == .dismissed }

    var isComplete: Bool { status == .completed }

    mutating func mark(_ milestone: CountingSheepOrientationMilestone) {
        guard status != .skipped else { return }
        milestones.insert(milestone)

        if milestone == .practiceCompleted {
            milestones.insert(.practiceStarted)
        }
        if milestone == .practiceRecordViewed {
            milestones.insert(.practiceCompleted)
            milestones.insert(.practiceStarted)
        }
    }

    mutating func advanceTour() {
        guard isVisibleOnHome else { return }
        switch currentStep {
        case .home:
            currentStep = .start
            status = .inProgress
        case .start:
            currentStep = .navigation
            status = .inProgress
        case .navigation:
            completeTour()
        }
    }

    mutating func moveBack() {
        guard isVisibleOnHome else { return }
        switch currentStep {
        case .home:
            return
        case .start:
            currentStep = .home
        case .navigation:
            currentStep = .start
        }
        status = .inProgress
    }

    mutating func completeTour() {
        guard status != .skipped else { return }
        status = .completed
    }

    mutating func recordPracticePeriod(_ periodID: UUID) {
        practicePeriodID = periodID
    }

    mutating func recordPracticeRun(_ runID: UUID) {
        practiceRunID = runID
        mark(.practiceStarted)
    }

    mutating func dismiss() {
        guard status != .skipped, status != .completed else { return }
        status = .dismissed
    }

    mutating func resume() {
        guard status == .dismissed else { return }
        status = .inProgress
    }

    mutating func skipPermanently() {
        guard status != .completed else { return }
        status = .skipped
    }

    var canShowContextualTips: Bool {
        status != .skipped && status != .dismissed && !contextualTipsDisabled
    }

    func nextContextualTip(from candidates: [CountingSheepContextualTip]) -> CountingSheepContextualTip? {
        guard canShowContextualTips else { return nil }
        return candidates.first { !seenContextualTips.contains($0) }
    }

    mutating func markContextualTipSeen(_ tip: CountingSheepContextualTip) {
        guard canShowContextualTips else { return }
        seenContextualTips.insert(tip)
        if tip == .barnCapacity {
            seenContextualTips.insert(.farm)
        }
    }

    mutating func disableContextualTips() {
        contextualTipsDisabled = true
    }

    mutating func replay() {
        self = .fresh
        status = .inProgress
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case status
        case currentStep
        case milestones
        case practicePeriodID
        case practiceRunID
        case seenContextualTips
        case contextualTipsDisabled
        // These fields make a partial pre-versioned state safe to migrate.
        case homeExplained
        case nightsExplored
        case farmExplored
        case settingsExplored
        case windDownSaved
        case practiceStarted
        case practiceCompleted
        case practiceRecordViewed
        case dismissed
        case skipped
        case completed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        var decodedStatus = try container.decodeIfPresent(
            CountingSheepOrientationStatus.self,
            forKey: .status
        ) ?? .notStarted

        // Older development snapshots used independent flags before the state
        // became versioned. Preserve those flags if one is encountered.
        if try container.decodeIfPresent(Bool.self, forKey: .skipped) == true {
            decodedStatus = .skipped
        } else if try container.decodeIfPresent(Bool.self, forKey: .completed) == true {
            decodedStatus = .completed
        } else if try container.decodeIfPresent(Bool.self, forKey: .dismissed) == true {
            decodedStatus = .dismissed
        }

        var decodedMilestones = try container.decodeIfPresent(
            Set<CountingSheepOrientationMilestone>.self,
            forKey: .milestones
        ) ?? []
        let legacyFlags: [(CodingKeys, CountingSheepOrientationMilestone)] = [
            (.homeExplained, .homeExplained),
            (.nightsExplored, .nightsExplored),
            (.farmExplored, .farmExplored),
            (.settingsExplored, .settingsExplored),
            (.windDownSaved, .windDownSaved),
            (.practiceStarted, .practiceStarted),
            (.practiceCompleted, .practiceCompleted),
            (.practiceRecordViewed, .practiceRecordViewed)
        ]
        for (key, milestone) in legacyFlags where try container.decodeIfPresent(Bool.self, forKey: key) == true {
            decodedMilestones.insert(milestone)
        }

        if decodedStatus == .notStarted, !decodedMilestones.isEmpty {
            decodedStatus = .inProgress
        }

        schemaVersion = max(storedVersion, Self.currentSchemaVersion)
        status = decodedStatus
        if storedVersion < 2 {
            currentStep = decodedMilestones.contains(.homeExplained) ? .navigation : .home
        } else {
            currentStep = try container.decodeIfPresent(
                CountingSheepOrientationStep.self,
                forKey: .currentStep
            ) ?? .home
        }
        milestones = decodedMilestones
        practicePeriodID = try container.decodeIfPresent(UUID.self, forKey: .practicePeriodID)
        practiceRunID = try container.decodeIfPresent(UUID.self, forKey: .practiceRunID)
        seenContextualTips = try container.decodeIfPresent(Set<CountingSheepContextualTip>.self, forKey: .seenContextualTips) ?? []
        contextualTipsDisabled = try container.decodeIfPresent(Bool.self, forKey: .contextualTipsDisabled) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(status, forKey: .status)
        try container.encode(currentStep, forKey: .currentStep)
        try container.encode(milestones, forKey: .milestones)
        try container.encodeIfPresent(practicePeriodID, forKey: .practicePeriodID)
        try container.encodeIfPresent(practiceRunID, forKey: .practiceRunID)
        try container.encode(seenContextualTips, forKey: .seenContextualTips)
        try container.encode(contextualTipsDisabled, forKey: .contextualTipsDisabled)
    }
}
