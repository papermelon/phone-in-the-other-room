import Foundation

/// Stable, factual labels for shared-habit summaries. Values remain local or
/// server-derived; this type adds no score, rank, or adherence interpretation.
/// The party wire date is a persisted local date, so it is always interpreted
/// with a Gregorian calendar while the visible text follows the supplied locale.
enum NightFlockSharedHabitPresentation {
    static func durationText(_ minutes: Int) -> String {
        OllieFormat.duration(minutes: minutes)
    }

    static func meanDurationText(_ minutes: Double) -> String {
        OllieFormat.approximateDuration(minutes: minutes)
    }

    static func localDateText(_ date: NightFlockLocalDate, locale: Locale = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.timeZone = .gmt
        guard let value = calendar.date(from: DateComponents(
            timeZone: .gmt,
            year: date.year,
            month: date.month,
            day: date.day
        )) else {
            return "\(date.year)-\(date.month)-\(date.day)"
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = .gmt
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: value)
    }

    static func kindTitle(_ kind: NightFlockSharedHabitKind) -> String {
        switch kind {
        case .sleep: "Sleep duration"
        case .windDown: "Wind Down"
        case .phoneAway: "Phone Away"
        }
    }

    static func periodTitle(_ period: NightFlockSharedHabitPeriodSummary.Period) -> String {
        switch period {
        case .lastNight: "Last completed night"
        case .last7Nights: "Last 7 nights"
        case .last30Nights: "Last 30 nights"
        }
    }

    static func methodTitle(_ method: String) -> String {
        method == "eligibleMean" ? "Mean of eligible observed nights" : method
    }

}
