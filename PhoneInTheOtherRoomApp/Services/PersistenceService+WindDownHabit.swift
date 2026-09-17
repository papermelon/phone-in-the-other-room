import Foundation

/// A draft is valid only for the local owner and save lineage it was opened in.
struct WindDownHabitLocalIdentity: Equatable {
    let scope: AccountFarmScope
    let lineageID: UUID
}

extension PersistenceService {
    func windDownHabitIdentity() throws -> WindDownHabitLocalIdentity {
        let document = try farmSaveStore.snapshot()
        guard document.effectiveScope != .signedOut else { throw FarmSaveError.unavailable }
        return WindDownHabitLocalIdentity(scope: document.effectiveScope, lineageID: document.lineageID)
    }

    func loadWindDownHabitPlan() throws -> WindDownHabitPlan {
        _ = try windDownHabitIdentity()
        guard let data = farmSaveStore.localData(for: WindDownHabitPlan.storageKey) else {
            return WindDownHabitPlan()
        }
        return try JSONDecoder().decode(WindDownHabitPlan.self, from: data)
    }

    func loadWindDownHabitReflections() throws -> WindDownHabitReflectionHistory {
        _ = try windDownHabitIdentity()
        guard let data = farmSaveStore.localData(for: WindDownHabitReflectionHistory.storageKey) else {
            return WindDownHabitReflectionHistory()
        }
        return try JSONDecoder().decode(WindDownHabitReflectionHistory.self, from: data)
    }

    func saveWindDownHabitPlan(_ plan: WindDownHabitPlan, identity: WindDownHabitLocalIdentity) throws {
        try saveWindDownHabitValue(plan.normalized(), key: WindDownHabitPlan.storageKey, identity: identity)
    }

    func saveWindDownHabitReflections(_ history: WindDownHabitReflectionHistory, identity: WindDownHabitLocalIdentity) throws {
        try saveWindDownHabitValue(history, key: WindDownHabitReflectionHistory.storageKey, identity: identity)
    }

    private func saveWindDownHabitValue<T: Encodable>(_ value: T, key: String, identity: WindDownHabitLocalIdentity) throws {
        try farmSaveStore.transaction {
            // An enclosing transaction may already have staged an owner switch.
            // Check that staged document while the store's transaction lock is held.
            guard let pending = farmSaveStore.pending,
                  pending.effectiveScope == identity.scope,
                  pending.lineageID == identity.lineageID,
                  pending.effectiveScope != .signedOut else { throw FarmSaveError.unavailable }
            try farmSaveStore.setLocalData(JSONEncoder().encode(value), for: key)
        }
    }
}
