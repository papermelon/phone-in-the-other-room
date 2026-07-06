import Foundation

#if canImport(HealthKit)
import HealthKit
#endif

@MainActor
final class HealthSleepService {
    enum AuthorizationState: Equatable {
        case unavailable
        case notRequested
        case authorized
        case denied(String)

        var label: String {
            switch self {
            case .unavailable: return "Unavailable"
            case .notRequested: return "Not connected"
            case .authorized: return "Connected"
            case .denied: return "Needs permission"
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

    func requestSleepAccess() async -> AuthorizationState {
#if canImport(HealthKit)
        guard isAvailable, let sleepType else { return .unavailable }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
            return .authorized
        } catch {
            return .denied(error.localizedDescription)
        }
#else
        return .unavailable
#endif
    }

    func lastNightSleep() async -> SleepSummary? {
#if canImport(HealthKit)
        guard isAvailable, let sleepType else { return nil }
        let interval = lastNightInterval()
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        let descriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [descriptor]) { _, samples, error in
                guard error == nil else {
                    continuation.resume(returning: nil)
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
                continuation.resume(returning: SleepIntervalMath.summary(for: asleepIntervals))
            }
            healthStore.execute(query)
        }
#else
        return nil
#endif
    }

#if canImport(HealthKit)
    private var sleepType: HKCategoryType? {
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
    }
#endif

    private func lastNightInterval(calendar: Calendar = .current) -> DateInterval {
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .hour, value: -12, to: todayStart) ?? todayStart.addingTimeInterval(-12 * 60 * 60)
        let end = calendar.date(byAdding: .hour, value: 12, to: todayStart) ?? todayStart.addingTimeInterval(12 * 60 * 60)
        return DateInterval(start: start, end: end)
    }
}
