import Foundation

struct SheepSearchOutcome: Codable, Equatable, Identifiable {
    enum Result: String, Codable {
        case found
        case trailOnly
    }

    let id: UUID
    let runID: UUID
    let protectedNightNumber: Int
    let result: Result
    let sheepID: String?
    let rarity: SheepRarity?
    let habitat: SheepHabitat?
    let trailStrength: Int
    let encounterOdds: Double
    let trailDistance: Double
    let consecutiveNoFinds: Int
    let bonusPoints: Int
    let trailMapBonusPercentagePoints: Int
    let createdAt: Date

    init(
        id: UUID,
        runID: UUID,
        protectedNightNumber: Int,
        result: Result,
        sheepID: String?,
        rarity: SheepRarity?,
        habitat: SheepHabitat?,
        trailStrength: Int,
        encounterOdds: Double,
        trailDistance: Double,
        consecutiveNoFinds: Int,
        bonusPoints: Int,
        trailMapBonusPercentagePoints: Int = 0,
        createdAt: Date
    ) {
        self.id = id
        self.runID = runID
        self.protectedNightNumber = protectedNightNumber
        self.result = result
        self.sheepID = sheepID
        self.rarity = rarity
        self.habitat = habitat
        self.trailStrength = trailStrength
        self.encounterOdds = encounterOdds
        self.trailDistance = trailDistance
        self.consecutiveNoFinds = consecutiveNoFinds
        self.bonusPoints = bonusPoints
        self.trailMapBonusPercentagePoints = max(0, trailMapBonusPercentagePoints)
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, runID, protectedNightNumber, result, sheepID, rarity, habitat
        case trailStrength, encounterOdds, trailDistance, consecutiveNoFinds, bonusPoints
        case trailMapBonusPercentagePoints, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            runID: try container.decode(UUID.self, forKey: .runID),
            protectedNightNumber: try container.decode(Int.self, forKey: .protectedNightNumber),
            result: try container.decode(Result.self, forKey: .result),
            sheepID: try container.decodeIfPresent(String.self, forKey: .sheepID),
            rarity: try container.decodeIfPresent(SheepRarity.self, forKey: .rarity),
            habitat: try container.decodeIfPresent(SheepHabitat.self, forKey: .habitat),
            trailStrength: try container.decode(Int.self, forKey: .trailStrength),
            encounterOdds: try container.decode(Double.self, forKey: .encounterOdds),
            trailDistance: try container.decode(Double.self, forKey: .trailDistance),
            consecutiveNoFinds: try container.decode(Int.self, forKey: .consecutiveNoFinds),
            bonusPoints: try container.decodeIfPresent(Int.self, forKey: .bonusPoints) ?? 0,
            trailMapBonusPercentagePoints: try container.decodeIfPresent(Int.self, forKey: .trailMapBonusPercentagePoints) ?? 0,
            createdAt: try container.decode(Date.self, forKey: .createdAt)
        )
    }
}

struct SheepTrailMapState: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let maximumMappedMinutes = 75
    static let maximumCreditedRunIDs = 128

    var schemaVersion: Int = currentSchemaVersion
    var pendingMappedMinutes: Int = 0
    var creditedAdHocRunIDs: [UUID] = []

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, pendingMappedMinutes, creditedAdHocRunIDs
    }

    init(
        schemaVersion: Int = currentSchemaVersion,
        pendingMappedMinutes: Int = 0,
        creditedAdHocRunIDs: [UUID] = []
    ) {
        self.schemaVersion = schemaVersion
        self.pendingMappedMinutes = min(Self.maximumMappedMinutes, max(0, pendingMappedMinutes))
        self.creditedAdHocRunIDs = Array(creditedAdHocRunIDs.suffix(Self.maximumCreditedRunIDs))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: Self.currentSchemaVersion,
            pendingMappedMinutes: try container.decodeIfPresent(Int.self, forKey: .pendingMappedMinutes) ?? 0,
            creditedAdHocRunIDs: try container.decodeIfPresent([UUID].self, forKey: .creditedAdHocRunIDs) ?? []
        )
    }

    var availableBonusPercentagePoints: Int {
        min(5, max(0, pendingMappedMinutes) / 15)
    }

    @discardableResult
    mutating func credit(runID: UUID, minutes: Int) -> Int {
        guard minutes > 0, !creditedAdHocRunIDs.contains(runID) else { return 0 }
        creditedAdHocRunIDs.append(runID)
        if creditedAdHocRunIDs.count > Self.maximumCreditedRunIDs {
            creditedAdHocRunIDs.removeFirst(creditedAdHocRunIDs.count - Self.maximumCreditedRunIDs)
        }
        let previous = pendingMappedMinutes
        pendingMappedMinutes = min(Self.maximumMappedMinutes, previous + minutes)
        return pendingMappedMinutes - previous
    }

    mutating func consume(percentagePoints: Int) {
        pendingMappedMinutes = max(0, pendingMappedMinutes - max(0, percentagePoints) * 15)
    }
}

struct SheepSearchState: Codable, Equatable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var outcomes: [SheepSearchOutcome]
    var foundSheepIDs: [String]
    var consecutiveNoFinds: Int
    var totalTrailDistance: Double
    var showExactOdds: Bool
    var trailMap: SheepTrailMapState

    static let empty = SheepSearchState(
        schemaVersion: currentSchemaVersion,
        outcomes: [],
        foundSheepIDs: [],
        consecutiveNoFinds: 0,
        totalTrailDistance: 0,
        showExactOdds: false,
        trailMap: SheepTrailMapState()
    )

    var lastOutcome: SheepSearchOutcome? { outcomes.last }

    mutating func append(_ outcome: SheepSearchOutcome) {
        guard !outcomes.contains(where: { $0.runID == outcome.runID }) else { return }
        outcomes.append(outcome)
        trailMap.consume(percentagePoints: outcome.trailMapBonusPercentagePoints)
        if let sheepID = outcome.sheepID {
            if !foundSheepIDs.contains(sheepID) {
                foundSheepIDs.append(sheepID)
            }
            consecutiveNoFinds = 0
        } else {
            consecutiveNoFinds += 1
        }
        totalTrailDistance += outcome.trailDistance
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, outcomes, foundSheepIDs, consecutiveNoFinds, totalTrailDistance
        case showExactOdds, trailMap
    }

    init(
        schemaVersion: Int,
        outcomes: [SheepSearchOutcome],
        foundSheepIDs: [String],
        consecutiveNoFinds: Int,
        totalTrailDistance: Double,
        showExactOdds: Bool,
        trailMap: SheepTrailMapState = SheepTrailMapState()
    ) {
        self.schemaVersion = schemaVersion
        self.outcomes = outcomes
        self.foundSheepIDs = foundSheepIDs
        self.consecutiveNoFinds = consecutiveNoFinds
        self.totalTrailDistance = totalTrailDistance
        self.showExactOdds = showExactOdds
        self.trailMap = trailMap
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: Self.currentSchemaVersion,
            outcomes: try container.decodeIfPresent([SheepSearchOutcome].self, forKey: .outcomes) ?? [],
            foundSheepIDs: try container.decodeIfPresent([String].self, forKey: .foundSheepIDs) ?? [],
            consecutiveNoFinds: try container.decodeIfPresent(Int.self, forKey: .consecutiveNoFinds) ?? 0,
            totalTrailDistance: try container.decodeIfPresent(Double.self, forKey: .totalTrailDistance) ?? 0,
            showExactOdds: try container.decodeIfPresent(Bool.self, forKey: .showExactOdds) ?? false,
            trailMap: try container.decodeIfPresent(SheepTrailMapState.self, forKey: .trailMap) ?? SheepTrailMapState()
        )
    }
}
