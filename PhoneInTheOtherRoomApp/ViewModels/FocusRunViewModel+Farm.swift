import Foundation

@MainActor
extension FocusRunViewModel {
    func shearFarmSheep(_ sheepID: UUID) {
        mutateFarm { state in
            let amount = try state.shear(
                sheepID: sheepID,
                protectedNightCount: coordinator.progress.totalCompletedRuns
            )
            return "+\(amount) wool. The fleece will grow back over more protected nights."
        }
    }

    func tradeFarmSheep(_ sheepID: UUID) {
        mutateFarm { state in
            let amount = try state.tradeToAnotherFarm(
                sheepID: sheepID,
                protectedNightCount: coordinator.progress.totalCompletedRuns
            )
            return "+\(amount) wool. This sheep has moved to another farm. Its story stays in the Search Journal."
        }
    }

    func welcomePendingFarmSheep(_ sheepID: UUID) {
        mutateFarm { state in
            try state.welcomePending(sheepID: sheepID)
            return "The Barn door is open. Your new sheep is in the pasture."
        }
    }

    func toggleFarmSheepFavorite(_ sheepID: UUID) {
        mutateFarm { state in
            try state.toggleFavorite(sheepID: sheepID)
            return nil
        }
    }

    func purchaseFarmShopItem(_ itemID: String) {
        mutateFarm { state in
            try state.purchase(itemID: itemID)
            let title = FarmShopCatalog.item(for: itemID)?.title ?? "Farm Shop find"
            return "\(title) is yours and ready at the Farm."
        }
    }

    func equipFarmShopItem(_ itemID: String) {
        mutateFarm { state in
            try state.equip(itemID: itemID)
            let title = FarmShopCatalog.item(for: itemID)?.title ?? "Farm Shop find"
            return "\(title) is now part of the Farm."
        }
    }

    func wearOllieAccessory(_ itemID: String) {
        mutateFarm { state in
            try state.wearOllieAccessory(itemID: itemID)
            return FarmShopCatalog.item(for: itemID).map { "Ollie is wearing \($0.title)." }
        }
    }

    func takeOffOllieAccessory(_ itemID: String) {
        mutateFarm { state in
            try state.takeOffOllieAccessory(itemID: itemID)
            return "Ollie is ready for the next trail."
        }
    }

    func wearShepherdOutfit(_ itemID: String) {
        mutateFarm { state in
            try state.wearShepherdOutfit(itemID: itemID)
            return FarmShopCatalog.item(for: itemID).map { "\($0.title) is ready for the next trail." }
        }
    }

    func takeOffShepherdOutfit(_ itemID: String) {
        mutateFarm { state in
            try state.takeOffShepherdOutfit(itemID: itemID)
            return "Your Shepherd’s coat is back in the wardrobe."
        }
    }

    func wearShepherdAccessory(_ itemID: String) {
        mutateFarm { state in
            try state.wearShepherdAccessory(itemID: itemID)
            return FarmShopCatalog.item(for: itemID).map { "Your Shepherd is wearing \($0.title)." }
        }
    }

    func takeOffShepherdAccessory(_ itemID: String) {
        mutateFarm { state in
            try state.takeOffShepherdAccessory(itemID: itemID)
            return "Your Shepherd’s field gear is back in the wardrobe."
        }
    }

    func placeFarmDecoration(_ itemID: String) {
        mutateFarm { state in
            try state.placeFarmDecoration(itemID: itemID)
            return FarmShopCatalog.item(for: itemID).map { "\($0.title) has a place in the pasture." }
        }
    }

    func putAwayFarmDecoration(_ itemID: String) {
        mutateFarm { state in
            try state.putAwayFarmDecoration(itemID: itemID)
            return "The decoration is safe in the Farm store room."
        }
    }

    func displayFarmCollectible(_ itemID: String) {
        mutateFarm { state in
            try state.displayCollectible(itemID: itemID)
            return FarmShopCatalog.item(for: itemID).map { "\($0.title) is on display by the Barn." }
        }
    }

    func storeFarmCollectible(_ itemID: String) {
        mutateFarm { state in
            try state.storeCollectible(itemID: itemID)
            return "The keepsake is tucked safely away."
        }
    }

    func trackSheepDefinition(_ definitionID: String?) {
        mutateFarm { state in
            state.setTrackedSheep(definitionID)
            guard let definitionID,
                  let sheep = SheepCatalog.definition(for: definitionID) else {
                return "Ollie will follow whichever trail looks strongest."
            }
            return "Ollie will favour \(sheep.name)’s trail—not guarantee it."
        }
    }

    func setShepherdSkinTone(_ skinTone: ShepherdSkinTone) {
        mutateFarm { state in
            state.setShepherdSkinTone(skinTone)
            return nil
        }
    }

    func setShepherdHairStyle(_ hairStyle: ShepherdHairStyle) {
        mutateFarm { state in
            state.setShepherdHairStyle(hairStyle)
            return nil
        }
    }

    func clearFarmActionMessage() {
        farmActionMessage = nil
    }

    private func mutateFarm(_ mutation: (inout FarmState) throws -> String?) {
        var state = coordinator.farmState
        do {
            let message = try mutation(&state)
            coordinator.farmState = state
            persistence.farmState = state
            farmActionMessage = message
        } catch let error as FarmActionError {
            farmActionMessage = farmMessage(for: error)
        } catch {
            farmActionMessage = "The Farm could not save that change. Please try once more."
        }
    }

    private func farmMessage(for error: FarmActionError) -> String {
        switch error {
        case .sheepNotFound:
            return "That sheep is no longer in this part of the Farm."
        case .sheepNotActive:
            return "That sheep has already moved on from the active flock."
        case .woolRegrowing:
            return "The wool is still growing. The Barn shows how many protected nights remain."
        case .barnFull:
            return "The Barn is full. Trade a sheep to another farm or open another pasture first."
        case .itemNotFound:
            return "That Farm Shop item is not available."
        case .itemAlreadyOwned:
            return "That item is already yours."
        case .itemNotOwned:
            return "Bring that item home from the Farm Shop before equipping it."
        case .itemNotEquippable:
            return "That Farm Shop item belongs in a different place."
        case .itemNotEquipped:
            return "That item is not wearing this slot right now."
        case .itemNotPlaced:
            return "That decoration is already in the Farm store room."
        case .itemNotDisplayed:
            return "That keepsake is already tucked away."
        case .insufficientFunds:
            return "The till needs a little more wool."
        case .upgradeOutOfSequence:
            return "Open the next pasture before expanding farther."
        case .maximumCapacityReached:
            return "All four expansions are open. The Farm can hold 60 sheep."
        }
    }
}
