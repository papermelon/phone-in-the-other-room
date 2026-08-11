import Foundation
import SwiftUI

enum FarmPreviewData {
    static var searchState: SheepSearchState {
        var state = SheepSearchState.empty
        state.outcomes = (0..<6).map { index in
            let definition = SheepCatalog.all[index]
            return SheepSearchOutcome(
                id: previewUUID(index + 1),
                runID: previewUUID(index + 101),
                protectedNightNumber: index + 1,
                result: .found,
                sheepID: definition.id,
                rarity: definition.rarity,
                habitat: definition.habitat,
                trailStrength: 58 + index,
                encounterOdds: index < 3 ? 1 : 0.62,
                trailDistance: Double(index + 2),
                consecutiveNoFinds: 0,
                bonusPoints: 0,
                createdAt: Date().addingTimeInterval(Double(index - 6) * 86_400)
            )
        }
        state.foundSheepIDs = Array(SheepCatalog.all.prefix(6).map(\.id))
        state.trailMap.credit(runID: previewUUID(900), minutes: 45)
        return state
    }

    static var fullState: FarmState {
        var state = FarmMigration.migrated(existing: nil, searchState: searchState)
        for index in 6..<13 {
            let definition = SheepCatalog.all[index % SheepCatalog.all.count]
            let outcome = SheepSearchOutcome(
                id: previewUUID(index + 1),
                runID: previewUUID(index + 101),
                protectedNightNumber: index + 1,
                result: .found,
                sheepID: definition.id,
                rarity: definition.rarity,
                habitat: definition.habitat,
                trailStrength: 70,
                encounterOdds: 0.7,
                trailDistance: Double(index),
                consecutiveNoFinds: 0,
                bonusPoints: 0,
                createdAt: Date().addingTimeInterval(Double(index - 13) * 86_400)
            )
            state.recordArrival(outcome)
        }
        state.woolBalance = 34
        state.sheep[0].isFavorite = true
        state.sheep[1].lastShearedProtectedNight = 17
        state.ownedShopItemIDs = [
            "ollie_moss_bandana",
            "farm_lanterns",
            "shepherd_wool_hat",
            "collectible_trail_pin"
        ]
        state.equipment.ollieAccessoryItemID = "ollie_moss_bandana"
        state.equipment.farmDecorationItemIDs = ["farm_lanterns"]
        state.equipment.collectibleItemIDs = ["collectible_trail_pin"]
        state.shepherd.accessoryItemID = "shepherd_wool_hat"
        return state
    }

    static var oneSheepState: FarmState {
        var search = SheepSearchState.empty
        search.append(searchState.outcomes[0])
        return FarmMigration.migrated(existing: nil, searchState: search)
    }

    static var sixtySheepState: FarmState {
        var state = FarmState.empty
        state.barnCapacityLevel = FarmEconomyRules.maximumCapacityLevel
        for index in 0..<60 {
            let definition = SheepCatalog.all[index % SheepCatalog.all.count]
            state.sheep.append(FlockSheep(
                id: previewUUID(index + 1_000),
                definitionID: definition.id,
                displayName: index < SheepCatalog.all.count ? definition.name : "Pasture \(index + 1)",
                arrivedAt: Date().addingTimeInterval(Double(index - 60) * 86_400),
                protectedNightNumber: index + 1,
                rarity: definition.rarity,
                lastShearedProtectedNight: index.isMultiple(of: 3) ? 58 : nil
            ))
        }
        return state
    }

    static func previewUUID(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))!
    }
}

#Preview("The Barn · full and pending") {
    NavigationStack {
        FarmBarnPreview(state: FarmPreviewData.fullState)
    }
}

#Preview("The Barn · ready to shear") {
    NavigationStack {
        FarmBarnPreview(state: FarmPreviewData.oneSheepState)
    }
}

private struct FarmBarnPreview: View {
    let state: FarmState

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Text("\(state.activeSheep.count) / \(state.activeCapacity) in The Barn")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 138))]) {
                ForEach(state.activeSheep.prefix(4)) {
                    BarnSheepCard(sheep: $0, protectedNightCount: 18)
                }
            }
        }
        .padding()
        .background(AppColors.paper)
    }
}
