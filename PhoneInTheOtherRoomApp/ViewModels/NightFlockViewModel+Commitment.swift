import Foundation

@MainActor
extension NightFlockViewModel {
    var hasAcceptedSharedGoal: Bool {
        guard let snapshot else { return false }
        return snapshot.memberSetups.first(where: { $0.memberID == snapshot.myMemberID })?.goalAccepted == true
    }

    var hasReadySharedSetup: Bool {
        guard let snapshot else { return false }
        return snapshot.memberSetups.first(where: { $0.memberID == snapshot.myMemberID })?.setupReady == true
    }

    var isHost: Bool {
        guard let snapshot else { return false }
        return snapshot.members.first(where: { $0.id == snapshot.myMemberID })?.role == .keeper
    }

    var canStartSharedParty: Bool {
        guard let snapshot, snapshot.challenge.status == .pending, isHost else { return false }
        return snapshot.members.count >= 2
            && snapshot.members.allSatisfy { member in
                snapshot.memberSetups.first(where: { $0.memberID == member.id })?.goalAccepted == true
                    && snapshot.memberSetups.first(where: { $0.memberID == member.id })?.setupReady == true
            }
    }

    var currentSharedGoal: NightFlockSharedGoal? { snapshot?.challenge.sharedGoal }

    func createSharedParty() {
        let draft = commitmentDraft
        performV2(.createParty(
            goal: draft.goal,
            identity: draft.identity,
            timeZoneIdentifier: TimeZone.current.identifier,
            idempotencyKey: NightFlockV2Idempotency.command("create-party")
        ))
    }

    func createReusableInvite() {
        performV2(.createInvite(
            idempotencyKey: NightFlockV2Idempotency.command("create-invite")
        ))
    }

    func previewSharedInvite() {
        let code = joinCode.uppercased().filter { $0.isLetter || $0.isNumber }
        guard !code.isEmpty else { return }
        performV2(.previewInvite(
            shortCode: code,
            idempotencyKey: NightFlockV2Idempotency.command("preview-\(code)")
        ))
    }

    func redeemSharedInvite() {
        let code = joinCode.uppercased().filter { $0.isLetter || $0.isNumber }
        guard !code.isEmpty else { return }
        performV2(.redeemInvite(
            shortCode: code,
            idempotencyKey: NightFlockV2Idempotency.command("redeem-\(code)")
        ))
    }

    func acceptSharedGoal() {
        guard let challengeID = snapshot?.challenge.id else { return }
        performV2(.acceptGoal(
            challengeID: challengeID,
            idempotencyKey: NightFlockV2Idempotency.command("accept-goal")
        ))
    }

    func saveSharedSetup() {
        guard let challengeID = snapshot?.challenge.id else { return }
        performV2(.setLocalSetup(
            challengeID: challengeID,
            setupReady: true,
            shieldingEvidence: commitmentDraft.shieldingEvidence,
            idempotencyKey: NightFlockV2Idempotency.command("setup-ready")
        ))
    }

    func saveSharedRoutineIdeas() {
        guard let challengeID = snapshot?.challenge.id else { return }
        let ids = Array(commitmentDraft.sharedRoutineIDs.prefix(3))
        performV2(.setRoutineIdeas(
            challengeID: challengeID,
            guidanceIDs: ids,
            idempotencyKey: NightFlockV2Idempotency.command("routine-ideas")
        ))
    }

    func startSharedParty() {
        guard canStartSharedParty, let challengeID = snapshot?.challenge.id else { return }
        performV2(.startChallenge(
            challengeID: challengeID,
            idempotencyKey: NightFlockV2Idempotency.command("start-party")
        ))
    }

    func finishNightFlockOrientation() {
        orientationState.finishIntro()
        orientationStore.save(orientationState)
        objectWillChange.send()
    }

    func dismissNightFlockOrientation() {
        orientationState.dismissIntro()
        orientationStore.save(orientationState)
        objectWillChange.send()
    }

    func replayNightFlockOrientation() {
        orientationState.replay()
        orientationStore.save(orientationState)
        objectWillChange.send()
    }

    func markNightFlockTipSeen(_ tip: NightFlockOrientationTip) {
        orientationState.markTipSeen(tip)
        orientationStore.save(orientationState)
        objectWillChange.send()
    }

    private func performV2(_ command: NightFlockV2Command) {
        guard accountState == .linked, let service else { return }
        phase = .loading
        Task {
            do {
                let response = try await service.sendV2(command)
                guard response.accepted else { throw NightFlockServiceError.unsupportedResponse }
                invitePreview = response.invitePreview
                latestInviteCode = response.inviteCode ?? latestInviteCode
                latestInviteID = response.inviteID ?? latestInviteID
                if let responseSnapshot = response.snapshot {
                    snapshot = responseSnapshot
                } else {
                    snapshot = try await service.stateV2()
                }
                phase = .ready
            } catch {
                phase = Self.phase(for: error)
            }
        }
    }

    func enqueueCommitmentProgress(state: NightFlockCheckInState, for context: NightFlockRunShareContext) {
        let evidence = snapshot?.memberSetups.first(where: { $0.memberID == context.memberID })?.shieldingEvidence
            ?? .notRequested
        enqueueNightMetrics(
            for: context,
            metrics: NightFlockLocalNightMetrics(
                windDownMinutes: 0,
                phoneAwayMinutes: 0,
                shieldingEvidence: evidence,
                tuckedAway: true,
                completedSuccessfully: state == .morningQuietCompleted
            )
        )
    }
}
