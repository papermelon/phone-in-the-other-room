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
    static let sharedHabitsPrivacyFencesKey = "ollie.nightFlock.sharedHabitsPrivacyFences"
    static let sharedHabitsOutboxKey = "ollie.nightFlock.sharedHabitsOutbox"
    static let sharedHabitsPendingProjectionsKey = "ollie.nightFlock.sharedHabitsPendingProjections"
    static let sharedHabitsAgreementAttemptsKey = "ollie.nightFlock.sharedHabitsAgreementAttempts"
    static let sharedHabitsSleepPublicationLedgerKey = "ollie.nightFlock.sharedHabitsSleepPublicationLedger"
    static let sharedHabitsJoinAgreementIntentKey = "ollie.nightFlock.sharedHabitsJoinAgreementIntent"
    static let sharedHabitsMigratedAgreementIDsKey = "ollie.nightFlock.sharedHabitsMigratedAgreementIDs"
    static let sharedHabitsFormerPartiesKey = "ollie.nightFlock.sharedHabitsFormerParties"
    static let sharedNightOutboxKey = "ollie.nightFlock.sharedNightOutbox"
    static let sharedNightPlanRevisionLedgerKey = "ollie.nightFlock.sharedNightPlanRevisionLedger"
    static let sharedNightPlanBindingLedgerKey = "ollie.nightFlock.sharedNightPlanBindingLedger"
    static let sharedNightPlanPrivacyFencesKey = "ollie.nightFlock.sharedNightPlanPrivacyFences"
    static let primaryRunSharingDecisionsKey = "ollie.nightFlock.primaryRunSharingDecisions"
    static let primaryRunSharingRequiredAfterKey = "ollie.nightFlock.primaryRunSharingRequiredAfter"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var acceptedMutationEpoch: UInt64 = 0
    private var accountDeletionClosed: Bool
    private var pendingIntentClosed: Bool
    private var pendingAccountDeletionClosed: Bool
    private let primaryRunSharingRequiredAfter: Date

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        accountDeletionClosed = defaults.bool(forKey: Self.acceptedAccountDeletionKey)
        pendingIntentClosed = defaults.data(forKey: Self.pendingDestructiveIntentKey) != nil
        pendingAccountDeletionClosed = defaults.bool(forKey: Self.pendingAccountDeletionIntentKey)
        if let installed = defaults.object(forKey: Self.primaryRunSharingRequiredAfterKey) as? Date {
            primaryRunSharingRequiredAfter = installed
        } else {
            let installed = Date()
            defaults.set(installed, forKey: Self.primaryRunSharingRequiredAfterKey)
            primaryRunSharingRequiredAfter = installed
        }
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

    func markV4StatusAttempt(_ record: NightFlockV4StatusOutboxRecord, epoch: UInt64) {
        guard admits(epoch) else { return }
        var queued = v4StatusRecords()
        guard let index = queued.firstIndex(where: { $0.identity == record.identity }) else { return }
        queued[index].attemptCount += 1
        save(queued, key: Self.v4StatusOutboxKey)
    }

    func removeV4Status(_ record: NightFlockV4StatusOutboxRecord, epoch: UInt64) {
        guard admits(epoch) else { return }
        save(v4StatusRecords().filter { $0.identity != record.identity }, key: Self.v4StatusOutboxKey)
    }

    func sharedHabitsPrivacyFences() -> [NightFlockSharedHabitsPrivacyFence] {
        load([NightFlockSharedHabitsPrivacyFence].self, key: Self.sharedHabitsPrivacyFencesKey) ?? []
    }

    func permitsSharedHabitsPublication() -> Bool {
        NightFlockSharedHabitsFencePolicy.permitsAnyPublication(
            fences: sharedHabitsPrivacyFences()
        )
    }

    func sharedHabitsRecords() -> [NightFlockSharedHabitsOutboxRecord] {
        let records = load([NightFlockSharedHabitsOutboxRecord].self, key: Self.sharedHabitsOutboxKey) ?? []
        let migrated = NightFlockSharedHabitsSleepIdentifierRules.migratingOutboxRecords(records)
        if migrated != records { save(migrated, key: Self.sharedHabitsOutboxKey) }
        return migrated
    }

    func sharedNightRecords() -> [NightFlockSharedNightOutboxRecord] {
        load([NightFlockSharedNightOutboxRecord].self, key: Self.sharedNightOutboxKey) ?? []
    }

    func sharedNightPlanPrivacyFences() -> [SharedNightPlanCancellation] {
        load([SharedNightPlanCancellation].self, key: Self.sharedNightPlanPrivacyFencesKey) ?? []
    }

    func recordSharedNightPlanPrivacyFence(_ cancellation: SharedNightPlanCancellation, epoch: UInt64) {
        guard admits(epoch) else { return }
        save(
            SharedNightPlanCancellationRules.merging(cancellation, into: sharedNightPlanPrivacyFences()),
            key: Self.sharedNightPlanPrivacyFencesKey
        )
    }

    func primaryRunSharingPolicyRequiredAfter() -> Date { primaryRunSharingRequiredAfter }

    func primaryRunSharingDecisions() -> [NightFlockPrimaryRunSharingDecision] {
        load([NightFlockPrimaryRunSharingDecision].self, key: Self.primaryRunSharingDecisionsKey) ?? []
    }

    @discardableResult
    func savePrimaryRunSharingDecision(_ decision: NightFlockPrimaryRunSharingDecision, epoch: UInt64) -> Bool {
        lookupOrCreatePrimaryRunSharingDecision(decision, epoch: epoch) != nil
    }

    /// Atomically preserves the first durable selection for a run. Automatic
    /// callbacks can resume before the view model has restored its in-memory
    /// decisions, so replacement here would silently undo a private choice.
    func lookupOrCreatePrimaryRunSharingDecision(
        _ incoming: NightFlockPrimaryRunSharingDecision,
        epoch: UInt64
    ) -> NightFlockPrimaryRunSharingDecision? {
        guard NightFlockAccountDeletionIntentPolicy.permitsOrdinaryIntentTransition(
            phase: accountDeletionPhase, callerEpoch: epoch, acceptedEpoch: acceptedMutationEpoch
        ) else { return nil }
        let existing = primaryRunSharingDecisions().first { $0.runID == incoming.runID }
        let decision = NightFlockPrimaryRunSharingDecisionRules.durableDecision(
            incoming: incoming,
            existing: existing
        )
        guard existing == nil else { return decision }
        var decisions = primaryRunSharingDecisions()
        decisions.append(decision)
        save(Array(decisions.sorted { $0.capturedAt < $1.capturedAt }.suffix(96)), key: Self.primaryRunSharingDecisionsKey)
        return decision
    }

    func nextSharedNightPlanRevision(
        partyID: UUID,
        memberEpochID: UUID,
        nightEndingDate: NightFlockLocalDate,
        observedRevision: Int64,
        epoch: UInt64
    ) -> Int64? {
        guard admits(epoch) else { return nil }
        let existing = load([NightFlockSharedNightPlanRevisionLedgerEntry].self, key: Self.sharedNightPlanRevisionLedgerKey) ?? []
        let revision = NightFlockSharedNightPlanRevisionRules.nextRevision(
            existing: existing, partyID: partyID, memberEpochID: memberEpochID,
            nightEndingDate: nightEndingDate, observedRevision: observedRevision
        )
        let entry = NightFlockSharedNightPlanRevisionLedgerEntry(
            partyID: partyID, memberEpochID: memberEpochID, nightEndingDate: nightEndingDate,
            revision: revision, updatedAt: Date()
        )
        save(NightFlockSharedNightPlanRevisionRules.merging(entry, into: existing), key: Self.sharedNightPlanRevisionLedgerKey)
        return revision
    }

    func recordSharedNightPlanBinding(_ plan: SharedNightPlan, epoch: UInt64) {
        guard admits(epoch) else { return }
        var entries = load([NightFlockSharedNightPlanBindingLedgerEntry].self, key: Self.sharedNightPlanBindingLedgerKey) ?? []
        let incoming = NightFlockSharedNightPlanBindingLedgerEntry(plan: plan, updatedAt: Date())
        entries.removeAll { $0.identity == incoming.identity }
        entries.append(incoming)
        save(Array(entries.sorted { $0.updatedAt > $1.updatedAt }.prefix(256)), key: Self.sharedNightPlanBindingLedgerKey)
    }

    func sharedNightPlanBinding(partyID: UUID, memberEpochID: UUID, nightEndingDate: NightFlockLocalDate) -> SharedNightPlan? {
        let identity = NightFlockSharedNightPlanBindingLedgerEntry(plan: .init(planID: UUID(), partyID: partyID, memberID: UUID(), memberEpochID: memberEpochID, agreementID: UUID(), revision: 0, nightEndingDate: nightEndingDate, timeZoneIdentifier: "UTC", plannedWindDownStart: .distantPast, intendedBedtime: .distantPast, intendedWakeTime: .distantPast, morningQuietEnd: .distantPast, beforeBedMinutes: 0, afterWakingMinutes: 0, eveningSuggestionIDs: [], morningSuggestionIDs: []), updatedAt: .distantPast).identity
        return (load([NightFlockSharedNightPlanBindingLedgerEntry].self, key: Self.sharedNightPlanBindingLedgerKey) ?? []).first(where: { $0.identity == identity })?.plan
    }

    func removeSharedNightPlanBinding(
        partyID: UUID,
        memberEpochID: UUID,
        nightEndingDate: NightFlockLocalDate,
        epoch: UInt64
    ) {
        guard admits(epoch) else { return }
        removeSharedNightPlanBindingPersisted(
            partyID: partyID,
            memberEpochID: memberEpochID,
            nightEndingDate: nightEndingDate
        )
    }

    private func removeSharedNightPlanBindingPersisted(
        partyID: UUID,
        memberEpochID: UUID,
        nightEndingDate: NightFlockLocalDate
    ) {
        let identity = NightFlockSharedNightPlanBindingLedgerEntry(plan: .init(planID: UUID(), partyID: partyID, memberID: UUID(), memberEpochID: memberEpochID, agreementID: UUID(), revision: 0, nightEndingDate: nightEndingDate, timeZoneIdentifier: "UTC", plannedWindDownStart: .distantPast, intendedBedtime: .distantPast, intendedWakeTime: .distantPast, morningQuietEnd: .distantPast, beforeBedMinutes: 0, afterWakingMinutes: 0, eveningSuggestionIDs: [], morningSuggestionIDs: []), updatedAt: .distantPast).identity
        let entries = (load([NightFlockSharedNightPlanBindingLedgerEntry].self, key: Self.sharedNightPlanBindingLedgerKey) ?? [])
            .filter { $0.identity != identity }
        save(entries, key: Self.sharedNightPlanBindingLedgerKey)
    }

    func enqueueSharedNight(_ record: NightFlockSharedNightOutboxRecord, epoch: UInt64) -> Bool {
        guard admits(epoch), let merged = NightFlockSharedNightOutboxRules.merge(record, into: sharedNightRecords()) else { return false }
        save(merged, key: Self.sharedNightOutboxKey)
        return true
    }

    /// A plan cancellation changes two durable local facts: the command that
    /// must travel and the plan version receipts are allowed to bind.  Keep
    /// those writes in this actor turn so an older in-flight plan response
    /// cannot squeeze between enqueue and binding removal.
    @discardableResult
    func enqueueSharedNightCancellationAndClearBinding(
        _ record: NightFlockSharedNightOutboxRecord,
        epoch: UInt64
    ) -> Bool {
        guard admits(epoch),
              case let .cancellation(cancellation) = record.payload,
              record.partyID == cancellation.partyID,
              record.agreementID == cancellation.agreementID,
              record.memberEpochID == cancellation.memberEpochID,
              let merged = NightFlockSharedNightOutboxRules.merge(record, into: sharedNightRecords())
        else { return false }

        // Cancellation merge may make room only by evicting ordinary plan or
        // receipt work; it never evicts another tombstone. Never clear an
        // acknowledged plan binding unless this cancellation is now durable.
        save(merged, key: Self.sharedNightOutboxKey)
        removeSharedNightPlanBindingPersisted(
            partyID: cancellation.partyID,
            memberEpochID: cancellation.memberEpochID,
            nightEndingDate: cancellation.nightEndingDate
        )
        return true
    }

    func removeSharedNight(_ record: NightFlockSharedNightOutboxRecord, epoch: UInt64) {
        guard admits(epoch) else { return }
        // A fresh correction may replace the same logical item while a
        // request is in flight. The physical id and serialized command must
        // both match, so an old acknowledgement cannot erase its successor.
        save(
            NightFlockSharedNightOutboxRules.acknowledging(record, in: sharedNightRecords()),
            key: Self.sharedNightOutboxKey
        )
        if case let .cancellation(cancellation) = record.payload {
            // A cancellation is authoritative even when its server response
            // is stale. Never leave a local frozen-plan binding behind it.
            removeSharedNightPlanBindingPersisted(
                partyID: cancellation.partyID,
                memberEpochID: cancellation.memberEpochID,
                nightEndingDate: cancellation.nightEndingDate
            )
        }
    }

    /// Commits the acknowledgement and its binding in one actor turn. If a
    /// cancellation superseded the in-flight plan before this turn, the plan
    /// is no longer current and cannot recreate a binding after cancellation.
    @discardableResult
    func acknowledgeSharedNightPlan(
        _ record: NightFlockSharedNightOutboxRecord,
        plan: SharedNightPlan,
        acknowledgement: SharedNightPlanBindingPolicy.Acknowledgement,
        epoch: UInt64
    ) -> Bool {
        guard admits(epoch) else { return false }
        let records = sharedNightRecords()
        let queuedCancellation = NightFlockSharedNightOutboxRules.hasQueuedCancellation(for: plan, in: records)
        let hasNewerQueuedPlan = NightFlockSharedNightOutboxRules.hasNewerQueuedPlan(than: plan, in: records)
        let existingBinding = sharedNightPlanBinding(
            partyID: plan.partyID,
            memberEpochID: plan.memberEpochID,
            nightEndingDate: plan.nightEndingDate
        )
        let planIsStillCurrent = NightFlockSharedNightOutboxRules.shouldRecordPlanBinding(
            for: record,
            plan: plan,
            serverAcceptedBinding: acknowledgement == .bind,
            in: records
        )
        save(
            NightFlockSharedNightOutboxRules.acknowledging(record, in: records),
            key: Self.sharedNightOutboxKey
        )
        if planIsStillCurrent, acknowledgement == .bind {
            recordSharedNightPlanBinding(plan, epoch: epoch)
            return true
        }
        if SharedNightPlanBindingPolicy.shouldClearBinding(
            binding: existingBinding,
            acknowledgedPlan: plan,
            acknowledgement: acknowledgement,
            queuedCancellation: queuedCancellation,
            hasNewerQueuedPlan: hasNewerQueuedPlan
        ) {
            removeSharedNightPlanBindingPersisted(
                partyID: plan.partyID,
                memberEpochID: plan.memberEpochID,
                nightEndingDate: plan.nightEndingDate
            )
        }
        return false
    }

    func markSharedNightAttempt(_ record: NightFlockSharedNightOutboxRecord, epoch: UInt64) {
        guard admits(epoch) else { return }
        var records = sharedNightRecords()
        // Do not increment a newer replacement for the same night after an
        // older in-flight transport attempt fails.
        records = NightFlockSharedNightOutboxRules.markingAttempt(record, in: records)
        save(records, key: Self.sharedNightOutboxKey)
    }

    /// Returns false when the bounded queue is full. It never evicts a
    /// sensitive publication silently; the caller keeps the local record and
    /// asks the person to retry once sharing can travel.
    func sharedHabitsFormerParties() -> [NightFlockSharedHabitsFormerParty] {
        load([NightFlockSharedHabitsFormerParty].self, key: Self.sharedHabitsFormerPartiesKey) ?? []
    }

    func recordSharedHabitsFormerParty(_ partyID: UUID, epoch: UInt64) {
        guard NightFlockAccountDeletionIntentPolicy.permitsOrdinaryIntentTransition(
            phase: accountDeletionPhase,
            callerEpoch: epoch,
            acceptedEpoch: acceptedMutationEpoch
        ) else { return }
        var parties = sharedHabitsFormerParties().filter { $0.partyID != partyID }
        parties.append(.init(partyID: partyID, leftAt: Date()))
        save(Array(parties.suffix(16)), key: Self.sharedHabitsFormerPartiesKey)
    }

    func removeSharedHabitsFormerParty(_ partyID: UUID, epoch: UInt64) {
        guard NightFlockAccountDeletionIntentPolicy.permitsOrdinaryIntentTransition(
            phase: accountDeletionPhase,
            callerEpoch: epoch,
            acceptedEpoch: acceptedMutationEpoch
        ) else { return }
        save(sharedHabitsFormerParties().filter { $0.partyID != partyID }, key: Self.sharedHabitsFormerPartiesKey)
    }

    func hasMigratedSharedHabits(agreementID: UUID) -> Bool {
        (load([UUID].self, key: Self.sharedHabitsMigratedAgreementIDsKey) ?? []).contains(agreementID)
    }

    func markSharedHabitsMigrated(agreementID: UUID, epoch: UInt64) {
        guard admits(epoch) else { return }
        var ids = load([UUID].self, key: Self.sharedHabitsMigratedAgreementIDsKey) ?? []
        guard !ids.contains(agreementID) else { return }
        ids.append(agreementID)
        save(Array(ids.suffix(64)), key: Self.sharedHabitsMigratedAgreementIDsKey)
    }

    func stageSharedHabitsJoinAgreementIntent(commandID: UUID, timeZoneIdentifier: String, epoch: UInt64) -> Bool {
        guard admits(epoch) else { return false }
        save(NightFlockSharedHabitsJoinAgreementIntent(commandID: commandID, partyID: nil, timeZoneIdentifier: timeZoneIdentifier, createdAt: Date()), key: Self.sharedHabitsJoinAgreementIntentKey)
        return true
    }

    func resolveSharedHabitsJoinAgreementIntent(commandID: UUID, partyID: UUID, epoch: UInt64) -> NightFlockSharedHabitsJoinAgreementIntent? {
        guard admits(epoch),
              let intent = NightFlockSharedHabitsJoinAgreementIntentPolicy.resolving(
                load(NightFlockSharedHabitsJoinAgreementIntent.self, key: Self.sharedHabitsJoinAgreementIntentKey),
                commandID: commandID,
                partyID: partyID
              )
        else { return nil }
        save(intent, key: Self.sharedHabitsJoinAgreementIntentKey)
        return intent
    }

    func sharedHabitsJoinAgreementIntent(epoch: UInt64) -> NightFlockSharedHabitsJoinAgreementIntent? {
        guard admits(epoch) else { return nil }
        return load(NightFlockSharedHabitsJoinAgreementIntent.self, key: Self.sharedHabitsJoinAgreementIntentKey)
    }

    func clearSharedHabitsJoinAgreementIntent(partyID: UUID, epoch: UInt64) {
        guard admits(epoch),
              load(NightFlockSharedHabitsJoinAgreementIntent.self, key: Self.sharedHabitsJoinAgreementIntentKey)?.partyID == partyID
        else { return }
        defaults.removeObject(forKey: Self.sharedHabitsJoinAgreementIntentKey)
    }

    func sharedHabitsSleepPublication(
        nightEndingDate: NightFlockLocalDate,
        timeZoneIdentifier: String,
        minutes: Int,
        epoch: UInt64
    ) -> NightFlockSharedHabitsSleepPublicationLedger? {
        guard admits(epoch) else { return nil }
        var entries = sharedHabitsSleepPublicationLedger()
        if let index = entries.firstIndex(where: { $0.nightEndingDate == nightEndingDate && $0.timeZoneIdentifier == timeZoneIdentifier }) {
            // Delivery is party authority-scoped in the shared outbox. A
            // global acknowledgement must never suppress the same window for
            // another party that has not yet accepted its own receipt.
            if entries[index].minutes == minutes { return entries[index] }
            guard entries[index].revision < Int64.max else { return nil }
            entries[index].minutes = minutes
            entries[index].revision += 1
            entries[index].delivered = false
            entries[index].deliveries = NightFlockSharedHabitsSleepDeliveryPolicy.resettingForNewRevision()
            save(entries, key: Self.sharedHabitsSleepPublicationLedgerKey)
            return entries[index]
        }
        let entry = NightFlockSharedHabitsSleepPublicationLedger(
            sourceID: NightFlockSharedHabitsSleepIdentifierRules.sourceID(nightEndingDate: nightEndingDate, timeZoneIdentifier: timeZoneIdentifier),
            nightEndingDate: nightEndingDate, timeZoneIdentifier: timeZoneIdentifier,
            minutes: max(0, minutes), revision: 1, delivered: false, deliveries: []
        )
        entries.append(entry)
        save(entries, key: Self.sharedHabitsSleepPublicationLedgerKey)
        return entry
    }

    func hasSharedHabitsSleepDelivery(
        sourceID: UUID,
        revision: Int64,
        partyID: UUID,
        agreementID: UUID,
        memberEpochID: UUID,
        epoch: UInt64
    ) -> Bool {
        guard admits(epoch),
              let entry = sharedHabitsSleepPublicationLedger()
                .first(where: { $0.sourceID == sourceID && $0.revision == revision })
        else { return false }
        return NightFlockSharedHabitsSleepDeliveryPolicy.contains(
            entry.deliveries,
            partyID: partyID,
            agreementID: agreementID,
            memberEpochID: memberEpochID
        )
    }

    func markSharedHabitsSleepDelivery(
        sourceID: UUID,
        revision: Int64,
        partyID: UUID,
        agreementID: UUID,
        memberEpochID: UUID,
        epoch: UInt64
    ) {
        guard admits(epoch) else { return }
        var entries = sharedHabitsSleepPublicationLedger()
        guard let index = entries.firstIndex(where: { $0.sourceID == sourceID && $0.revision == revision }) else { return }
        entries[index].deliveries = NightFlockSharedHabitsSleepDeliveryPolicy.adding(
            .init(partyID: partyID, agreementID: agreementID, memberEpochID: memberEpochID),
            to: entries[index].deliveries
        )
        save(entries, key: Self.sharedHabitsSleepPublicationLedgerKey)
    }


    func sharedHabitsAgreementAttempt(partyID: UUID, memberID: UUID, timeZoneIdentifier: String, epoch: UInt64) -> UUID? {
        guard admits(epoch) else { return nil }
        var attempts = load([NightFlockSharedHabitsAgreementAttempt].self, key: Self.sharedHabitsAgreementAttemptsKey) ?? []
        if let current = attempts.first(where: { $0.partyID == partyID && $0.memberID == memberID && $0.timeZoneIdentifier == timeZoneIdentifier }) {
            return current.seed
        }
        let seed = UUID()
        attempts.removeAll { $0.partyID == partyID && $0.memberID != memberID }
        attempts.append(.init(partyID: partyID, memberID: memberID, timeZoneIdentifier: timeZoneIdentifier, seed: seed))
        save(attempts, key: Self.sharedHabitsAgreementAttemptsKey)
        return seed
    }

    func clearSharedHabitsAgreementAttempt(partyID: UUID, memberID: UUID, epoch: UInt64) {
        guard admits(epoch) else { return }
        let attempts = (load([NightFlockSharedHabitsAgreementAttempt].self, key: Self.sharedHabitsAgreementAttemptsKey) ?? [])
            .filter { !($0.partyID == partyID && $0.memberID == memberID) }
        save(attempts, key: Self.sharedHabitsAgreementAttemptsKey)
    }

    func sharedHabitsPendingProjections() -> [NightFlockSharedHabitsPendingProjection] {
        let projections = load([NightFlockSharedHabitsPendingProjection].self, key: Self.sharedHabitsPendingProjectionsKey) ?? []
        let migrated = NightFlockSharedHabitsSleepIdentifierRules.migratingPendingProjections(projections)
        if migrated != projections { save(migrated, key: Self.sharedHabitsPendingProjectionsKey) }
        return migrated
    }

    func enqueueSharedHabitsPending(_ pending: NightFlockSharedHabitsPendingProjection, epoch: UInt64) -> Bool {
        guard admits(epoch) else { return false }
        var values = sharedHabitsPendingProjections()
        let replacesExisting = values.contains { $0.partyID == pending.partyID && $0.projection.sourceID == pending.projection.sourceID && $0.projection.kind == pending.projection.kind && $0.projection.revision <= pending.projection.revision }
        guard values.count < 128 || replacesExisting else { return false }
        values.removeAll { $0.partyID == pending.partyID && $0.projection.sourceID == pending.projection.sourceID && $0.projection.kind == pending.projection.kind && $0.projection.revision <= pending.projection.revision }
        values.append(pending)
        save(values, key: Self.sharedHabitsPendingProjectionsKey)
        return true
    }

    func removeSharedHabitsPending(_ pending: NightFlockSharedHabitsPendingProjection, epoch: UInt64) {
        guard admits(epoch) else { return }
        save(sharedHabitsPendingProjections().filter { $0.id != pending.id }, key: Self.sharedHabitsPendingProjectionsKey)
    }

    func enqueueSharedHabits(_ record: NightFlockSharedHabitsOutboxRecord, epoch: UInt64) -> Bool {
        guard admits(epoch),
              let merged = NightFlockSharedHabitsOutboxRules.merge(record, into: sharedHabitsRecords())
        else { return false }
        save(merged, key: Self.sharedHabitsOutboxKey)
        return true
    }

    func removeSharedHabits(_ record: NightFlockSharedHabitsOutboxRecord, epoch: UInt64) {
        guard admits(epoch) else { return }
        save(
            NightFlockSharedHabitsOutboxRules.acknowledging(record, in: sharedHabitsRecords()),
            key: Self.sharedHabitsOutboxKey
        )
    }

    /// A server tombstone applies to one source in one party authority. Keep
    /// unrelated current/future records available to travel.
    func dropSharedHabitsSource(
        _ sourceID: UUID?,
        recordID: UUID,
        partyID: UUID,
        epoch: UInt64
    ) {
        guard admits(epoch) else { return }
        save(sharedHabitsRecords().filter { queued in
            guard queued.record.partyID == partyID else { return true }
            if let sourceID {
                return queued.record.sourceID != sourceID
            }
            return queued.record.recordID != recordID
        }, key: Self.sharedHabitsOutboxKey)
    }

    func markSharedHabitsAttempt(_ record: NightFlockSharedHabitsOutboxRecord, epoch: UInt64) {
        guard admits(epoch) else { return }
        save(
            NightFlockSharedHabitsOutboxRules.markingAttempt(record, in: sharedHabitsRecords()),
            key: Self.sharedHabitsOutboxKey
        )
    }

    /// A party that is leaving must never retain queued material to replay
    /// through a future membership epoch.
    func dropSharedHabits(for partyID: UUID, epoch: UInt64) -> Bool {
        guard NightFlockAccountDeletionIntentPolicy.permitsOrdinaryIntentTransition(
            phase: accountDeletionPhase,
            callerEpoch: epoch,
            acceptedEpoch: acceptedMutationEpoch
        ) else { return false }
        save(sharedHabitsRecords().filter { $0.record.partyID != partyID }, key: Self.sharedHabitsOutboxKey)
        save(sharedNightRecords().filter { $0.partyID != partyID }, key: Self.sharedNightOutboxKey)
        let ledgers = load([NightFlockSharedNightPlanRevisionLedgerEntry].self, key: Self.sharedNightPlanRevisionLedgerKey) ?? []
        save(ledgers.filter { $0.partyID != partyID }, key: Self.sharedNightPlanRevisionLedgerKey)
        let bindings = load([NightFlockSharedNightPlanBindingLedgerEntry].self, key: Self.sharedNightPlanBindingLedgerKey) ?? []
        save(bindings.filter { $0.plan.partyID != partyID }, key: Self.sharedNightPlanBindingLedgerKey)
        save(sharedHabitsPendingProjections().filter { $0.partyID != partyID }, key: Self.sharedHabitsPendingProjectionsKey)
        return true
    }

    func stageSharedHabitsPrivacyFence(
        _ fence: NightFlockSharedHabitsPrivacyFence,
        epoch: UInt64
    ) -> Bool {
        guard NightFlockAccountDeletionIntentPolicy.permitsOrdinaryIntentTransition(
            phase: accountDeletionPhase,
            callerEpoch: epoch,
            acceptedEpoch: acceptedMutationEpoch
        ) else { return false }
        save(
            NightFlockSharedHabitsFencePolicy.replacing(sharedHabitsPrivacyFences(), with: fence),
            key: Self.sharedHabitsPrivacyFencesKey
        )
        return true
    }

    func removeSharedHabitsPrivacyFence(
        partyID: UUID,
        epoch: UInt64
    ) -> Bool {
        guard NightFlockAccountDeletionIntentPolicy.permitsOrdinaryIntentTransition(
            phase: accountDeletionPhase,
            callerEpoch: epoch,
            acceptedEpoch: acceptedMutationEpoch
        ) else { return false }
        save(
            sharedHabitsPrivacyFences().filter { $0.partyID != partyID },
            key: Self.sharedHabitsPrivacyFencesKey
        )
        return true
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
        defaults.removeObject(forKey: Self.sharedHabitsPrivacyFencesKey)
        defaults.removeObject(forKey: Self.sharedHabitsOutboxKey)
        defaults.removeObject(forKey: Self.sharedHabitsPendingProjectionsKey)
        defaults.removeObject(forKey: Self.sharedHabitsAgreementAttemptsKey)
        defaults.removeObject(forKey: Self.sharedHabitsSleepPublicationLedgerKey)
        defaults.removeObject(forKey: Self.sharedHabitsJoinAgreementIntentKey)
        defaults.removeObject(forKey: Self.sharedHabitsMigratedAgreementIDsKey)
        defaults.removeObject(forKey: Self.sharedHabitsFormerPartiesKey)
        defaults.removeObject(forKey: Self.sharedNightOutboxKey)
        defaults.removeObject(forKey: Self.sharedNightPlanRevisionLedgerKey)
        defaults.removeObject(forKey: Self.sharedNightPlanBindingLedgerKey)
        defaults.removeObject(forKey: Self.sharedNightPlanPrivacyFencesKey)
        defaults.removeObject(forKey: Self.primaryRunSharingDecisionsKey)
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
        defaults.removeObject(forKey: Self.sharedHabitsPrivacyFencesKey)
        defaults.removeObject(forKey: Self.sharedHabitsOutboxKey)
        defaults.removeObject(forKey: Self.sharedHabitsPendingProjectionsKey)
        defaults.removeObject(forKey: Self.sharedHabitsAgreementAttemptsKey)
        defaults.removeObject(forKey: Self.sharedHabitsSleepPublicationLedgerKey)
        defaults.removeObject(forKey: Self.sharedHabitsJoinAgreementIntentKey)
        defaults.removeObject(forKey: Self.sharedHabitsMigratedAgreementIDsKey)
        defaults.removeObject(forKey: Self.sharedHabitsFormerPartiesKey)
        defaults.removeObject(forKey: Self.sharedNightOutboxKey)
        defaults.removeObject(forKey: Self.sharedNightPlanRevisionLedgerKey)
        defaults.removeObject(forKey: Self.sharedNightPlanBindingLedgerKey)
        defaults.removeObject(forKey: Self.sharedNightPlanPrivacyFencesKey)
        defaults.removeObject(forKey: Self.primaryRunSharingDecisionsKey)
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
        !pendingIntentClosed
            && permitsSharedHabitsPublication()
            && NightFlockAccountDeletionIntentPolicy.permitsActorMutation(
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

    private func sharedHabitsSleepPublicationLedger() -> [NightFlockSharedHabitsSleepPublicationLedger] {
        let entries = load([NightFlockSharedHabitsSleepPublicationLedger].self, key: Self.sharedHabitsSleepPublicationLedgerKey) ?? []
        let migrated = NightFlockSharedHabitsSleepIdentifierRules.migratingSleepLedger(entries)
        if migrated != entries { save(migrated, key: Self.sharedHabitsSleepPublicationLedgerKey) }
        return migrated
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
