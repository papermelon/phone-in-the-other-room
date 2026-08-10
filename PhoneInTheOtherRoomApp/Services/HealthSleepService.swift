import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

@MainActor
final class HealthSleepService {
    private let requestedAccessKey = "ollie.health.sleep.requested"
    enum AuthorizationState: Equatable {
        case unavailable
        case notRequested
        case requested
        case error(String)

        var label: String {
            switch self {
            case .unavailable: return "Unavailable"
            case .notRequested: return "Not connected"
            case .requested: return "Requested"
            case .error: return "Try again"
            }
        }
    }

#if canImport(HealthKit)
    private let healthStore = HKHealthStore()
#endif

    var isAvailable: Bool {
#if canImport(HealthKit)
        HKHealthStore.isHealthDataAvailable() && sleepType != nil
#else
        false
#endif
    }

    var hasRequestedAccess: Bool {
        UserDefaults.standard.bool(forKey: requestedAccessKey)
    }

    func resetLocalState() {
        UserDefaults.standard.removeObject(forKey: requestedAccessKey)
    }

    func requestSleepAccess() async -> AuthorizationState {
#if canImport(HealthKit)
        guard isAvailable, let sleepType else { return .unavailable }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
            UserDefaults.standard.set(true, forKey: requestedAccessKey)
            return .requested
        } catch {
            return .error(error.localizedDescription)
        }
#else
        return .unavailable
#endif
    }

    func lastNightSleep() async -> SleepSummary? {
        let summaries = await recentNightSleeps(days: 1)
        return summaries.first
    }

    func recentNightSleeps(days: Int = 7) async -> [SleepSummary] {
#if canImport(HealthKit)
        guard isAvailable, let sleepType else { return [] }
        let calendar = Calendar.current
        let windows = (0..<max(1, days)).compactMap { offset -> DatedSleepWindow? in
            guard let referenceDate = Calendar.current.date(
                byAdding: .day,
                value: -offset,
                to: Date()
            ) else { return nil }
            return DatedSleepWindow(
                nightEndingDate: calendar.startOfDay(for: referenceDate),
                interval: lastNightInterval(referenceDate: referenceDate, calendar: calendar)
            )
        }
        guard let earliestStart = windows.map(\.interval.start).min(),
              let latestEnd = windows.map(\.interval.end).max() else {
            return []
        }
        let interval = DateInterval(start: earliestStart, end: latestEnd)
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        let descriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [descriptor]) { _, samples, error in
                guard error == nil else {
                    continuation.resume(returning: [])
                    return
                }
                let sleepSamples = (samples as? [HKCategorySample]) ?? []
                let summaries = windows.compactMap { window -> SleepSummary? in
                    self.summary(
                        from: sleepSamples,
                        in: window.interval,
                        nightEndingDate: window.nightEndingDate
                    )
                }
                continuation.resume(returning: summaries)
            }
            healthStore.execute(query)
        }
#else
        return []
#endif
    }

#if canImport(HealthKit)
    private var sleepType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
    }

    private nonisolated func summary(
        from samples: [HKCategorySample],
        in window: DateInterval,
        nightEndingDate: Date
    ) -> SleepSummary? {
        let grouped = Dictionary(grouping: samples) {
            $0.sourceRevision.source.bundleIdentifier
        }
        let candidates = grouped.compactMap { _, sourceSamples -> SourceSleepCandidate? in
            let clipped = sourceSamples.compactMap { sample -> StagedInterval? in
                guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                      let stage = SleepStage(value: value) else { return nil }
                let start = max(sample.startDate, window.start)
                let end = min(sample.endDate, window.end)
                guard start < end else { return nil }
                return StagedInterval(
                    interval: DateInterval(start: start, end: end),
                    stage: stage
                )
            }
            let asleep = clipped.filter(\.stage.isAsleep).map(\.interval)
            let duration = SleepIntervalMath.duration(of: asleep)
            guard duration > 0 else { return nil }
            let stageCoverage = SleepIntervalMath.duration(
                of: clipped.filter(\.stage.isSpecificSleepStage).map(\.interval)
            )
            return SourceSleepCandidate(
                sourceName: sourceSamples.first?.sourceRevision.source.name,
                intervals: clipped,
                asleepDuration: duration,
                stageCoverage: stageCoverage
            )
        }
        guard let chosen = candidates.max(by: {
            if $0.asleepDuration == $1.asleepDuration {
                return $0.stageCoverage < $1.stageCoverage
            }
            return $0.asleepDuration < $1.asleepDuration
        }) else { return nil }

        return SleepIntervalMath.summary(
            for: chosen.intervals.filter(\.stage.isAsleep).map(\.interval),
            nightEndingDate: nightEndingDate,
            stages: SleepStageBreakdown(
                awakeSeconds: duration(for: .awake, in: chosen.intervals),
                coreSeconds: duration(for: .core, in: chosen.intervals),
                deepSeconds: duration(for: .deep, in: chosen.intervals),
                remSeconds: duration(for: .rem, in: chosen.intervals),
                unspecifiedSeconds: duration(for: .unspecified, in: chosen.intervals)
            ),
            sourceName: chosen.sourceName
        )
    }

    private nonisolated func duration(
        for stage: SleepStage,
        in intervals: [StagedInterval]
    ) -> TimeInterval {
        SleepIntervalMath.duration(
            of: intervals.filter { $0.stage == stage }.map(\.interval)
        )
    }

    private enum SleepStage: Equatable {
        case awake
        case core
        case deep
        case rem
        case unspecified

        init?(value: HKCategoryValueSleepAnalysis) {
            switch value {
            case .awake: self = .awake
            case .asleepCore: self = .core
            case .asleepDeep: self = .deep
            case .asleepREM: self = .rem
            case .asleepUnspecified: self = .unspecified
            default: return nil
            }
        }

        var isAsleep: Bool {
            self != .awake
        }

        var isSpecificSleepStage: Bool {
            self == .core || self == .deep || self == .rem
        }
    }

    private struct StagedInterval {
        var interval: DateInterval
        var stage: SleepStage
    }

    private struct SourceSleepCandidate {
        var sourceName: String?
        var intervals: [StagedInterval]
        var asleepDuration: TimeInterval
        var stageCoverage: TimeInterval
    }
#endif

    private func lastNightInterval(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> DateInterval {
        let todayStart = calendar.startOfDay(for: referenceDate)
        let start = calendar.date(byAdding: .hour, value: -12, to: todayStart) ?? todayStart.addingTimeInterval(-12 * 60 * 60)
        let end = calendar.date(byAdding: .hour, value: 12, to: todayStart) ?? todayStart.addingTimeInterval(12 * 60 * 60)
        return DateInterval(start: start, end: end)
    }

    private struct DatedSleepWindow {
        var nightEndingDate: Date
        var interval: DateInterval
    }
}
