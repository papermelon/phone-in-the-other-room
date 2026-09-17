import Foundation

@MainActor
extension FarmBackupViewModel {
    func scheduleAutomaticRetry(after error: Error? = nil, immediate: Bool = false) {
        guard automaticRetryIsAllowed(for: error), automaticRetryAttempts < 3 else { return }
        automaticRetryTask?.cancel()
        if immediate { automaticRetryAttempts = 0 }
        let attempt = immediate ? 0 : automaticRetryAttempts + 1
        if !immediate { automaticRetryAttempts = attempt }
        let delay = immediate ? Duration.zero : automaticRetryDelay(attempt)
        let expectedEpoch = epoch
        let expectedLineage = try? persistence.farmSaveStore.snapshot().lineageID
        automaticRetryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self,
                  self.epoch == expectedEpoch,
                  !self.busy,
                  !self.isFinishingSignOut,
                  (try? self.persistence.farmSaveStore.snapshot().lineageID) == expectedLineage,
                  self.hasUnsyncedChanges,
                  self.permitsTransport() else { return }
            self.perform { try await self.uploadIfEnabled() }
        }
    }

    func resetAutomaticRetry() {
        automaticRetryAttempts = 0
        automaticRetryTask?.cancel()
        automaticRetryTask = nil
    }

    func connectivityRecovered() {
        guard hasUnsyncedChanges else { return }
        resetAutomaticRetry()
        scheduleAutomaticRetry(immediate: true)
    }

    func automaticRetryIsAllowed(for error: Error?) -> Bool {
        guard !isFinishingSignOut,
              permitsTransport(),
              let state = try? persistence.farmSaveStore.snapshot().backup,
              state.enabled,
              state.conflictRevision == nil,
              state.pending?.action != "delete" else { return false }
        guard let error else { return true }
        if error is NightFlockAccountError || error is AccountCredentialError || error is FarmBackupRemoteError { return false }
        switch error as? FarmSaveError {
        case .corrupt?, .unsupportedSchema?, .unavailable?, .invalidComponent?: return false
        default: return true
        }
    }
}
