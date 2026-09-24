import Foundation

/// A display snapshot explicitly shared by Global visibility, never the private Farm save.
struct CampfireProfileSnapshot: Codable, Equatable, Sendable {
    var session: [String]
    var tasks: [String]
    var routines: [String]
    var intention: String
    var history: [String]
    var partyNames: [String]
    var inventory: [String]
    var sheep: [Sheep]
    var appearance: PublicCampfireAppearance
    var decorations: [String: String]
    var collectibles: [String: String]
    var ollieAccessory: String
    var barnCapacityLevel: Int

    struct Sheep: Codable, Equatable, Sendable {
        var id: UUID
        var definitionID: String
        var name: String
        var status: String
        var cosmetics: [String]
    }

    var thought: String? { tasks.first ?? routines.first }
    var farm: FarmState {
        var state = FarmState.empty
        state.shepherd = appearance.presentation.shepherdProfile
        state.barnCapacityLevel = barnCapacityLevel
        state.ownedShopItemIDs = inventory
        state.equipment.ollieAccessoryItemID = ollieAccessory == "none" ? nil : ollieAccessory
        state.equipment.ollieCoatID = appearance.presentation.renderableAppearance.ollieCoatID
        for (zone, item) in decorations {
            if let zone = FarmDecorationZone(rawValue: zone) { state.equipment.decorationPlacements[zone] = item }
        }
        for (slot, item) in collectibles {
            if let slot = FarmCollectibleSlot(rawValue: slot) { state.equipment.collectiblePlacements[slot] = item }
        }
        state.sheep = sheep.compactMap { value in
            guard let definition = SheepCatalog.definition(for: value.definitionID),
                  let status = FlockSheepStatus(rawValue: value.status) else { return nil }
            return FlockSheep(id: value.id, definitionID: value.definitionID, displayName: value.name,
                arrivedAt: .distantPast, protectedNightNumber: 0, rarity: definition.rarity,
                status: status, equippedCosmeticIDs: value.cosmetics)
        }
        return state
    }
}

struct CampfireProfileResponse: Decodable {
    var accepted: Bool
    var profile: CampfireProfileSnapshot?
    var observedAt: Date
}
