import Foundation

enum QuietPeriodPreset: Equatable {
    case general
    case startNowPractice

    var duration: TimeInterval {
        switch self {
        case .general: return 30 * 60
        case .startNowPractice: return 5 * 60
        }
    }
}

enum QuietPeriodSchedulingError: Error, Equatable {
    case invalidInterval
    case expired
    case insufficientRemainingDuration
}

/// Calendar-only rules for finite one-time quiet periods. The caller supplies
/// the clock and calendar so editing, start confirmation, and tests use the
/// same wall-clock decisions.
enum QuietPeriodScheduling {
    static let quarterHourMinutes = 15
    static let meaningfulMinimumRemainingDuration: TimeInterval = 60

    static func nextLocalQuarterHour(
        after date: Date,
        calendar: Calendar = .current
    ) -> Date {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = components.minute ?? 0
        let flooredMinute = minute - (minute % quarterHourMinutes)
        let boundary = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: components.year,
            month: components.month,
            day: components.day,
            hour: components.hour,
            minute: flooredMinute,
            second: 0
        )) ?? date

        guard date > boundary else { return boundary }
        return calendar.date(byAdding: .minute, value: quarterHourMinutes, to: boundary)
            ?? boundary.addingTimeInterval(TimeInterval(quarterHourMinutes * 60))
    }

    static func defaultWindow(
        now: Date = Date(),
        calendar: Calendar = .current,
        preset: QuietPeriodPreset = .general
    ) -> DateInterval {
        let start = preset == .startNowPractice
            ? now
            : nextLocalQuarterHour(after: now, calendar: calendar)
        let end = calendar.date(byAdding: .second, value: Int(preset.duration), to: start)
            ?? start.addingTimeInterval(preset.duration)
        return DateInterval(start: start, end: end)
    }

    static func normalizedInterval(
        requestedStart: Date,
        end: Date,
        now: Date,
        minimumRemainingDuration: TimeInterval = meaningfulMinimumRemainingDuration
    ) throws -> DateInterval {
        guard end > requestedStart else { throw QuietPeriodSchedulingError.invalidInterval }
        guard end > now else { throw QuietPeriodSchedulingError.expired }

        let effectiveStart = max(requestedStart, now)
        guard end.timeIntervalSince(effectiveStart) >= minimumRemainingDuration else {
            throw QuietPeriodSchedulingError.insufficientRemainingDuration
        }
        return DateInterval(start: effectiveStart, end: end)
    }

    static func validateNoOverlap(
        _ candidate: DateInterval,
        with intervals: [DateInterval]
    ) throws {
        guard candidate.end > candidate.start else {
            throw QuietPeriodSchedulingError.invalidInterval
        }
        guard !intervals.contains(where: {
            candidate.start < $0.end && $0.start < candidate.end
        }) else {
            throw QuietPeriodSchedulingError.invalidInterval
        }
    }
}
