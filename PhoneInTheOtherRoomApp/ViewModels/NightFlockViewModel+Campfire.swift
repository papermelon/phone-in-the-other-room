import Foundation

extension NightFlockViewModel {
    var campfireOwnerForNewRun: UUID? {
        accountState == .linked && permitsFarmOwnerScopedSocialEffects ? pastureOwner : nil
    }

    var hasCampfireSharing: Bool {
        slumberParties.contains { campfireAgreement(partyID: $0.partyID) != nil }
    }

    func campfireParticipationNotice(partyID: UUID, run: FocusRun?) -> String? {
        guard let party = v4ObservedPartyDetail(for: partyID),
              v4ObservedPartyObservationState(for: partyID).permitsLivePresence,
              let campfire = party.pasture?.campfire, campfire.isSupported,
              let owner = pastureOwner,
              let pending = try? pastureOutbox.commands(owner: owner),
              !pending.contains(where: { $0.partyID == partyID && $0.command == "setCampfireSharing" }) else { return nil }
        guard campfire.agreement?.permitsSharing == true else {
            return "Joining a Slumber Party doesn’t enable Campfire sharing. Review sharing before your next Wind Down or Phone Away to bring your Shepherd to the fire."
        }
        guard let run, let end = CampfireRules.end(for: run), end > Date(),
              run.state != .completed, run.state != .endedEarly else { return nil }
        if CampfireRules.currentSessions(campfire, members: Set(party.memberships.map(\.memberID)), isFresh: true, at: Date())
            .contains(where: { $0.memberID == party.myMemberID && $0.id == run.id }) { return nil }
        if let acceptedAt = campfire.agreement?.acceptedAt, run.startedAt < acceptedAt {
            return "Sharing is ready for your next session. This session started before Campfire sharing was enabled."
        }
        if run.nightWatchPlan?.campfirePartyIDs?.contains(partyID) == false
            || (run.nightWatchPlan?.role == .primarySleepBookend && !maySharePrimaryRun(run)) {
            return "This session wasn’t selected for sharing with this party. You can choose this party when you start your next session."
        }
        return "Your session hasn’t appeared at this campfire. Refresh to check its sharing status. Your timer can keep running."
    }

    func campfireAgreement(partyID: UUID) -> CampfireAgreement? {
        guard permitsFarmOwnerScopedSocialEffects, !isSharedHabitsPartySuppressed(partyID),
              let owner = pastureOwner,
              let state = v4ObservedPartyDetail(for: partyID)?.pasture,
              state.campfire?.isSupported == true,
              let agreement = state.campfire?.agreement, agreement.permitsSharing,
              let pending = try? pastureOutbox.commands(owner: owner),
              !pending.contains(where: { $0.partyID == partyID && $0.command == "setCampfireSharing" }) else { return nil }
        return agreement
    }

    func setCampfireSharing(_ enabled: Bool, partyID: UUID) {
        guard let command = campfireSharingCommand(enabled, partyID: partyID) else { return }
        enqueuePasture(command)
    }

    func campfireSharingCommand(_ enabled: Bool, partyID: UUID) -> SharedPastureCommand? {
        guard let state = v4ObservedPartyDetail(for: partyID)?.pasture,
              state.campfire?.isSupported == true else { return nil }
        var command = SharedPastureCommand(command: "setCampfireSharing", partyID: partyID, memberEpochID: state.memberEpochID)
        command.enabled = enabled; command.consentVersion = state.campfire?.buddies?.isSupported == true ? 2 : 1
        command.expectedRevision = state.campfire?.agreement?.revision ?? 0
        return command
    }

    /// Called by admitted/terminal phone runs, never by opening the campfire.
    /// Each target carries the exact consent and membership receipt at capture.
    func publishCampfireSession(_ run: FocusRun, ended: Bool = false) {
        guard restoreCampfireVisibility() else { return }
        reconcileCampfirePrivateVisibility()
        publishGlobalCampfireSession(run, ended: ended)
        let selection = campfireSelection(for: run)
        let explicitlyChanged = campfireDocument.runSelections[run.id] != nil
        guard permitsLocalSocialMutation, mayPublishWhileSharedHabitsFenceIsOpen(),
              let expiresAt = CampfireRules.end(for: run),
              expiresAt > Date(),
              let plan = run.nightWatchPlan,
              CampfireRules.permitsOwner(captured: plan.campfireOwnerID, current: pastureOwner),
              selection.visibility != .off,
              plan.role != .primarySleepBookend || maySharePrimaryRun(run) || explicitlyChanged else { return }
        for party in slumberParties {
            guard selection.partyIDs.contains(party.partyID), selectedCampfirePartyIDs.contains(party.partyID) else { continue }
            guard let agreement = campfireAgreement(partyID: party.partyID),
                  let state = v4ObservedPartyDetail(for: party.partyID)?.pasture else { continue }
            if explicitlyChanged && selection.partyAgreementIDs?[party.partyID] != agreement.id { continue }
            let sharingStart = explicitlyChanged ? selection.partyStartedAt?[party.partyID] ?? run.startedAt : run.startedAt
            guard sharingStart >= agreement.acceptedAt, sharingStart < expiresAt else { continue }
            if state.campfire?.sessions.contains(where: {
                $0.memberID == v4ObservedPartyDetail(for: party.partyID)?.myMemberID
                    && (($0.id == run.id && $0.revision >= (ended ? 2 : 1)) || $0.startedAt > run.startedAt)
            }) == true { continue }
            var command = SharedPastureCommand(command: "publishCampfireSession", partyID: party.partyID,
                                               memberEpochID: state.memberEpochID)
            command.agreementID = agreement.id; command.sourceID = run.id
            command.kind = plan.role == .primarySleepBookend ? .windDown : .phoneAway
            command.activity = plan.role == .additionalQuiet ? plan.campfireActivity : nil
            if agreement.version == 2,
               let intention = plan.campfireIntentions?.first(where: { $0.partyID == party.partyID && $0.agreementID == agreement.id }) {
                command.publicIntention = intention.text
                command.asksForBuddy = intention.asksForBuddy
                command.announceStart = intention.announceStart
                command.checkInAfter = max(expiresAt, min(plan.protectedUntil, expiresAt.addingTimeInterval(6 * 3600)))
            }
            command.startedAt = sharingStart; command.expiresAt = expiresAt
            command.observedAt = ended ? max(sharingStart, run.endedAt ?? Date()) : sharingStart
            command.ended = ended; command.revision = ended ? 2 : 1
            command.idempotencyKey = NightFlockV4Idempotency.command(
                "campfire-\(party.partyID)-\(agreement.id)-\(ended ? 2 : 1)", seed: run.id)
            enqueuePasture(command)
        }
    }
}
