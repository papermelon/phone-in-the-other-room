import Foundation

#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls) && canImport(ManagedSettings)
import DeviceActivity
import FamilyControls
import ManagedSettings
#endif

enum QuietTimeShieldingOutcome: Equatable {
    case disabled
    case noSelection
    case scheduled
    case applied
    case cleared
    case failed(String)
}

@MainActor
protocol QuietTimeShieldingProviding {
    @discardableResult
    func reconcile(for run: FocusRun?, at date: Date) -> QuietTimeShieldingOutcome
    func clear()
    func protectionSummary(for run: FocusRun, at date: Date) -> QuietTimeShieldProtectionSummary
}

@MainActor
final class QuietTimeShieldingService: QuietTimeShieldingProviding {
    static let enabledKey = "ollie.screenTime.shielding.enabled"

    private let defaults: UserDefaults
    private let sharedDefaults: UserDefaults?
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls) && canImport(ManagedSettings)
    private let store = ManagedSettingsStore(named: .init("ollie.quietTime"))
    private let selections = ScreenTimeSelectionService.shared
    private let activityCenter = DeviceActivityCenter()
#endif

    init(
        defaults: UserDefaults = .standard,
        sharedDefaults: UserDefaults? = UserDefaults(
            suiteName: ScreenTimeSharedStorage.appGroupIdentifier
        )
    ) {
        self.defaults = defaults
        self.sharedDefaults = sharedDefaults
    }

    @discardableResult
    func reconcile(for run: FocusRun?, at date: Date = Date()) -> QuietTimeShieldingOutcome {
        guard defaults.bool(forKey: Self.enabledKey) else {
            clear()
            return .disabled
        }
        guard let run,
              ![.setup, .completed, .endedEarly].contains(run.state),
              let snapshot = scheduleSnapshot(for: run, at: date) else {
            clear()
            return .cleared
        }
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls) && canImport(ManagedSettings)
        let selection = selections.load(.bedtime)
        guard !selection.phoneOtherIsEmpty else {
            clear()
            return .noSelection
        }

        if let automaticSnapshot = loadSchedule(), automaticSnapshot.repeatsDaily {
            return reconcileRepeatingAutomatic(
                run: run,
                snapshot: automaticSnapshot,
                selection: selection,
                at: date
            )
        }

        do {
            try installMonitoringIfNeeded(snapshot, at: date)
        } catch {
            writeStatus(
                for: snapshot,
                status: .failed,
                window: run.nightWatchPhase(at: date)?.shieldWindow,
                at: date,
                failureCode: "monitoring"
            )
            clearStore()
            return .failed("monitoring")
        }

        if QuietTimeShieldingPolicy.shouldShield(run: run, at: date, isEnabled: true) {
            apply(selection)
            writeStatus(
                for: snapshot,
                status: .applied,
                window: statusWindow(for: snapshot, run: run, at: date),
                at: date
            )
            return .applied
        }

        clearStore()
        writeStatus(for: snapshot, status: .cleared, window: nil, at: date)
        return .scheduled
#else
        return .failed("unavailable")
#endif
    }

    /// Schedules future DeviceActivity windows from the saved Wind Down plan.
    /// DeviceActivity can enforce those windows while the main app is suspended;
    /// the app reconstructs the corresponding run when it next becomes active.
    @discardableResult
    func scheduleAutomatic(
        for schedule: AutomaticWindDownSchedule,
        at date: Date = Date()
    ) -> QuietTimeShieldingOutcome {
        guard defaults.bool(forKey: Self.enabledKey) else {
            clear()
            return .disabled
        }
        let existing = loadSchedule()
        let revision = existing?.runID == schedule.id
            ? (existing?.revision ?? 0) + 1
            : 1
        let snapshot = QuietTimeShieldScheduleBuilder.snapshot(
            for: schedule,
            revision: revision,
            updatedAt: date
        )
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls) && canImport(ManagedSettings)
        let selection = selections.load(.bedtime)
        guard !selection.phoneOtherIsEmpty else {
            clear()
            return .noSelection
        }
        do {
            try installMonitoringIfNeeded(snapshot, at: date)
            // Scheduling a future repeating window must never leave a shield from
            // the window it replaced. The monitor will apply it when the first
            // eligible interval actually begins.
            if !snapshot.isEligible(at: date) {
                clearStore()
                writeStatus(for: snapshot, status: .cleared, window: nil, at: date)
            }
            return .scheduled
        } catch {
            clear()
            return .failed("monitoring")
        }
#else
        return .failed("unavailable")
#endif
    }

    func clear() {
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(ManagedSettings)
        let preserveAutomaticSchedule = defaults.bool(forKey: Self.enabledKey)
            && loadSchedule()?.repeatsDaily == true
        clearStore()
        guard !preserveAutomaticSchedule else { return }
        activityCenter.stopMonitoring([
            .ollieProtectedSession,
            .ollieWindDown,
            .ollieMorningQuiet
        ])
#endif
        sharedDefaults?.removeObject(forKey: QuietTimeShieldSharedStorage.scheduleKey)
    }

    func cancelAutomaticSchedule() {
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(ManagedSettings)
        activityCenter.stopMonitoring([
            .ollieProtectedSession,
            .ollieWindDown,
            .ollieMorningQuiet
        ])
        clearStore()
#endif
        sharedDefaults?.removeObject(forKey: QuietTimeShieldSharedStorage.scheduleKey)
    }

    func protectionSummary(
        for run: FocusRun,
        at date: Date
    ) -> QuietTimeShieldProtectionSummary {
        let automaticScheduleID = loadSchedule().flatMap { snapshot in
            snapshot.repeatsDaily ? snapshot.runID : nil
        }
        return QuietTimeShieldEvidenceMath.summary(
            for: run,
            statuses: loadStatusHistory(),
            at: date,
            additionalRunIDs: automaticScheduleID.map { Set([$0]) } ?? []
        )
    }

    private func scheduleSnapshot(
        for run: FocusRun,
        at date: Date
    ) -> QuietTimeShieldScheduleSnapshot? {
        let existing = loadSchedule()
        let nextRevision = existing?.runID == run.id
            ? (existing?.revision ?? 0) + 1
            : 1
        guard let proposed = QuietTimeShieldScheduleBuilder.snapshot(
            for: run,
            revision: nextRevision,
            updatedAt: date
        ) else { return nil }
        if let existing, existing.hasSameWindows(as: proposed) {
            return existing
        }
        return proposed
    }

    private func loadSchedule() -> QuietTimeShieldScheduleSnapshot? {
        guard let data = sharedDefaults?.data(
            forKey: QuietTimeShieldSharedStorage.scheduleKey
        ) else { return nil }
        return try? JSONDecoder().decode(QuietTimeShieldScheduleSnapshot.self, from: data)
    }

#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls) && canImport(ManagedSettings)
    private func installMonitoringIfNeeded(
        _ snapshot: QuietTimeShieldScheduleSnapshot,
        at date: Date
    ) throws {
        // New schedules use one continuous interval so the monitor cannot clear
        // an overnight shield when the wind-down bookend ends. Snapshots written
        // by older builds have no protected interval and retain the two-window
        // compatibility path.
        let windows: [QuietTimeShieldWindow] = snapshot.protectedSessionInterval != nil
            ? [.protectedSession]
            : [.windDown, .morningQuiet]
        let expectedActivities = Set<DeviceActivityName>(
            windows.compactMap { window -> DeviceActivityName? in
                guard let interval = snapshot.interval(for: window),
                      interval.end > date else { return nil }
                return window.activityName
            }
        )
        if loadSchedule() == snapshot,
           expectedActivities.isSubset(of: Set(activityCenter.activities)) {
            return
        }

        activityCenter.stopMonitoring([
            .ollieProtectedSession,
            .ollieWindDown,
            .ollieMorningQuiet
        ])
        clearStore()

        // Publish the snapshot before registering the interval. DeviceActivity
        // may deliver an immediate start callback; the monitor must be able to
        // validate that callback instead of treating it as a stale schedule.
        guard let data = try? JSONEncoder().encode(snapshot) else {
            throw QuietTimeShieldingError.encodingFailed
        }
        sharedDefaults?.set(data, forKey: QuietTimeShieldSharedStorage.scheduleKey)

        for window in windows {
            guard let interval = snapshot.interval(for: window),
                  interval.end > date else { continue }
            let effectiveStart = max(
                interval.start,
                date.addingTimeInterval(1)
            )
            guard effectiveStart < interval.end else { continue }
            let schedule = DeviceActivitySchedule(
                intervalStart: snapshot.repeatsDaily
                    ? dailyDateComponents(for: effectiveStart)
                    : dateComponents(for: effectiveStart),
                intervalEnd: snapshot.repeatsDaily
                    ? dailyDateComponents(for: interval.end)
                    : dateComponents(for: interval.end),
                repeats: snapshot.repeatsDaily
            )
            try activityCenter.startMonitoring(window.activityName, during: schedule)
        }
        writeStatus(for: snapshot, status: .scheduled, window: nil, at: Date())
    }

    private func dateComponents(for date: Date) -> DateComponents {
        Calendar.current.dateComponents(
            [.era, .year, .month, .day, .hour, .minute, .second],
            from: date
        )
    }

    private func dailyDateComponents(for date: Date) -> DateComponents {
        Calendar.current.dateComponents([.hour, .minute, .second], from: date)
    }

    private func reconcileRepeatingAutomatic(
        run: FocusRun,
        snapshot: QuietTimeShieldScheduleSnapshot,
        selection: FamilyActivitySelection,
        at date: Date
    ) -> QuietTimeShieldingOutcome {
        if QuietTimeShieldingPolicy.shouldShield(run: run, at: date, isEnabled: true) {
            apply(selection)
            writeStatus(
                for: snapshot,
                status: .applied,
                window: statusWindow(for: snapshot, run: run, at: date),
                at: date
            )
            return .applied
        }
        clearStore()
        writeStatus(for: snapshot, status: .cleared, window: nil, at: date)
        return .scheduled
    }

    private func apply(_ selection: FamilyActivitySelection) {
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }

    private func statusWindow(
        for snapshot: QuietTimeShieldScheduleSnapshot,
        run: FocusRun,
        at date: Date
    ) -> QuietTimeShieldWindow? {
        if snapshot.contains(date, in: .protectedSession) {
            return .protectedSession
        }
        return run.nightWatchPhase(at: date)?.shieldWindow
    }

    private func clearStore() {
        store.clearAllSettings()
    }

    private func writeStatus(
        for snapshot: QuietTimeShieldScheduleSnapshot,
        status: QuietTimeShieldStatus,
        window: QuietTimeShieldWindow?,
        at date: Date,
        failureCode: String? = nil
    ) {
        let statusSnapshot = QuietTimeShieldStatusSnapshot(
            runID: snapshot.runID,
            revision: snapshot.revision,
            status: status,
            window: window,
            observedAt: date,
            failureCode: failureCode
        )
        guard let data = try? JSONEncoder().encode(statusSnapshot) else { return }
        sharedDefaults?.set(data, forKey: QuietTimeShieldSharedStorage.statusKey)
        appendStatus(statusSnapshot)
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

    private func appendStatus(_ status: QuietTimeShieldStatusSnapshot) {
        var history = loadStatusHistory()
        if history.last != status {
            history.append(status)
        }
        history = Array(history.suffix(40))
        guard let data = try? JSONEncoder().encode(history) else { return }
        sharedDefaults?.set(data, forKey: QuietTimeShieldSharedStorage.statusHistoryKey)
    }
#endif
}

private enum QuietTimeShieldingError: Error {
    case encodingFailed
}

private extension NightWatchPhase {
    var shieldWindow: QuietTimeShieldWindow? {
        switch self {
        case .windDown: return .windDown
        case .morningQuiet: return .morningQuiet
        case .overnight, .complete: return nil
        }
    }
}
