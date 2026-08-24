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
        completionHandler(action == .primaryButtonPressed ? returnToQuietTimeResponse() : .none)
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
        if action == .primaryButtonPressed {
            return returnToQuietTimeResponse()
        }

        if #available(iOS 26.4, *) {
            // Every role-specific submenu choice confirms the same bounded
            // grant. The system-provided Cancel action is the sole no-op path.
            switch action {
            case .firstSecondarySubmenuItemPressed,
                 .secondSecondarySubmenuItemPressed,
                 .thirdSecondarySubmenuItemPressed:
                break
            default:
                return .none
            }
        } else {
            guard action == .secondaryButtonPressed else { return .none }
        }

        // A scheduling failure must leave the user in the protected app state.
        guard grantBriefAccess(route: route) else { return .none }
        return .none
    }

    private func returnToQuietTimeResponse() -> ShieldActionResponse {
        if #available(iOS 26.5, *) {
            return .openParentalControlsApp
        }
        return .close
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
              let identity = currentIdentity(for: schedule, defaults: defaults, at: now),
              let expiration = schedule.intervalEnd(at: now),
              min(now.addingTimeInterval(BriefAccessShieldActionStorage.duration), expiration)
                .timeIntervalSince(now) >= BriefAccessShieldActionStorage.minimumDuration else {
            return false
        }

        var state: BriefAccessShieldActionState
        if let stateData = defaults.data(forKey: BriefAccessShieldActionStorage.stateKey),
           let stored = try? JSONDecoder().decode(BriefAccessShieldActionState.self, from: stateData) {
            state = stored
            if state.runID != identity.runID
                || state.occurrenceID != identity.occurrenceID
                || state.scheduleRevision != identity.revision
                || state.scheduleEpoch != identity.epoch {
                DeviceActivityCenter().stopMonitoring([BriefAccessShieldActionStorage.restoreActivity])
                state.carryingLedgerForward(
                    to: identity.runID,
                    occurrenceID: identity.occurrenceID,
                    revision: identity.revision,
                    epoch: identity.epoch,
                    at: now
                )
            } else if let activeGrant = state.activeGrant {
                if activeGrant.expiresAt <= now {
                    state.archiveCurrentRun(at: now)
                } else {
                    return false
                }
            }
        } else {
            state = BriefAccessShieldActionState(
                runID: identity.runID,
                occurrenceID: identity.occurrenceID,
                scheduleRevision: identity.revision,
                scheduleEpoch: identity.epoch,
                updatedAt: now
            )
        }

        let expiresAt = min(
            now.addingTimeInterval(BriefAccessShieldActionStorage.duration),
            expiration
        )
        let grant = BriefAccessShieldActionGrantFactory.make(
            runID: identity.runID,
            occurrenceID: identity.occurrenceID,
            revision: identity.revision,
            epoch: identity.epoch,
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
                  currentRunID: identity.runID,
                  currentOccurrenceID: identity.occurrenceID,
                  currentRevision: identity.revision,
                  currentEpoch: identity.epoch
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
        currentOccurrenceID: UUID,
        currentRevision: Int,
        currentEpoch: Int
    ) -> Bool {
        state.runID == currentRunID
            && state.occurrenceID == currentOccurrenceID
            && state.scheduleRevision == currentRevision
            && state.scheduleEpoch == currentEpoch
            && grant.runID == currentRunID
            && grant.occurrenceID == currentOccurrenceID
            && grant.scheduleRevision == currentRevision
            && grant.scheduleEpoch == currentEpoch
            && state.rejectedGrantNonce != grant.nonce
            && state.archivedAt == nil
            && state.activeGrant?.nonce == grant.nonce
            && state.activeGrant?.status == .pending
    }

    private func save(_ state: BriefAccessShieldActionState, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: BriefAccessShieldActionStorage.stateKey)
    }

    private func currentIdentity(
        for schedule: BriefAccessShieldActionSchedule,
        defaults: UserDefaults,
        at date: Date
    ) -> BriefAccessShieldActionIdentity? {
        let registry = BriefAccessShieldActionRegistryStorage.load(from: defaults)
        guard !registry.entries.isEmpty || !registry.tombstones.isEmpty else {
            return BriefAccessShieldActionIdentity(
                runID: schedule.runID,
                occurrenceID: schedule.occurrenceID,
                revision: schedule.revision,
                epoch: schedule.epoch
            )
        }
        guard let entry = registry.entry(for: schedule.occurrenceID),
              entry.interval.contains(date) else { return nil }
        // Parse the stable DeviceActivity name we derive from the entry rather
        // than trusting an unversioned snapshot field. This keeps a legacy
        // grant from matching a newer registry revision by coincidence.
        let dynamicActivity = BriefAccessShieldActionRegistryActivity(
            occurrenceID: entry.occurrenceID,
            revision: entry.revision,
            epoch: entry.epoch
        )
        guard let parsed = BriefAccessShieldActionRegistryActivity(identifier: dynamicActivity.identifier),
              registry.accepts(
                  occurrenceID: parsed.occurrenceID,
                  revision: parsed.revision,
                  epoch: parsed.epoch
              ) else { return nil }
        return BriefAccessShieldActionIdentity(
            runID: schedule.runID,
            occurrenceID: parsed.occurrenceID,
            revision: parsed.revision,
            epoch: parsed.epoch
        )
    }
}

private enum BriefAccessSchedulingError: Error {
    case invalidInterval
}

private struct BriefAccessShieldActionGrantFactory {
    static func make(
        runID: UUID,
        occurrenceID: UUID,
        revision: Int,
        epoch: Int,
        requestedAt: Date,
        expiresAt: Date
    ) -> BriefAccessGrant {
        BriefAccessGrant(
            schemaVersion: 1,
            runID: runID,
            occurrenceID: occurrenceID,
            scheduleRevision: revision,
            scheduleEpoch: epoch,
            requestedAt: requestedAt,
            expiresAt: expiresAt,
            nonce: UUID(),
            restoreActivityIdentifier: "ollie.quietTime.briefAccessRestore",
            status: .pending
        )
    }
}

private struct BriefAccessShieldActionIdentity {
    let runID: UUID
    let occurrenceID: UUID
    let revision: Int
    let epoch: Int
}
