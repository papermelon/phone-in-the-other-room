import Foundation

struct SleepSummary: Equatable {
    var durationSeconds: TimeInterval
    var startDate: Date?
    var endDate: Date?
    var nightEndingDate: Date? = nil

    var durationLabel: String {
        let minutes = Int(durationSeconds / 60)
        guard minutes > 0 else { return "No sleep data" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

struct WakeTimeRange: Equatable {
    var sampleCount: Int
    var minutes: Int
}

enum SleepIntervalMath {
    static func summary(
        for intervals: [DateInterval],
        nightEndingDate: Date? = nil
    ) -> SleepSummary? {
        let merged = merge(intervals)
        guard !merged.isEmpty else { return nil }
        let duration = merged.reduce(0) { $0 + $1.duration }
        return SleepSummary(
            durationSeconds: duration,
            startDate: merged.first?.start,
            endDate: merged.last?.end,
            nightEndingDate: nightEndingDate
        )
    }

    static func merge(_ intervals: [DateInterval]) -> [DateInterval] {
        let sorted = intervals
            .filter { $0.duration > 0 }
            .sorted { $0.start < $1.start }
        guard var current = sorted.first else { return [] }

        var merged: [DateInterval] = []
        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                merged.append(current)
                current = interval
            }
        }
        merged.append(current)
        return merged
    }

    static func wakeTimeRange(
        for summaries: [SleepSummary],
        calendar: Calendar = .current
    ) -> WakeTimeRange? {
        let minutes = summaries.compactMap(\.endDate).map {
            calendar.component(.hour, from: $0) * 60 + calendar.component(.minute, from: $0)
        }
        guard minutes.count >= 2 else { return nil }

        let sorted = minutes.sorted()
        let internalGaps = zip(sorted, sorted.dropFirst()).map { $1 - $0 }
        let midnightGap = (sorted.first ?? 0) + 24 * 60 - (sorted.last ?? 0)
        let largestGap = max(internalGaps.max() ?? 0, midnightGap)
        return WakeTimeRange(
            sampleCount: minutes.count,
            minutes: max(0, 24 * 60 - largestGap)
        )
    }
}
