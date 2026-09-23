import Foundation

struct FarmBackupAccountPreview: Equatable {
    let revisionID: UUID
    let savedAt: Date
    let activeSheepCount: Int
    let woolBalance: Int
    let hasPasture: Bool
    let hasAppearance: Bool

    init?(revision: FarmBackupRevision) {
        guard let payload = revision.payload else { return nil }
        revisionID = revision.id
        savedAt = revision.createdAt
        activeSheepCount = payload.farm.activeSheep.count
        woolBalance = payload.farm.woolBalance
        hasPasture = payload.pasture != nil
        hasAppearance = payload.appearance != nil
    }

    init(revisionID: UUID, savedAt: Date, activeSheepCount: Int, woolBalance: Int,
         hasPasture: Bool = false, hasAppearance: Bool = false) {
        self.revisionID = revisionID
        self.savedAt = savedAt
        self.activeSheepCount = activeSheepCount
        self.woolBalance = woolBalance
        self.hasPasture = hasPasture
        self.hasAppearance = hasAppearance
    }
}

enum FarmBackupAccountPresentation: Equatable {
    case unavailable
    case signedOut
    case checking
    case failed
    case noRemoteSave
    case remoteFarm(FarmBackupAccountPreview)
    case remoteFarmUnavailable
    case backupPending
    case backupConfirmed(Date?)
}

/// A committed local Farm restore. This is deliberately separate from display
/// messages so callers never route a person based on copy meant for humans.
struct FarmBackupRestoreSuccess: Equatable {
    let revisionID: UUID
    let restoredAt: Date
}

@MainActor
extension FarmBackupViewModel {
    func payload(from document: FarmSaveDocument) throws -> FarmBackupPayload {
        let decoder = JSONDecoder()
        let pasture = try document.localValues?["ollie.farm.pastureScene"].map {
            try decoder.decode(PastureSceneSnapshot.self, from: $0)
        }
        let profile = try document.localValues?["ollie.userProfile"].map {
            try decoder.decode(CountingSheepUserProfile.self, from: $0)
        }
        return try FarmBackupPayload(document: document, pasture: pasture, appearance: profile?.presentation)
    }

    var hasUnsyncedChanges: Bool {
        guard let document = try? persistence.farmSaveStore.snapshot(),
              let sync = document.backup, sync.enabled else { return false }
        return sync.pending != nil || (try? payload(from: document).fingerprint()) != sync.confirmedDigest
    }

    func schedule() {
        // A fresh local mutation receives a new bounded retry budget. Upload
        // staging runs while busy, so it cannot cancel its own recovery retry.
        if !busy { resetAutomaticRetry() }
        scheduled?.cancel()
        scheduled = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self, !self.busy else { return }
            self.sync = try? self.persistence.farmSaveStore.snapshot().backup
            guard self.hasUnsyncedChanges else { return }
            self.perform { try await self.uploadIfEnabled() }
        }
    }

    func show(_ error: Error) {
        if available { accountPresentation = .failed }
        if signedIn && sync?.accountSyncVersion != 1 { needsSyncAgreement = true }
        if error is FarmBackupRemoteError {
            if operationEpoch == epoch, (try? persistence.farmSaveStore.snapshot().lineageID) == operationLineage {
                try? persistence.farmSaveStore.updateBackup { $0?.pending = nil; $0?.enabled = false }
            }
            message = "The account Farm changed. Review the latest Farm before continuing."
            return
        }
        if error as? FarmSaveError == .unsupportedSchema {
            message = "Update Counting Sheep to open this account Farm. Your current Farm has been kept."
        } else if error is NightFlockAccountError {
            authenticatedAccountID = nil
            message = "Sign in again to reconnect your account."
        } else {
            message = hasAuthenticatedAccount && !signedIn
                ? "Your account is connected, but your Farm couldn’t open. Please try again in a moment."
                : "Your Farm couldn’t sync right now. Your changes have been kept on this phone."
        }
    }

    func updateAccountPresentation(remote: FarmBackupLookup, sync: FarmBackupSync?) {
        if sync?.pending != nil { accountPresentation = .backupPending; return }
        if sync?.enabled == true, sync?.confirmedAt != nil, !hasUnsyncedChanges {
            accountPresentation = .backupConfirmed(sync?.confirmedAt)
            return
        }
        if sync?.enabled == true, hasUnsyncedChanges {
            accountPresentation = .backupPending
            return
        }
        guard let head = remote.head else {
            accountPresentation = .noRemoteSave
            message = "This account has no saved Farm yet. Confirm automatic sync to connect your Farm."
            return
        }
        guard let preview = FarmBackupAccountPreview(revision: head) else {
            accountPresentation = .remoteFarmUnavailable
            message = "An account Farm was found, but its preview could not be loaded. Your Farm is still on this phone."
            return
        }
        accountPresentation = .remoteFarm(preview)
        if sync?.enabled != true { message = "Your account has a Farm save. Backup on this phone is off." }
    }

    func finishWithoutPendingAction() {
        if let lookup {
            updateAccountPresentation(remote: lookup, sync: sync)
        } else {
            accountPresentation = signedIn ? .failed : .signedOut
            message = signedIn
                ? "There is no unfinished backup action to retry. Check the account save again."
                : "Sign in with Apple to find or save your Farm."
        }
    }

    func restoreActionPresentation() {
        if let lookup { updateAccountPresentation(remote: lookup, sync: sync) }
        else { accountPresentation = signedIn ? .failed : .signedOut }
    }
}
