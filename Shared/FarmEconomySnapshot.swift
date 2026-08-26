import Foundation

struct FarmEconomySnapshot: Codable, Equatable {
    let woolBalance: Int
    let woolEarnedByKind: [String: Int]
    let woolSpentByKind: [String: Int]
    let ownedItemCount: Int
    let activeSheepCount: Int
    let pendingSheepCount: Int
    let barnCapacity: Int
}

extension FarmState {
    var economySnapshot: FarmEconomySnapshot {
        var earned: [String: Int] = [:]
        var spent: [String: Int] = [:]
        for transaction in transactions where transaction.woolDelta != 0 {
            if transaction.woolDelta > 0 {
                earned[transaction.kind.rawValue, default: 0] += transaction.woolDelta
            } else {
                spent[transaction.kind.rawValue, default: 0] += abs(transaction.woolDelta)
            }
        }
        return FarmEconomySnapshot(
            woolBalance: woolBalance,
            woolEarnedByKind: earned,
            woolSpentByKind: spent,
            ownedItemCount: ownedShopItemIDs.count,
            activeSheepCount: activeSheep.count,
            pendingSheepCount: pendingSheep.count,
            barnCapacity: activeCapacity
        )
    }
}
