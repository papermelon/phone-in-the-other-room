import Foundation

extension PersistenceService {
    func personalShieldOwner() throws -> String {
        let identity = try windDownHabitIdentity()
        guard let scope = identity.scope.archiveKey else { throw FarmSaveError.unavailable }
        return scope + ":" + identity.lineageID.uuidString
    }

    func personalShieldSessions() throws -> [PersonalShieldSession] {
        let owner = try personalShieldOwner()
        guard let data = farmSaveStore.localData(for: PersonalShieldSession.storageKey) else { return [] }
        let sessions = try JSONDecoder().decode([PersonalShieldSession].self, from: data)
        return sessions.filter { $0.owner == owner }
    }

    func savePersonalShieldSession(_ session: PersonalShieldSession, at date: Date) throws {
        try farmSaveStore.transaction {
            guard try personalShieldOwner() == session.owner else { throw FarmSaveError.unavailable }
            var sessions = try personalShieldSessions().filter { $0.interval.end > date && $0.id != session.id }
            sessions.append(session)
            try farmSaveStore.setLocalData(JSONEncoder().encode(Array(sessions.suffix(3))), for: PersonalShieldSession.storageKey)
        }
    }
}
