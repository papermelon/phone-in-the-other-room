import Foundation

@MainActor
extension NightFlockViewModel {
    func saveSharingPreferences() {
        performV3(.setSharingPreferences(
            commitmentDraft.sharing,
            idempotencyKey: NightFlockV3Idempotency.command("sharing-preferences")
        ))
    }

    func enqueueNightMetrics(
        for context: NightFlockRunShareContext,
        metrics: NightFlockLocalNightMetrics
    ) {
        guard let outbox else { return }
        let goal = snapshot?.challenge.sharedGoal
        let status = NightFlockProgressRules.status(
            for: goal,
            tuckedAway: metrics.tuckedAway,
            completedSuccessfully: metrics.completedSuccessfully,
            quietMinutes: metrics.windDownMinutes,
            shielding: metrics.shieldingEvidence
        )
        var stored = context
        if metrics.tuckedAway || NightFlockProgressRules.statusRank(status) >= 3 {
            stored.phoneTuckedQueued = true
        }
        if metrics.completedSuccessfully || NightFlockProgressRules.isQualifying(status) {
            stored.morningQuietCompletedQueued = true
        }
        runContexts[stored.runID] = stored
        let compatibility = NightFlockV2OutboxRecord(
            challengeID: stored.challengeID,
            memberID: stored.memberID,
            challengeDay: stored.challengeDay,
            runID: stored.runID,
            status: status,
            shieldingEvidence: metrics.shieldingEvidence,
            idempotencyKey: NightFlockV2Idempotency.command(
                "progress-\(stored.challengeDay)-\(status.rawValue)",
                seed: stored.runID
            )
        )
        guard let windDown = metrics.roundedWindDownMinutes,
              let phoneAway = metrics.roundedPhoneAwayMinutes else {
            Task {
                await outbox.saveRunContext(stored)
                if NightFlockProgressRules.statusRank(status) > 0 {
                    await outbox.enqueueV2(compatibility)
                }
                await flushOutbox()
            }
            return
        }
        let record = NightFlockV3OutboxRecord(
            challengeID: stored.challengeID,
            memberID: stored.memberID,
            challengeDay: stored.challengeDay,
            runID: stored.runID,
            status: status,
            shieldingEvidence: metrics.shieldingEvidence,
            windDownMinutes: windDown,
            phoneAwayMinutes: phoneAway,
            sleepDurationMinutes: snapshot?.sharing.shareSleepDuration == true
                ? metrics.roundedSleepMinutes
                : nil,
            restfulness: snapshot?.sharing.shareRestfulness == true ? metrics.restfulness : nil,
            idempotencyKey: NightFlockV3Idempotency.command(
                "metrics-\(stored.challengeDay)-\(status.rawValue)",
                seed: stored.runID
            )
        )
        Task {
            await outbox.saveRunContext(stored)
            await outbox.enqueueV3(record)
            if NightFlockProgressRules.statusRank(status) > 0 {
                await outbox.enqueueV2(compatibility)
            }
            await flushOutbox()
        }
    }

    func shareSupplementalMetrics(
        _ metrics: NightFlockLocalNightMetrics,
        runID: UUID?,
        at date: Date
    ) {
        guard let snapshot else { return }
        let existing = runID.flatMap { runContexts[$0] }
            ?? runContexts.values.first { context in
                NightFlockChallengeDayRules.challengeDay(at: date, challenge: snapshot.challenge)
                    == context.challengeDay
            }
        let day = existing?.challengeDay
            ?? NightFlockChallengeDayRules.challengeDay(at: date, challenge: snapshot.challenge)
        guard let day else { return }
        let context = existing ?? NightFlockRunShareContext(
            runID: runID ?? snapshot.challenge.id,
            challengeID: snapshot.challenge.id,
            memberID: snapshot.myMemberID,
            challengeDay: day,
            createdAt: date
        )
        enqueueNightMetrics(for: context, metrics: metrics)
    }

    func applyPendingGrantsIfPossible() {
        guard let grants = snapshot?.pendingGrants, !grants.isEmpty else { return }
        onApplyRewardGrants?(grants)
    }

    func acknowledgeAppliedGrants(_ grantIDs: [UUID]) {
        for grantID in grantIDs {
            performV3(.acknowledgeGrant(
                grantID: grantID,
                idempotencyKey: NightFlockV3Idempotency.command("ack-\(grantID.uuidString.lowercased())")
            ), showLoading: false)
        }
    }

    func performV3(_ command: NightFlockV3Command, showLoading: Bool = true) {
        guard accountState == .linked, let service else { return }
        if showLoading { phase = .loading }
        Task {
            do {
                let response = try await service.sendV3(command)
                guard response.accepted else { throw NightFlockServiceError.unsupportedResponse }
                if let responseSnapshot = response.snapshot {
                    snapshot = responseSnapshot
                    syncDraftFromSnapshot()
                } else {
                    snapshot = try await service.stateV3()
                    syncDraftFromSnapshot()
                }
                phase = .ready
                applyPendingGrantsIfPossible()
            } catch {
                phase = snapshot == nil ? .offline : .ready
            }
        }
    }

    func syncDraftFromSnapshot() {
        guard let snapshot else { return }
        commitmentDraft.sharing = snapshot.sharing
        if let setup = snapshot.memberSetups.first(where: { $0.memberID == snapshot.myMemberID }) {
            commitmentDraft.shieldingEvidence = setup.shieldingEvidence
            commitmentDraft.sharing.shareRoutineIdeas = setup.shareRoutineIdeas
        }
    }
}
