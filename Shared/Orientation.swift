import Foundation

enum CountingSheepOrientationStatus: String, Codable, Equatable {
    case notStarted
    case inProgress
    case dismissed
    case skipped
    case completed
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

/// The small, resumable orientation state is separate from the Wind Down state
/// machine. It records what the person has genuinely done in the app, not which
/// orientation control they happened to tap.
struct CountingSheepOrientationState: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var status: CountingSheepOrientationStatus
    var milestones: Set<CountingSheepOrientationMilestone>
    var practicePeriodID: UUID?
    var practiceRunID: UUID?

    static let fresh = Self(
        schemaVersion: currentSchemaVersion,
        status: .notStarted,
        milestones: [],
        practicePeriodID: nil,
        practiceRunID: nil
    )

    init(
        schemaVersion: Int = currentSchemaVersion,
        status: CountingSheepOrientationStatus = .notStarted,
        milestones: Set<CountingSheepOrientationMilestone> = [],
        practicePeriodID: UUID? = nil,
        practiceRunID: UUID? = nil
    ) {
        self.schemaVersion = max(schemaVersion, Self.currentSchemaVersion)
        self.status = status
        self.milestones = milestones
        self.practicePeriodID = practicePeriodID
        self.practiceRunID = practiceRunID
    }

    var isVisibleOnHome: Bool {
        status == .notStarted || status == .inProgress
    }

    var canResume: Bool { status == .dismissed }

    var requiredMilestones: Set<CountingSheepOrientationMilestone> {
        Set(CountingSheepOrientationMilestone.allCases)
    }

    var isComplete: Bool { status == .completed }

    mutating func mark(_ milestone: CountingSheepOrientationMilestone) {
        guard status != .skipped, status != .completed else { return }
        milestones.insert(milestone)

        if milestone == .practiceCompleted {
            milestones.insert(.practiceStarted)
        }
        if milestone == .practiceRecordViewed {
            milestones.insert(.practiceCompleted)
            milestones.insert(.practiceStarted)
        }
        if requiredMilestones.isSubset(of: milestones) {
            status = .completed
        } else if status == .notStarted {
            status = .inProgress
        }
    }

    mutating func recordPracticePeriod(_ periodID: UUID) {
        guard status != .skipped, status != .completed else { return }
        practicePeriodID = periodID
        if status == .notStarted || status == .dismissed { status = .inProgress }
    }

    mutating func recordPracticeRun(_ runID: UUID) {
        guard status != .skipped, status != .completed else { return }
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

    mutating func replay() {
        self = .fresh
        status = .inProgress
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case status
        case milestones
        case practicePeriodID
        case practiceRunID
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

        schemaVersion = max(storedVersion, Self.currentSchemaVersion)
        status = decodedStatus
        milestones = decodedMilestones
        practicePeriodID = try container.decodeIfPresent(UUID.self, forKey: .practicePeriodID)
        practiceRunID = try container.decodeIfPresent(UUID.self, forKey: .practiceRunID)
        if status == .notStarted && !milestones.isEmpty {
            status = .inProgress
        }
        if requiredMilestones.isSubset(of: milestones), status != .skipped {
            status = .completed
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(status, forKey: .status)
        try container.encode(milestones, forKey: .milestones)
        try container.encodeIfPresent(practicePeriodID, forKey: .practicePeriodID)
        try container.encodeIfPresent(practiceRunID, forKey: .practiceRunID)
    }
}
