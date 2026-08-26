import Foundation

#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls) && canImport(ManagedSettings)
import DeviceActivity
import FamilyControls
import ManagedSettings
#endif

@MainActor
protocol QuietTimeShieldingProviding {
    @discardableResult
    func reconcile(for run: FocusRun?, at date: Date) -> QuietTimeShieldingOutcome
    @discardableResult
    func reconcile(for occurrence: MorningQuietOccurrence, at date: Date) -> QuietTimeShieldingOutcome
    func clear()
    func clear(occurrenceID: UUID)
    func cancelAutomaticSchedule()
    func protectionSummary(for run: FocusRun, at date: Date) -> QuietTimeShieldProtectionSummary
    func briefAccessUseCount(for run: FocusRun) -> Int
    func briefAccessTrackerSummary(for run: FocusRun) -> QuietTimeBriefAccessTrackerSummary
    func briefAccessTrackerSummary(forOccurrenceID occurrenceID: UUID) -> QuietTimeBriefAccessTrackerSummary
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
        guard run?.appShieldingRequested != false else {
            clear()
            return .disabled
        }
        // The run's immutable request is authoritative once started. The
        // saved toggle gates only future/automatic scheduling; changing it
        // during an active run must not lift that run's barrier.
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
            prepareBriefAccessState(for: automaticSnapshot, at: date)
            switch reconcileBriefAccess(
                for: run,
                snapshot: automaticSnapshot,
                at: date,
                currentRunID: automaticSnapshot.runID
            ) {
            case .active:
                return .scheduled
            case .restored, .none:
                break
            }
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

        prepareBriefAccessState(for: snapshot, at: date)

        switch reconcileBriefAccess(for: run, snapshot: snapshot, at: date) {
        case .active:
            return .scheduled
        case .restored, .none:
            break
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
        guard QuietTimeShieldingIntentPolicy.savedIntent(
            defaults.object(forKey: Self.enabledKey) as? Bool
        ) else {
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
            prepareBriefAccessState(for: snapshot, at: date)
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
        let preserveAutomaticSchedule = QuietTimeShieldingIntentPolicy.savedIntent(
            defaults.object(forKey: Self.enabledKey) as? Bool
        )
            && loadSchedule()?.repeatsDaily == true
        clearStore()
        activityCenter.stopMonitoring([.ollieBriefAccessRestore])
        archiveBriefAccessState(at: Date())
        guard !preserveAutomaticSchedule else { return }
        activityCenter.stopMonitoring([
            .ollieProtectedSession,
            .ollieWindDown,
            .ollieMorningQuiet
        ])
#endif
        tombstoneCurrentRegistry(at: Date())
        sharedDefaults?.removeObject(forKey: QuietTimeShieldSharedStorage.scheduleKey)
        sharedDefaults?.removeObject(forKey: QuietTimeShieldPresentationStorage.purposeCueKey)
    }

    /// Screen-Free Morning is an independent occurrence. Its registry entry
    /// must be removed without clearing a deferred or automatic Wind Down.
    func clear(occurrenceID: UUID) {
        guard let sharedDefaults else { return }
        var registry = QuietTimeShieldScheduleRegistryStorage.load(from: sharedDefaults)
        let originalRegistry = registry
        registry.prune(at: Date())
        if registry != originalRegistry {
            QuietTimeShieldScheduleRegistryStorage.save(registry, to: sharedDefaults)
        }
        guard let entry = registry.entry(for: occurrenceID) else { return }
        let cleanup = QuietTimeShieldRegistryCleanupPolicy.decision(
            registry: registry,
            removing: occurrenceID,
            at: Date()
        )
        // Keep the legacy compatibility snapshot pointed at another active
        // desired window before tombstoning this one. The monitor treats the
        // registry as authority too, but this ordering prevents a cross-
        // process callback from observing an empty compatibility snapshot.
        if case .keepShielded(let remaining) = cleanup,
           let active = remaining.sorted(by: { $0.updatedAt > $1.updatedAt }).first {
            let snapshot = QuietTimeShieldRegistryCleanupPolicy.snapshot(for: active)
            if let data = try? JSONEncoder().encode(snapshot) {
                sharedDefaults.set(data, forKey: QuietTimeShieldSharedStorage.scheduleKey)
            }
        }
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls) && canImport(ManagedSettings)
        activityCenter.stopMonitoring([
            QuietTimeShieldRegistryActivity(
                occurrenceID: entry.occurrenceID,
                revision: entry.revision,
                epoch: entry.epoch
            ).deviceActivityName
        ])
        switch cleanup {
        case .clearStore:
            clearStore()
        case .keepShielded:
            let selection = selections.load(.bedtime)
            if selection.phoneOtherIsEmpty {
                clearStore()
            } else {
                apply(selection)
            }
        }
#endif
        registry.remove(occurrenceID: occurrenceID, at: Date())
        QuietTimeShieldScheduleRegistryStorage.save(registry, to: sharedDefaults)
        QuietPurposeCueState.clear(
            occurrenceID: entry.occurrenceID,
            revision: entry.revision,
            epoch: entry.epoch,
            from: sharedDefaults
        )
        if loadSchedule()?.runID == occurrenceID {
            switch cleanup {
            case .clearStore:
                sharedDefaults.removeObject(forKey: QuietTimeShieldSharedStorage.scheduleKey)
            case .keepShielded:
                break
            }
        }
    }

    /// Projects an already-persisted Morning occurrence to the App Group. The
    /// journal remains the authority; this schedule contains only a bounded
    /// desired window and carries the occurrence identity into extensions.
    @discardableResult
    func reconcile(
        for occurrence: MorningQuietOccurrence,
        at date: Date = Date()
    ) -> QuietTimeShieldingOutcome {
        guard occurrence.outcome == .active || occurrence.outcome == .scheduled else {
            clear(occurrenceID: occurrence.id)
            return .cleared
        }
        let snapshot = QuietTimeShieldScheduleSnapshot(
            runID: occurrence.id,
            revision: 1,
            role: .screenFreeMorning,
            windDownInterval: nil,
            morningQuietInterval: DateInterval(
                start: occurrence.scheduledStart,
                end: occurrence.scheduledEnd
            ),
            updatedAt: date
        )
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls) && canImport(ManagedSettings)
        let selection = selections.load(.bedtime)
        guard !selection.phoneOtherIsEmpty else { return .noSelection }
        do {
            try installMonitoringIfNeeded(
                snapshot,
                at: date,
                preservingActiveBarrier: occurrence.outcome == .active
            )
            if occurrence.outcome == .active, occurrence.scheduledStart <= date, date < occurrence.scheduledEnd {
                apply(selection)
                writeStatus(for: snapshot, status: .applied, window: .morningQuiet, at: date)
                return .applied
            }
            writeStatus(for: snapshot, status: .scheduled, window: nil, at: date)
            return .scheduled
        } catch {
            clear(occurrenceID: occurrence.id)
            return .failed("monitoring")
        }
#else
        return .failed("unavailable")
#endif
    }

    func cancelAutomaticSchedule() {
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(ManagedSettings)
        activityCenter.stopMonitoring([
            .ollieProtectedSession,
            .ollieWindDown,
            .ollieMorningQuiet,
            .ollieBriefAccessRestore
        ])
        clearStore()
        archiveBriefAccessState(at: Date())
#endif
        tombstoneCurrentRegistry(at: Date())
        sharedDefaults?.removeObject(forKey: QuietTimeShieldSharedStorage.scheduleKey)
        sharedDefaults?.removeObject(forKey: QuietTimeShieldPresentationStorage.purposeCueKey)
    }

    /// Clears all shield runtime artifacts, including extension evidence. This
    /// is intentionally separate from `clear()`, which preserves a repeating
    /// automatic schedule during ordinary run reconciliation.
    func resetLocalState() {
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls) && canImport(ManagedSettings)
        activityCenter.stopMonitoring([
            .ollieProtectedSession,
            .ollieWindDown,
            .ollieMorningQuiet,
            .ollieBriefAccessRestore
        ])
        clearStore()
#endif
        sharedDefaults?.removeObject(forKey: QuietTimeShieldSharedStorage.scheduleKey)
        sharedDefaults?.removeObject(forKey: QuietTimeShieldSharedStorage.registryKey)
        sharedDefaults?.removeObject(forKey: QuietTimeShieldSharedStorage.statusKey)
        sharedDefaults?.removeObject(forKey: QuietTimeShieldSharedStorage.statusHistoryKey)
        sharedDefaults?.removeObject(forKey: QuietTimeShieldSharedStorage.briefAccessStateKey)
        sharedDefaults?.removeObject(forKey: QuietTimeShieldPresentationStorage.purposeCueKey)
    }

    func briefAccessUseCount(for run: FocusRun) -> Int {
        var count = run.briefAccessUseCount
        if let data = sharedDefaults?.data(forKey: QuietTimeShieldSharedStorage.briefAccessStateKey),
           let state = try? JSONDecoder().decode(QuietTimeBriefAccessState.self, from: data) {
            count = max(count, state.durableCount(for: run.id))
        }
        return count
    }

    func briefAccessTrackerSummary(for run: FocusRun) -> QuietTimeBriefAccessTrackerSummary {
        guard let sharedDefaults else {
            return QuietTimeBriefAccessTrackerSummary(
                pauseCount: run.briefAccessUseCount,
                allottedMinutes: run.briefAccessUseCount * Int(QuietTimeBriefAccessConstants.duration / 60)
            )
        }
        return QuietTimeBriefAccessTrackerSummary.load(
            for: run.id,
            from: sharedDefaults,
            fallbackUseCount: run.briefAccessUseCount
        )
    }

    func briefAccessTrackerSummary(forOccurrenceID occurrenceID: UUID) -> QuietTimeBriefAccessTrackerSummary {
        guard let sharedDefaults else { return QuietTimeBriefAccessTrackerSummary() }
        return QuietTimeBriefAccessTrackerSummary.load(for: occurrenceID, from: sharedDefaults)
    }

    func protectionSummary(
        for run: FocusRun,
        at date: Date
    ) -> QuietTimeShieldProtectionSummary {
        guard run.appShieldingRequested else { return .none }
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

    @discardableResult
    private func publishRegistry(
        for snapshot: QuietTimeShieldScheduleSnapshot,
        at date: Date
    ) -> QuietTimeShieldRegistryActivityDiff? {
        guard let sharedDefaults else { return nil }
        let previous = QuietTimeShieldScheduleRegistryStorage.load(from: sharedDefaults)
        var registry = previous
        let interval = snapshot.protectedSessionInterval
            ?? snapshot.windDownInterval
            ?? snapshot.morningQuietInterval
        _ = registry.upsert(
            occurrenceID: snapshot.runID,
            interval: interval,
            role: snapshot.role,
            at: date
        )
        QuietTimeShieldScheduleRegistryStorage.save(registry, to: sharedDefaults)
        return QuietTimeShieldRegistryActivityDiff.make(previous: previous, desired: registry)
    }

    private func tombstoneCurrentRegistry(at date: Date) {
        guard let sharedDefaults,
              let snapshot = loadSchedule() else { return }
        var registry = QuietTimeShieldScheduleRegistryStorage.load(from: sharedDefaults)
        registry.remove(occurrenceID: snapshot.runID, at: date)
        QuietTimeShieldScheduleRegistryStorage.save(registry, to: sharedDefaults)
    }

#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls) && canImport(ManagedSettings)
    private enum BriefAccessReconcileResult {
        case none
        case active
        case restored
    }

    private func briefAccessIdentity(
        for snapshot: QuietTimeShieldScheduleSnapshot
    ) -> QuietTimeBriefAccessScheduleIdentity? {
        let registry = QuietTimeShieldScheduleRegistryStorage.load(
            from: sharedDefaults ?? .standard
        )
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
              ) else {
            return nil
        }
        return QuietTimeBriefAccessScheduleIdentity(
            runID: snapshot.runID,
            occurrenceID: entry.occurrenceID,
            revision: entry.revision,
            epoch: entry.epoch
        )
    }

    private func prepareBriefAccessState(
        for snapshot: QuietTimeShieldScheduleSnapshot,
        at date: Date
    ) {
        guard let identity = briefAccessIdentity(for: snapshot) else { return }
        var state: QuietTimeBriefAccessState
        if let existing = loadBriefAccessState() {
            state = existing
            if state.runID != identity.runID
                || state.occurrenceID != identity.occurrenceID
                || state.scheduleRevision != identity.revision
                || state.scheduleEpoch != identity.epoch {
                activityCenter.stopMonitoring([.ollieBriefAccessRestore])
                state.carryingLedgerForward(
                    to: identity.runID,
                    occurrenceID: identity.occurrenceID,
                    revision: identity.revision,
                    epoch: identity.epoch,
                    at: date
                )
            }
        } else {
            state = QuietTimeBriefAccessState(
                runID: identity.runID,
                occurrenceID: identity.occurrenceID,
                scheduleRevision: identity.revision,
                scheduleEpoch: identity.epoch,
                updatedAt: date
            )
        }
        saveBriefAccessState(state)
    }

    private func reconcileBriefAccess(
        for run: FocusRun,
        snapshot: QuietTimeShieldScheduleSnapshot,
        at date: Date,
        currentRunID: UUID? = nil
    ) -> BriefAccessReconcileResult {
        guard let identity = briefAccessIdentity(for: snapshot) else {
            if loadBriefAccessState()?.activeGrant != nil {
                activityCenter.stopMonitoring([.ollieBriefAccessRestore])
                archiveBriefAccessState(at: date)
            }
            return .none
        }
        let state = loadBriefAccessState()
        switch QuietTimeBriefAccessPolicy.reconciliation(
            state: state,
            schedule: snapshot,
            currentRunID: currentRunID ?? identity.runID,
            currentRevision: identity.revision,
            currentOccurrenceID: identity.occurrenceID,
            currentEpoch: identity.epoch,
            at: date
        ) {
        case .noActiveGrant:
            activityCenter.stopMonitoring([.ollieBriefAccessRestore])
            return .none
        case .discardStaleGrant:
            if state?.activeGrant != nil {
                activityCenter.stopMonitoring([.ollieBriefAccessRestore])
                archiveBriefAccessState(at: date)
            }
            return .none
        case .rejectPendingGrant:
            guard var state, let grant = state.activeGrant else {
                activityCenter.stopMonitoring([.ollieBriefAccessRestore])
                return .none
            }
            state.rejectPendingGrant(nonce: grant.nonce, at: date)
            saveBriefAccessState(state)
            activityCenter.stopMonitoring([.ollieBriefAccessRestore])
            return .none
        case .keepShieldClear:
            guard let grant = state?.activeGrant,
                  ensureBriefAccessRestoreScheduled(for: grant, at: date) else {
                activityCenter.stopMonitoring([.ollieBriefAccessRestore])
                archiveBriefAccessState(at: date)
                return .restored
            }
            clearStore()
            return .active
        case .restoreShield:
            activityCenter.stopMonitoring([.ollieBriefAccessRestore])
            archiveBriefAccessState(at: date)
            return .restored
        }
    }

    private func ensureBriefAccessRestoreScheduled(
        for grant: QuietTimeBriefAccessGrant,
        at date: Date
    ) -> Bool {
        guard grant.expiresAt > date.addingTimeInterval(QuietTimeBriefAccessConstants.minimumSchedulingLead),
              !activityCenter.activities.contains(.ollieBriefAccessRestore) else {
            return grant.expiresAt > date.addingTimeInterval(QuietTimeBriefAccessConstants.minimumSchedulingLead)
        }
        guard let restorePlan = QuietTimeBriefAccessRestorePlan.make(
            requestedAt: date,
            expiresAt: grant.expiresAt
        ) else { return false }
        let schedule = DeviceActivitySchedule(
            intervalStart: dateComponents(for: restorePlan.intervalStart),
            intervalEnd: dateComponents(for: restorePlan.intervalEnd),
            repeats: false,
            warningTime: restorePlan.warningTime
        )
        do {
            try activityCenter.startMonitoring(.ollieBriefAccessRestore, during: schedule)
            return true
        } catch {
            return false
        }
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

    private func archiveBriefAccessState(at date: Date) {
        guard var state = loadBriefAccessState() else { return }
        state.archiveCurrentRun(at: date)
        saveBriefAccessState(state)
    }

    private func installMonitoringIfNeeded(
        _ snapshot: QuietTimeShieldScheduleSnapshot,
        at date: Date,
        preservingActiveBarrier: Bool = false
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

        if !preservingActiveBarrier {
            activityCenter.stopMonitoring([
                .ollieProtectedSession,
                .ollieWindDown,
                .ollieMorningQuiet,
                .ollieBriefAccessRestore
            ])
            clearStore()
        }

        // Publish the snapshot before registering the interval. DeviceActivity
        // may deliver an immediate start callback; the monitor must be able to
        // validate that callback instead of treating it as a stale schedule.
        guard let data = try? JSONEncoder().encode(snapshot) else {
            throw QuietTimeShieldingError.encodingFailed
        }
        sharedDefaults?.set(data, forKey: QuietTimeShieldSharedStorage.scheduleKey)
        let registryDiff = publishRegistry(for: snapshot, at: date)

        if let registryDiff {
            activityCenter.stopMonitoring(registryDiff.stop.map(\.deviceActivityName))
            let registry = QuietTimeShieldScheduleRegistryStorage.load(
                from: sharedDefaults ?? .standard
            )
            if let entry = registry.entry(for: snapshot.runID) {
                var presentationSnapshot = snapshot
                presentationSnapshot.registryRevision = entry.revision
                presentationSnapshot.registryEpoch = entry.epoch
                if let data = try? JSONEncoder().encode(presentationSnapshot) {
                    sharedDefaults?.set(data, forKey: QuietTimeShieldSharedStorage.scheduleKey)
                }
            }
            for activity in registryDiff.register {
                guard let entry = registry.entry(for: activity.occurrenceID), entry.interval.end > date else {
                    continue
                }
                let effectiveStart = max(entry.interval.start, date.addingTimeInterval(1))
                guard effectiveStart < entry.interval.end else { continue }
                let schedule = DeviceActivitySchedule(
                    intervalStart: dateComponents(for: effectiveStart),
                    intervalEnd: dateComponents(for: entry.interval.end),
                    repeats: false
                )
                try activityCenter.startMonitoring(activity.deviceActivityName, during: schedule)
            }
        }

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
