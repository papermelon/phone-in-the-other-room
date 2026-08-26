import Foundation

enum SunriseTrailRules {
    static let meterMinutes = 100
    static let minimumOccurrenceMinutes = 15
    static let woolPerFill = 1
    static let firstGuaranteedSearches = 3
    static let hardGuaranteeAfterNoFinds = 4

    static func chance(afterNoFinds drought: Int) -> Double {
        [0.20, 0.30, 0.40, 0.50][min(max(0, drought), 3)]
    }
}

struct SunriseTrailFill: Codable, Equatable, Identifiable {
    var id: UUID
    var occurrenceID: UUID
    var fillIndex: Int
    var woolGranted: Int
    var outcome: SheepSearchOutcome
    var settledAt: Date
}

struct SunriseTrailOccurrenceSettlement: Codable, Equatable {
    var occurrenceID: UUID
    var eligibleMinutes: Int
    var appliedMinutes: Int
    var createdAt: Date
}

struct SunriseTrailState: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let empty = SunriseTrailState()

    var schemaVersion: Int
    var pendingMinutes: Int
    var completedSearchCount: Int
    var consecutiveNoFinds: Int
    var occurrenceSettlements: [SunriseTrailOccurrenceSettlement]
    var fills: [SunriseTrailFill]

    init(
        schemaVersion: Int = currentSchemaVersion,
        pendingMinutes: Int = 0,
        completedSearchCount: Int = 0,
        consecutiveNoFinds: Int = 0,
        occurrenceSettlements: [SunriseTrailOccurrenceSettlement] = [],
        fills: [SunriseTrailFill] = []
    ) {
        self.schemaVersion = max(schemaVersion, Self.currentSchemaVersion)
        self.pendingMinutes = max(0, pendingMinutes)
        self.completedSearchCount = max(0, completedSearchCount)
        self.consecutiveNoFinds = max(0, consecutiveNoFinds)
        self.occurrenceSettlements = occurrenceSettlements
        self.fills = fills
    }

    func settlement(for occurrenceID: UUID) -> SunriseTrailOccurrenceSettlement? {
        occurrenceSettlements.first { $0.occurrenceID == occurrenceID }
    }
}

struct SunriseTrailSettlementResult: Equatable {
    var state: SunriseTrailState
    var appliedMinutes: Int
    var fills: [SunriseTrailFill]
    var woolGranted: Int
}

enum SunriseTrailSettlementEngine {
    static func settle(
        occurrence: MorningQuietOccurrence,
        at date: Date,
        state: SunriseTrailState,
        protectedWindDownCount: Int,
        trackedSheepID: String? = nil
    ) -> SunriseTrailSettlementResult {
        if let existing = state.settlement(for: occurrence.id) {
            let fills = state.fills.filter { $0.occurrenceID == occurrence.id }
            return SunriseTrailSettlementResult(
                state: state,
                appliedMinutes: existing.appliedMinutes,
                fills: fills,
                woolGranted: fills.reduce(0) { $0 + $1.woolGranted }
            )
        }

        let elapsed = occurrence.eligibleElapsedMinutes(at: date)
        let eligible = occurrence.outcome != .skipped && elapsed >= SunriseTrailRules.minimumOccurrenceMinutes
        let applied = eligible ? min(occurrence.configuredDurationMinutes, elapsed) : 0
        var next = state
        next.occurrenceSettlements.append(SunriseTrailOccurrenceSettlement(
            occurrenceID: occurrence.id,
            eligibleMinutes: elapsed,
            appliedMinutes: applied,
            createdAt: date
        ))

        let total = next.pendingMinutes + applied
        let fillCount = total / SunriseTrailRules.meterMinutes
        next.pendingMinutes = total % SunriseTrailRules.meterMinutes
        var newFills: [SunriseTrailFill] = []
        let baseSearchCount = next.completedSearchCount
        for index in 0..<fillCount {
            let fillIndex = baseSearchCount + index + 1
            let fillID = stableFillID(occurrenceID: occurrence.id, fillIndex: fillIndex)
            let outcome = outcome(
                fillID: fillID,
                occurrenceID: occurrence.id,
                fillIndex: fillIndex,
                protectedWindDownCount: protectedWindDownCount,
                drought: next.consecutiveNoFinds,
                foundSheepIDs: next.fills.compactMap { $0.outcome.sheepID },
                trackedSheepID: trackedSheepID,
                at: date
            )
            let fill = SunriseTrailFill(
                id: fillID,
                occurrenceID: occurrence.id,
                fillIndex: fillIndex,
                woolGranted: SunriseTrailRules.woolPerFill,
                outcome: outcome,
                settledAt: date
            )
            next.fills.append(fill)
            newFills.append(fill)
            next.completedSearchCount += 1
            next.consecutiveNoFinds = outcome.result == .found ? 0 : next.consecutiveNoFinds + 1
        }
        return SunriseTrailSettlementResult(
            state: next,
            appliedMinutes: applied,
            fills: newFills,
            woolGranted: newFills.reduce(0) { $0 + $1.woolGranted }
        )
    }

    private static func outcome(
        fillID: UUID,
        occurrenceID: UUID,
        fillIndex: Int,
        protectedWindDownCount: Int,
        drought: Int,
        foundSheepIDs: [String],
        trackedSheepID: String?,
        at date: Date
    ) -> SheepSearchOutcome {
        let guaranteed = fillIndex <= SunriseTrailRules.firstGuaranteedSearches
            || drought >= SunriseTrailRules.hardGuaranteeAfterNoFinds
        let odds = guaranteed ? 1 : SunriseTrailRules.chance(afterNoFinds: drought)
        let seed = SheepSearchEngine.stableSeed(runID: occurrenceID, protectedNightNumber: fillIndex)
            ^ 0x53554E5249534554
        let generator = DeterministicSheepRandom(seed: seed)
        let shouldFind = guaranteed || generator.value() < odds
        let eligible = SheepCatalog.eligible(for: max(1, protectedWindDownCount))
            .filter { !foundSheepIDs.contains($0.id) }
        let candidates = eligible.isEmpty ? SheepCatalog.eligible(for: max(1, protectedWindDownCount)) : eligible
        let sheep = shouldFind
            ? SheepSearchEngine.weightedSheep(
                from: candidates,
                score: 50,
                trackedSheepID: trackedSheepID,
                random: generator
            )
            : nil
        return SheepSearchOutcome(
            id: fillID,
            runID: occurrenceID,
            origin: .sunrise,
            protectedNightNumber: max(0, protectedWindDownCount),
            result: sheep == nil ? .trailOnly : .found,
            sheepID: sheep?.id,
            rarity: sheep?.rarity,
            habitat: sheep?.habitat,
            trailStrength: 50,
            encounterOdds: odds,
            trailDistance: 1,
            consecutiveNoFinds: drought,
            bonusPoints: 0,
            trailMapBonusPercentagePoints: 0,
            createdAt: date
        )
    }

    private static func stableFillID(occurrenceID: UUID, fillIndex: Int) -> UUID {
        var seed = SheepSearchEngine.stableSeed(runID: occurrenceID, protectedNightNumber: fillIndex)
            ^ 0x53554E5249534554
        var bytes: [UInt8] = []
        for _ in 0..<16 {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1
            bytes.append(UInt8(truncatingIfNeeded: seed >> 56))
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

extension FarmState {
    /// Applies a settled Sunrise fill without borrowing any Wind Down or
    /// Phone Away ledger. The transaction key makes a terminated-app replay
    /// safe, and `recordArrival` keeps the usual capacity gate.
    mutating func applySunriseTrailFill(_ fill: SunriseTrailFill) {
        let key = "sunrise:\(fill.id.uuidString):wool"
        if !transactions.contains(where: { $0.idempotencyKey == key }) {
            woolBalance += fill.woolGranted
            appendTransaction(FarmTransaction(
                id: UUID(),
                idempotencyKey: key,
                kind: .sunriseTrail,
                sheepID: nil,
                itemID: nil,
                woolDelta: fill.woolGranted,
                createdAt: fill.settledAt
            ))
        }
        // Arrival has its own outcome-ID ledger. If a process stopped between
        // the wool write and Farm arrival projection, replay repairs only the
        // missing arrival and never duplicates the wool.
        recordArrival(fill.outcome)
    }
}
