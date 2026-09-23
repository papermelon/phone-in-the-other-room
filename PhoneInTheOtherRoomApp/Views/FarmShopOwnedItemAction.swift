import SwiftUI

/// Detail previews retain the same reversible equipment intents as Shop cards.
struct FarmShopOwnedItemAction: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let item: FarmShopItem
    let state: FarmState

    private var active: Bool {
        switch item.effect {
        case .ollieAccessory: return state.equipment.ollieAccessoryItemID == item.id
        case .shepherdAccessory: return state.shepherd.accessoryItemID == item.id
        case .shepherdShirt: return state.shepherd.shirtItemID == item.id
        case .shepherdOutfit: return state.shepherd.outfitItemID == item.id
        case .farmDecoration: return state.equipment.farmDecorationItemIDs.contains(item.id)
        case .collectible: return state.equipment.collectibleItemIDs.contains(item.id)
        case .capacity: return true
        }
    }

    var body: some View {
        if case .capacity = item.effect {
            Label("Pasture open", systemImage: "checkmark").font(AppTypography.body)
        } else {
            Button(title, action: toggle)
                .buttonStyle(PixelPrimaryButtonStyle())
                .accessibilityLabel("\(title) \(item.title)")
        }
    }

    private var title: String {
        switch item.effect {
        case .ollieAccessory, .shepherdAccessory, .shepherdOutfit, .shepherdShirt: return active ? "Take off" : "Wear"
        case .farmDecoration: return active ? "Put away" : "Place"
        case .collectible: return active ? "Store" : "Display"
        case .capacity: return "Open"
        }
    }

    private func toggle() {
        switch item.effect {
        case .ollieAccessory:
            if active { viewModel.takeOffOllieAccessory(item.id) } else { viewModel.wearOllieAccessory(item.id) }
        case .shepherdAccessory:
            if active { viewModel.takeOffShepherdAccessory(item.id) } else { viewModel.wearShepherdAccessory(item.id) }
        case .shepherdShirt:
            if active { viewModel.takeOffShepherdShirt(item.id) } else { viewModel.wearShepherdShirt(item.id) }
        case .shepherdOutfit:
            if active { viewModel.takeOffShepherdOutfit(item.id) } else { viewModel.wearShepherdOutfit(item.id) }
        case .farmDecoration:
            if active { viewModel.putAwayFarmDecoration(item.id) } else { viewModel.placeFarmDecoration(item.id) }
        case .collectible:
            if active { viewModel.storeFarmCollectible(item.id) } else { viewModel.displayFarmCollectible(item.id) }
        case .capacity: break
        }
    }
}

#Preview("Owned bandana") {
    FarmShopOwnedItemAction(item: FarmShopCatalog.item(for: "ollie_moss_bandana")!, state: FarmPreviewData.fullState)
        .environmentObject(FocusRunViewModel()).padding().background(AppColors.paper)
}
