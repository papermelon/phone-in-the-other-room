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

    struct SleepQueryResult: Equatable {
        var summaries: [SleepSummary]
        /// A query error is deliberately separate from an empty result: HealthKit
        /// cannot expose read authorization, and no matching samples are valid.
        var errorDescription: String?
    }

#if canImport(HealthKit)
    private let healthStore = HKHealthStore()
#endif
    private var localStateGeneration: UInt = 0

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
        localStateGeneration &+= 1
        UserDefaults.standard.removeObject(forKey: requestedAccessKey)
    }

    func requestSleepAccess() async -> AuthorizationState {
#if canImport(HealthKit)
        guard isAvailable, let sleepType else { return .unavailable }
        let generation = localStateGeneration
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
            guard generation == localStateGeneration else { return .notRequested }
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
        let result = await recentNightSleepQuery(days: 1)
        return result.summaries.first
    }

    func recentNightSleeps(days: Int = 7) async -> [SleepSummary] {
        await recentNightSleepQuery(days: days).summaries
    }

    func recentNightSleepQuery(days: Int = 7) async -> SleepQueryResult {
#if canImport(HealthKit)
        guard isAvailable, let sleepType else {
            return SleepQueryResult(summaries: [], errorDescription: nil)
        }
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
            return SleepQueryResult(summaries: [], errorDescription: nil)
        }
        let interval = DateInterval(start: earliestStart, end: latestEnd)
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        let descriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [descriptor]) { _, samples, error in
                if let error {
                    continuation.resume(
                        returning: SleepQueryResult(
                            summaries: [],
                            errorDescription: error.localizedDescription
                        )
                    )
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
                continuation.resume(
                    returning: SleepQueryResult(
                        summaries: summaries,
                        errorDescription: nil
                    )
                )
            }
            healthStore.execute(query)
        }
#else
        return SleepQueryResult(summaries: [], errorDescription: nil)
#endif
    }

    /// This is deliberately separate from Nights. A shared-habit read uses a
    /// completed, fixed-zone noon-to-noon window and returns only a derived
    /// duration plus private cutoff metadata, never stages or source identity.
    /// Reads one bounded range for a contributor’s fixed-zone completed
    /// windows. It excludes pre-agreement windows before constructing the
    /// HealthKit predicate, so old samples are never fetched for social use.
    func sharedHabitSleepQueries(
        in windows: [NightFlockSharedSleepWindow],
        acceptedAt: Date,
        now: Date = Date()
    ) async -> [NightFlockSharedSleepQueryResult] {
        let eligible = NightFlockSharedSleepWindowRules.eligibleBatchWindows(
            windows,
            acceptedAt: acceptedAt,
            now: now
        )
        guard !eligible.isEmpty else { return [] }
#if canImport(HealthKit)
        guard isAvailable, let sleepType else {
            return eligible.map {
                NightFlockSharedSleepQueryResult(
                    window: $0,
                    state: .failed(message: "Apple Health sleep data is unavailable.")
                )
            }
        }
        guard let start = eligible.map(\.interval.start).min(),
              let end = eligible.map(\.interval.end).max()
        else { return [] }
        // Omitting strict-start includes intervals crossing each completed
        // window’s boundary. Each result is clipped locally before minutes are
        // derived, and the enclosing predicate is already post-agreement.
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let descriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [descriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(returning: eligible.map {
                        NightFlockSharedSleepQueryResult(
                            window: $0,
                            state: .failed(message: error.localizedDescription)
                        )
                    })
                    return
                }
                let sleepSamples = (samples as? [HKCategorySample]) ?? []
                let results = eligible.map { window -> NightFlockSharedSleepQueryResult in
                    guard let summary = self.sharedHabitSummary(
                        from: sleepSamples,
                        in: window.interval
                    ) else {
                        return NightFlockSharedSleepQueryResult(window: window, state: .noData)
                    }
                    return NightFlockSharedSleepQueryResult(
                        window: window,
                        state: .data(minutes: max(0, Int(summary.duration / 60))),
                        earliestContributingIntervalStart: summary.earliestContributingIntervalStart
                    )
                }
                continuation.resume(returning: results)
            }
            healthStore.execute(query)
        }
#else
        return eligible.map {
            NightFlockSharedSleepQueryResult(
                window: $0,
                state: .failed(message: "Apple Health sleep data is unavailable.")
            )
        }
#endif
    }

    func sharedHabitSleepQuery(
        in window: NightFlockSharedSleepWindow,
        now: Date = Date()
    ) async -> NightFlockSharedSleepQueryResult {
        guard window.isComplete(at: now) else {
            return NightFlockSharedSleepQueryResult(
                window: window,
                state: .incompleteWindow
            )
        }
#if canImport(HealthKit)
        guard isAvailable, let sleepType else {
            return NightFlockSharedSleepQueryResult(
                window: window,
                state: .failed(message: "Apple Health sleep data is unavailable.")
            )
        }
        // Omitting strict-start includes samples crossing the window boundary;
        // `sharedHabitSummary` clips their duration before deriving minutes.
        let predicate = HKQuery.predicateForSamples(
            withStart: window.interval.start,
            end: window.interval.end,
            options: []
        )
        let descriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [descriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(returning: NightFlockSharedSleepQueryResult(
                        window: window,
                        state: .failed(message: error.localizedDescription)
                    ))
                    return
                }
                let sleepSamples = (samples as? [HKCategorySample]) ?? []
                guard let summary = self.sharedHabitSummary(
                    from: sleepSamples,
                    in: window.interval
                ) else {
                    continuation.resume(returning: NightFlockSharedSleepQueryResult(
                        window: window,
                        state: .noData
                    ))
                    return
                }
                continuation.resume(returning: NightFlockSharedSleepQueryResult(
                    window: window,
                    state: .data(minutes: max(0, Int(summary.duration / 60))),
                    earliestContributingIntervalStart: summary.earliestContributingIntervalStart
                ))
            }
            healthStore.execute(query)
        }
#else
        return NightFlockSharedSleepQueryResult(
            window: window,
            state: .failed(message: "Apple Health sleep data is unavailable.")
        )
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
        guard let chosen = chosenSourceSleepCandidate(from: samples, in: window) else {
            return nil
        }

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

    private nonisolated func sharedHabitSummary(
        from samples: [HKCategorySample],
        in window: DateInterval
    ) -> (duration: TimeInterval, earliestContributingIntervalStart: Date?)? {
        guard let chosen = chosenSourceSleepCandidate(from: samples, in: window) else {
            return nil
        }
        return (
            duration: chosen.asleepDuration,
            earliestContributingIntervalStart: chosen.earliestContributingIntervalStart
        )
    }

    private nonisolated func chosenSourceSleepCandidate(
        from samples: [HKCategorySample],
        in window: DateInterval
    ) -> SourceSleepCandidate? {
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
                    stage: stage,
                    originalStart: sample.startDate
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
                stageCoverage: stageCoverage,
                earliestContributingIntervalStart: clipped
                    .filter(\.stage.isAsleep)
                    .map(\.originalStart)
                    .min()
            )
        }
        return candidates.max(by: {
            if $0.asleepDuration == $1.asleepDuration {
                return $0.stageCoverage < $1.stageCoverage
            }
            return $0.asleepDuration < $1.asleepDuration
        })
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
        var originalStart: Date
    }

    private struct SourceSleepCandidate {
        var sourceName: String?
        var intervals: [StagedInterval]
        var asleepDuration: TimeInterval
        var stageCoverage: TimeInterval
        var earliestContributingIntervalStart: Date?
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
