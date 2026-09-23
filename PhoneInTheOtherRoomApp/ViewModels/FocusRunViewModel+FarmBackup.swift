import Foundation

extension FocusRunViewModel {
    func configureFarmBackup() {
        nightFlockViewModel.sharedFarmAccount = farmBackupViewModel
        nightFlockViewModel.didRemoveAccountCredentials = { [weak self] in
            guard let self else { return false }
            do {
                try persistence.farmSaveStore.finishCredentialRemoval()
                farmBackupViewModel.accountPresentation = .signedOut
                farmBackupViewModel.message = "Your account was deleted."
                return true
            } catch { return false }
        }
        farmBackupViewModel.permitsTransport = { [weak self] in
            self?.nightFlockViewModel.permitsFarmAccountTransport == true
        }
        nightFlockViewModel.prepareFarmForAccountDeletion = { [weak self] in
            guard let self, self.farmBackupViewModel.canRestore?() == true else { return false }
            return self.farmBackupViewModel.pause()
        }
        farmBackupViewModel.clearAccountContext = { [weak self] in
            await self?.nightFlockViewModel.clearSignedOutAccountContext() == true
        }
        nightFlockViewModel.removeDeletedAccountFarm = { [weak self] in
            guard let self else { return false }
            do {
                try persistence.farmSaveStore.deleteActiveAccount()
                try persistence.farmSaveStore.purgeObsoleteAccountFiles()
                persistence.purgeLegacyFarmDefaultsAfterAccountDeletion()
                farmBackupViewModel.accessBlocked = true
                farmBackupViewModel.signedIn = false
                farmBackupViewModel.authenticatedAccountID = nil
                farmBackupViewModel.credentialProfile = nil
                farmBackupViewModel.credentials.clearForSignOut()
                farmBackupViewModel.didRestore?()
                return true
            } catch { return false }
        }
        farmBackupViewModel.didSignOut = { [weak self] in
            guard let self else { return }
            reloadWindDownHabitState()
            nightFlockViewModel.farmAccountDidSignOut()
            reconcileAutomaticWindDownIfNeeded()
            persistence.automaticWindDownSchedule = nil
        }
        farmBackupViewModel.didSignIn = { [weak self] in self?.nightFlockViewModel.farmAccountDidSignIn() }
        farmBackupViewModel.prepareAccount = { [weak self] in
            guard let self else { return false }
            return await nightFlockViewModel.prepareForFarmAccountSignIn()
        }
        farmBackupViewModel.canRestore = { [weak self] in
            guard let self else { return false }
            // A completed receipt must be dismissed first. Pending morning
            // delivery/authorization belongs to this device and cannot move.
            let journal = persistence.windDownMorningSettlementJournal
            return coordinator.run == nil
                && journal.pendingAuthorizedTerminalMorningDecisions.isEmpty
                && !journal.morningOccurrences.contains { $0.outcome == .active || $0.outcome == .scheduled }
                && !journal.windDownBenefits.contains { !$0.isDelivered }
        }
        farmBackupViewModel.didRestore = { [weak self] in
            guard let self else { return }
            let previousIdentity = habitLocalIdentity
            reloadWindDownHabitState()
            // Ordinary same-account synchronization also invokes didRestore.
            // Keep its due occurrence until admission; replacing it here would
            // silently move tonight's start to tomorrow during foreground sync.
            if previousIdentity == nil || previousIdentity != habitLocalIdentity {
                persistence.automaticWindDownSchedule = nil
                quietTimeShielding.cancelAutomaticSchedule()
            }
            coordinator.farmState = persistence.farmState
            coordinator.sheepSearchState = persistence.sheepSearchState
            coordinator.progress = persistence.progress
            coordinator.rewards = persistence.rewards
            coordinator.latestReward = nil
            coordinator.latestSheepSearchOutcome = nil
            impactSharingPreferences = persistence.impactSharingPreferences
            reconcileAutomaticWindDownIfNeeded()
            WatchConnectivityManager.shared.send(WatchMessage(type: .focusRunStateUpdate, run: nil))
            objectWillChange.send()
        }
        farmBackupViewModel.didCompleteRestore = { [weak self] _ in
            guard let self,
                  persistence.onboardingVersion < CountingSheepOnboarding.currentVersion else { return }
            var draft = persistence.onboardingDraft ?? OnboardingDraft.defaults()
            draft.beginReturningUserDeviceSetup()
            persistence.onboardingDraft = draft
            objectWillChange.send()
        }
    }
}
