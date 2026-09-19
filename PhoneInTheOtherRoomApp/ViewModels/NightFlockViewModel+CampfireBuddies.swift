import Foundation

extension NightFlockViewModel {
    func setCampfireAlerts(_ enabled: Bool, partyID: UUID) {
        guard let command = campfireBuddyCommand("setCampfireAlerts", partyID: partyID) else { return }
        var change = command
        change.startAlerts = enabled
        enqueuePasture(change)
    }

    func sendCampfireAction(_ action: String, session: CampfireBuddySession, partyID: UUID,
                            outcome: CampfireOutcome? = nil, reflection: String? = nil) {
        guard var command = campfireBuddyCommand("campfireBuddyAction", partyID: partyID) else { return }
        command.sourceID = session.sourceID; command.targetMemberID = session.memberID
        command.buddyAction = action; command.outcome = outcome
        command.reflection = reflection.map { CampfireBuddiesRules.publicText($0, limit: 160) }
        enqueuePasture(command)
    }

    private func campfireBuddyCommand(_ name: String, partyID: UUID) -> SharedPastureCommand? {
        guard let agreement = campfireAgreement(partyID: partyID), agreement.version == 2,
              let state = v4ObservedPartyDetail(for: partyID)?.pasture, state.campfire?.buddies?.isSupported == true else { return nil }
        var command = SharedPastureCommand(command: name, partyID: partyID, memberEpochID: state.memberEpochID)
        command.agreementID = agreement.id
        return command
    }
}
