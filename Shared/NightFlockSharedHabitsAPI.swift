import Foundation

/// Versioned archive transport, deliberately separate from the account-wide V4 activity ledger.
enum NightFlockSharedHabitsListCapability: Int, Codable, Sendable { case v1 = 1, v2 = 2 }

struct NightFlockRetainedSharedHabitParty: Codable, Equatable, Sendable, Identifiable {
    var id: UUID { partyID }
    var partyID: UUID
    var partyName: String
    var recordCount: Int
}

struct NightFlockSharedHabitsStateRequest: Encodable, Sendable {
    let schemaVersion = NightFlockV4Rules.schemaVersion
    let scope: String
    var partyID: UUID
    var cursor: String?

    init(partyID: UUID, cursor: String? = nil, scope: String = "habits") {
        self.partyID = partyID
        self.cursor = cursor
        self.scope = scope
    }
}

struct NightFlockSharedHabitRecord: Codable, Identifiable, Equatable, Sendable {
    var id: UUID { recordID }
    var recordID: UUID
    var partyID: UUID
    var memberID: UUID
    /// Returned only for the record owner; peers use the opaque record ID.
    var sourceID: UUID?
    var revision: Int64
    var kind: NightFlockSharedHabitKind
    var localDate: NightFlockLocalDate?
    /// Coarse legacy activity date, never a substitute for a nightly anchor.
    var activityDate: NightFlockLocalDate? = nil
    var timeZoneIdentifier: String
    var minutes: Int
    var outcome: NightFlockSharedHabitOutcome?
    var protectionMinutes: Int?
    var evidence: NightFlockSharedHabitEvidence
    var profileSnapshot: NightFlockSharedHabitProfileSnapshot
    var isFormerMember: Bool
    /// Migration time labels a legacy activity whose original local date is unknown.
    var migratedAt: Date?
}

struct NightFlockSharedHabitProfileSnapshot: Codable, Equatable, Sendable {
    var displayName: String
    var avatarID: String?
}

struct NightFlockSharedHabitPeriodSummary: Codable, Equatable, Sendable {
    enum Period: String, Codable, Sendable { case lastNight, last7Nights, last30Nights }
    var memberID: UUID
    var kind: NightFlockSharedHabitKind
    var period: Period
    var endingOn: NightFlockLocalDate
    var availableNights: Int
    var coveredNights: Int
    var averageMinutes: Double?
    var method: String
}

struct NightFlockSharedHabitsAgreementReceipt: Codable, Equatable, Sendable {
    var agreementID: UUID
    var memberEpochID: UUID
    var acceptedAt: Date
    var timeZoneIdentifier: String
    var firstEligibleSleepNight: NightFlockLocalDate?
    var agreementVersion: Int = 1

    private enum CodingKeys: String, CodingKey {
        case agreementID, memberEpochID, acceptedAt, timeZoneIdentifier, firstEligibleSleepNight, agreementVersion
    }

    init(
        agreementID: UUID,
        memberEpochID: UUID,
        acceptedAt: Date,
        timeZoneIdentifier: String,
        firstEligibleSleepNight: NightFlockLocalDate?,
        agreementVersion: Int = 1
    ) {
        self.agreementID = agreementID
        self.memberEpochID = memberEpochID
        self.acceptedAt = acceptedAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.firstEligibleSleepNight = firstEligibleSleepNight
        self.agreementVersion = agreementVersion
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        agreementID = try values.decode(UUID.self, forKey: .agreementID)
        memberEpochID = try values.decode(UUID.self, forKey: .memberEpochID)
        acceptedAt = try values.decode(Date.self, forKey: .acceptedAt)
        timeZoneIdentifier = try values.decode(String.self, forKey: .timeZoneIdentifier)
        firstEligibleSleepNight = try values.decodeIfPresent(NightFlockLocalDate.self, forKey: .firstEligibleSleepNight)
        agreementVersion = try values.decodeIfPresent(Int.self, forKey: .agreementVersion) ?? 1
    }
}

struct NightFlockSharedHabitsStateResponse: Decodable, Equatable, Sendable {
    var agreement: NightFlockSharedHabitsAgreementReceipt?
    var records: [NightFlockSharedHabitRecord]
    var nextCursor: String?
    var snapshotRevision: Int
    var periods: [NightFlockSharedHabitPeriodSummary]
    /// V2 additions are optional so a v1 archive remains decodable.
    var sharedNightPlans: [SharedNightPlan] = []
    var sharedNightReceipts: [SharedNightReceipt] = []
    /// A v2-only cursor is intentionally independent from the legacy habits archive.
    var sharedNightsNextCursor: String?
    var sharedNightsSnapshotRevision: Int?

    private enum CodingKeys: String, CodingKey {
        case agreement, records, nextCursor, snapshotRevision, periods, sharedNightPlans, sharedNightReceipts, sharedNightsNextCursor, sharedNightsSnapshotRevision
    }

    init(
        agreement: NightFlockSharedHabitsAgreementReceipt?,
        records: [NightFlockSharedHabitRecord],
        nextCursor: String?,
        snapshotRevision: Int,
        periods: [NightFlockSharedHabitPeriodSummary],
        sharedNightPlans: [SharedNightPlan] = [],
        sharedNightReceipts: [SharedNightReceipt] = [],
        sharedNightsNextCursor: String? = nil,
        sharedNightsSnapshotRevision: Int? = nil
    ) {
        self.agreement = agreement
        self.records = records
        self.nextCursor = nextCursor
        self.snapshotRevision = snapshotRevision
        self.periods = periods
        self.sharedNightPlans = sharedNightPlans
        self.sharedNightReceipts = sharedNightReceipts
        self.sharedNightsNextCursor = sharedNightsNextCursor
        self.sharedNightsSnapshotRevision = sharedNightsSnapshotRevision
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        agreement = try values.decodeIfPresent(NightFlockSharedHabitsAgreementReceipt.self, forKey: .agreement)
        records = try values.decode([NightFlockSharedHabitRecord].self, forKey: .records)
        nextCursor = try values.decodeIfPresent(String.self, forKey: .nextCursor)
        snapshotRevision = try values.decode(Int.self, forKey: .snapshotRevision)
        periods = try values.decode([NightFlockSharedHabitPeriodSummary].self, forKey: .periods)
        sharedNightPlans = try values.decodeIfPresent([SharedNightPlan].self, forKey: .sharedNightPlans) ?? []
        sharedNightReceipts = try values.decodeIfPresent([SharedNightReceipt].self, forKey: .sharedNightReceipts) ?? []
        sharedNightsNextCursor = try values.decodeIfPresent(String.self, forKey: .sharedNightsNextCursor)
        sharedNightsSnapshotRevision = try values.decodeIfPresent(Int.self, forKey: .sharedNightsSnapshotRevision)
    }
}

struct NightFlockSharedHabitsCommandResponse: Decodable, Equatable, Sendable {
    var accepted: Bool
    var staleRevision: Bool?
    var agreementID: UUID?
    var memberEpochID: UUID?
    var archiveRevision: Int64?
}

enum NightFlockSharedHabitsCommand: Sendable {
    case acceptAgreement(partyID: UUID, agreementVersion: Int = 1, timeZoneIdentifier: String, idempotencyKey: String)
    case publish(record: NightFlockSharedHabitRecord, agreementID: UUID, memberEpochID: UUID, idempotencyKey: String)
    case deleteSource(partyID: UUID, sourceID: UUID, idempotencyKey: String)
    case deleteAll(partyID: UUID, idempotencyKey: String)
    case migrate(partyID: UUID, agreementID: UUID, idempotencyKey: String)
    case publishNightPlan(SharedNightPlan, idempotencyKey: String)
    case cancelNightPlan(SharedNightPlanCancellation, idempotencyKey: String)
    case publishNightReceipt(SharedNightReceipt, idempotencyKey: String)
}

struct NightFlockSharedHabitsCommandRequest: Encodable, Sendable {
    let schemaVersion = NightFlockV4Rules.schemaVersion
    var command: NightFlockSharedHabitsCommand

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: DynamicCodingKey.self)
        try c.encode(schemaVersion, forKey: .init("schemaVersion"))
        switch command {
        case let .acceptAgreement(partyID, version, timeZoneIdentifier, key):
            try c.encode("acceptSharedHabitsAgreement", forKey: .init("command")); try c.encode(partyID, forKey: .init("partyID")); try c.encode(version, forKey: .init("agreementVersion")); try c.encode(timeZoneIdentifier, forKey: .init("timeZoneIdentifier")); try c.encode(key, forKey: .init("idempotencyKey"))
        case let .publish(record, agreementID, memberEpochID, key):
            guard let sourceID = record.sourceID, let localDate = record.localDate else { throw EncodingError.invalidValue(record, .init(codingPath: c.codingPath, debugDescription: "Publication requires sourceID and localDate")) }
            try c.encode("publishSharedHabit", forKey: .init("command")); try c.encode(record.partyID, forKey: .init("partyID")); try c.encode(agreementID, forKey: .init("agreementID")); try c.encode(memberEpochID, forKey: .init("memberEpochID")); try c.encode(sourceID, forKey: .init("sourceID")); try c.encode(record.revision, forKey: .init("revision")); try c.encode(record.kind, forKey: .init("kind")); try c.encode(localDate, forKey: .init("localDate")); try c.encode(record.timeZoneIdentifier, forKey: .init("timeZoneIdentifier")); try c.encode(record.minutes, forKey: .init("minutes")); try c.encodeIfPresent(record.outcome, forKey: .init("outcome")); try c.encodeIfPresent(record.protectionMinutes, forKey: .init("protectionMinutes")); try c.encode(record.evidence, forKey: .init("evidence")); try c.encode(key, forKey: .init("idempotencyKey"))
        case let .deleteSource(partyID, sourceID, key):
            try c.encode("deleteSharedHabitHistory", forKey: .init("command")); try c.encode(partyID, forKey: .init("partyID")); try c.encode(sourceID, forKey: .init("sourceID")); try c.encode(key, forKey: .init("idempotencyKey"))
        case let .deleteAll(partyID, key):
            try c.encode("deleteSharedHabitHistory", forKey: .init("command")); try c.encode(partyID, forKey: .init("partyID")); try c.encode(true, forKey: .init("allSources")); try c.encode(key, forKey: .init("idempotencyKey"))
        case let .migrate(partyID, agreementID, key):
            try c.encode("migrateSharedHabits", forKey: .init("command")); try c.encode(partyID, forKey: .init("partyID")); try c.encode(agreementID, forKey: .init("agreementID")); try c.encode(key, forKey: .init("idempotencyKey"))
        case let .publishNightPlan(plan, key):
            try c.encode("publishSharedNightPlan", forKey: .init("command")); try c.encode(plan.partyID, forKey: .init("partyID")); try c.encode(plan.planID, forKey: .init("planID")); try c.encode(plan.memberEpochID, forKey: .init("memberEpochID")); try c.encode(plan.agreementID, forKey: .init("agreementID")); try c.encode(plan.revision, forKey: .init("revision")); try c.encode(plan.nightEndingDate, forKey: .init("nightEndingDate")); try c.encode(plan.timeZoneIdentifier, forKey: .init("timeZoneIdentifier")); try c.encode(plan.plannedWindDownStart, forKey: .init("plannedWindDownStart")); try c.encode(plan.intendedBedtime, forKey: .init("intendedBedtime")); try c.encode(plan.intendedWakeTime, forKey: .init("intendedWakeTime")); try c.encode(plan.morningQuietEnd, forKey: .init("morningQuietEnd")); try c.encode(plan.beforeBedMinutes, forKey: .init("beforeBedMinutes")); try c.encode(plan.afterWakingMinutes, forKey: .init("afterWakingMinutes")); try c.encode(plan.eveningSuggestionIDs, forKey: .init("eveningSuggestionIDs")); try c.encode(plan.morningSuggestionIDs, forKey: .init("morningSuggestionIDs")); try c.encode(key, forKey: .init("idempotencyKey"))
        case let .cancelNightPlan(cancellation, key):
            try c.encode("cancelSharedNightPlan", forKey: .init("command")); try c.encode(cancellation.partyID, forKey: .init("partyID")); try c.encode(cancellation.memberEpochID, forKey: .init("memberEpochID")); try c.encode(cancellation.agreementID, forKey: .init("agreementID")); try c.encode(cancellation.revision, forKey: .init("revision")); try c.encode(cancellation.nightEndingDate, forKey: .init("nightEndingDate")); try c.encode(cancellation.timeZoneIdentifier, forKey: .init("timeZoneIdentifier")); try c.encode(cancellation.authority.rawValue, forKey: .init("cancellationAuthority")); try c.encode(key, forKey: .init("idempotencyKey"))
        case let .publishNightReceipt(receipt, key):
            try c.encode("publishSharedNightReceipt", forKey: .init("command")); try c.encode(receipt.partyID, forKey: .init("partyID")); try c.encode(receipt.receiptID, forKey: .init("receiptID")); try c.encode(receipt.memberEpochID, forKey: .init("memberEpochID")); try c.encode(receipt.agreementID, forKey: .init("agreementID")); try c.encodeIfPresent(receipt.planID, forKey: .init("planID")); try c.encodeIfPresent(receipt.planRevision, forKey: .init("planRevision")); try c.encodeIfPresent(receipt.sourceID, forKey: .init("sourceID")); try c.encode(receipt.revision, forKey: .init("revision")); try c.encode(receipt.nightEndingDate, forKey: .init("nightEndingDate")); try c.encode(receipt.timeZoneIdentifier, forKey: .init("timeZoneIdentifier")); try c.encodeIfPresent(receipt.actualStart, forKey: .init("actualStart")); try c.encodeIfPresent(receipt.terminalAt, forKey: .init("terminalAt")); try c.encode(receipt.outcome, forKey: .init("outcome")); try c.encodeIfPresent(receipt.windDownMinutes, forKey: .init("windDownMinutes")); try c.encodeIfPresent(receipt.protectionMinutes, forKey: .init("protectionMinutes")); try c.encode(receipt.protectionEvidence, forKey: .init("protectionEvidence")); try c.encodeIfPresent(receipt.emergencyExitUsed, forKey: .init("emergencyExitUsed")); try c.encode(key, forKey: .init("idempotencyKey"))
        }
    }
}

private struct DynamicCodingKey: CodingKey { var stringValue: String; init(_ value: String) { stringValue = value }; init?(stringValue: String) { self.stringValue = stringValue }; var intValue: Int? { nil }; init?(intValue: Int) { nil } }
