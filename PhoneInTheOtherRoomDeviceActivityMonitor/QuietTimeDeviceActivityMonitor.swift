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
        guard QuietTimeShieldWindow(activityName: activity) != nil
                || QuietTimeShieldRegistryActivity(deviceActivityName: activity) != nil else { return }
        reconcileCurrentProtection(
            at: Date(),
            callback: QuietTimeShieldRegistryActivity(deviceActivityName: activity)
        )
    }

    private func reconcileCurrentProtection(
        at date: Date,
        callback: QuietTimeShieldRegistryActivity? = nil
    ) {
        let registry = QuietTimeShieldScheduleRegistryStorage.load(from: sharedDefaults ?? .standard)
        let activeRegistryEntries = registry.activeEntries(at: date)
        guard let snapshot = loadSchedule() else {
            // The registry is the desired-state authority. A cross-process
            // handoff may briefly replace the compatibility snapshot, but a
            // stale callback must never clear another active registry window.
            guard QuietTimeShieldRegistryPolicy.retainsActiveBarrier(
                registry: registry,
                snapshotOccurrenceID: nil,
                at: date
            ),
                  let selection = loadSelection(),
                  !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
                store.clearAllSettings()
                archiveBriefAccessState()
                stopBriefAccessRestore()
                return
            }
            store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty
                ? nil : .specific(selection.categoryTokens)
            return
        }
        if let callback {
            switch QuietTimeShieldRegistryPolicy.reconciliation(
                registry: registry,
                occurrenceID: callback.occurrenceID,
                revision: callback.revision,
                epoch: callback.epoch,
                at: date
            ) {
            case .ignoreStale:
                // A callback from an old DeviceActivity window must have no
                // effect on another currently desired shield.
                return
            case .apply, .clear:
                break
            }
        }
        let snapshotIsStale = registry.tombstones.contains(where: { $0.occurrenceID == snapshot.runID })
            || (registry.entries.isEmpty == false && registry.entry(for: snapshot.runID) == nil)
        if snapshotIsStale, QuietTimeShieldRegistryPolicy.retainsActiveBarrier(
            registry: registry,
            snapshotOccurrenceID: snapshot.runID,
            at: date
        ) {
            // The compatibility snapshot can be stale during a handoff or
            // terminal removal. Another registry entry is still authoritative
            // and active, so a callback must retain its barrier rather than
            // clearing ManagedSettings because the old snapshot was retired.
            guard let selection = loadSelection(),
                  !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
                store.clearAllSettings()
                archiveBriefAccessState()
                stopBriefAccessRestore()
                return
            }
            store.shield.applications = selection.applicationTokens.isEmpty
                ? nil
                : selection.applicationTokens
            store.shield.applicationCategories = selection.categoryTokens.isEmpty
                ? nil
                : .specific(selection.categoryTokens)
            return
        }
        if snapshotIsStale {
            // A callback for an ended/replaced occurrence must not clear or
            // apply a different desired window.
            store.clearAllSettings()
            archiveBriefAccessState()
            stopBriefAccessRestore()
            return
        }
        let activeWindow = QuietTimeShieldSchedulePolicy.activeWindow(in: snapshot, at: date)
        let hasActiveRegistryProtection = !activeRegistryEntries.isEmpty
        guard let selection = loadSelection(),
              !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
            store.clearAllSettings()
            if activeWindow == nil && !hasActiveRegistryProtection {
                writeStatus(.cleared, snapshot: snapshot, window: nil)
            } else {
                writeStatus(.failed, snapshot: snapshot, window: activeWindow, failureCode: "missingSelection")
                scheduleShieldingFailureNotification()
            }
            return
        }
        guard activeWindow != nil || hasActiveRegistryProtection else {
            store.clearAllSettings()
            writeStatus(.cleared, snapshot: snapshot, window: nil)
            return
        }

        let identity = briefAccessIdentity(for: snapshot, registry: registry)
        if let state = loadBriefAccessState(),
           let grant = state.activeGrant,
           grant.status == .scheduled,
           activeRegistryEntries.count <= 1,
           grantMatchesCurrentIdentity(grant, state: state, identity: identity),
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
        guard QuietTimeShieldWindow(activityName: activity) != nil
                || QuietTimeShieldRegistryActivity(deviceActivityName: activity) != nil else { return }
        reconcileCurrentProtection(
            at: Date(),
            callback: QuietTimeShieldRegistryActivity(deviceActivityName: activity)
        )
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
        let registry = QuietTimeShieldScheduleRegistryStorage.load(from: sharedDefaults ?? .standard)
        let identity = schedule.flatMap { briefAccessIdentity(for: $0, registry: registry) }
        let isLegacyRegistry = registry.entries.isEmpty && registry.tombstones.isEmpty
        let currentRunID = identity?.runID ?? (isLegacyRegistry ? state?.runID ?? UUID() : UUID())
        let currentRevision = identity?.revision ?? (isLegacyRegistry ? state?.scheduleRevision ?? 1 : 1)
        let currentOccurrenceID = identity?.occurrenceID ?? (isLegacyRegistry ? state?.occurrenceID : UUID())
        let currentEpoch = identity?.epoch ?? (isLegacyRegistry ? state?.scheduleEpoch ?? 1 : 1)
        switch QuietTimeBriefAccessPolicy.reconciliation(
            state: state,
            schedule: schedule,
            currentRunID: currentRunID,
            currentRevision: currentRevision,
            currentOccurrenceID: currentOccurrenceID,
            currentEpoch: currentEpoch,
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
                at: now,
                hasActiveRegistryProtection: !registry.activeEntries(at: now).isEmpty
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
              let selection = loadSelection(),
              !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
            store.clearAllSettings()
            return
        }
        let registry = QuietTimeShieldScheduleRegistryStorage.load(from: sharedDefaults ?? .standard)
        let hasActiveRegistryProtection = !registry.activeEntries(at: date).isEmpty
        guard let window = QuietTimeShieldSchedulePolicy.activeWindow(in: schedule, at: date)
                ?? (hasActiveRegistryProtection ? .protectedSession : nil) else {
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

    private func briefAccessIdentity(
        for snapshot: QuietTimeShieldScheduleSnapshot,
        registry: QuietTimeShieldScheduleRegistry
    ) -> QuietTimeBriefAccessScheduleIdentity? {
        guard !registry.entries.isEmpty || !registry.tombstones.isEmpty else {
            return QuietTimeBriefAccessScheduleIdentity(
                runID: snapshot.runID,
                revision: snapshot.revision
            )
        }
        guard let entry = registry.entry(for: snapshot.runID),
              registry.accepts(
                  occurrenceID: entry.occurrenceID,
                  revision: entry.revision,
                  epoch: entry.epoch
              ) else { return nil }
        return QuietTimeBriefAccessScheduleIdentity(
            runID: snapshot.runID,
            occurrenceID: entry.occurrenceID,
            revision: entry.revision,
            epoch: entry.epoch
        )
    }

    private func grantMatchesCurrentIdentity(
        _ grant: QuietTimeBriefAccessGrant,
        state: QuietTimeBriefAccessState,
        identity: QuietTimeBriefAccessScheduleIdentity?
    ) -> Bool {
        guard let identity else { return false }
        return state.runID == identity.runID
            && state.occurrenceID == identity.occurrenceID
            && state.scheduleRevision == identity.revision
            && state.scheduleEpoch == identity.epoch
            && grant.runID == identity.runID
            && grant.occurrenceID == identity.occurrenceID
            && grant.scheduleRevision == identity.revision
            && grant.scheduleEpoch == identity.epoch
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
