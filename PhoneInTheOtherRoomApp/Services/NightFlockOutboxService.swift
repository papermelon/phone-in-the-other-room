import Foundation

actor NightFlockOutboxService {
    static let outboxKey = "ollie.nightFlock.outbox"
    static let v2OutboxKey = "ollie.nightFlock.commitmentOutbox"
    static let v3OutboxKey = "ollie.nightFlock.metricsOutbox"
    static let v4OutboxKey = "ollie.nightFlock.v4SourceOutbox"
    static let v4StatusOutboxKey = "ollie.nightFlock.v4StatusOutbox"
    static let runContextsKey = "ollie.nightFlock.runContexts"
    static let stagedDestructiveEffectKey = "ollie.nightFlock.stagedDestructiveEffect"
    static let acceptedAccountDeletionKey = "ollie.nightFlock.acceptedAccountDeletion"
    static let pendingDestructiveIntentKey = "ollie.nightFlock.pendingDestructiveIntent"
    static let pendingAccountDeletionIntentKey = "ollie.nightFlock.pendingAccountDeletionIntent"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var acceptedMutationEpoch: UInt64 = 0
    private var accountDeletionClosed: Bool
    private var pendingIntentClosed: Bool
    private var pendingAccountDeletionClosed: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accountDeletionClosed = defaults.bool(forKey: Self.acceptedAccountDeletionKey)
        pendingIntentClosed = defaults.data(forKey: Self.pendingDestructiveIntentKey) != nil
        pendingAccountDeletionClosed = defaults.bool(forKey: Self.pendingAccountDeletionIntentKey)
    }

    func records() -> [NightFlockOutboxRecord] {
        load([NightFlockOutboxRecord].self, key: Self.outboxKey) ?? []
    }

    func enqueue(_ record: NightFlockOutboxRecord, epoch: UInt64) {
        guard admits(epoch) else { return }
        save(NightFlockOutboxRules.merge(record, into: records()), key: Self.outboxKey)
    }

    func enqueue(_ record: NightFlockOutboxRecord, updating context: NightFlockRunShareContext, epoch: UInt64) {
        guard admits(epoch) else { return }
        saveRunContext(context, epoch: epoch)
        enqueue(record, epoch: epoch)
    }

    func markAttempt(_ id: UUID, epoch: UInt64) {
        guard admits(epoch) else { return }
        var queued = records()
        guard let index = queued.firstIndex(where: { $0.id == id }) else { return }
        queued[index].attemptCount += 1
        save(queued, key: Self.outboxKey)
    }

    func v2Records() -> [NightFlockV2OutboxRecord] {
        load([NightFlockV2OutboxRecord].self, key: Self.v2OutboxKey) ?? []
    }

    func enqueueV2(_ record: NightFlockV2OutboxRecord, epoch: UInt64) {
        guard admits(epoch) else { return }
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

    func markV2Attempt(_ id: UUID, epoch: UInt64) {
        guard admits(epoch) else { return }
        var queued = v2Records()
        guard let index = queued.firstIndex(where: { $0.id == id }) else { return }
        queued[index].attemptCount += 1
        save(queued, key: Self.v2OutboxKey)
    }

    func removeV2(_ id: UUID, epoch: UInt64) {
        guard admits(epoch) else { return }
        save(v2Records().filter { $0.id != id }, key: Self.v2OutboxKey)
    }

    func v3Records() -> [NightFlockV3OutboxRecord] {
        load([NightFlockV3OutboxRecord].self, key: Self.v3OutboxKey) ?? []
    }

    func enqueueV3(_ record: NightFlockV3OutboxRecord, epoch: UInt64) {
        guard admits(epoch) else { return }
        save(NightFlockV3OutboxRules.merge(record, into: v3Records()), key: Self.v3OutboxKey)
    }

    func markV3Attempt(_ id: UUID, epoch: UInt64) {
        guard admits(epoch) else { return }
        var queued = v3Records()
        guard let index = queued.firstIndex(where: { $0.id == id }) else { return }
        queued[index].attemptCount += 1
        save(queued, key: Self.v3OutboxKey)
    }

    func removeV3(_ id: UUID, epoch: UInt64) {
        guard admits(epoch) else { return }
        save(v3Records().filter { $0.id != id }, key: Self.v3OutboxKey)
    }

    /// Schema four deliberately stores one factual source activity per account.  The
    /// server derives the eligible party/round publications, so this queue must never
    /// grow one record per party.
    func v4Records() -> [NightFlockV4OutboxSourceRecord] {
        load([NightFlockV4OutboxSourceRecord].self, key: Self.v4OutboxKey) ?? []
    }

    func enqueueV4(_ record: NightFlockV4OutboxSourceRecord, epoch: UInt64) {
        guard admits(epoch) else { return }
        save(NightFlockV4OutboxRules.merge(record, into: v4Records()), key: Self.v4OutboxKey)
    }

    func markV4Attempt(_ sourceEventID: UUID, kind: NightFlockV4ActivityKind, epoch: UInt64) {
        guard admits(epoch) else { return }
        var queued = v4Records()
        guard let index = queued.firstIndex(where: {
            $0.source.sourceEventID == sourceEventID && $0.source.kind == kind
        }) else { return }
        queued[index].attemptCount += 1
        save(queued, key: Self.v4OutboxKey)
    }

    func removeV4(_ sourceEventID: UUID, kind: NightFlockV4ActivityKind, epoch: UInt64) {
        guard admits(epoch) else { return }
        save(v4Records().filter {
            !($0.source.sourceEventID == sourceEventID && $0.source.kind == kind)
        }, key: Self.v4OutboxKey)
    }

    func v4StatusRecords() -> [NightFlockV4StatusOutboxRecord] {
        load([NightFlockV4StatusOutboxRecord].self, key: Self.v4StatusOutboxKey) ?? []
    }

    func enqueueV4Status(_ record: NightFlockV4StatusOutboxRecord, epoch: UInt64) {
        guard admits(epoch) else { return }
        save(NightFlockV4StatusOutboxRules.merge(record, into: v4StatusRecords()), key: Self.v4StatusOutboxKey)
    }

    func markV4StatusAttempt(_ sourceEventID: UUID, epoch: UInt64) {
        guard admits(epoch) else { return }
        var queued = v4StatusRecords()
        guard let index = queued.firstIndex(where: { $0.sourceEventID == sourceEventID }) else { return }
        queued[index].attemptCount += 1
        save(queued, key: Self.v4StatusOutboxKey)
    }

    func removeV4Status(_ sourceEventID: UUID, epoch: UInt64) {
        guard admits(epoch) else { return }
        save(v4StatusRecords().filter { $0.sourceEventID != sourceEventID }, key: Self.v4StatusOutboxKey)
    }

    func remove(_ id: UUID, epoch: UInt64) {
        guard admits(epoch) else { return }
        let queued = records().filter { $0.id != id }
        save(queued, key: Self.outboxKey)
    }

    func runContexts() -> [NightFlockRunShareContext] {
        load([NightFlockRunShareContext].self, key: Self.runContextsKey) ?? []
    }

    func saveRunContext(_ context: NightFlockRunShareContext, epoch: UInt64) {
        guard admits(epoch) else { return }
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

    func removeRunContext(_ runID: UUID, epoch: UInt64) {
        guard admits(epoch) else { return }
        save(runContexts().filter { $0.runID != runID }, key: Self.runContextsKey)
    }

    func clear(epoch: UInt64) -> NightFlockOutboxClearResult {
        guard !pendingIntentClosed,
              NightFlockAccountDeletionIntentPolicy.permitsOrdinaryClear(
            phase: accountDeletionPhase,
            callerEpoch: epoch,
            acceptedEpoch: acceptedMutationEpoch
        ) else { return NightFlockOutboxClearResult(epoch: acceptedMutationEpoch, didClear: false) }
        acceptedMutationEpoch = NightFlockOutboxEpochPolicy.advancingClear(
            acceptedEpoch: acceptedMutationEpoch,
            requestedEpoch: epoch
        )
        defaults.removeObject(forKey: Self.outboxKey)
        defaults.removeObject(forKey: Self.v2OutboxKey)
        defaults.removeObject(forKey: Self.v3OutboxKey)
        defaults.removeObject(forKey: Self.v4OutboxKey)
        defaults.removeObject(forKey: Self.v4StatusOutboxKey)
        defaults.removeObject(forKey: Self.runContextsKey)
        // Keep the marker until every queued record is gone. If termination
        // interrupts earlier removal, launch still reconciles before flushing.
        defaults.removeObject(forKey: Self.stagedDestructiveEffectKey)
        return NightFlockOutboxClearResult(epoch: acceptedMutationEpoch, didClear: true)
    }

    func stagedDestructiveEffect() -> NightFlockDestructiveLocalEffect {
        load(NightFlockDestructiveLocalEffect.self, key: Self.stagedDestructiveEffectKey) ?? .none
    }

    func stageDestructiveEffect(_ effect: NightFlockDestructiveLocalEffect, epoch: UInt64) {
        guard admits(epoch) else { return }
        save(effect, key: Self.stagedDestructiveEffectKey)
    }

    func hasAcceptedAccountDeletion() -> Bool { accountDeletionClosed }
    func pendingDestructiveIntent() -> NightFlockPendingDestructiveIntent? {
        load(NightFlockPendingDestructiveIntent.self, key: Self.pendingDestructiveIntentKey)
    }
    func hasPendingAccountDeletionIntent() -> Bool {
        pendingAccountDeletionClosed
    }
    func stagePendingAccountDeletionIntent(epoch: UInt64) -> Bool {
        // This is intentionally not idempotent. The actor serializes the
        // complete -> pending transition, so only its first caller acquires
        // the right to send `deleteAccount`; later taps observe pending and
        // must never issue another request.
        guard NightFlockAccountDeletionIntentPolicy.permitsExclusivePreflightAcquisition(
            phase: accountDeletionPhase,
            ordinaryIntentPresent: pendingIntentClosed,
            stagedOrdinaryEffect: stagedDestructiveEffect(),
            callerEpoch: epoch,
            acceptedEpoch: acceptedMutationEpoch
        ) else { return false }
        defaults.set(true, forKey: Self.pendingAccountDeletionIntentKey)
        pendingAccountDeletionClosed = true
        return true
    }
    func rejectPendingAccountDeletionIntent(epoch: UInt64) -> Bool {
        guard pendingAccountDeletionClosed,
              !accountDeletionClosed,
              epoch == acceptedMutationEpoch
        else { return false }
        defaults.removeObject(forKey: Self.pendingAccountDeletionIntentKey)
        pendingAccountDeletionClosed = false
        return true
    }
    func stagePendingDestructiveIntent(_ intent: NightFlockPendingDestructiveIntent, epoch: UInt64) -> Bool {
        guard admits(epoch) else { return false }
        save(intent, key: Self.pendingDestructiveIntentKey)
        pendingIntentClosed = true
        return true
    }
    func removePendingDestructiveIntent(epoch: UInt64) -> Bool {
        guard NightFlockAccountDeletionIntentPolicy.permitsOrdinaryIntentTransition(
            phase: accountDeletionPhase,
            callerEpoch: epoch,
            acceptedEpoch: acceptedMutationEpoch
        ) else { return false }
        defaults.removeObject(forKey: Self.pendingDestructiveIntentKey)
        pendingIntentClosed = false
        return true
    }

    /// An accepted destructive command is durably promoted before its pending
    /// intent is removed. That order makes a termination between the writes
    /// reconcile locally instead of replaying the command.
    func acceptPendingDestructiveIntent(
        _ intent: NightFlockPendingDestructiveIntent,
        effect: NightFlockDestructiveLocalEffect,
        epoch: UInt64
    ) -> Bool {
        guard NightFlockAccountDeletionIntentPolicy.permitsOrdinaryIntentTransition(
            phase: accountDeletionPhase,
            callerEpoch: epoch,
            acceptedEpoch: acceptedMutationEpoch
        ),
              pendingDestructiveIntent() == intent
        else { return false }
        let markerFirst = NightFlockPendingIntentTransitionPolicy.afterAcceptedMarkerWrite(effect: effect)
        save(markerFirst.stagedEffect, key: Self.stagedDestructiveEffectKey)
        let completed = NightFlockPendingIntentTransitionPolicy.afterAcceptedTransition(effect: effect)
        if !completed.pendingIntentPresent {
            defaults.removeObject(forKey: Self.pendingDestructiveIntentKey)
        }
        pendingIntentClosed = false
        return true
    }

    func acceptAccountDeletion(epoch: UInt64) -> UInt64 {
        if accountDeletionClosed, defaults.bool(forKey: Self.acceptedAccountDeletionKey) {
            defaults.removeObject(forKey: Self.pendingAccountDeletionIntentKey)
            pendingAccountDeletionClosed = false
            return acceptedMutationEpoch
        }
        // The accepted tombstone is durable before the pending preflight is
        // removed, so restart finalization always dominates a lost response.
        accountDeletionClosed = true
        defaults.set(true, forKey: Self.acceptedAccountDeletionKey)
        acceptedMutationEpoch = NightFlockAcceptedDeletionPolicy.closedEpoch(
            acceptedEpoch: acceptedMutationEpoch,
            requestedEpoch: epoch
        )
        defaults.removeObject(forKey: Self.pendingAccountDeletionIntentKey)
        pendingAccountDeletionClosed = false
        return acceptedMutationEpoch
    }

    func finalizeAcceptedAccountDeletion(epoch: UInt64) -> Bool {
        guard accountDeletionClosed, epoch == acceptedMutationEpoch else { return false }
        defaults.removeObject(forKey: Self.outboxKey)
        defaults.removeObject(forKey: Self.v2OutboxKey)
        defaults.removeObject(forKey: Self.v3OutboxKey)
        defaults.removeObject(forKey: Self.v4OutboxKey)
        defaults.removeObject(forKey: Self.v4StatusOutboxKey)
        defaults.removeObject(forKey: Self.runContextsKey)
        defaults.removeObject(forKey: Self.stagedDestructiveEffectKey)
        defaults.removeObject(forKey: Self.pendingAccountDeletionIntentKey)
        pendingAccountDeletionClosed = false
        return true
    }

    func completeAcceptedAccountDeletion(epoch: UInt64) -> Bool {
        guard accountDeletionClosed, epoch == acceptedMutationEpoch else { return false }
        defaults.removeObject(forKey: Self.acceptedAccountDeletionKey)
        defaults.removeObject(forKey: Self.pendingAccountDeletionIntentKey)
        accountDeletionClosed = false
        pendingAccountDeletionClosed = false
        return true
    }

    private func admits(_ epoch: UInt64) -> Bool {
        !pendingIntentClosed && NightFlockAccountDeletionIntentPolicy.permitsActorMutation(
            phase: accountDeletionPhase,
            callerEpoch: epoch,
            acceptedEpoch: acceptedMutationEpoch
        )
    }

    private var accountDeletionPhase: NightFlockAccountDeletionIntentPolicy.Phase {
        NightFlockAccountDeletionIntentPolicy.phase(
            pendingIntentPresent: pendingAccountDeletionClosed,
            tombstonePresent: accountDeletionClosed
        )
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
