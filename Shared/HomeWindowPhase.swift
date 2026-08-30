import Foundation

/// The Home window reflects the iPhone's local clock only. It deliberately
/// makes no location, season, sunrise, or weather inference.
enum HomeWindowPhase: Equatable {
    case day
    case night

    static func phase(
        at date: Date,
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> HomeWindowPhase {
        var localCalendar = calendar
        localCalendar.timeZone = timeZone
        let components = localCalendar.dateComponents([.hour, .minute], from: date)
        let minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return (6 * 60..<(18 * 60)).contains(minuteOfDay) ? .day : .night
    }
}
