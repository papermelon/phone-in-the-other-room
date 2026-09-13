import Foundation

extension FocusSessionCoordinator {
    /// Main-actor callers stage related domain changes synchronously. Rendering
    /// and social acknowledgements only observe success after the disk commit.
    @discardableResult
    func commitFarmChanges(using persistence: PersistenceService, _ update: () throws -> Void) -> Bool {
        let previousFarm = farmState
        let previousSearch = sheepSearchState
        let previousProgress = progress
        let previousRewards = rewards
        let previousReward = latestReward
        let previousOutcome = latestSheepSearchOutcome
        do {
            try persistence.farmSaveStore.transaction(update)
            farmSaveUnavailable = false
            farmSaveMessage = persistence.farmSaveStore.recoveredPreviousGeneration
                ? "An earlier Farm save was recovered. Your latest changes may be missing."
                : nil
            return true
        } catch {
            farmState = previousFarm
            sheepSearchState = previousSearch
            progress = previousProgress
            rewards = previousRewards
            latestReward = previousReward
            latestSheepSearchOutcome = previousOutcome
            farmSaveUnavailable = !persistence.farmSaveStore.hasReadableSave
            switch persistence.farmSaveStore.failure {
            case .unsupportedSchema:
                farmSaveMessage = "This Farm was saved by a newer version of Counting Sheep. Update the app to open it."
            case .corrupt, .invalidComponent:
                farmSaveMessage = "Your Farm save could not be read. The original has been kept."
            default:
                farmSaveMessage = farmSaveUnavailable
                    ? "Your Farm save is unavailable. The app has not replaced it. Please try again."
                    : "Your Farm could not save this change. Your previous save has been kept. Please try again."
            }
            return false
        }
    }
}
