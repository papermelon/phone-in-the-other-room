import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

final class QuietTimeShieldAction: ShieldActionDelegate {
    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action, route: .application))
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        completionHandler(response(for: action, route: .category))
    }

    private enum Route {
        case application
        case category
    }

    private func response(
        for action: ShieldAction,
        route: Route
    ) -> ShieldActionResponse {
        guard action == .secondaryButtonPressed else { return .close }
        // A scheduling failure must leave the user in the protected app state.
        guard grantBriefAccess(route: route) else { return .none }
        return .none
    }

    private func grantBriefAccess(route: Route) -> Bool {
        let now = Date()
        let defaults = UserDefaults(suiteName: BriefAccessShieldActionStorage.appGroupIdentifier)
        guard let defaults,
              let scheduleData = defaults.data(forKey: BriefAccessShieldActionStorage.scheduleKey),
              let schedule = try? JSONDecoder().decode(BriefAccessShieldActionSchedule.self, from: scheduleData),
              let selectionData = defaults.data(forKey: BriefAccessShieldActionStorage.selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData),
              !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty,
              schedule.isEligible(at: now),
              schedule.isShielded(at: now),
              let expiration = schedule.intervalEnd(at: now),
              min(now.addingTimeInterval(BriefAccessShieldActionStorage.duration), expiration)
                .timeIntervalSince(now) >= BriefAccessShieldActionStorage.minimumDuration else {
            return false
        }

        var state: BriefAccessShieldActionState
        if let stateData = defaults.data(forKey: BriefAccessShieldActionStorage.stateKey),
           let stored = try? JSONDecoder().decode(BriefAccessShieldActionState.self, from: stateData) {
            state = stored
            if state.runID != schedule.runID || state.scheduleRevision != schedule.revision {
                DeviceActivityCenter().stopMonitoring([BriefAccessShieldActionStorage.restoreActivity])
                state.carryingLedgerForward(to: schedule.runID, revision: schedule.revision, at: now)
            } else if let activeGrant = state.activeGrant {
                if activeGrant.expiresAt <= now {
                    state.archiveCurrentRun(at: now)
                } else {
                    return false
                }
            }
        } else {
            state = BriefAccessShieldActionState(
                runID: schedule.runID,
                scheduleRevision: schedule.revision,
                updatedAt: now
            )
        }

        let expiresAt = min(
            now.addingTimeInterval(BriefAccessShieldActionStorage.duration),
            expiration
        )
        let grant = BriefAccessShieldActionGrantFactory.make(
            runID: schedule.runID,
            revision: schedule.revision,
            requestedAt: now,
            expiresAt: expiresAt
        )
        guard state.propose(grant, at: now),
              let proposedData = try? JSONEncoder().encode(state) else { return false }
        defaults.set(proposedData, forKey: BriefAccessShieldActionStorage.stateKey)

        do {
            guard let restorePlan = BriefAccessRestorePlan.make(
                requestedAt: grant.requestedAt,
                expiresAt: grant.expiresAt
            ) else { throw BriefAccessSchedulingError.invalidInterval }
            let activitySchedule = DeviceActivitySchedule(
                intervalStart: Calendar.current.dateComponents(
                    [.era, .year, .month, .day, .hour, .minute, .second],
                    from: restorePlan.intervalStart
                ),
                intervalEnd: Calendar.current.dateComponents(
                    [.era, .year, .month, .day, .hour, .minute, .second],
                    from: restorePlan.intervalEnd
                ),
                repeats: false,
                warningTime: restorePlan.warningTime
            )
            try DeviceActivityCenter().startMonitoring(
                BriefAccessShieldActionStorage.restoreActivity,
                during: activitySchedule
            )
        } catch {
            DeviceActivityCenter().stopMonitoring([BriefAccessShieldActionStorage.restoreActivity])
            state.rollback(nonce: grant.nonce, at: Date())
            save(state, defaults: defaults)
            return false
        }

        guard let currentData = defaults.data(forKey: BriefAccessShieldActionStorage.stateKey),
              let currentState = try? JSONDecoder().decode(BriefAccessShieldActionState.self, from: currentData),
              canCommitScheduledGrant(
                  state: currentState,
                  grant: grant,
                  currentRunID: schedule.runID,
                  currentRevision: schedule.revision
              ) else {
            DeviceActivityCenter().stopMonitoring([BriefAccessShieldActionStorage.restoreActivity])
            return false
        }
        var committedState = currentState
        guard committedState.markScheduled(nonce: grant.nonce, at: Date()) else {
            DeviceActivityCenter().stopMonitoring([BriefAccessShieldActionStorage.restoreActivity])
            return false
        }
        save(committedState, defaults: defaults)
        ManagedSettingsStore(named: .init("ollie.quietTime")).clearAllSettings()
        _ = route
        return true
    }

    private func canCommitScheduledGrant(
        state: BriefAccessShieldActionState,
        grant: BriefAccessGrant,
        currentRunID: UUID,
        currentRevision: Int
    ) -> Bool {
        state.runID == currentRunID
            && state.scheduleRevision == currentRevision
            && state.rejectedGrantNonce != grant.nonce
            && state.archivedAt == nil
            && state.activeGrant?.nonce == grant.nonce
            && state.activeGrant?.status == .pending
    }

    private func save(_ state: BriefAccessShieldActionState, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: BriefAccessShieldActionStorage.stateKey)
    }
}

private enum BriefAccessSchedulingError: Error {
    case invalidInterval
}

private struct BriefAccessShieldActionGrantFactory {
    static func make(
        runID: UUID,
        revision: Int,
        requestedAt: Date,
        expiresAt: Date
    ) -> BriefAccessGrant {
        BriefAccessGrant(
            schemaVersion: 1,
            runID: runID,
            scheduleRevision: revision,
            requestedAt: requestedAt,
            expiresAt: expiresAt,
            nonce: UUID(),
            restoreActivityIdentifier: "ollie.quietTime.briefAccessRestore",
            status: .pending
        )
    }
}
