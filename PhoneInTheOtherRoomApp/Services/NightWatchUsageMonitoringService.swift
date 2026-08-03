import Foundation

#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
import DeviceActivity
import FamilyControls
#endif

@MainActor
final class NightWatchUsageMonitoringService {
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
    private let activityCenter = DeviceActivityCenter()
    private let selections = ScreenTimeSelectionService.shared
#endif

    func schedule(
        for plan: NightWatchPlan,
        startedAt: Date,
        repeatsDaily: Bool = false,
        now: Date = Date()
    ) {
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
        guard #available(iOS 17.4, *) else { return }
        guard PhoneNotificationService.shared.preferences.remindersEnabled,
              PhoneNotificationService.shared.preferences.usageAwareRemindersEnabled else {
            cancel()
            return
        }
        let selection = selections.load(.bedtime)
        guard !selection.phoneOtherIsEmpty else {
            cancel()
            return
        }

        cancel()
        for activity in NightWatchUsageActivity.allCases {
            guard let interval = interval(for: activity.phase, plan: plan, startedAt: startedAt),
                  interval.end > now else { continue }
            let effectiveStart = max(interval.start, now.addingTimeInterval(1))
            guard effectiveStart < interval.end else { continue }
            let schedule = DeviceActivitySchedule(
                intervalStart: repeatsDaily
                    ? dailyComponents(for: effectiveStart)
                    : dateComponents(for: effectiveStart),
                intervalEnd: repeatsDaily
                    ? dailyComponents(for: interval.end)
                    : dateComponents(for: interval.end),
                repeats: repeatsDaily
            )
            let event = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: [],
                threshold: DateComponents(minute: 3),
                includesPastActivity: false
            )
            do {
                try activityCenter.startMonitoring(
                    activity.activityName,
                    during: schedule,
                    events: [activity.eventName: event]
                )
            } catch {
                // A later reconciliation can retry without affecting scheduled local cues.
            }
        }
#endif
    }

    func cancel() {
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity)
        DeviceActivityCenter().stopMonitoring(
            NightWatchUsageActivity.allCases.map(\.activityName)
        )
#endif
    }

#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls)
    private func interval(
        for phase: NightWatchPhase,
        plan: NightWatchPlan,
        startedAt: Date
    ) -> DateInterval? {
        switch phase {
        case .windDown:
            return DateInterval(
                start: max(
                    startedAt,
                    plan.intendedBedtime.addingTimeInterval(TimeInterval(-plan.windDownMinutes * 60))
                ),
                end: plan.intendedBedtime
            )
        case .overnight:
            return DateInterval(start: plan.intendedBedtime, end: plan.wakeTime)
        case .morningQuiet:
            return DateInterval(start: plan.wakeTime, end: plan.protectedUntil)
        case .complete:
            return nil
        }
    }

    private func dateComponents(for date: Date) -> DateComponents {
        Calendar.current.dateComponents(
            [.era, .year, .month, .day, .hour, .minute, .second],
            from: date
        )
    }

    private func dailyComponents(for date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute, .second], from: date)
    }
#endif
}
