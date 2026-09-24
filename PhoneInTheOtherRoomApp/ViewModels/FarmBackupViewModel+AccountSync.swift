import AuthenticationServices
import Foundation

@MainActor
extension FarmBackupViewModel {
    func prepareApple(_ request: ASAuthorizationAppleIDRequest) {
        guard !busy, !appleSignInInProgress else { return }
        nonce = nil
        appleSignInFailure = nil
        do {
            let value = try NightFlockAccountService.makeAppleNonce()
            nonce = value.rawValue
            request.nonce = value.requestValue
            request.requestedScopes = []
            // A foreground refresh must not take the operation slot while
            // Apple's system sheet is presenting or returning its credential.
            appleSignInInProgress = true
        } catch {
            linkingApple = false
            appleSignInFailure = AppleAccountFailure(stage: .credential)
        }
    }

    func completeApple(_ result: Result<ASAuthorization, Error>) {
        let requestNonce = nonce
        let wasLinkingApple = linkingApple
        nonce = nil
        linkingApple = false
        appleSignInInProgress = false
        if case .failure(let error) = result {
            let systemError = error as NSError
            if systemError.domain == ASAuthorizationError.errorDomain,
               systemError.code == ASAuthorizationError.canceled.rawValue {
                appleSignInFailure = nil
            } else {
                appleSignInFailure = AppleAccountFailure(stage: .authorization, code: systemError.code)
            }
            return
        }
        guard let requestNonce, !busy,
              case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let data = credential.identityToken, let token = String(data: data, encoding: .utf8),
              !token.isEmpty, let account else {
            appleSignInFailure = AppleAccountFailure(stage: .credential)
            return
        }
        appleSignInFailure = nil
        perform {
            if wasLinkingApple {
                guard self.canRestore?() == true,
                      await self.prepareAccount?() != false else { throw FarmSaveError.unavailable }
                do {
                    try await account.connectApple(identityToken: token, nonce: requestNonce)
                    self.credentialProfile = try await account.credentialProfile()
                } catch {
                    self.appleSignInFailure = AppleAccountFailure(stage: .account)
                    throw error
                }
            } else {
                try await self.completeAppleFarmSignIn(identityToken: token, nonce: requestNonce)
            }
        }
    }

    /// Publish sign-in only after account-owned Farm activation succeeds.
    func completeAppleFarmSignIn(identityToken: String, nonce: String) async throws {
        guard canRestore?() == true, let account else { throw FarmSaveError.unavailable }
        guard await prepareAccount?() != false else { throw FarmSaveError.unavailable }
        do {
            try await account.signInForFarm(identityToken: identityToken, nonce: nonce)
        } catch {
            appleSignInFailure = AppleAccountFailure(stage: .account)
            throw error
        }
        do {
            try await completeAccountConnection(acceptSync: true)
            appleSignInFailure = nil
        } catch {
            appleSignInFailure = AppleAccountFailure(stage: .farm)
            throw error
        }
    }

    func acceptAutomaticSync() {
        guard !busy, !appleSignInInProgress else { return }
        syncConnectionNotice = nil
        perform {
            let previousMessage = self.message
            do {
                try await self.completeAccountConnection(acceptSync: true, resolveChangedGeneration: true)
                if self.needsSyncAgreement {
                    self.syncConnectionNotice = self.message != previousMessage ? self.message
                        : "Your Farm hasn’t connected yet. Try again when you’re online."
                }
            } catch {
                self.show(error)
                self.syncConnectionNotice = self.message
            }
        }
    }

    func signInWithPassword(identifier: String, password: String) {
        perform {
            guard self.canRestore?() == true, let account = self.account,
                  await self.prepareAccount?() != false else { throw FarmSaveError.unavailable }
            try await account.signInWithPassword(identifier: identifier, password: password)
            try await self.completeAccountConnection(acceptSync: true)
        }
    }

    func completeAccountConnection(acceptSync: Bool, resolveChangedGeneration: Bool = false) async throws {
        guard let account, let service else { throw FarmSaveError.unavailable }
        try assertTransport()
        guard let owner = try await account.currentLinkedAccountID() else {
            try await loadAccount()
            return
        }
        try assertTransport()
        authenticatedAccountID = owner
        let original = try persistence.farmSaveStore.snapshot()
        let cached = original.effectiveScope.ownerID == owner ? original.backup
            : try persistence.farmSaveStore.cachedAccount(owner)?.backup
        guard acceptSync || cached?.accountSyncVersion == 1 else {
            needsSyncAgreement = true
            return
        }
        try await service.acceptAccountSync(owner: owner, authorization: transportAuthorization)
        let remote = try await service.lookup(owner: owner, authorization: transportAuthorization)
        try assertTransport()
        // Ordinary cached play can sync during a run. Changing the active
        // lineage or adopting another device's head must wait for settlement.
        let changesOwner = original.effectiveScope.ownerID != owner
        let cachedAccount = changesOwner ? try persistence.farmSaveStore.cachedAccount(owner) : nil
        let candidate = FarmSaveDocument(
            lineageID: cachedAccount?.lineageID ?? original.lineageID,
            generation: original.generation,
            values: cachedAccount?.values ?? (changesOwner ? [:] : original.values),
            backup: cachedAccount?.backup ?? (changesOwner ? nil : original.backup),
            accountScope: .account(owner),
            localValues: cachedAccount?.localValues ?? (changesOwner ? nil : original.localValues)
        )
        let candidateDigest = try? payload(from: candidate).fingerprint()
        let candidateIsClean = candidate.backup?.pending == nil
            && candidate.backup?.confirmedDigest != nil
            && candidateDigest == candidate.backup?.confirmedDigest
        let candidateGenerationMatches = cachedAccount?.backup.map { $0.generation == remote.generation } ?? true
        let candidateCanAdoptRemote = candidateGenerationMatches
            && (candidate.backup == nil && candidate.values.isEmpty || candidateIsClean)

        // A remote restore changes both owner and values.  Keep those changes
        // in one FarmSaveStore transaction so a failed restore cannot publish
        // an empty B Farm while the coordinator still presents A's Farm.
        if changesOwner, let head = remote.head, candidateCanAdoptRemote {
            guard canRestore?() == true, let payload = head.payload else {
                message = "Finish your current session to load the account’s latest Farm."
                return
            }
            let backup = FarmBackupSync(ownerID: owner, enabled: true, generation: remote.generation,
                baseRevision: head.id, confirmedDigest: try payload.fingerprint(), confirmedAt: head.createdAt,
                pendingPresentation: FarmBackupPresentationRestore(pasture: payload.pasture, appearance: payload.appearance),
                accountSyncVersion: 1)
            try persistence.farmSaveStore.transaction {
                try persistence.farmSaveStore.activate(.account(owner))
                try persistence.farmSaveStore.restore(payload, backup: backup, expectedGeneration: original.generation)
            }
            operationLineage = try persistence.farmSaveStore.snapshot().lineageID
            signedIn = true
            needsSyncAgreement = false
            lookup = remote
            accountFarmPreview = FarmBackupAccountPreview(revision: head)
            sync = try persistence.farmSaveStore.snapshot().backup
            accessBlocked = false
            // Publish only after the owner/value commit, before secondary
            // appearance persistence or navigation callbacks can fail.
            didRestore?()
            didSignIn?()
            let success = FarmBackupRestoreSuccess(revisionID: head.id, restoredAt: Date())
            restoreSuccess = success
            didCompleteRestore?(success)
            var presentationNeedsRetry = false
            do {
                try applyPendingPresentation()
            } catch {
                presentationNeedsRetry = true
                message = "Your account Farm is restored. Its appearance still needs to finish saving. Please check again."
            }
            if !presentationNeedsRetry {
                try await uploadIfEnabled()
                if appleSignInFailure?.stage == .farm { appleSignInFailure = nil }
            }
            credentialProfile = try? await account.credentialProfile()
            return
        }

        var publishedOwner = false
        if changesOwner {
            guard canRestore?() == true else { throw FarmSaveError.unavailable }
            // First verified account adoption carries this device's guest Farm
            // only when the account has no remote Farm or local account cache.
            // Switching people, and restoring a remote Farm, archives it.
            let adoptsGuestFarm = original.effectiveScope == .guest && remote.head == nil && cachedAccount == nil
            try persistence.farmSaveStore.activate(.account(owner), preservingGuest: adoptsGuestFarm)
            operationLineage = try persistence.farmSaveStore.snapshot().lineageID
            signedIn = true
            needsSyncAgreement = false
            lookup = remote
            accountFarmPreview = remote.head.flatMap(FarmBackupAccountPreview.init)
            sync = try persistence.farmSaveStore.snapshot().backup
            accessBlocked = false
            didRestore?()
            didSignIn?()
            publishedOwner = true
        }
        signedIn = true
        needsSyncAgreement = false
        lookup = remote
        accountFarmPreview = remote.head.flatMap(FarmBackupAccountPreview.init)
        var local = try persistence.farmSaveStore.snapshot()
        if let state = local.backup, state.generation != remote.generation {
            guard resolveChangedGeneration else {
                try persistence.farmSaveStore.updateBackup { $0?.enabled = false }
                needsSyncAgreement = true
                generationNeedsReview = true
                message = "This account’s Farm changed or was deleted. Review it before continuing."
                return
            }
            try persistence.farmSaveStore.updateBackup {
                $0 = FarmBackupSync(ownerID: owner, generation: remote.generation, accountSyncVersion: 1)
            }
            local = try persistence.farmSaveStore.snapshot()
            generationNeedsReview = false
        }
        if let head = remote.head, local.backup?.baseRevision != head.id {
            let localDigest = try? payload(from: local).fingerprint()
            let clean = local.backup?.pending == nil && local.backup?.confirmedDigest != nil
                && localDigest == local.backup?.confirmedDigest
            if local.backup == nil && local.values.isEmpty || clean {
                guard canRestore?() == true, let payload = head.payload else {
                    message = "Finish your current session to load the account’s latest Farm."
                    return
                }
                let backup = FarmBackupSync(ownerID: owner, enabled: true, generation: remote.generation,
                    baseRevision: head.id, confirmedDigest: try payload.fingerprint(), confirmedAt: head.createdAt,
                    pendingPresentation: FarmBackupPresentationRestore(pasture: payload.pasture, appearance: payload.appearance),
                    accountSyncVersion: 1)
                try persistence.farmSaveStore.restore(payload, backup: backup, expectedGeneration: local.generation)
                operationLineage = payload.lineageID
                didRestore?()
                let success = FarmBackupRestoreSuccess(revisionID: head.id, restoredAt: Date())
                restoreSuccess = success
                didCompleteRestore?(success)
                do {
                    try applyPendingPresentation()
                } catch {
                    message = "Your account Farm is restored. Its appearance still needs to finish saving. Please check again."
                }
            } else {
                // Preserve both offline branches; selection is only exceptional.
                accountPresentation = accountFarmPreview.map(FarmBackupAccountPresentation.remoteFarm) ?? .remoteFarmUnavailable
                message = "Two Farms have changes. Choose which one to continue."
                try persistence.farmSaveStore.updateBackup { state in
                    if state == nil { state = FarmBackupSync(ownerID: owner, generation: remote.generation) }
                    state?.enabled = false
                    state?.accountSyncVersion = 1
                }
                return
            }
        } else {
            try persistence.farmSaveStore.updateBackup { state in
                if state == nil { state = FarmBackupSync(ownerID: owner, generation: remote.generation) }
                state?.enabled = true
                state?.accountSyncVersion = 1
            }
        }
        sync = try persistence.farmSaveStore.snapshot().backup
        accessBlocked = false
        if !publishedOwner {
            didRestore?()
            // The atomic remote-adoption path returns above. All remaining
            // paths have committed their active owner before account routing.
            didSignIn?()
        }
        try await uploadIfEnabled()
        if appleSignInFailure?.stage == .farm { appleSignInFailure = nil }
        // Identity metadata is secondary to publishing the correct Farm.
        credentialProfile = try? await account.credentialProfile()
    }

    func disconnectAccount() async throws {
        guard canRestore?() == true, account != nil else {
            message = "Finish your current session before signing out."
            return
        }
        // Persist inaccessible recovery before removing credentials, including
        // when the network cannot acknowledge the latest local generation.
        try persistence.farmSaveStore.activate(.signedOut)
        epoch = UUID()
        scheduled?.cancel()
        resetAutomaticRetry()
        accessBlocked = true
        signedIn = false
        authenticatedAccountID = nil
        needsSyncAgreement = false
        syncConnectionNotice = nil
        generationNeedsReview = false
        sync = nil
        lookup = nil
        credentialProfile = nil
        credentials.clearForSignOut()
        nonce = nil
        linkingApple = false
        appleSignInInProgress = false
        appleSignInFailure = nil
        accountFarmPreview = nil
        didRestore?()
        didSignOut?()
        try await finishSignOut()
        accountPresentation = .signedOut
        message = "Signed out. Sign in to continue your Farm."
    }

    func finishSignOut() async throws {
        guard permitsTransport(), let account, await clearAccountContext?() != false else { throw FarmSaveError.unavailable }
        try await account.signOutForAccountSwitch()
        try persistence.farmSaveStore.finishCredentialRemoval()
        accountPresentation = .signedOut
    }

    func continueAsGuest() {
        guard !busy, !appleSignInInProgress else { return }
        do {
            try persistence.farmSaveStore.activate(.guest)
            accessBlocked = false
            didRestore?()
            message = "Playing as a guest."
        } catch { show(error) }
    }
}
