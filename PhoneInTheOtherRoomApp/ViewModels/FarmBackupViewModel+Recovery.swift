import Foundation

@MainActor
extension FarmBackupViewModel {
    func deleteBackup() {
        perform {
            guard try self.persistence.farmSaveStore.snapshot().backup?.pending == nil else { throw FarmSaveError.unavailable }
            try await self.loadAccount()
            guard let owner = try await self.account?.currentLinkedAccountID(), let remote = self.lookup,
                  let service = self.service else { throw FarmSaveError.unavailable }
            try self.assertTransport()
            let command = FarmBackupCommand(action: "delete", generation: remote.generation,
                baseRevision: remote.head?.id, operationID: UUID())
            try self.persistence.farmSaveStore.updateBackup {
                if $0 == nil { $0 = FarmBackupSync(ownerID: owner, generation: remote.generation) }
                $0?.enabled = false
                $0?.pending = command
            }
            let receipt = try await service.send(command, owner: owner, authorization: self.transportAuthorization)
            try self.assertTransport()
            guard receipt.status == "deleted" else { throw FarmSaveError.corrupt }
            try self.persistence.farmSaveStore.updateBackup {
                $0 = FarmBackupSync(ownerID: owner, generation: receipt.generation)
            }
            self.lookup = nil
            self.accountFarmPreview = nil
            self.accountPresentation = .noRemoteSave
            self.message = "Your online Farm copies were deleted. Your Farm is still on this phone."
        }
    }

    func chooseAccountFarm() {
        perform {
            try await self.completeAccountConnection(acceptSync: true, resolveChangedGeneration: true, preferAccountFarm: true)
        }
    }

    func chooseLocalFarm() {
        perform {
            guard self.canRestore?() == true else { throw FarmSaveError.unavailable }
            try await self.saveLocalFarm()
            try await self.completeAccountConnection(acceptSync: true)
        }
    }
}
