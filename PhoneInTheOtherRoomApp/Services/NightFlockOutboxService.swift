import Foundation

actor NightFlockOutboxService {
    static let outboxKey = "ollie.nightFlock.outbox"
    static let v2OutboxKey = "ollie.nightFlock.commitmentOutbox"
    static let runContextsKey = "ollie.nightFlock.runContexts"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func records() -> [NightFlockOutboxRecord] {
        load([NightFlockOutboxRecord].self, key: Self.outboxKey) ?? []
    }

    func enqueue(_ record: NightFlockOutboxRecord) {
        save(NightFlockOutboxRules.merge(record, into: records()), key: Self.outboxKey)
    }

    func enqueue(_ record: NightFlockOutboxRecord, updating context: NightFlockRunShareContext) {
        saveRunContext(context)
        enqueue(record)
    }

    func markAttempt(_ id: UUID) {
        var queued = records()
        guard let index = queued.firstIndex(where: { $0.id == id }) else { return }
        queued[index].attemptCount += 1
        save(queued, key: Self.outboxKey)
    }

    func v2Records() -> [NightFlockV2OutboxRecord] {
        load([NightFlockV2OutboxRecord].self, key: Self.v2OutboxKey) ?? []
    }

    func enqueueV2(_ record: NightFlockV2OutboxRecord) {
        var queued = v2Records()
        if let index = queued.firstIndex(where: {
            $0.challengeID == record.challengeID && $0.memberID == record.memberID
                && $0.challengeDay == record.challengeDay && $0.runID == record.runID
        }) {
            if queued[index].status != .morningQuietCompleted {
                queued[index] = record
            }
        } else {
            queued.append(record)
        }
        save(Array(queued.sorted { $0.createdAt < $1.createdAt }.suffix(64)), key: Self.v2OutboxKey)
    }

    func markV2Attempt(_ id: UUID) {
        var queued = v2Records()
        guard let index = queued.firstIndex(where: { $0.id == id }) else { return }
        queued[index].attemptCount += 1
        save(queued, key: Self.v2OutboxKey)
    }

    func removeV2(_ id: UUID) {
        save(v2Records().filter { $0.id != id }, key: Self.v2OutboxKey)
    }

    func remove(_ id: UUID) {
        let queued = records().filter { $0.id != id }
        save(queued, key: Self.outboxKey)
    }

    func runContexts() -> [NightFlockRunShareContext] {
        load([NightFlockRunShareContext].self, key: Self.runContextsKey) ?? []
    }

    func saveRunContext(_ context: NightFlockRunShareContext) {
        var savedContext = context
        var contexts = runContexts()
        if let existing = contexts.first(where: { $0.runID == context.runID }) {
            savedContext.phoneTuckedQueued = existing.phoneTuckedQueued || context.phoneTuckedQueued
            savedContext.morningQuietCompletedQueued = existing.morningQuietCompletedQueued
                || context.morningQuietCompletedQueued
        }
        contexts.removeAll { $0.runID == context.runID }
        contexts.append(savedContext)
        contexts.sort { $0.createdAt < $1.createdAt }
        save(Array(contexts.suffix(32)), key: Self.runContextsKey)
    }

    func removeRunContext(_ runID: UUID) {
        save(runContexts().filter { $0.runID != runID }, key: Self.runContextsKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.outboxKey)
        defaults.removeObject(forKey: Self.v2OutboxKey)
        defaults.removeObject(forKey: Self.runContextsKey)
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
