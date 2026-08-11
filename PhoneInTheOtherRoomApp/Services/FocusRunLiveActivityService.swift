import Foundation

#if canImport(ActivityKit)
import ActivityKit
#if DEBUG
import CryptoKit
#endif
import OSLog

@available(iOS 16.1, *)
@MainActor
protocol FocusRunLiveActivityRemoteSink: AnyObject {
    func sync(_ run: FocusRunCloudSync) async
    func upsert(_ registration: FocusRunLiveActivityPushRegistration) async
    func cancel(_ cancellation: FocusRunLiveActivityCancellation) async
}

@available(iOS 16.1, *)
@MainActor
final class DisabledFocusRunLiveActivityRemoteSink: FocusRunLiveActivityRemoteSink {
    func sync(_ run: FocusRunCloudSync) async {}
    func upsert(_ registration: FocusRunLiveActivityPushRegistration) async {}
    func cancel(_ cancellation: FocusRunLiveActivityCancellation) async {}
}

@available(iOS 16.1, *)
@MainActor
final class FocusRunLiveActivityService {
    private static let completionDismissalInterval: TimeInterval = 15 * 60
    private let remoteSink: FocusRunLiveActivityRemoteSink
    private var enabled: Bool
    private var tokenObservationTasks: [String: Task<Void, Never>] = [:]
    private var latestTokens: [String: Data] = [:]
    private var tokenGenerations: [String: Int] = [:]
    private let installationID: UUID
    private let remotePushEnabled: Bool
    private let logger = Logger(subsystem: "com.ngawangchime.countingsheep", category: "LiveActivity")
#if DEBUG
    private var debugStartCount = 0
    private var debugUpdateCount = 0
    private var debugEndCount = 0
    private var debugLastUpdateAt: Date?
#endif

    static let preferenceKey = "ollie.liveActivity.enabled"

    static var preferenceEnabled: Bool {
        guard UserDefaults.standard.object(forKey: preferenceKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: preferenceKey)
    }

    init(
        remoteSink: FocusRunLiveActivityRemoteSink? = nil,
        installationID: UUID = PersistenceService.shared.installationID,
        enabled: Bool? = nil
    ) {
        let resolvedEnabled = enabled ?? Self.defaultEnabled
        self.enabled = resolvedEnabled
        self.remotePushEnabled = (try? SupabaseConfiguration.load().liveActivityPushEnabled) ?? false
        // Keep the configured sink available if the user turns Live Activity on later
        // from Settings; the enabled preference gates all activity work, not sink setup.
        self.remoteSink = remoteSink ?? DisabledFocusRunLiveActivityRemoteSink()
        self.installationID = installationID
#if DEBUG
        logger.debug("Live Activity policy enabled=\(resolvedEnabled, privacy: .public)")
#endif
        // Keep the target available for controlled comparisons without adding a persistent
        // Dynamic Island surface, token observer, or push transport to normal sessions.
        if !resolvedEnabled {
            endAll(reason: .reset)
        }
    }

    deinit {
        for task in tokenObservationTasks.values {
            task.cancel()
        }
    }

    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.preferenceKey)
        if !enabled { endAll(reason: .reset) }
    }

    func resetToFreshInstallDefaults() {
        UserDefaults.standard.removeObject(forKey: Self.preferenceKey)
        enabled = Self.defaultEnabled
        endAll(reason: .reset)
    }

    func start(for run: FocusRun) {
        // The Settings toggle is only the default. Each run records the explicit
        // answer from its start sheet so relaunching cannot create an activity
        // that the user declined.
        guard run.liveActivityRequested else { return }
#if DEBUG
        debugStartCount += 1
        logger.debug("start requested count=\(self.debugStartCount) run=\(run.id.uuidString, privacy: .public)")
        if liveActivitiesDisabledForEnergyProfiling {
            logger.notice("Live Activity disabled by ollie.debug.disableLiveActivity")
            endAll(reason: .reset)
            return
        }
#endif
        guard enabled else {
#if DEBUG
            logger.notice("Live Activity disabled by default policy")
#endif
            endAll(reason: .reset)
            return
        }
        syncRun(run, status: .active)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if let activity = activeActivity(for: run.id) {
            if remotePushEnabled {
                observePushTokens(for: activity, run: run)
            }
            synchronize(activity, with: run)
            return
        }

        let attributes = FocusRunLiveActivityAttributes(
            runID: run.id,
            plannedDurationSeconds: run.plannedDurationSeconds
        )
        let content = contentState(for: run, terminalStatus: nil)
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: content, staleDate: run.plannedEndAt),
                // A local Live Activity does not need an APNs token. Requesting
                // token delivery while the backend flag is off exercised a
                // separate extension/entitlement path and regressed Build 9.
                pushType: remotePushEnabled ? .token : nil
            )
#if DEBUG
            logger.debug("Live Activity created activity=\(activity.id, privacy: .public)")
#endif
            if remotePushEnabled {
                observePushTokens(for: activity, run: run)
            }
        } catch {
            logger.error("Live Activity request failed: \(error.localizedDescription, privacy: .public)")
            // A Live Activity is a glanceable extra; a denied or unavailable system state
            // must never prevent the phone-away ritual from starting.
        }
    }

    func finish(for run: FocusRun) {
#if DEBUG
        if liveActivitiesDisabledForEnergyProfiling {
            endAll(reason: run.completedSuccessfully ? .completed : .endedEarly)
            return
        }
#endif
        guard enabled else {
            endAll(reason: run.completedSuccessfully ? .completed : .endedEarly)
            return
        }
        syncRun(run, status: run.completedSuccessfully ? .completed : .endedEarly)
        let terminalStatus: FocusRunLiveActivityTerminalStatus = run.completedSuccessfully
            ? .completed
            : .endedEarly
        let finalContent = contentState(for: run, terminalStatus: terminalStatus)
        let content = ActivityContent(state: finalContent, staleDate: nil)
        let activities = Activity<FocusRunLiveActivityAttributes>.activities
            .filter { $0.attributes.runID == run.id }
        let reason: FocusRunLiveActivityCancellationReason = run.completedSuccessfully ? .completed : .endedEarly
        let dismissalPolicy: ActivityUIDismissalPolicy = reason == .completed
            ? .after(Date().addingTimeInterval(Self.completionDismissalInterval))
            : .immediate

        Task {
            for activity in activities {
                await activity.end(content, dismissalPolicy: dismissalPolicy)
#if DEBUG
                self.debugEndCount += 1
                self.logger.debug(
                    "Live Activity ended count=\(self.debugEndCount) activity=\(activity.id, privacy: .public) reason=\(reason.rawValue, privacy: .public)"
                )
#endif
                stopObserving(activityID: activity.id)
                await cancelRemoteSchedule(for: activity, reason: reason)
            }
        }
    }

    func update(for run: FocusRun) {
#if DEBUG
        guard !liveActivitiesDisabledForEnergyProfiling else { return }
#endif
        guard run.liveActivityRequested else { return }
        guard enabled else { return }
        syncRun(run, status: .active)
        guard let activity = activeActivity(for: run.id) else { return }
        let state = contentState(for: run, terminalStatus: nil)
#if DEBUG
        logActivityUpdate(reason: "phase transition")
#endif
        Task {
            await activity.update(ActivityContent(state: state, staleDate: run.plannedEndAt))
        }
    }

    func endAll(reason: FocusRunLiveActivityCancellationReason = .reset) {
        let activities = Activity<FocusRunLiveActivityAttributes>.activities
        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
#if DEBUG
                self.debugEndCount += 1
                self.logger.debug(
                    "Live Activity ended count=\(self.debugEndCount) activity=\(activity.id, privacy: .public) reason=\(reason.rawValue, privacy: .public)"
                )
#endif
                stopObserving(activityID: activity.id)
                await cancelRemoteSchedule(for: activity, reason: reason)
            }
        }
    }

    private func synchronize(
        _ activity: Activity<FocusRunLiveActivityAttributes>,
        with run: FocusRun
    ) {
        let state = contentState(for: run, terminalStatus: nil)
#if DEBUG
        logActivityUpdate(reason: "reconciliation")
#endif
        Task {
            await activity.update(ActivityContent(state: state, staleDate: run.plannedEndAt))
            if let token = latestTokens[activity.id] {
                await sendRegistration(token: token, activity: activity, run: run)
            }
        }
    }

    private func observePushTokens(
        for activity: Activity<FocusRunLiveActivityAttributes>,
        run: FocusRun
    ) {
        guard tokenObservationTasks[activity.id] == nil else { return }
#if DEBUG
        logger.debug("Push-token observer created activity=\(activity.id, privacy: .public)")
#endif
        tokenObservationTasks[activity.id] = Task { [weak self] in
            for await token in activity.pushTokenUpdates {
                guard !Task.isCancelled, let self else { return }
                self.latestTokens[activity.id] = token
                self.tokenGenerations[activity.id, default: 0] += 1
#if DEBUG
                let fingerprint = SHA256.hash(data: token).prefix(6)
                    .map { String(format: "%02x", $0) }
                    .joined()
                self.logger.info(
                    "Observed Live Activity token activity=\(activity.id, privacy: .public) run=\(run.id.uuidString, privacy: .public) fingerprint=\(fingerprint, privacy: .public)"
                )
#endif
                await self.sendRegistration(token: token, activity: activity, run: run)
            }
        }
    }

    private func sendRegistration(
        token: Data,
        activity: Activity<FocusRunLiveActivityAttributes>,
        run: FocusRun
    ) async {
        let registration = FocusRunLiveActivityPushRegistration(
            runID: run.id,
            activityID: activity.id,
            pushToken: token.map { String(format: "%02x", $0) }.joined(),
            plannedEndAt: run.plannedEndAt,
            observedAt: Date(),
            environment: Self.apnsEnvironment,
            installationID: installationID,
            runRevision: 1,
            tokenGeneration: tokenGenerations[activity.id, default: 1],
            idempotencyKey: "\(run.id.uuidString):\(activity.id):schedule:\(tokenGenerations[activity.id, default: 1])",
            phase: run.nightWatchPhase(at: Date()),
            role: run.nightWatchPlan?.role,
            bedtimeAt: run.nightWatchPlan?.intendedBedtime,
            wakeAt: run.nightWatchPlan?.wakeTime,
            morningQuietEndsAt: run.nightWatchPlan?.protectedUntil,
            eveningActivityTitle: run.nightWatchPlan?.eveningActivityTitle,
            morningActivityTitle: run.nightWatchPlan?.morningActivityTitle
        )
        await remoteSink.upsert(registration)
    }

    private func syncRun(_ run: FocusRun, status: FocusRunCloudStatus) {
        let revision = status == .active ? 1 : 2
        let sync = FocusRunCloudSync(
            runID: run.id,
            installationID: installationID,
            plannedEndAt: run.plannedEndAt,
            observedAt: Date(),
            status: status,
            runRevision: revision,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            idempotencyKey: "\(run.id.uuidString):run:\(revision):\(status.rawValue)"
        )
#if DEBUG
        logger.debug(
            "Remote run sync enqueued run=\(run.id.uuidString, privacy: .public) status=\(status.rawValue, privacy: .public)"
        )
#endif
        Task { await remoteSink.sync(sync) }
    }

    private func cancelRemoteSchedule(
        for activity: Activity<FocusRunLiveActivityAttributes>,
        reason: FocusRunLiveActivityCancellationReason
    ) async {
        await remoteSink.cancel(
            FocusRunLiveActivityCancellation(
                runID: activity.attributes.runID,
                activityID: activity.id,
                reason: reason,
                occurredAt: Date(),
                installationID: installationID,
                runRevision: 1,
                idempotencyKey: "\(activity.attributes.runID.uuidString):\(activity.id):cancel:\(reason.rawValue)"
            )
        )
    }

    private func stopObserving(activityID: String) {
        tokenObservationTasks.removeValue(forKey: activityID)?.cancel()
        latestTokens.removeValue(forKey: activityID)
        tokenGenerations.removeValue(forKey: activityID)
#if DEBUG
        logger.debug("Push-token observer cancelled activity=\(activityID, privacy: .public)")
#endif
    }

#if DEBUG
    private var liveActivitiesDisabledForEnergyProfiling: Bool {
        UserDefaults.standard.bool(forKey: "ollie.debug.disableLiveActivity")
    }

    private static var defaultEnabled: Bool {
        if UserDefaults.standard.bool(forKey: "ollie.debug.disableLiveActivity") {
            return false
        }
        if UserDefaults.standard.bool(forKey: "ollie.debug.enableLiveActivity") {
            return true
        }
        return Self.preferenceEnabled
    }

    private func logActivityUpdate(reason: String) {
        debugUpdateCount += 1
        let now = Date()
        let interval = debugLastUpdateAt.map { now.timeIntervalSince($0) } ?? 0
        debugLastUpdateAt = now
        logger.debug(
            "activity.update count=\(self.debugUpdateCount) reason=\(reason, privacy: .public) secondsSincePrevious=\(interval, format: .fixed(precision: 3))"
        )
    }
#else
    private static var defaultEnabled: Bool {
        Self.preferenceEnabled
    }
#endif

    private static var apnsEnvironment: LiveActivityAPNSEnvironment {
#if DEBUG
        .sandbox
#else
        .production
#endif
    }

    private func activeActivity(for runID: UUID) -> Activity<FocusRunLiveActivityAttributes>? {
        Activity<FocusRunLiveActivityAttributes>.activities.first { $0.attributes.runID == runID }
    }

    private func contentState(
        for run: FocusRun,
        terminalStatus: FocusRunLiveActivityTerminalStatus?
    ) -> FocusRunLiveActivityAttributes.ContentState {
        let isComplete = terminalStatus == .completed
        let phase: NightWatchPhase? = switch terminalStatus {
        case .completed:
            .complete
        case .endedEarly:
            nil
        case nil:
            run.nightWatchPhase(at: Date())
        }
        return FocusRunLiveActivityAttributes.ContentState(
            plannedEndAt: run.plannedEndAt,
            isComplete: isComplete,
            phase: phase,
            role: run.nightWatchPlan?.role,
            terminalStatus: terminalStatus,
            bedtimeAt: run.nightWatchPlan?.intendedBedtime,
            wakeAt: run.nightWatchPlan?.wakeTime,
            morningQuietEndsAt: run.nightWatchPlan?.protectedUntil,
            eveningActivityTitle: run.nightWatchPlan?.eveningActivityTitle,
            morningActivityTitle: run.nightWatchPlan?.morningActivityTitle
        )
    }
}
#else
@MainActor
final class FocusRunLiveActivityService {
    static let preferenceKey = "ollie.liveActivity.enabled"
    static var preferenceEnabled: Bool { true }
    func resetToFreshInstallDefaults() {}
    func setEnabled(_ enabled: Bool) {}
    func start(for run: FocusRun) {}
    func update(for run: FocusRun) {}
    func finish(for run: FocusRun) {}
    func endAll(reason: FocusRunLiveActivityCancellationReason = .reset) {}
}
#endif
