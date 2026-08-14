import Foundation

enum WindDownStartKind: String, Codable, Equatable {
    case primary
    case practice
    case oneTimeQuiet
    case repeatingQuiet
}

/// Stable identity for the exact quiet period a start action will claim.
/// Views use this instead of inferring intent from the saved nightly plan.
struct WindDownStartContext: Equatable {
    let sourceID: UUID?
    let kind: WindDownStartKind
    let title: String
    let interval: DateInterval

    var durationMinutes: Int {
        max(1, Int((interval.duration / 60).rounded()))
    }

    var isAdditionalQuiet: Bool { kind != .primary }
    var isPractice: Bool { kind == .practice }

    static func isPracticeOccurrence(
        sourceID: UUID?,
        practicePeriodID: UUID?
    ) -> Bool {
        guard let sourceID, let practicePeriodID else { return false }
        return sourceID == practicePeriodID
    }

    init(
        period: WindDownSchedulePeriod,
        practicePeriodID: UUID?
    ) {
        sourceID = period.sourceID
        title = period.title
        interval = period.occurrence.interval
        if period.occurrence.role == .primarySleepBookend {
            kind = .primary
        } else if period.sourceID == practicePeriodID {
            kind = .practice
        } else {
            kind = period.recurring ? .repeatingQuiet : .oneTimeQuiet
        }
    }

    init(
        sourceID: UUID? = nil,
        kind: WindDownStartKind,
        title: String,
        interval: DateInterval
    ) {
        self.sourceID = sourceID
        self.kind = kind
        self.title = title
        self.interval = interval
    }
}
