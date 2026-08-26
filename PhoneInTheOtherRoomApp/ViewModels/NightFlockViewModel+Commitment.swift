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
        beginInviteMutation(replacing: nil)
    }

    func finishCreatingReusableInvite() {
        beginInviteMutation(replacing: nil)
    }

    func replaceReusableInvite() {
        guard let expected = snapshot?.activeInvite?.id else { return }
        beginInviteMutation(replacing: expected)
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
        guard accountState == .linked, permitsNightFlockNetwork, let service else { return }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        phase = .loading
        pendingNightFlockRecovery = nil
        Task {
            do {
                guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                let response = try await service.sendV2(command)
                guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                guard response.accepted else { throw NightFlockServiceError.unsupportedResponse }
                if let responseSnapshot = response.snapshot {
                    snapshot = responseSnapshot
                } else {
                    guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                    let reconciledSnapshot = try await service.stateV2()
                    guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                    snapshot = reconciledSnapshot
                }
                let identityValidated = await reconcileInviteCredential(authoritativeSnapshot: snapshot)
                guard permitsNightFlockNetwork,
                      isCurrentTransportTask(generation: generation, epoch: transportEpoch)
                else { return }
                invitePreview = response.invitePreview
                if NightFlockInviteUnresolvedLookupPolicy.permitsLegacyResponsePresentation(
                    identityValidated: identityValidated
                ) {
                    latestInviteCode = response.inviteCode ?? latestInviteCode
                    latestInviteID = response.inviteID ?? latestInviteID
                }
                phase = .ready
            } catch let error as NightFlockRemoteError where error.shouldReconcileMembership && command.requiresMembershipReconciliation {
                guard permitsNightFlockNetwork, isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                await reconcileMembershipRecovery(requestID: error.requestID)
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                presentNightFlockError(error, lane: .directCommand(schema: 2))
            }
        }
    }

    @discardableResult
    func reconcileInviteCredential(authoritativeSnapshot: NightFlockSnapshot?) async -> Bool {
        guard let inviteCredentialService else { return false }
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        let capturedLinkedAccountID = linkedAccountID
        let authoritativeToken = NightFlockInviteReconciliationSnapshotToken(snapshot: authoritativeSnapshot)
        guard permitsNightFlockNetwork,
              accountState == .linked,
              authoritativeToken == NightFlockInviteReconciliationSnapshotToken(snapshot: snapshot),
              authoritativeToken.keeperAuthorized
        else { return false }
        @MainActor func stillOwnsContinuation() -> Bool {
            NightFlockInviteReconciliationAuthorityPolicy.ownsContinuation(
                capturedGeneration: generation,
                capturedTransportEpoch: transportEpoch,
                currentGeneration: localSocialGeneration,
                currentTransportEpoch: transportRecoveryEpoch,
                transportPermitted: permitsNightFlockNetwork,
                accountLinked: accountState == .linked,
                capturedLinkedAccountID: capturedLinkedAccountID,
                currentLinkedAccountID: linkedAccountID,
                capturedSnapshot: authoritativeToken,
                currentSnapshot: NightFlockInviteReconciliationSnapshotToken(snapshot: snapshot)
            )
        }
        do {
            let returnedAccountID = try await accountService?.currentLinkedAccountID()
            @MainActor func stillOwnsReconciliation() -> Bool {
                NightFlockInviteReconciliationAuthorityPolicy.owns(
                    capturedGeneration: generation,
                    capturedTransportEpoch: transportEpoch,
                    currentGeneration: localSocialGeneration,
                    currentTransportEpoch: transportRecoveryEpoch,
                    transportPermitted: permitsNightFlockNetwork,
                    accountLinked: accountState == .linked,
                    capturedLinkedAccountID: capturedLinkedAccountID,
                    currentLinkedAccountID: linkedAccountID,
                    returnedLinkedAccountID: returnedAccountID,
                    capturedSnapshot: authoritativeToken,
                    currentSnapshot: NightFlockInviteReconciliationSnapshotToken(snapshot: snapshot)
                )
            }
            guard let returnedAccountID else {
                if NightFlockInviteUnresolvedLookupPolicy.action(
                    continuationOwned: stillOwnsContinuation()
                ) == .hidePlaintextPreservingCredential {
                    hideInvitePlaintextPresentation()
                }
                return false
            }
            guard stillOwnsReconciliation() else { return false }
            let storedCredential = try inviteCredentialService.load()
            guard stillOwnsReconciliation() else { return false }
            if inviteCredential == nil { inviteCredential = storedCredential }
            if authoritativeSnapshot == nil,
               inviteCredential?.boundAccountID == returnedAccountID {
                guard stillOwnsReconciliation() else { return false }
                try inviteCredentialService.clear()
                guard stillOwnsReconciliation() else { return false }
                inviteCredential = nil
            }
            if var credential = inviteCredential,
               credential.state == .pending,
               credential.boundAccountID == returnedAccountID,
               credential.flockID == authoritativeSnapshot?.flockID,
               credential.inviteID == authoritativeSnapshot?.activeInvite?.id {
                credential.state = .confirmed
                guard stillOwnsReconciliation() else { return false }
                try inviteCredentialService.save(credential)
                guard stillOwnsReconciliation() else { return false }
                inviteCredential = credential
            }
            if let credential = inviteCredential,
               NightFlockInviteRecoveryPolicy.shouldClear(
                credential: credential,
                snapshot: authoritativeSnapshot,
                accountID: returnedAccountID
               ) {
                guard stillOwnsReconciliation() else { return false }
                try inviteCredentialService.clear()
                guard stillOwnsReconciliation() else { return false }
                inviteCredential = nil
            }
            guard stillOwnsReconciliation() else { return false }
            linkedAccountID = returnedAccountID
            guard let authoritativeSnapshot else {
                inviteRecoveryPresentation = .hidden
                latestInviteCode = nil
                latestInviteID = nil
                return true
            }
            inviteRecoveryPresentation = NightFlockInviteRecoveryPolicy.presentation(
                credential: inviteCredential,
                activeInvite: authoritativeSnapshot.activeInvite,
                accountID: returnedAccountID,
                flockID: authoritativeSnapshot.flockID,
                challengeStatus: authoritativeSnapshot.challenge.status
            )
            if case let .code(code) = inviteRecoveryPresentation {
                latestInviteCode = code
                latestInviteID = authoritativeSnapshot.activeInvite?.id
            } else {
                latestInviteCode = nil
                latestInviteID = authoritativeSnapshot.activeInvite?.id
            }
            return true
        } catch {
            let continuationOwned = stillOwnsContinuation()
            guard NightFlockInviteUnresolvedLookupPolicy.action(
                continuationOwned: continuationOwned
            ) == .hidePlaintextPreservingCredential
            else { return false }
            hideInvitePlaintextPresentation()
            return false
        }
    }

    private func beginInviteMutation(replacing expectedInviteID: UUID?) {
        guard !inviteMutationInFlight, accountState == .linked, permitsNightFlockNetwork,
              let service, let accountService, let inviteCredentialService,
              let flockID = snapshot?.flockID, snapshot?.challenge.status == .pending, isHost
        else { return }
        inviteMutationInFlight = true
        phase = .loading
        let generation = localSocialGeneration
        let transportEpoch = transportRecoveryEpoch
        Task {
            defer { inviteMutationInFlight = false }
            @MainActor func stillOwnsMutation() -> Bool {
                let currentSnapshot = snapshot
                let keeperAuthorized = currentSnapshot.flatMap { current in
                    current.members.first(where: { $0.id == current.myMemberID })?.role
                } == .keeper
                return NightFlockInviteMutationOwnershipPolicy.owns(
                    capturedGeneration: generation,
                    capturedTransportEpoch: transportEpoch,
                    currentGeneration: localSocialGeneration,
                    currentTransportEpoch: transportRecoveryEpoch,
                    transportPermitted: permitsNightFlockNetwork,
                    accountLinked: accountState == .linked,
                    keeperAuthorized: keeperAuthorized,
                    capturedFlockID: flockID,
                    currentFlockID: currentSnapshot?.flockID,
                    challengePending: currentSnapshot?.challenge.status == .pending,
                    capturedExpectedInviteID: expectedInviteID,
                    currentActiveInviteID: currentSnapshot?.activeInvite?.id
                )
            }
            do {
                guard let accountID = try await accountService.currentLinkedAccountID() else {
                    throw NightFlockServiceError.unsupportedResponse
                }
                guard stillOwnsMutation() else { return }
                var credential: NightFlockInviteCredential
                if expectedInviteID == nil,
                   let existing = try inviteCredentialService.load(),
                   existing.state == .pending,
                   existing.boundAccountID == accountID,
                   existing.flockID == flockID {
                    credential = existing
                } else {
                    credential = NightFlockInviteCode.makeCredential(accountID: accountID, flockID: flockID)
                    guard stillOwnsMutation() else { return }
                    try inviteCredentialService.save(credential)
                }
                guard stillOwnsMutation() else { return }
                inviteCredential = credential
                let command: NightFlockV2Command
                if let expectedInviteID {
                    command = .replaceInvite(
                        expectedInviteID: expectedInviteID,
                        inviteID: credential.inviteID,
                        inviteDigest: credential.inviteDigest,
                        idempotencyKey: credential.idempotencyKey
                    )
                } else {
                    command = .createInvite(
                        inviteID: credential.inviteID,
                        inviteDigest: credential.inviteDigest,
                        idempotencyKey: credential.idempotencyKey
                    )
                }
                guard stillOwnsMutation() else { return }
                let response = try await service.sendV2(command)
                guard response.accepted, stillOwnsMutation()
                else { throw NightFlockServiceError.unsupportedResponse }
                let authoritative: NightFlockSnapshot?
                if let responseSnapshot = response.snapshot {
                    authoritative = responseSnapshot
                } else {
                    authoritative = try await service.stateV2()
                }
                guard stillOwnsMutation() else { return }
                if authoritative?.activeInvite?.id == credential.inviteID {
                    credential.state = .confirmed
                    guard stillOwnsMutation() else { return }
                    try inviteCredentialService.save(credential)
                    guard stillOwnsMutation() else { return }
                    inviteCredential = credential
                }
                guard stillOwnsMutation() else { return }
                snapshot = authoritative
                linkedAccountID = accountID
                if let authoritative {
                    inviteRecoveryPresentation = NightFlockInviteRecoveryPolicy.presentation(
                        credential: inviteCredential,
                        activeInvite: authoritative.activeInvite,
                        accountID: accountID,
                        flockID: authoritative.flockID,
                        challengeStatus: authoritative.challenge.status
                    )
                    if case let .code(code) = inviteRecoveryPresentation {
                        latestInviteCode = code
                        latestInviteID = authoritative.activeInvite?.id
                    } else {
                        latestInviteCode = nil
                        latestInviteID = authoritative.activeInvite?.id
                    }
                }
                phase = .ready
            } catch {
                guard isCurrentTransportTask(generation: generation, epoch: transportEpoch) else { return }
                if Self.remoteError(from: error)?.code == .unauthorized {
                    linkedAccountID = nil
                    inviteRecoveryPresentation = .hidden
                    latestInviteCode = nil
                }
                presentNightFlockError(error, lane: .directCommand(schema: 2))
                if Self.remoteError(from: error)?.code != .unauthorized {
                    _ = await refreshState(showLoading: false)
                }
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

private extension NightFlockV2Command {
    var requiresMembershipReconciliation: Bool {
        switch self {
        case .createParty, .redeemInvite:
            return true
        default:
            return false
        }
    }
}
