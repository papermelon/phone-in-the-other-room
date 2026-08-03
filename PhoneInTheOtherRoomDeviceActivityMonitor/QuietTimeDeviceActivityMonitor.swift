import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

final class QuietTimeDeviceActivityMonitor: DeviceActivityMonitor {
    private let store = ManagedSettingsStore(named: .init("ollie.quietTime"))
    private let sharedDefaults = UserDefaults(
        suiteName: ScreenTimeSharedStorage.appGroupIdentifier
    )

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        if let usage = NightWatchUsageActivity(activityName: activity) {
            _ = usage
            return
        }
        guard let window = QuietTimeShieldWindow(activityName: activity),
              let snapshot = loadSchedule() else { return }
        guard snapshot.contains(Date(), in: window),
              let selection = loadSelection(),
              !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
            store.clearAllSettings()
            writeStatus(
                .failed,
                snapshot: snapshot,
                window: window,
                failureCode: "missingSelectionOrWindow"
            )
            scheduleShieldingFailureNotification()
            return
        }

        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        writeStatus(.applied, snapshot: snapshot, window: window)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard let window = QuietTimeShieldWindow(activityName: activity) else { return }
        store.clearAllSettings()
        guard let snapshot = loadSchedule() else { return }
        writeStatus(
            .cleared,
            snapshot: snapshot,
            window: window
        )
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        guard let usage = NightWatchUsageActivity(activityName: activity),
              event == usage.eventName else { return }
        let copy = NightWatchGuidance.notificationCopy(for: .usageCue(usage.phase))
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.interruptionLevel = .active
        content.userInfo = ["destination": NotificationDestination.activeRun.rawValue]
        let request = UNNotificationRequest(
            identifier: "night-watch-usage-\(usage.rawValue)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleShieldingFailureNotification() {
        let copy = NightWatchGuidance.notificationCopy(for: .shieldingFailed)
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.interruptionLevel = .active
        content.userInfo = ["destination": NotificationDestination.activeRun.rawValue]
        let request = UNNotificationRequest(
            identifier: "night-watch-shielding-failed",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func loadSchedule() -> QuietTimeShieldScheduleSnapshot? {
        guard let data = sharedDefaults?.data(
            forKey: QuietTimeShieldSharedStorage.scheduleKey
        ) else { return nil }
        return try? JSONDecoder().decode(QuietTimeShieldScheduleSnapshot.self, from: data)
    }

    private func loadSelection() -> FamilyActivitySelection? {
        guard let data = sharedDefaults?.data(
            forKey: ScreenTimeSharedStorage.selectionKey(for: .bedtime)
        ) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    private func writeStatus(
        _ status: QuietTimeShieldStatus,
        snapshot: QuietTimeShieldScheduleSnapshot,
        window: QuietTimeShieldWindow?,
        failureCode: String? = nil
    ) {
        let value = QuietTimeShieldStatusSnapshot(
            runID: snapshot.runID,
            revision: snapshot.revision,
            status: status,
            window: window,
            observedAt: Date(),
            failureCode: failureCode
        )
        guard let data = try? JSONEncoder().encode(value) else { return }
        sharedDefaults?.set(data, forKey: QuietTimeShieldSharedStorage.statusKey)
        var history = loadStatusHistory()
        if history.last != value {
            history.append(value)
        }
        history = Array(history.suffix(40))
        guard let historyData = try? JSONEncoder().encode(history) else { return }
        sharedDefaults?.set(
            historyData,
            forKey: QuietTimeShieldSharedStorage.statusHistoryKey
        )
    }

    private func loadStatusHistory() -> [QuietTimeShieldStatusSnapshot] {
        guard let data = sharedDefaults?.data(
            forKey: QuietTimeShieldSharedStorage.statusHistoryKey
        ) else { return [] }
        return (try? JSONDecoder().decode(
            [QuietTimeShieldStatusSnapshot].self,
            from: data
        )) ?? []
    }
}
