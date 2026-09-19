import Foundation
import UIKit

extension NightFlockViewModel {
    func enableCampfireInvitations(partyID: UUID) {
        let owner = pastureOwner
        Task {
            guard await CampfireNotificationService.requestPermission() else {
                campfirePushStatus = "Notifications are off on this phone. You can enable them in Settings."
                return
            }
            guard owner == pastureOwner, accountState == .linked else { return }
            setCampfireAlerts(true, partyID: partyID)
            syncCampfirePush()
        }
    }

    func refreshCampfireNotificationToken() {
        guard permitsNightFlockNetwork, accountState == .linked else { return }
        Task { await CampfireNotificationService.refreshTokenIfAuthorized() }
    }

    func updateCampfireQuietPeriod(for run: FocusRun?) {
        let quietUntil: Date
        if let run, !run.isPractice, [.running, .placementGrace, .waitingForPhoneAway, .warningPhoneTooClose, .signalLost].contains(run.state), let plan = run.nightWatchPlan {
            quietUntil = plan.role == .primarySleepBookend ? plan.protectedUntil : run.plannedEndAt
        } else { quietUntil = .distantPast }
        UserDefaults.standard.set(quietUntil, forKey: "ollie.campfire.localQuietUntil")
        campfireNotificationQuietUntil = quietUntil
        syncCampfirePush()
    }

    func syncCampfirePush() {
        guard permitsNightFlockNetwork, accountState == .linked, let service, let owner = pastureOwner else { return }
        guard UserDefaults.standard.string(forKey: CampfireNotificationService.tokenKey) != nil else { return }
        // Serialize registration so a delayed previous quiet window cannot replace
        // the latest one. Account ID is checked again by the authenticated endpoint.
        campfirePushNeedsSync = true
        guard !campfirePushIsSyncing else { return }
        campfirePushIsSyncing = true
        Task {
            defer {
                campfirePushIsSyncing = false
                if campfirePushNeedsSync { syncCampfirePush() }
            }
            while campfirePushNeedsSync {
                campfirePushNeedsSync = false
                guard owner == pastureOwner, accountState == .linked,
                      let registration = await CampfireNotificationService.registration(owner: owner, quietUntil: campfireNotificationQuietUntil) else { return }
                guard owner == pastureOwner, accountState == .linked else { return }
                do {
                    try await service.registerCampfireDevice(registration)
                    guard owner == pastureOwner else { return }
                    campfirePushStatus = registration.enabled ? "This phone is registered for invitations. Quiet hours still apply." : "Notifications are off on this phone."
                } catch {
                    guard owner == pastureOwner else { return }
                    campfirePushStatus = "This phone hasn’t registered for invitations yet. Try again when connected."
                }
            }
        }
    }
}
