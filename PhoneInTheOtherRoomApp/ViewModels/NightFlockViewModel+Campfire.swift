import Foundation

extension NightFlockViewModel {
    var campfireOwnerForNewRun: UUID? {
        accountState == .linked && permitsFarmOwnerScopedSocialEffects ? pastureOwner : nil
    }

    var hasCampfireSharing: Bool {
        slumberParties.contains { campfireAgreement(partyID: $0.partyID) != nil }
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
        guard let state = v4ObservedPartyDetail(for: partyID)?.pasture,
              state.campfire?.isSupported == true else { return }
        var command = SharedPastureCommand(command: "setCampfireSharing", partyID: partyID, memberEpochID: state.memberEpochID)
        command.enabled = enabled; command.consentVersion = 1
        command.expectedRevision = state.campfire?.agreement?.revision ?? 0
        enqueuePasture(command)
    }

    /// Called by admitted/terminal phone runs, never by opening the campfire.
    /// Each target carries the exact consent and membership receipt at capture.
    func publishCampfireSession(_ run: FocusRun, ended: Bool = false) {
        guard permitsLocalSocialMutation, mayPublishWhileSharedHabitsFenceIsOpen(),
              let expiresAt = CampfireRules.end(for: run),
              expiresAt > Date(),
              let plan = run.nightWatchPlan,
              CampfireRules.permitsOwner(captured: plan.campfireOwnerID, current: pastureOwner),
              plan.role != .primarySleepBookend || maySharePrimaryRun(run) else { return }
        for party in slumberParties {
            guard let agreement = campfireAgreement(partyID: party.partyID),
                  run.startedAt >= agreement.acceptedAt,
                  let state = v4ObservedPartyDetail(for: party.partyID)?.pasture else { continue }
            if state.campfire?.sessions.contains(where: {
                $0.memberID == v4ObservedPartyDetail(for: party.partyID)?.myMemberID
                    && (($0.id == run.id && $0.revision >= (ended ? 2 : 1)) || $0.startedAt > run.startedAt)
            }) == true { continue }
            var command = SharedPastureCommand(command: "publishCampfireSession", partyID: party.partyID,
                                               memberEpochID: state.memberEpochID)
            command.agreementID = agreement.id; command.sourceID = run.id
            command.kind = plan.role == .primarySleepBookend ? .windDown : .phoneAway
            command.activity = plan.role == .additionalQuiet ? plan.campfireActivity : nil
            command.startedAt = run.startedAt; command.expiresAt = expiresAt
            command.observedAt = ended ? run.endedAt ?? Date() : run.startedAt
            command.ended = ended; command.revision = ended ? 2 : 1
            command.idempotencyKey = NightFlockV4Idempotency.command(
                "campfire-\(party.partyID)-\(agreement.id)-\(ended ? 2 : 1)", seed: run.id)
            enqueuePasture(command)
        }
    }
}
