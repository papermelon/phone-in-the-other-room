import Foundation

struct RitualPersonalisationEditToken: Equatable {
    let identity: WindDownHabitLocalIdentity
    let storedData: Data?
    let reflectionData: Data?
    let preferences: NightWatchPreferences
    let support: WindDownHabitPlan
}

extension PersistenceService {
    func personalisationEditToken() throws -> RitualPersonalisationEditToken {
        RitualPersonalisationEditToken(
            identity: try windDownHabitIdentity(),
            storedData: farmSaveStore.localData(for: RitualPersonalisation.storageKey),
            reflectionData: farmSaveStore.localData(for: WindDownHabitReflectionHistory.storageKey),
            preferences: nightWatchPreferences, support: try loadWindDownHabitPlan()
        )
    }

    func loadPersonalisation() throws -> RitualPersonalisation {
        _ = try windDownHabitIdentity()
        guard let data = farmSaveStore.localData(for: RitualPersonalisation.storageKey) else { return RitualPersonalisation() }
        let state = try JSONDecoder().decode(RitualPersonalisation.self, from: data)
        guard state.schemaVersion == 1,
              state.goals.filter({ $0.archivedAt == nil }).count <= 1,
              state.goals.allSatisfy({ !$0.wording.isEmpty && $0.wording.count <= 120 && $0.kind.supports($0.mode) })
        else { throw FarmSaveError.unavailable }
        return state
    }

    func savePersonalisation(_ state: RitualPersonalisation, token: RitualPersonalisationEditToken,
                             reflections: WindDownHabitReflectionHistory? = nil,
                             support: WindDownHabitPlan? = nil) throws {
        try farmSaveStore.transaction {
            guard let pending = farmSaveStore.pending,
                  pending.effectiveScope == token.identity.scope,
                  pending.lineageID == token.identity.lineageID,
                  pending.effectiveScope != .signedOut,
                  pending.localValues?[RitualPersonalisation.storageKey] == token.storedData,
                  pending.localValues?[WindDownHabitReflectionHistory.storageKey] == token.reflectionData,
                  nightWatchPreferences == token.preferences,
                  try loadWindDownHabitPlan() == token.support else { throw FarmSaveError.unavailable }
            if token.storedData != nil { _ = try loadPersonalisation() }
            if reflections != nil, token.reflectionData != nil { _ = try loadWindDownHabitReflections() }
            try farmSaveStore.setLocalData(JSONEncoder().encode(state), for: RitualPersonalisation.storageKey)
            if let reflections {
                try farmSaveStore.setLocalData(JSONEncoder().encode(reflections), for: WindDownHabitReflectionHistory.storageKey)
            }
            if let support {
                try farmSaveStore.setLocalData(JSONEncoder().encode(support.normalized()), for: WindDownHabitPlan.storageKey)
            }
        }
    }
}
