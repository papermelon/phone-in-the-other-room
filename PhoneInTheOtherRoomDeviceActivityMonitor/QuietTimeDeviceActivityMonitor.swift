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
        if activity == .ollieBriefAccessRestore {
            reconcileBriefAccessRestore()
            return
        }
        if let usage = NightWatchUsageActivity(activityName: activity) {
            _ = usage
            return
        }
        guard QuietTimeShieldWindow(activityName: activity) != nil else { return }
        reconcileCurrentProtection(at: Date())
    }

    private func reconcileCurrentProtection(at date: Date) {
        guard let snapshot = loadSchedule() else {
            // A stale callback after the app cancelled a schedule must not leave
            // a ManagedSettings shield stranded on the device.
            store.clearAllSettings()
            archiveBriefAccessState()
            stopBriefAccessRestore()
            return
        }
        let activeWindow = QuietTimeShieldSchedulePolicy.activeWindow(in: snapshot, at: date)
        guard let selection = loadSelection(),
              !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
            store.clearAllSettings()
            if activeWindow == nil {
                writeStatus(.cleared, snapshot: snapshot, window: nil)
            } else {
                writeStatus(.failed, snapshot: snapshot, window: activeWindow, failureCode: "missingSelection")
                scheduleShieldingFailureNotification()
            }
            return
        }
        guard let activeWindow else {
            store.clearAllSettings()
            writeStatus(.cleared, snapshot: snapshot, window: nil)
            return
        }

        if let state = loadBriefAccessState(),
           let grant = state.activeGrant,
           grant.status == .scheduled,
           grant.runID == snapshot.runID,
           grant.scheduleRevision == snapshot.revision,
           date < grant.expiresAt {
            return
        }

        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        writeStatus(.applied, snapshot: snapshot, window: activeWindow)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        if activity == .ollieBriefAccessRestore {
            reconcileBriefAccessRestore()
            return
        }
        guard QuietTimeShieldWindow(activityName: activity) != nil else { return }
        reconcileCurrentProtection(at: Date())
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        guard activity == .ollieBriefAccessRestore else { return }
        reconcileBriefAccessRestore()
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

    private func reconcileBriefAccessRestore() {
        let now = Date()
        let state = loadBriefAccessState()
        let schedule = loadSchedule()
        let currentRunID = schedule?.runID ?? state?.runID ?? UUID()
        let currentRevision = schedule?.revision ?? state?.scheduleRevision ?? 1
        switch QuietTimeBriefAccessPolicy.reconciliation(
            state: state,
            schedule: schedule,
            currentRunID: currentRunID,
            currentRevision: currentRevision,
            at: now
        ) {
        case .noActiveGrant:
            stopBriefAccessRestore()
        case .keepShieldClear:
            // A start callback can arrive before the requested expiry. The shield
            // must remain clear only for the already scheduled grant, never longer.
            return
        case .rejectPendingGrant:
            guard var state, let grant = state.activeGrant else { return }
            state.rejectPendingGrant(nonce: grant.nonce, at: now)
            saveBriefAccessState(state)
            reapplyCurrentShieldIfEligible(at: now, schedule: schedule)
            stopBriefAccessRestore()
        case .discardStaleGrant:
            switch QuietTimeBriefAccessPolicy.staleGrantAction(
                schedule: schedule,
                at: now
            ) {
            case .reapplyCurrentShield:
                guard let schedule,
                      let selection = loadSelection(),
                      !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
                    store.clearAllSettings()
                    stopBriefAccessRestore()
                    archiveBriefAccessState()
                    return
                }
                store.shield.applications = selection.applicationTokens.isEmpty
                    ? nil
                    : selection.applicationTokens
                store.shield.applicationCategories = selection.categoryTokens.isEmpty
                    ? nil
                    : .specific(selection.categoryTokens)
                writeStatus(
                    .applied,
                    snapshot: schedule,
                    window: activeWindow(in: schedule, at: now)
                )
            case .clearProtection:
                store.clearAllSettings()
            }
            stopBriefAccessRestore()
            archiveBriefAccessState()
        case .restoreShield:
            guard let schedule, let selection = loadSelection(),
                  !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
                store.clearAllSettings()
                stopBriefAccessRestore()
                archiveBriefAccessState()
                return
            }
            store.shield.applications = selection.applicationTokens.isEmpty
                ? nil
                : selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty
                ? nil
                : .specific(selection.categoryTokens)
            stopBriefAccessRestore()
            archiveBriefAccessState()
            writeStatus(
                .applied,
                snapshot: schedule,
                window: activeWindow(in: schedule, at: now)
            )
        }
    }

    private func reapplyCurrentShieldIfEligible(
        at date: Date,
        schedule: QuietTimeShieldScheduleSnapshot?
    ) {
        guard let schedule,
              let window = QuietTimeShieldSchedulePolicy.activeWindow(in: schedule, at: date),
              let selection = loadSelection(),
              !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
            store.clearAllSettings()
            return
        }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        writeStatus(.applied, snapshot: schedule, window: window)
    }

    private func activeWindow(
        in snapshot: QuietTimeShieldScheduleSnapshot,
        at date: Date
    ) -> QuietTimeShieldWindow? {
        QuietTimeShieldWindow.allCases.first { snapshot.contains(date, in: $0) }
    }

    private func loadBriefAccessState() -> QuietTimeBriefAccessState? {
        guard let data = sharedDefaults?.data(
            forKey: QuietTimeShieldSharedStorage.briefAccessStateKey
        ) else { return nil }
        return try? JSONDecoder().decode(QuietTimeBriefAccessState.self, from: data)
    }

    private func saveBriefAccessState(_ state: QuietTimeBriefAccessState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        sharedDefaults?.set(data, forKey: QuietTimeShieldSharedStorage.briefAccessStateKey)
    }

    private func archiveBriefAccessState() {
        guard var state = loadBriefAccessState() else { return }
        state.archiveCurrentRun(at: Date())
        guard let data = try? JSONEncoder().encode(state) else { return }
        sharedDefaults?.set(data, forKey: QuietTimeShieldSharedStorage.briefAccessStateKey)
    }

    private func stopBriefAccessRestore() {
        DeviceActivityCenter().stopMonitoring([.ollieBriefAccessRestore])
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
