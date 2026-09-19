import Foundation

extension FocusRunViewModel {
    /// Update a future automatic admission only when its captured audience has
    /// changed. Repeated presence reads must not reinstall the shield schedule.
    func reconcileScheduledCampfireAudience() {
        guard !isRunning, let schedule = persistence.automaticWindDownSchedule else { return }
        let social = nightFlockViewModel
        _ = social.restoreCampfireVisibility()
        let visibility = social.campfireVisibility
        let parties = visibility == .off ? [] : social.selectedCampfirePartyIDs.filter { social.campfireAgreement(partyID: $0) != nil }
        let receipt = visibility == .global && social.campfireStartIsReady ? social.campfireDocument.publicAgreement?.id : nil
        let intentions = parties.compactMap { id -> CampfireSharedIntention? in
            guard let agreement = social.campfireAgreement(partyID: id), agreement.version == 2 else { return nil }
            return .init(partyID: id, agreementID: agreement.id, text: "", announceStart: true, asksForBuddy: false)
        }
        guard schedule.plan.campfireVisibility != visibility
            || schedule.plan.campfireOwnerID != social.campfireOwnerForNewRun
            || schedule.plan.publicCampfireAgreementID != receipt
            || Set(schedule.plan.campfirePartyIDs ?? []) != Set(parties)
            || schedule.plan.campfireIntentions != intentions else { return }
        scheduleAutomaticWindDownIfNeeded()
    }
}
