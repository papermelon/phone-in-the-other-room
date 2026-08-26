import Foundation

struct ScreenTimeActivityBucket: Identifiable, Equatable {
    var startDate: Date
    var endDate: Date
    var selectedAppDuration: TimeInterval

    var id: String {
        "\(startDate.timeIntervalSinceReferenceDate)-\(endDate.timeIntervalSinceReferenceDate)"
    }

    var intervalDuration: TimeInterval {
        max(0, endDate.timeIntervalSince(startDate))
    }

    var fillFraction: Double {
        guard intervalDuration > 0 else { return 0 }
        return min(1, max(0, selectedAppDuration / intervalDuration))
    }
}

enum ScreenTimeReportMath {
    static func aggregate(
        _ samples: [ScreenTimeActivityBucket]
    ) -> [ScreenTimeActivityBucket] {
        struct BucketKey: Hashable {
            var startDate: Date
            var endDate: Date
        }

        var durations: [BucketKey: TimeInterval] = [:]
        for sample in samples where sample.endDate > sample.startDate {
            let key = BucketKey(startDate: sample.startDate, endDate: sample.endDate)
            durations[key, default: 0] += max(0, sample.selectedAppDuration)
        }

        return durations.map { key, duration in
            ScreenTimeActivityBucket(
                startDate: key.startDate,
                endDate: key.endDate,
                selectedAppDuration: duration
            )
        }
        .sorted { $0.startDate < $1.startDate }
    }

    static func selectedAppPercentage(
        for buckets: [ScreenTimeActivityBucket]
    ) -> Int {
        let windowDuration = buckets.reduce(0) { $0 + $1.intervalDuration }
        let selectedDuration = buckets.reduce(0) { $0 + $1.selectedAppDuration }
        return selectedAppPercentage(
            selectedDuration: selectedDuration,
            windowDuration: windowDuration
        )
    }

    static func selectedAppPercentage(
        selectedDuration: TimeInterval,
        windowDuration: TimeInterval
    ) -> Int {
        guard windowDuration > 0 else { return 0 }
        return Int((min(1, selectedDuration / windowDuration) * 100).rounded())
    }

    static func hourlyBuckets(
        in interval: DateInterval,
        from samples: [ScreenTimeActivityBucket],
        calendar: Calendar = .current
    ) -> [ScreenTimeActivityBucket] {
        guard interval.duration > 0 else { return [] }
        var buckets: [ScreenTimeActivityBucket] = []
        var bucketStart = interval.start

        while bucketStart < interval.end, buckets.count < 48 {
            let nextHour = calendar.date(
                byAdding: .hour,
                value: 1,
                to: bucketStart
            ) ?? bucketStart.addingTimeInterval(60 * 60)
            let bucketEnd = min(nextHour, interval.end)
            let selectedDuration = samples.reduce(0) { total, sample in
                let overlapStart = max(bucketStart, sample.startDate)
                let overlapEnd = min(bucketEnd, sample.endDate)
                guard overlapStart < overlapEnd, sample.intervalDuration > 0 else {
                    return total
                }
                let overlapShare = overlapEnd.timeIntervalSince(overlapStart)
                    / sample.intervalDuration
                return total + sample.selectedAppDuration * overlapShare
            }
            buckets.append(
                ScreenTimeActivityBucket(
                    startDate: bucketStart,
                    endDate: bucketEnd,
                    selectedAppDuration: selectedDuration
                )
            )
            bucketStart = bucketEnd
        }

        return buckets
    }

    static func peakBucket(
        in buckets: [ScreenTimeActivityBucket]
    ) -> ScreenTimeActivityBucket? {
        buckets
            .filter { $0.selectedAppDuration > 0 }
            .max { $0.selectedAppDuration < $1.selectedAppDuration }
    }
}
