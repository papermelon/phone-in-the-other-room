import Foundation

/// A completed, contributor-local noon-to-noon window. It carries only the
/// stable attribution needed for a derived sleep duration; it has no schedule.
struct NightFlockSharedSleepWindow: Equatable, Sendable {
    let nightEndingDate: NightFlockLocalDate
    let timeZoneIdentifier: String
    let interval: DateInterval

    init?(
        nightEndingDate: NightFlockLocalDate,
        timeZoneIdentifier: String
    ) {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let midnight = nightEndingDate.date(in: timeZoneIdentifier, calendar: calendar),
              let end = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: midnight),
              let precedingDay = calendar.date(byAdding: .day, value: -1, to: midnight),
              let start = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: precedingDay)
        else { return nil }
        self.nightEndingDate = nightEndingDate
        self.timeZoneIdentifier = timeZoneIdentifier
        self.interval = DateInterval(start: start, end: end)
    }

    func isComplete(at date: Date) -> Bool {
        date >= interval.end
    }

}

/// Pure admission for a range Health read. Windows that began before the
/// agreement are excluded before HealthKit is queried, not merely withheld at
/// publication time.
enum NightFlockSharedSleepWindowRules {
    static func eligibleBatchWindows(
        _ windows: [NightFlockSharedSleepWindow],
        acceptedAt: Date,
        now: Date,
        limit: Int = 30
    ) -> [NightFlockSharedSleepWindow] {
        let unique = Dictionary(grouping: windows, by: { window in
            "\(window.nightEndingDate.year)-\(window.nightEndingDate.month)-\(window.nightEndingDate.day):\(window.timeZoneIdentifier)"
        })
        return unique.values.compactMap(\.first)
            .filter { $0.interval.start >= acceptedAt && $0.isComplete(at: now) }
            .sorted { $0.interval.end > $1.interval.end }
            .prefix(max(0, limit))
            .map { $0 }
    }
}

enum NightFlockSharedSleepQueryState: Equatable, Sendable {
    case incompleteWindow
    case noData
    case data(minutes: Int)
    case failed(message: String)
}

/// `earliestContributingIntervalStart` is private publisher metadata. It is
/// never included in the social record, but blocks a first-night upload when
/// an otherwise clipped Health interval began before agreement acceptance.
struct NightFlockSharedSleepQueryResult: Equatable, Sendable {
    let window: NightFlockSharedSleepWindow
    let state: NightFlockSharedSleepQueryState
    let earliestContributingIntervalStart: Date?

    init(
        window: NightFlockSharedSleepWindow,
        state: NightFlockSharedSleepQueryState,
        earliestContributingIntervalStart: Date? = nil
    ) {
        self.window = window
        self.state = state
        self.earliestContributingIntervalStart = earliestContributingIntervalStart
    }

    func isEligibleForFirstPublication(acceptedAt: Date) -> Bool {
        guard case .data = state,
              window.interval.start >= acceptedAt,
              let earliestContributingIntervalStart
        else { return false }
        return earliestContributingIntervalStart >= acceptedAt
    }
}

enum NightFlockSharedSleepAttribution {
    static func matchingAnchor(
        for window: NightFlockSharedSleepWindow,
        in anchors: [NightWatchLocalDateAnchor]
    ) -> NightWatchLocalDateAnchor? {
        anchors.first {
            $0.nightEndingDate == window.nightEndingDate
                && $0.timeZoneIdentifier == window.timeZoneIdentifier
        }
    }
}
