import Foundation

#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls) && canImport(ManagedSettings)
import DeviceActivity
import FamilyControls
import ManagedSettings

private struct MonitoringClient {
    var activities: () -> [DeviceActivityName]
    var start: (DeviceActivityName, DeviceActivitySchedule) throws -> Void
    var stop: ([DeviceActivityName]) -> Void

    init(center: DeviceActivityCenter) {
        activities = { center.activities }
        start = { name, schedule in try center.startMonitoring(name, during: schedule) }
        stop = { names in center.stopMonitoring(names) }
    }

    init(
        activities: @escaping () -> [DeviceActivityName],
        start: @escaping (DeviceActivityName, DeviceActivitySchedule) throws -> Void,
        stop: @escaping ([DeviceActivityName]) -> Void
    ) {
        self.activities = activities
        self.start = start
        self.stop = stop
    }
}
#endif

@MainActor
protocol QuietTimeShieldingProviding {
    @discardableResult
    func reconcile(for run: FocusRun?, at date: Date) -> QuietTimeShieldingOutcome
    @discardableResult
    func reconcile(for occurrence: MorningQuietOccurrence, at date: Date) -> QuietTimeShieldingOutcome
    func clear()
    func clear(occurrenceID: UUID)
    @discardableResult
    func scheduleAutomatic(for schedule: AutomaticWindDownSchedule, at date: Date) -> QuietTimeShieldingOutcome
    func cancelAutomaticSchedule()
    func resetLocalState()
    func protectionSummary(for run: FocusRun, at date: Date) -> QuietTimeShieldProtectionSummary
    func briefAccessUseCount(for run: FocusRun) -> Int
    func briefAccessTrackerSummary(for run: FocusRun) -> QuietTimeBriefAccessTrackerSummary
    func briefAccessTrackerSummary(forOccurrenceID occurrenceID: UUID) -> QuietTimeBriefAccessTrackerSummary
}

extension QuietTimeShieldingProviding {
    @discardableResult
    func scheduleAutomatic(for schedule: AutomaticWindDownSchedule) -> QuietTimeShieldingOutcome {
        scheduleAutomatic(for: schedule, at: Date())
    }
}

@MainActor
final class QuietTimeShieldingService: QuietTimeShieldingProviding {
    static let enabledKey = "ollie.screenTime.shielding.enabled"

    private let defaults: UserDefaults
    private let sharedDefaults: UserDefaults?
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls) && canImport(ManagedSettings)
    private let store = ManagedSettingsStore(named: .init("ollie.quietTime"))
    private let selections = ScreenTimeSelectionService.shared
    private let activityCenter: DeviceActivityCenter
    private let monitoring: MonitoringClient
#endif

    init(
        defaults: UserDefaults = .standard,
        sharedDefaults: UserDefaults? = UserDefaults(
            suiteName: ScreenTimeSharedStorage.appGroupIdentifier
        )
    ) {
        self.defaults = defaults
        self.sharedDefaults = sharedDefaults
#if SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls) && canImport(ManagedSettings)
        let center = DeviceActivityCenter()
        self.activityCenter = center
        self.monitoring = MonitoringClient(center: center)
#endif
    }

#if DEBUG && SCREEN_TIME_REPORTS && canImport(DeviceActivity) && canImport(FamilyControls) && canImport(ManagedSettings)
    private init(defaults: UserDefaults, sharedDefaults: UserDefaults, monitoring: MonitoringClient) {
        self.defaults = defaults
        self.sharedDefaults = sharedDefaults
        self.activityCenter = DeviceActivityCenter()
        self.monitoring = monitoring
    }

    /// Screenbook can call this without touching a real Screen Time selection
    /// or ManagedSettings. It runs the production installer and rollback.
    static func debugRollbackProbe() -> Bool {
        let suite = "ollie.shielding.rollback-probe.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let now = Date()
        let unrelatedID = UUID()
        var registry = QuietTimeShieldScheduleRegistry()
        _ = registry.upsert(
            occurrenceID: unrelatedID,
            interval: DateInterval(start: now.addingTimeInterval(-60), end: now.addingTimeInterval(600)),
            role: .screenFreeMorning,
            at: now
        )
        QuietTimeShieldScheduleRegistryStorage.save(registry, to: defaults)
        let unrelatedActivity = QuietTimeShieldRegistryActivity(
            occurrenceID: unrelatedID,
            revision: registry.entry(for: unrelatedID)!.revision,
            epoch: registry.entry(for: unrelatedID)!.epoch
        ).deviceActivityName
        var stopped: [DeviceActivityName] = []
        var startedNames: [DeviceActivityName] = []
        var starts = 0
        let client = MonitoringClient(
            activities: { [] },
            start: { name, _ in startedNames.append(name); starts += 1; if starts > 1 { throw QuietTimeShieldingError.encodingFailed } },
            stop: { stopped.append(contentsOf: $0) }
        )
        let service = QuietTimeShieldingService(defaults: defaults, sharedDefaults: defaults, monitoring: client)
        let failedID = UUID()
        let snapshot = QuietTimeShieldScheduleSnapshot(
            runID: failedID, revision: 1, role: .primaryWindDown,
            protectedSessionInterval: DateInterval(start: now, end: now.addingTimeInterval(600)),
            windDownInterval: nil,
            morningQuietInterval: DateInterval(start: now, end: now.addingTimeInterval(600)),
            updatedAt: now
        )
        do { try service.installMonitoringIfNeeded(snapshot, at: now, preservingActiveBarrier: true) } catch {}
        let result = QuietTimeShieldScheduleRegistryStorage.load(from: defaults)
        let fractionalNow = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970) + 0.75)
        let preflightID = UUID()
        let preflight = QuietTimeShieldScheduleSnapshot(
            runID: preflightID, revision: 1, role: .primaryWindDown,
            protectedSessionInterval: DateInterval(start: fractionalNow, end: fractionalNow.addingTimeInterval(0.1)),
            windDownInterval: nil,
            morningQuietInterval: DateInterval(start: fractionalNow, end: fractionalNow.addingTimeInterval(0.1)),
            updatedAt: fractionalNow
        )
        var seeded = QuietTimeShieldScheduleRegistryStorage.load(from: defaults)
        guard let preflightInterval = preflight.protectedSessionInterval else { return false }
        _ = seeded.upsert(
            occurrenceID: preflightID,
            interval: preflightInterval,
            role: preflight.role,
            at: fractionalNow
        )
        QuietTimeShieldScheduleRegistryStorage.save(seeded, to: defaults)
        if let preflightData = try? JSONEncoder().encode(preflight) {
            defaults.set(preflightData, forKey: QuietTimeShieldSharedStorage.scheduleKey)
        }
        let startsBeforePreflight = starts
        do { try service.installMonitoringIfNeeded(preflight, at: fractionalNow, preservingActiveBarrier: true) } catch {}
        let afterPreflight = QuietTimeShieldScheduleRegistryStorage.load(from: defaults)
        return starts >= 2
            && starts == startsBeforePreflight
            && !stopped.isEmpty
            && startedNames.first.map { stopped.contains($0) } == true
            && !stopped.contains(unrelatedActivity)
            && result.entry(for: failedID) == nil
            && result.entry(for: unrelatedID) != nil
            && !result.accepts(occurrenceID: failedID, revision: 1, epoch: 1)
            && QuietTimeShieldRegistryCleanupPolicy.snapshot(for: result.entry(for: unrelatedID)!).runID == (service.loadSchedule()?.runID)
            && afterPreflight.entry(for: unrelatedID) != nil
            && afterPreflight.entry(for: preflightID) == nil
            && !afterPreflight.accepts(occurrenceID: preflightID, revision: 1, epoch: 1)
            && service.loadSchedule()?.runID == unrelatedID
    }
#endif

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
            preserveUnrelatedBarrierOrClear(selection, at: date)
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
            writeStatus(for: snapshot, status: .failed, window: nil, at: date, failureCode: "monitoring")
            preserveUnrelatedBarrierOrClear(selection, at: date)
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
            writeStatus(for: snapshot, status: .failed, window: .morningQuiet, at: date, failureCode: "monitoring")
            preserveUnrelatedBarrierOrClear(selection, at: date)
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
           expectedActivities.isSubset(of: Set(monitoring.activities())) {
            return
        }

        var attemptActivities: [DeviceActivityName] = []
        do {
        // Do this before publishing either cross-process schedule source. If
        // less than one whole second remains, DeviceActivity cannot receive a
        // monitor that will end this desired window. Silently skipping it
        // could leave an already applied shield with no clearing callback.
        for window in windows {
            guard let interval = snapshot.interval(for: window), interval.end > date else { continue }
            guard QuietTimeShieldMonitoringPolicy.window(for: interval, requestedAt: date) != nil else {
                throw QuietTimeShieldingError.monitoringWindowUnavailable
            }
        }

        if !preservingActiveBarrier {
            monitoring.stop([
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
            monitoring.stop(registryDiff.stop.map(\.deviceActivityName))
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
                guard let monitorWindow = QuietTimeShieldMonitoringPolicy.window(
                    for: entry.interval,
                    requestedAt: date
                ) else {
                    throw QuietTimeShieldingError.monitoringWindowUnavailable
                }
                let schedule = DeviceActivitySchedule(
                    intervalStart: dateComponents(for: monitorWindow.monitoring.start),
                    intervalEnd: dateComponents(for: monitorWindow.monitoring.end),
                    repeats: false,
                    warningTime: monitorWindow.warningTime
                )
                try self.monitoring.start(activity.deviceActivityName, schedule)
                attemptActivities.append(activity.deviceActivityName)
            }
        }

        for window in windows {
            guard let interval = snapshot.interval(for: window),
                  interval.end > date else { continue }
            guard let monitorWindow = QuietTimeShieldMonitoringPolicy.window(
                for: interval,
                requestedAt: date
            ) else {
                throw QuietTimeShieldingError.monitoringWindowUnavailable
            }
            let schedule = DeviceActivitySchedule(
                intervalStart: snapshot.repeatsDaily
                    ? dailyDateComponents(for: monitorWindow.monitoring.start)
                    : dateComponents(for: monitorWindow.monitoring.start),
                intervalEnd: snapshot.repeatsDaily
                    ? dailyDateComponents(for: monitorWindow.monitoring.end)
                    : dateComponents(for: monitorWindow.monitoring.end),
                repeats: snapshot.repeatsDaily,
                warningTime: monitorWindow.warningTime
            )
            try self.monitoring.start(window.activityName, schedule)
            attemptActivities.append(window.activityName)
        }
        writeStatus(for: snapshot, status: .scheduled, window: nil, at: Date())
        } catch {
            // A partial registration is not a schedule. Remove only the
            // names this attempt started and tombstone this occurrence so a
            // delayed extension callback cannot reapply it. Other registry
            // entries remain authoritative and untouched.
            monitoring.stop(attemptActivities)
            rollbackFailedMonitoringInstallation(for: snapshot, at: date)
            throw error
        }
    }

    private func rollbackFailedMonitoringInstallation(
        for snapshot: QuietTimeShieldScheduleSnapshot,
        at date: Date
    ) {
        guard let sharedDefaults else { return }
        var registry = QuietTimeShieldScheduleRegistryStorage.load(from: sharedDefaults)
        registry.remove(occurrenceID: snapshot.runID, at: date)
        QuietTimeShieldScheduleRegistryStorage.save(registry, to: sharedDefaults)
        if let remaining = registry.activeEntries(at: date)
            .sorted(by: { $0.updatedAt > $1.updatedAt })
            .first,
           let data = try? JSONEncoder().encode(
                QuietTimeShieldRegistryCleanupPolicy.snapshot(for: remaining)
           ) {
            sharedDefaults.set(data, forKey: QuietTimeShieldSharedStorage.scheduleKey)
        } else if loadSchedule()?.runID == snapshot.runID {
            sharedDefaults.removeObject(forKey: QuietTimeShieldSharedStorage.scheduleKey)
        }
        QuietPurposeCueState.clear(
            occurrenceID: snapshot.runID,
            revision: snapshot.registryRevision,
            epoch: snapshot.registryEpoch,
            from: sharedDefaults
        )
    }

    private func preserveUnrelatedBarrierOrClear(
        _ selection: FamilyActivitySelection,
        at date: Date
    ) {
        let registry = QuietTimeShieldScheduleRegistryStorage.load(from: sharedDefaults ?? .standard)
        if !registry.activeEntries(at: date).isEmpty {
            apply(selection)
        } else {
            clearStore()
        }
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
    case monitoringWindowUnavailable
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
