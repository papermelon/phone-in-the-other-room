import Foundation

/// Private, phone-authoritative state for the independent Screen-Free Morning.
/// It deliberately has no social or impact projection fields.
enum MorningQuietOccurrenceOutcome: String, Codable, Equatable {
    case scheduled
    case active
    case skipped
    case finished
}

enum MorningQuietOccurrenceIdentity {
    /// Stable, separate identity for the saved Morning attached to a Wind
    /// Down. It is reproducible after termination without sharing the run's
    /// registry entry or relying on a random foreground restore UUID.
    static func ordinary(for runID: UUID) -> UUID {
        for counter in 0...3 {
            if let candidate = candidate(for: runID, counter: counter), candidate != runID {
                return candidate
            }
        }
        // Deterministic byte change that is guaranteed distinct from source
        // if a pathological hash collision exhausts the rehash attempts. This
        // deliberately avoids a parsing or random-UUID fallback on restore.
        var bytes = runID.uuid
        bytes.0 = bytes.0 == 0 ? 1 : 0
        return UUID(uuid: bytes)
    }

    private static func candidate(for runID: UUID, counter: Int) -> UUID? {
        let input = Array("ollie.morning-occurrence.v1.\(counter):\(runID.uuidString.lowercased())".utf8)
        let high = fnv1a(input, seed: 0xcbf29ce484222325)
        let low = fnv1a(input, seed: 0x9e3779b97f4a7c15)
        var hex = String(format: "%016llx%016llx", high, low)
        // RFC 4122 v4/variant bits; domain-separated hashes make this stable
        // and separate from the source run ID without a foreground UUID.
        var characters = Array(hex)
        characters[12] = "4"
        let variant = Int(String(characters[16]), radix: 16) ?? 0
        characters[16] = Array("89ab")[variant & 0x03]
        hex = String(characters)
        let formatted = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20))"
        return UUID(uuidString: formatted)
    }

    private static func fnv1a(_ bytes: [UInt8], seed: UInt64) -> UInt64 {
        bytes.reduce(seed) { partial, byte in
            (partial ^ UInt64(byte)) &* 0x100000001b3
        }
    }
}

enum MorningQuietOccurrenceBoundary {
    /// The coordinator uses this pure reducer for the next foreground wakeup;
    /// a scheduled occurrence advances at its start and an active one at end.
    static func next(after date: Date, occurrences: [MorningQuietOccurrence]) -> Date? {
        occurrences.compactMap { occurrence -> Date? in
            switch occurrence.outcome {
            case .scheduled where occurrence.scheduledStart > date:
                return occurrence.scheduledStart
            case .active where occurrence.scheduledEnd > date:
                return occurrence.scheduledEnd
            case .scheduled, .active, .skipped, .finished:
                return nil
            }
        }.min()
    }
}

struct MorningQuietOccurrence: Codable, Equatable, Identifiable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: UUID
    var linkedWindDownRunID: UUID?
    var scheduleOccurrenceID: UUID
    var scheduledStart: Date
    var scheduledEnd: Date
    var actualStart: Date?
    var endedAt: Date?
    var outcome: MorningQuietOccurrenceOutcome
    /// Carries the user's per-run Live Activity choice beyond terminal Wind
    /// Down cleanup; older occurrences preserve the historic enabled default.
    var liveActivityRequested: Bool

    init(
        id: UUID = UUID(),
        linkedWindDownRunID: UUID? = nil,
        scheduleOccurrenceID: UUID = UUID(),
        scheduledStart: Date,
        scheduledEnd: Date,
        actualStart: Date? = nil,
        endedAt: Date? = nil,
        outcome: MorningQuietOccurrenceOutcome = .scheduled,
        liveActivityRequested: Bool = true
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.linkedWindDownRunID = linkedWindDownRunID
        self.scheduleOccurrenceID = scheduleOccurrenceID
        self.scheduledStart = scheduledStart
        self.scheduledEnd = max(scheduledStart.addingTimeInterval(60), scheduledEnd)
        self.actualStart = actualStart
        self.endedAt = endedAt
        self.outcome = outcome
        self.liveActivityRequested = liveActivityRequested
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, linkedWindDownRunID, scheduleOccurrenceID, scheduledStart, scheduledEnd
        case actualStart, endedAt, outcome, liveActivityRequested
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let start = try container.decode(Date.self, forKey: .scheduledStart)
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            linkedWindDownRunID: try container.decodeIfPresent(UUID.self, forKey: .linkedWindDownRunID),
            scheduleOccurrenceID: try container.decodeIfPresent(UUID.self, forKey: .scheduleOccurrenceID) ?? UUID(),
            scheduledStart: start,
            scheduledEnd: try container.decodeIfPresent(Date.self, forKey: .scheduledEnd)
                ?? start.addingTimeInterval(60),
            actualStart: try container.decodeIfPresent(Date.self, forKey: .actualStart),
            endedAt: try container.decodeIfPresent(Date.self, forKey: .endedAt),
            outcome: try container.decodeIfPresent(MorningQuietOccurrenceOutcome.self, forKey: .outcome)
                ?? .scheduled,
            liveActivityRequested: try container.decodeIfPresent(Bool.self, forKey: .liveActivityRequested) ?? true
        )
    }

    var configuredDurationMinutes: Int {
        max(1, Int(scheduledEnd.timeIntervalSince(scheduledStart) / 60))
    }

    func eligibleElapsedMinutes(at date: Date) -> Int {
        guard let actualStart else { return 0 }
        let terminal = min(endedAt ?? date, scheduledEnd)
        return min(configuredDurationMinutes, max(0, Int(terminal.timeIntervalSince(actualStart) / 60)))
    }
}

enum MorningQuietIntent: Equatable {
    case startNow
    case deferToUsualTime
    case skipToday
    case keepWindDownRunning
}

enum MorningQuietIntentEngine {
    static func isAvailable(run: FocusRun, at date: Date) -> Bool {
        guard run.isProgressionEligibleNightWatch,
              run.nightWatchPlan?.phase(at: date) == .overnight,
              ![.completed, .endedEarly, .setup].contains(run.state) else { return false }
        return true
    }

    static func occurrence(
        for intent: MorningQuietIntent,
        run: FocusRun,
        at date: Date,
        id: UUID = UUID(),
        scheduleOccurrenceID: UUID = UUID()
    ) -> MorningQuietOccurrence? {
        guard isAvailable(run: run, at: date), let plan = run.nightWatchPlan else { return nil }
        switch intent {
        case .keepWindDownRunning:
            return nil
        case .startNow:
            let end = date.addingTimeInterval(TimeInterval(plan.morningQuietMinutes * 60))
            return MorningQuietOccurrence(
                id: id,
                linkedWindDownRunID: run.id,
                scheduleOccurrenceID: scheduleOccurrenceID,
                scheduledStart: date,
                scheduledEnd: end,
                actualStart: date,
                outcome: .active,
                liveActivityRequested: run.liveActivityRequested
            )
        case .deferToUsualTime:
            return MorningQuietOccurrence(
                id: id,
                linkedWindDownRunID: run.id,
                scheduleOccurrenceID: scheduleOccurrenceID,
                scheduledStart: plan.wakeTime,
                scheduledEnd: plan.protectedUntil,
                outcome: .scheduled,
                liveActivityRequested: run.liveActivityRequested
            )
        case .skipToday:
            return MorningQuietOccurrence(
                id: id,
                linkedWindDownRunID: run.id,
                scheduleOccurrenceID: scheduleOccurrenceID,
                scheduledStart: plan.wakeTime,
                scheduledEnd: plan.protectedUntil,
                endedAt: date,
                outcome: .skipped,
                liveActivityRequested: run.liveActivityRequested
            )
        }
    }
}

struct WindDownBenefitSettlement: Codable, Equatable, Identifiable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: UUID { runID }
    var runID: UUID
    var entitledAt: Date
    var phoneAwaySpanMinutes: Int
    /// Stored privately until delivery. The search/farm projections are not authority.
    var searchOutcomeID: UUID?
    /// The resolved payload is immutable authority. It is intentionally kept
    /// out of SheepSearchState until an authorized terminal delivery projects it.
    var hiddenSearchOutcome: SheepSearchOutcome?
    /// Terminal-only projections are planned into the authority before their
    /// separate defaults writes. This makes a crash replay use identical IDs.
    var deliveredReward: RewardItem?
    var deliveredProgress: UserProgress?
    var resolvedAt: Date
    var deliveredAt: Date?
    var revealedAt: Date?

    init(
        runID: UUID,
        entitledAt: Date,
        phoneAwaySpanMinutes: Int,
        searchOutcomeID: UUID? = nil,
        hiddenSearchOutcome: SheepSearchOutcome? = nil,
        deliveredReward: RewardItem? = nil,
        deliveredProgress: UserProgress? = nil,
        resolvedAt: Date = Date(),
        deliveredAt: Date? = nil,
        revealedAt: Date? = nil
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.runID = runID
        self.entitledAt = entitledAt
        self.phoneAwaySpanMinutes = max(FocusRunRules.minimumProtectedNightSearchSpanMinutes, phoneAwaySpanMinutes)
        self.hiddenSearchOutcome = hiddenSearchOutcome
        self.searchOutcomeID = hiddenSearchOutcome?.id ?? searchOutcomeID
        self.deliveredReward = deliveredReward
        self.deliveredProgress = deliveredProgress
        self.resolvedAt = resolvedAt
        self.deliveredAt = deliveredAt
        self.revealedAt = revealedAt
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, runID, entitledAt, phoneAwaySpanMinutes, searchOutcomeID, hiddenSearchOutcome
        case deliveredReward, deliveredProgress
        case resolvedAt, deliveredAt, revealedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let runID = try container.decode(UUID.self, forKey: .runID)
        let outcome = try container.decodeIfPresent(SheepSearchOutcome.self, forKey: .hiddenSearchOutcome)
        self.init(
            runID: runID,
            entitledAt: try container.decode(Date.self, forKey: .entitledAt),
            phoneAwaySpanMinutes: try container.decodeIfPresent(Int.self, forKey: .phoneAwaySpanMinutes)
                ?? FocusRunRules.minimumProtectedNightSearchSpanMinutes,
            searchOutcomeID: try container.decodeIfPresent(UUID.self, forKey: .searchOutcomeID),
            hiddenSearchOutcome: outcome,
            deliveredReward: try container.decodeIfPresent(RewardItem.self, forKey: .deliveredReward),
            deliveredProgress: try container.decodeIfPresent(UserProgress.self, forKey: .deliveredProgress),
            resolvedAt: try container.decodeIfPresent(Date.self, forKey: .resolvedAt) ?? Date(),
            deliveredAt: try container.decodeIfPresent(Date.self, forKey: .deliveredAt),
            revealedAt: try container.decodeIfPresent(Date.self, forKey: .revealedAt)
        )
        schemaVersion = max(
            try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion,
            Self.currentSchemaVersion
        )
    }

    var isDelivered: Bool { deliveredAt != nil }
    var isRevealed: Bool { revealedAt != nil }

    /// A terminal-delivery retry must not recalculate under changed rules or
    /// mutable search state. Attach only the first deterministic resolution.
    mutating func attachHiddenOutcome(_ outcome: SheepSearchOutcome) {
        guard hiddenSearchOutcome == nil else { return }
        hiddenSearchOutcome = outcome
        searchOutcomeID = outcome.id
    }

    mutating func attachTerminalProjections(reward: RewardItem?, progress: UserProgress) {
        guard deliveredProgress == nil else { return }
        deliveredReward = reward
        deliveredProgress = progress
    }
}

/// The journal is the only authority for hidden results and replay markers.
/// User-facing histories, Farm state, search state, and App Group values are projections.
struct WindDownMorningSettlementJournal: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let storageKey = "ollie.windDownMorning.settlementJournal"
    static let maximumEffectMarkers = 512

    var schemaVersion: Int
    var windDownBenefits: [WindDownBenefitSettlement]
    var morningOccurrences: [MorningQuietOccurrence]
    var sunriseTrail: SunriseTrailState
    var deliveredEffectIDs: [String]

    init(
        schemaVersion: Int = currentSchemaVersion,
        windDownBenefits: [WindDownBenefitSettlement] = [],
        morningOccurrences: [MorningQuietOccurrence] = [],
        sunriseTrail: SunriseTrailState = .empty,
        deliveredEffectIDs: [String] = []
    ) {
        self.schemaVersion = max(schemaVersion, Self.currentSchemaVersion)
        self.windDownBenefits = windDownBenefits
        self.morningOccurrences = morningOccurrences
        self.sunriseTrail = sunriseTrail
        self.deliveredEffectIDs = Array(Array(Set(deliveredEffectIDs)).suffix(Self.maximumEffectMarkers))
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, windDownBenefits, morningOccurrences, sunriseTrail, deliveredEffectIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion,
            windDownBenefits: try container.decodeIfPresent([WindDownBenefitSettlement].self, forKey: .windDownBenefits) ?? [],
            morningOccurrences: try container.decodeIfPresent([MorningQuietOccurrence].self, forKey: .morningOccurrences) ?? [],
            sunriseTrail: try container.decodeIfPresent(SunriseTrailState.self, forKey: .sunriseTrail) ?? .empty,
            deliveredEffectIDs: try container.decodeIfPresent([String].self, forKey: .deliveredEffectIDs) ?? []
        )
    }

    func benefit(for runID: UUID) -> WindDownBenefitSettlement? {
        windDownBenefits.first { $0.runID == runID }
    }

    var oldestUnreadDeliveredBenefit: WindDownBenefitSettlement? {
        windDownBenefits
            .filter { $0.deliveredAt != nil && $0.revealedAt == nil }
            .sorted { ($0.deliveredAt ?? .distantFuture) < ($1.deliveredAt ?? .distantFuture) }
            .first
    }

    mutating func resolveWindDown(
        run: FocusRun,
        at date: Date
    ) -> WindDownBenefitSettlement? {
        guard run.isProgressionEligibleNightWatch,
              !run.isPractice,
              FocusRunRules.protectedSpanMinutes(for: run, at: date)
                >= FocusRunRules.minimumProtectedNightSearchSpanMinutes else { return nil }
        if let existing = benefit(for: run.id) { return existing }
        let result = WindDownBenefitSettlement(
            runID: run.id,
            entitledAt: date,
            phoneAwaySpanMinutes: FocusRunRules.protectedSpanMinutes(for: run, at: date),
            resolvedAt: date
        )
        windDownBenefits.append(result)
        return result
    }

    @discardableResult
    mutating func persistHiddenOutcome(
        _ outcome: SheepSearchOutcome,
        for runID: UUID
    ) -> WindDownBenefitSettlement? {
        guard let index = windDownBenefits.firstIndex(where: { $0.runID == runID }) else { return nil }
        windDownBenefits[index].attachHiddenOutcome(outcome)
        return windDownBenefits[index]
    }

    @discardableResult
    mutating func persistTerminalProjections(
        for runID: UUID,
        reward: RewardItem?,
        progress: UserProgress
    ) -> WindDownBenefitSettlement? {
        guard let index = windDownBenefits.firstIndex(where: { $0.runID == runID }) else { return nil }
        windDownBenefits[index].attachTerminalProjections(reward: reward, progress: progress)
        return windDownBenefits[index]
    }

    @discardableResult
    mutating func markDelivered(runID: UUID, at date: Date) -> WindDownBenefitSettlement? {
        guard let index = windDownBenefits.firstIndex(where: { $0.runID == runID }) else { return nil }
        if windDownBenefits[index].deliveredAt == nil { windDownBenefits[index].deliveredAt = date }
        return windDownBenefits[index]
    }

    @discardableResult
    mutating func markRevealed(runID: UUID, at date: Date) -> WindDownBenefitSettlement? {
        guard let index = windDownBenefits.firstIndex(where: { $0.runID == runID }),
              windDownBenefits[index].deliveredAt != nil else { return nil }
        if windDownBenefits[index].revealedAt == nil { windDownBenefits[index].revealedAt = date }
        return windDownBenefits[index]
    }

    mutating func appendOccurrence(_ occurrence: MorningQuietOccurrence) {
        guard occurrence.scheduledEnd > occurrence.scheduledStart,
              !morningOccurrences.contains(where: { $0.id == occurrence.id }),
              !morningOccurrences.contains(where: {
                  $0.scheduleOccurrenceID == occurrence.scheduleOccurrenceID
                      || (occurrence.linkedWindDownRunID != nil
                          && $0.linkedWindDownRunID == occurrence.linkedWindDownRunID
                          && $0.outcome != .finished
                          && $0.outcome != .skipped)
              }) else { return }
        morningOccurrences.append(occurrence)
    }

    mutating func replaceOccurrence(_ occurrence: MorningQuietOccurrence) -> Bool {
        guard occurrence.scheduledEnd > occurrence.scheduledStart,
              let index = morningOccurrences.firstIndex(where: { $0.id == occurrence.id }) else { return false }
        morningOccurrences[index] = occurrence
        return true
    }

    mutating func markEffectDelivered(_ effectID: String) -> Bool {
        guard !deliveredEffectIDs.contains(effectID) else { return false }
        deliveredEffectIDs.append(effectID)
        if deliveredEffectIDs.count > Self.maximumEffectMarkers {
            deliveredEffectIDs.removeFirst(deliveredEffectIDs.count - Self.maximumEffectMarkers)
        }
        return true
    }
}
