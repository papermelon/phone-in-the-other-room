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
                let asleepIntervals = sleepSamples.compactMap { sample -> DateInterval? in
                    guard let value = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return nil }
                    guard value == .asleepUnspecified || value == .asleepCore || value == .asleepDeep || value == .asleepREM else {
                        return nil
                    }
                    return DateInterval(start: sample.startDate, end: sample.endDate)
                }
                let summaries = windows.compactMap { window -> SleepSummary? in
                    let clipped = asleepIntervals.compactMap { interval -> DateInterval? in
                        let start = max(interval.start, window.interval.start)
                        let end = min(interval.end, window.interval.end)
                        return start < end ? DateInterval(start: start, end: end) : nil
                    }
                    return SleepIntervalMath.summary(
                        for: clipped,
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
