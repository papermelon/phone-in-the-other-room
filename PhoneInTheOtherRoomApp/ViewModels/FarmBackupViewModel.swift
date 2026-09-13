import AuthenticationServices
import Combine
import Foundation

@MainActor
final class FarmBackupViewModel: ObservableObject {
    @Published var message = "Your Farm is saved on this phone. Online backup is off."
    @Published var busy = false
    @Published var signedIn = false
    @Published var appleSignInInProgress = false
    @Published var appleSignInFailure: AppleAccountFailure?
    @Published var lookup: FarmBackupLookup?
    var isFinishingSignOut: Bool { (try? persistence.farmSaveStore.snapshot().credentialsNeedRemoval) == true }
    @Published var accessBlocked = false
    @Published var needsSyncAgreement = false
    @Published var syncConnectionNotice: String?
    @Published var generationNeedsReview = false
    @Published var credentialProfile: AccountCredentialProfile?
    @Published var sync: FarmBackupSync?
    @Published var accountFarmPreview: FarmBackupAccountPreview?
    @Published var accountPresentation: FarmBackupAccountPresentation
    @Published var restoreSuccess: FarmBackupRestoreSuccess?
    lazy var credentials = PasswordAccountViewModel(farm: self)
    var linkingApple = false
    let available: Bool
    var permitsTransport: () -> Bool = { false }
    var prepareAccount: (() async -> Bool)?
    var canRestore: (() -> Bool)?
    var didRestore: (() -> Void)?
    var didSignOut: (() -> Void)?
    var clearAccountContext: (() async -> Bool)?
    var didSignIn: (() -> Void)?
    var didCompleteRestore: ((FarmBackupRestoreSuccess) -> Void)?
    let persistence: PersistenceService
    let account: NightFlockAccountService?
    let service: FarmBackupService?
    private var observer: AnyCancellable?
    var scheduled: Task<Void, Never>?
    var nonce: String?
    var epoch = UUID()
    var operationLineage: UUID?
    var operationEpoch: UUID?
    let connectivity: FarmSyncConnectivityService
    var automaticRetryTask: Task<Void, Never>?
    var automaticRetryAttempts = 0
    var automaticRetryDelay: (Int) -> Duration = { attempt in .seconds(Double(1 << min(attempt, 3))) }

    init(persistence: PersistenceService, account: NightFlockAccountService?, service: FarmBackupService?,
         connectivity: FarmSyncConnectivityService? = nil) {
        self.persistence = persistence
        self.account = account
        self.service = service
        self.connectivity = connectivity ?? FarmSyncConnectivityService()
        available = service != nil && account != nil
        accountPresentation = service != nil && account != nil ? .signedOut : .unavailable
        sync = try? persistence.farmSaveStore.snapshot().backup
        accessBlocked = !persistence.farmSaveStore.hasReadableSave || (try? persistence.farmSaveStore.snapshot().effectiveScope) == .signedOut
        try? applyPendingPresentation()
        observer = NotificationCenter.default.publisher(for: .farmSaveDidCommit, object: persistence.farmSaveStore)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in self?.schedule() }
        self.connectivity.onRecovery = { [weak self] in self?.connectivityRecovered() }
    }

    func refresh() {
        perform {
            if try self.persistence.farmSaveStore.snapshot().credentialsNeedRemoval == true {
                try await self.finishSignOut()
                return
            }
            try self.applyPendingPresentation()
            if self.sync?.accountSyncVersion == 1 || self.sync?.enabled == true {
                try await self.completeAccountConnection(acceptSync: self.sync?.accountSyncVersion != 1 && self.sync?.enabled == true)
            } else {
                try await self.loadAccount()
                self.needsSyncAgreement = self.signedIn
                try await self.uploadIfEnabled()
            }
        }
    }

    func retryPending() {
        perform {
            guard let state = try self.persistence.farmSaveStore.snapshot().backup,
                  let command = state.pending, let service = self.service else {
                self.finishWithoutPendingAction()
                return
            }
            let receipt = try await service.send(command, owner: state.ownerID, authorization: self.transportAuthorization)
            try self.assertTransport()
            if command.action == "delete" {
                guard receipt.status == "deleted" else { throw FarmSaveError.corrupt }
                try self.persistence.farmSaveStore.updateBackup {
                    $0 = FarmBackupSync(ownerID: state.ownerID, generation: receipt.generation)
                }
            } else {
                try self.confirm(receipt, digest: command.payload?.fingerprint(), owner: state.ownerID)
            }
            try await self.loadAccount()
        }
    }

    /// Called only after the player accepts the separately presented disclosure.
    func enableBackup() {
        perform {
            try await self.loadAccount()
            guard let owner = try await self.account?.currentLinkedAccountID(),
                  let remote = self.lookup else { throw FarmSaveError.unavailable }
            try self.assertTransport()
            let local = try self.persistence.farmSaveStore.snapshot()
            guard local.backup?.pending?.action != "delete" else { throw FarmSaveError.unavailable }
            guard local.backup?.ownerID == nil || local.backup?.ownerID == owner else {
                throw NightFlockAccountError.identityChanged
            }
            // Existing remote progress always asks for a branch choice first.
            if remote.head != nil && local.backup?.baseRevision == nil {
                self.message = "An account Farm is available. Choose which Farm to continue before turning on backup."
                self.updateAccountPresentation(remote: remote, sync: self.sync)
                return
            }
            try self.persistence.farmSaveStore.updateBackup { state in
                if state == nil || (state?.generation != remote.generation && remote.head == nil) {
                    state = FarmBackupSync(ownerID: owner, generation: remote.generation)
                }
                guard state?.generation == remote.generation else { throw FarmSaveError.unavailable }
                state?.enabled = true
            }
            try await self.uploadIfEnabled()
        }
    }

    @discardableResult
    func pause() -> Bool {
        epoch = UUID()
        scheduled?.cancel()
        resetAutomaticRetry()
        do {
            try persistence.farmSaveStore.updateBackup { $0?.enabled = false }
            sync = try persistence.farmSaveStore.snapshot().backup
            message = "Online backup is paused. Your saved account copy is kept."
            return true
        } catch { show(error); return false }
    }

    func signOut() {
        perform { try await self.disconnectAccount() }
    }

    func restoreAccountFarm(revisionID: UUID? = nil) {
        restoreSuccess = nil
        perform { try await self.restoreFarm(revisionID: revisionID) }
    }

    func restoreFarm(revisionID: UUID? = nil) async throws {
        guard try self.persistence.farmSaveStore.snapshot().backup?.pending == nil else { throw FarmSaveError.unavailable }
        guard self.canRestore?() == true else {
            self.message = "Finish your current Wind Down or Phone Away before restoring a Farm."
            self.restoreActionPresentation()
            return
        }
        try await self.loadAccount()
        guard let owner = try await self.account?.currentLinkedAccountID(), let service = self.service else {
            throw FarmSaveError.unavailable
        }
        let remote = try await service.lookup(owner: owner, revisionID: revisionID, authorization: self.transportAuthorization)
        guard
              let head = remote.head, let payload = head.payload else { throw FarmSaveError.unavailable }
        try self.assertTransport()
        let local = try self.persistence.farmSaveStore.snapshot()
        guard local.backup?.ownerID == nil || local.backup?.ownerID == owner else {
            throw NightFlockAccountError.identityChanged
        }
        guard self.canRestore?() == true else { throw FarmSaveError.unavailable }
        let backup = FarmBackupSync(ownerID: owner, enabled: false, generation: remote.generation,
            baseRevision: revisionID == nil ? head.id : remote.currentRevisionID,
            confirmedDigest: revisionID == nil ? try payload.fingerprint() : nil, confirmedAt: head.createdAt,
            pendingPresentation: FarmBackupPresentationRestore(pasture: payload.pasture, appearance: payload.appearance))
        try self.persistence.farmSaveStore.restore(payload, backup: backup, expectedGeneration: local.generation)
        // Publication cannot depend on a later cosmetic/metadata write.
        self.operationLineage = try self.persistence.farmSaveStore.snapshot().lineageID
        self.persistence.lastRun = nil
        self.didRestore?()
        let success = FarmBackupRestoreSuccess(revisionID: head.id, restoredAt: Date())
        self.restoreSuccess = success
        self.didCompleteRestore?(success)
        do { try self.applyPendingPresentation() } catch {
            self.message = "Your account Farm is restored. Its appearance still needs to finish saving. Please check again."
            return
        }
        self.message = "Your account Farm is restored."
        if self.sync?.accountSyncVersion == 1 { try await self.uploadIfEnabled() }
    }

    func keepThisFarm() {
        perform { try await self.saveLocalFarm() }
    }

    func saveLocalFarm() async throws {
        guard try self.persistence.farmSaveStore.snapshot().backup?.pending == nil else { throw FarmSaveError.unavailable }
        try await self.loadAccount()
        guard let owner = try await self.account?.currentLinkedAccountID(), let remote = self.lookup,
              let service = self.service else { throw FarmSaveError.unavailable }
        try self.assertTransport()
        let local = try self.persistence.farmSaveStore.snapshot()
        guard local.backup?.ownerID == nil || local.backup?.ownerID == owner else {
            throw NightFlockAccountError.identityChanged
        }
        // Base=nil preserves a divergent local Farm as a conflict before
        // explicit selection. The current account head remains in history.
        let payload = try self.payload(from: local)
        let command = FarmBackupCommand(action: "put", generation: remote.generation,
            operationID: UUID(), payload: payload)
        try self.persistence.farmSaveStore.updateBackup {
            $0 = FarmBackupSync(ownerID: owner, generation: remote.generation, pending: command)
        }
        let receipt = try await service.send(command, owner: owner, authorization: self.transportAuthorization)
        try self.assertTransport()
        guard let revision = receipt.revision else { throw FarmSaveError.corrupt }
        if receipt.status == "saved" {
            try self.confirm(receipt, digest: payload.fingerprint(), owner: owner)
            self.message = "This Farm is saved to your account. Turn on backup to save future changes."
            return
        }
        let selection = FarmBackupCommand(action: "select", generation: remote.generation,
            baseRevision: remote.head?.id, operationID: UUID(), revisionID: revision.id)
        try self.persistence.farmSaveStore.updateBackup { $0?.pending = selection }
        let selected = try await service.send(selection, owner: owner, authorization: self.transportAuthorization)
        try self.confirm(selected, digest: payload.fingerprint(), owner: owner)
        self.message = "This Farm is saved to your account. Turn on backup to save future changes."
    }

    func loadAccount() async throws {
        try assertTransport()
        guard let account, let service else { throw FarmSaveError.unavailable }
        guard let owner = try await account.currentLinkedAccountID() else {
            signedIn = false
            if (try? persistence.farmSaveStore.snapshot().effectiveScope.ownerID) != nil, canRestore?() == true {
                try persistence.farmSaveStore.activate(.signedOut)
                try persistence.farmSaveStore.finishCredentialRemoval()
                accessBlocked = true
                operationLineage = try persistence.farmSaveStore.snapshot().lineageID
                didRestore?()
            }
            accountFarmPreview = nil
            accountPresentation = .signedOut
            message = "Sign in with Apple to find or save your Farm."
            return
        }
        signedIn = true
        credentialProfile = try? await account.credentialProfile()
        try assertTransport()
        let local = try persistence.farmSaveStore.snapshot()
        guard local.backup?.ownerID == nil || local.backup?.ownerID == owner else {
            throw NightFlockAccountError.identityChanged
        }
        let remote = try await service.lookup(owner: owner, authorization: self.transportAuthorization)
        try assertTransport()
        lookup = remote
        accountFarmPreview = remote.head.flatMap { FarmBackupAccountPreview(revision: $0) }
        sync = local.backup
        if let state = local.backup, state.generation != remote.generation {
            try persistence.farmSaveStore.updateBackup {
                $0?.enabled = false
                if $0?.pending?.action != "delete" { $0?.pending = nil }
            }
            sync = try persistence.farmSaveStore.snapshot().backup
            updateAccountPresentation(remote: remote, sync: sync)
            message = "Online backup changed or was deleted. This Farm is still on your phone. Choose whether to save it again."
            return
        }
        if let state = local.backup, state.enabled, state.pending == nil,
           state.baseRevision != remote.head?.id {
            try persistence.farmSaveStore.updateBackup { $0?.enabled = false }
            sync = try persistence.farmSaveStore.snapshot().backup
            updateAccountPresentation(remote: remote, sync: sync)
            message = "Your account Farm changed on another device. Choose which Farm to continue."
            return
        }
        updateAccountPresentation(remote: remote, sync: sync)
    }

    func uploadIfEnabled() async throws {
        try assertTransport()
        let original = try persistence.farmSaveStore.snapshot()
        guard let state = original.backup, state.enabled, state.conflictRevision == nil,
              let account, let service else { return }
        let currentOwner = try await account.currentLinkedAccountID()
        guard currentOwner == state.ownerID else { throw NightFlockAccountError.identityChanged }
        try assertTransport()
        let payload = try self.payload(from: original)
        let digest = try payload.fingerprint()
        if state.pending == nil && state.confirmedDigest == digest {
            sync = try persistence.farmSaveStore.snapshot().backup
            if let lookup {
                updateAccountPresentation(remote: lookup, sync: sync)
            } else {
                accountPresentation = .backupConfirmed(sync?.confirmedAt)
            }
            message = "Your current Farm is backed up."
            return
        }
        let token = epoch
        let command = state.pending ?? FarmBackupCommand(action: "put", generation: state.generation,
            baseRevision: state.baseRevision, operationID: UUID(), payload: payload)
        try persistence.farmSaveStore.updateBackup { $0?.pending = command }
        sync = try persistence.farmSaveStore.snapshot().backup
        accountPresentation = .backupPending
        let receipt: FarmBackupReceipt
        do {
            receipt = try await service.send(command, owner: state.ownerID, authorization: self.transportAuthorization)
        } catch {
            scheduleAutomaticRetry(after: error)
            throw error
        }
        guard epoch == token, try persistence.farmSaveStore.snapshot().lineageID == original.lineageID else { return }
        try confirm(receipt, digest: command.payload?.fingerprint(), owner: state.ownerID)
        resetAutomaticRetry()
        message = receipt.status == "conflict"
            ? "Both Farms have changes. Choose which Farm to continue; both copies have been kept."
            : "Your Farm was backed up."
    }

    private func confirm(_ receipt: FarmBackupReceipt, digest: String?, owner: UUID) throws {
        try assertTransport()
        guard let revision = receipt.revision, ["saved", "conflict"].contains(receipt.status) else {
            throw FarmSaveError.corrupt
        }
        try persistence.farmSaveStore.updateBackup {
            guard $0?.ownerID == owner, $0?.generation == receipt.generation else { throw FarmSaveError.unavailable }
            $0?.pending = nil
            if receipt.status == "conflict" { $0?.conflictRevision = revision.id; $0?.enabled = false }
            else {
                $0?.baseRevision = revision.id
                $0?.confirmedDigest = digest
                $0?.confirmedAt = revision.createdAt
                $0?.conflictRevision = nil
            }
        }
        sync = try persistence.farmSaveStore.snapshot().backup
        if let lookup { updateAccountPresentation(remote: lookup, sync: sync) }
    }

    func perform(_ work: @escaping () async throws -> Void) {
        guard !busy, !appleSignInInProgress else { return }
        operationLineage = try? persistence.farmSaveStore.snapshot().lineageID
        operationEpoch = epoch
        busy = true
        if available { accountPresentation = .checking }
        Task {
            defer {
                busy = false
                sync = try? persistence.farmSaveStore.snapshot().backup
                accessBlocked = !persistence.farmSaveStore.hasReadableSave || (try? persistence.farmSaveStore.snapshot().effectiveScope) == .signedOut
                if hasUnsyncedChanges && accountPresentation != .failed { schedule() }
            }
            do { try await work() } catch { show(error) }
        }
    }

    var transportAuthorization: @MainActor @Sendable () -> Bool {
        let expectedEpoch = epoch
        return { [weak self] in
            guard let self, self.epoch == expectedEpoch else { return false }
            return (try? self.assertTransport()) != nil
        }
    }

    func assertTransport() throws {
        guard permitsTransport() else { throw FarmSaveError.unavailable }
        try assertContext()
    }

    private func assertContext() throws {
        guard operationEpoch == epoch,
              try persistence.farmSaveStore.snapshot().lineageID == operationLineage else {
            throw FarmSaveError.unavailable
        }
    }

    func applyPendingPresentation() throws {
        guard let pending = try persistence.farmSaveStore.snapshot().backup?.pendingPresentation else { return }
        persistence.farmPastureSceneSnapshot = pending.pasture
        if let appearance = pending.appearance {
            var profile = persistence.userProfile
            profile.presentation = appearance
            persistence.userProfile = profile
            persistence.hasExplicitSocialAvatarSelection = true
        }
        try persistence.farmSaveStore.updateBackup { $0?.pendingPresentation = nil }
    }

}
