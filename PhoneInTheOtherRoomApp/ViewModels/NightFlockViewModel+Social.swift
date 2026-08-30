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
        guard permitsLocalSocialMutation, let outbox else { return }
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
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
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
                guard isCurrentLocalSocialGeneration(generation) else { return }
                await outbox.saveRunContext(stored, epoch: generation)
                guard isCurrentLocalSocialGeneration(generation) else { return }
                if NightFlockProgressRules.statusRank(status) > 0 {
                    await outbox.enqueueV2(compatibility, epoch: generation)
                    guard isCurrentLocalSocialGeneration(generation) else { return }
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
            guard isCurrentLocalSocialGeneration(generation) else { return }
            await outbox.saveRunContext(stored, epoch: generation)
            guard isCurrentLocalSocialGeneration(generation) else { return }
            await outbox.enqueueV3(record, epoch: generation)
            guard isCurrentLocalSocialGeneration(generation) else { return }
            if NightFlockProgressRules.statusRank(status) > 0 {
                await outbox.enqueueV2(compatibility, epoch: generation)
                guard isCurrentLocalSocialGeneration(generation) else { return }
            }
            await flushOutbox()
        }
    }

    func shareSupplementalMetrics(
        _ metrics: NightFlockLocalNightMetrics,
        runID: UUID?,
        at date: Date
    ) {
        if let runID, !maySharePrimaryRun(runID: runID, startedAt: date) { return }
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
        guard accountState == .linked, permitsNightFlockNetwork, let service else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        if showLoading { phase = .loading }
        Task {
            do {
                guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                let response = try await service.sendV3(command)
                guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                guard response.accepted else { throw NightFlockServiceError.unsupportedResponse }
                if let responseSnapshot = response.snapshot {
                    snapshot = responseSnapshot
                    syncDraftFromSnapshot()
                } else {
                    guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                    let reconciledSnapshot = try await service.stateV3()
                    guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                    snapshot = reconciledSnapshot
                    syncDraftFromSnapshot()
                }
                guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                phase = .ready
                applyPendingGrantsIfPossible()
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                presentNightFlockError(error, lane: .directCommand(schema: 3))
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
