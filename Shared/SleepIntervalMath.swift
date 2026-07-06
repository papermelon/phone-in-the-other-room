import Foundation

struct SleepSummary: Equatable {
    var durationSeconds: TimeInterval
    var startDate: Date?
    var endDate: Date?

    var durationLabel: String {
        let minutes = Int(durationSeconds / 60)
        guard minutes > 0 else { return "No sleep data" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

enum SleepIntervalMath {
    static func summary(for intervals: [DateInterval]) -> SleepSummary? {
        let merged = merge(intervals)
        guard !merged.isEmpty else { return nil }
        let duration = merged.reduce(0) { $0 + $1.duration }
        return SleepSummary(
            durationSeconds: duration,
            startDate: merged.first?.start,
            endDate: merged.last?.end
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
}
