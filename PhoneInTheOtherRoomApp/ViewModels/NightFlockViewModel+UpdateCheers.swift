import Foundation

@MainActor
extension NightFlockViewModel {
    func stageUpdateCheerIfApplicable(key: NightFlockV4CheerCommandKey) -> Bool {
        let activityID: UUID
        let membershipStream: Bool
        switch key.target {
        case let .activity(id): activityID = id; membershipStream = false
        case let .membershipActivity(id): activityID = id; membershipStream = true
        default: return false
        }
        guard let party = v4ObservedPartyDetail(for: key.partyID),
              let me = party.memberships.first(where: { $0.memberID == party.myMemberID }),
              let recipient = party.memberships.first(where: { member in
                  member.memberID != me.memberID && SlumberPartySharedFarmRules.updates(for: member.memberID, in: party).contains { $0.activityID == activityID }
              }), accountState == .linked, permitsNightFlockNetwork, let outbox else {
            v4CheerSendStates[key] = .failed
            return true
        }
        let record = SlumberPartyQueuedUpdateCheer(partyID: key.partyID, activityID: activityID,
            membershipStream: membershipStream, senderMemberID: me.memberID, senderJoinedAt: me.joinedAt,
            recipientMemberID: recipient.memberID, recipientJoinedAt: recipient.joinedAt,
            cheer: key.cheer, createdAt: Date())
        let generation = localSocialGeneration
        v4CheerSendStates[key] = .pending
        Task {
            let saved = await outbox.enqueueUpdateCheer(record, epoch: generation)
            guard generation == localSocialGeneration, permitsNightFlockNetwork else { return }
            guard saved else { v4CheerSendStates[key] = .failed; return }
            sendQueuedUpdateCheer(record, key: key, generation: generation)
        }
        return true
    }

    private func sendQueuedUpdateCheer(_ record: SlumberPartyQueuedUpdateCheer, key: NightFlockV4CheerCommandKey, generation: UInt64) {
        guard let party = v4ObservedPartyDetail(for: record.partyID), record.isEligible(in: party, now: Date()),
              accountState == .linked, permitsNightFlockNetwork, service != nil else {
            v4CheerSendStates[key] = .failed
            return
        }
        performV4(record.command, showLoading: false) { [weak self] result in
            guard let self, generation == self.localSocialGeneration else { return }
            switch result {
            case .success:
                self.v4CheerSendStates[key] = .sent
                Task { await self.outbox?.removeUpdateCheer(record.identity, epoch: generation) }
            case .failure:
                self.v4CheerSendStates[key] = .failed
            }
        }
    }

    func recoverUpdateCheers(in party: NightFlockV4PartyDetail) {
        guard let outbox else { return }
        let generation = localSocialGeneration
        Task {
            let records = await outbox.updateCheers()
            guard generation == localSocialGeneration, permitsNightFlockNetwork else { return }
            for record in records where record.partyID == party.summary.partyID {
                guard record.isEligible(in: party, now: Date()), !isSharedHabitsPartySuppressed(record.partyID) else {
                    await outbox.removeUpdateCheer(record.identity, epoch: generation)
                    continue
                }
                let key = NightFlockV4CheerCommandKey(partyID: record.partyID,
                    target: record.membershipStream ? .membershipActivity(record.activityID) : .activity(record.activityID), cheer: record.cheer)
                let summaries = record.membershipStream ? party.sharedCheers : party.cheers
                if summaries.contains(where: { $0.activityID == record.activityID && $0.cheer == record.cheer && $0.sentByMe }) {
                    v4CheerSendStates[key] = .sent
                    await outbox.removeUpdateCheer(record.identity, epoch: generation)
                } else if v4CheerSendStates[key] == nil {
                    v4CheerSendStates[key] = .pending
                    sendQueuedUpdateCheer(record, key: key, generation: generation)
                }
            }
        }
    }

    /// This is app receipt evidence, never an assertion of human attention.
    func acknowledgeUpdateCheers(partyID: UUID, activityID: UUID) {
        guard let party = v4ObservedPartyDetail(for: partyID), party.updateCheerReceiptVersion == 1, accountState == .linked, permitsNightFlockNetwork, service != nil else { return }
        for receipt in party.updateCheerReceipts where receipt.activityID == activityID
            && receipt.recipientMemberID == party.myMemberID && receipt.receivedByAppAt == nil {
            guard updateCheerAcknowledgements[receipt.id] != .pending, updateCheerAcknowledgements[receipt.id] != .sent else { continue }
            updateCheerAcknowledgements[receipt.id] = .pending
            performV4(.acknowledgeUpdateCheer(partyID: partyID, reactionID: receipt.id,
                idempotencyKey: NightFlockV4Idempotency.command("app-received-cheer", seed: receipt.id)), showLoading: false) { [weak self] result in
                switch result {
                case .success: self?.updateCheerAcknowledgements[receipt.id] = .sent
                case .failure: self?.updateCheerAcknowledgements[receipt.id] = .failed
                }
            }
        }
    }
}
