import Foundation

enum PhoneAwaySearchMeter {
    static let maximumMinutes = 100
    static let perRunCreditCap = maximumMinutes
    static let minimumEligibleMinutes = 15
    static let maximumPendingMinutes = maximumMinutes * 2
}

enum SheepSearchOrigin: String, Codable {
    case windDown
    case phoneBreak
    case sunrise
    case starter
    case onboardingPractice
    case slumberParty
    /// Forward-compatible stand-in so unknown future origins do not count as Wind Down.
    case unspecified

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? .unspecified
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var countsTowardProtectedNightGuarantee: Bool { self == .windDown }
    var countsTowardPhoneAwayGuarantee: Bool { self == .phoneBreak }
    var countsTowardSunriseGuarantee: Bool { self == .sunrise }
}

struct SheepSearchOutcome: Codable, Equatable, Identifiable {

    enum Result: String, Codable {
        case found
        case trailOnly
    }

    let id: UUID
    let runID: UUID
    let origin: SheepSearchOrigin
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
        origin: SheepSearchOrigin = .windDown,
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
        self.origin = origin
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
        case id, runID, origin, protectedNightNumber, result, sheepID, rarity, habitat
        case trailStrength, encounterOdds, trailDistance, consecutiveNoFinds, bonusPoints
        case trailMapBonusPercentagePoints, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            runID: try container.decode(UUID.self, forKey: .runID),
            origin: try container.decodeIfPresent(SheepSearchOrigin.self, forKey: .origin) ?? .windDown,
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
    static let currentSchemaVersion = 3
    static let maximumMappedMinutes = PhoneAwaySearchMeter.maximumMinutes
    static let maximumPendingMinutes = PhoneAwaySearchMeter.maximumPendingMinutes
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
        self.pendingMappedMinutes = min(Self.maximumPendingMinutes, max(0, pendingMappedMinutes))
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

    var isReadyForBonusSearch: Bool {
        pendingMappedMinutes >= Self.maximumMappedMinutes
    }

    @discardableResult
    mutating func credit(
        runID: UUID,
        minutes: Int,
        pendingCap: Int = Self.maximumPendingMinutes
    ) -> Int {
        guard minutes > 0, !creditedAdHocRunIDs.contains(runID) else { return 0 }
        creditedAdHocRunIDs.append(runID)
        if creditedAdHocRunIDs.count > Self.maximumCreditedRunIDs {
            creditedAdHocRunIDs.removeFirst(creditedAdHocRunIDs.count - Self.maximumCreditedRunIDs)
        }
        let previous = pendingMappedMinutes
        let safeCap = min(Self.maximumPendingMinutes, max(0, pendingCap))
        pendingMappedMinutes = min(safeCap, previous + minutes)
        return pendingMappedMinutes - previous
    }

    mutating func consumeBonusSearchMeter() {
        pendingMappedMinutes = max(0, pendingMappedMinutes - Self.maximumMappedMinutes)
    }
}

struct SheepTrailMapPresentation: Equatable {
    var title: String
    var detail: String

    static func home(availableBonusPercentagePoints: Int) -> Self? {
        home(pendingMappedMinutes: max(0, availableBonusPercentagePoints) * 15)
    }

    static func home(
        pendingMappedMinutes: Int,
        protectedWindDownCount: Int = SheepSearchEngine.starterGuaranteeRuns
    ) -> Self? {
        let minutes = min(SheepTrailMapState.maximumMappedMinutes, max(0, pendingMappedMinutes))
        guard minutes > 0 else { return nil }
        let isUnlocked = protectedWindDownCount >= SheepSearchEngine.starterGuaranteeRuns
        let detail: String
        if isUnlocked {
            detail = minutes == SheepTrailMapState.maximumMappedMinutes
                ? "Gift progress is full. Complete another Phone Away and Ollie will look for a missing sheep."
                : "Every \(SheepTrailMapState.maximumMappedMinutes) completed Phone Away minutes, Ollie looks for a missing sheep."
        } else {
            detail = minutes == SheepTrailMapState.maximumMappedMinutes
                ? "Gift progress is full. It will wait until three Wind Downs are complete."
                : "These minutes are saved. Ollie looks for a missing sheep after three Wind Downs."
        }
        return Self(
            title: "Phone Away gift progress · \(minutes) / \(SheepTrailMapState.maximumMappedMinutes) minutes",
            detail: detail
        )
    }
}

struct SheepSearchState: Codable, Equatable {
    static let currentSchemaVersion = 4

    var schemaVersion: Int
    var outcomes: [SheepSearchOutcome]
    var foundSheepIDs: [String]
    var consecutiveNoFinds: Int
    var phoneBreakConsecutiveNoFinds: Int
    var totalTrailDistance: Double
    var showExactOdds: Bool
    var trailMap: SheepTrailMapState
    var phoneAwaySettlements: [PhoneAwaySearchSettlementRecord]

    static let empty = SheepSearchState(
        schemaVersion: currentSchemaVersion,
        outcomes: [],
        foundSheepIDs: [],
        consecutiveNoFinds: 0,
        phoneBreakConsecutiveNoFinds: 0,
        totalTrailDistance: 0,
        showExactOdds: false,
        trailMap: SheepTrailMapState(),
        phoneAwaySettlements: []
    )

    var lastOutcome: SheepSearchOutcome? { outcomes.last }

    var completedWindDownSearchCount: Int {
        outcomes.filter { $0.origin.countsTowardProtectedNightGuarantee }.count
    }

    var completedPhoneAwaySearchCount: Int {
        outcomes.filter { $0.origin.countsTowardPhoneAwayGuarantee }.count
    }

    func starterOutcome() -> SheepSearchOutcome? {
        outcomes.first { $0.origin == .starter }
    }

    func onboardingPracticeOutcome(for runID: UUID) -> SheepSearchOutcome? {
        outcomes.first { $0.origin == .onboardingPractice && $0.runID == runID }
    }

    func slumberPartyOutcome(for grantID: UUID) -> SheepSearchOutcome? {
        outcomes.first { $0.origin == .slumberParty && $0.runID == grantID }
    }

    func phoneBreakOutcome(for runID: UUID) -> SheepSearchOutcome? {
        outcomes.first { $0.origin == .phoneBreak && $0.runID == runID }
    }

    func phoneAwaySettlement(for runID: UUID) -> PhoneAwaySearchSettlementRecord? {
        phoneAwaySettlements.first { $0.runID == runID }
    }

    mutating func appendPhoneAwaySettlement(_ settlement: PhoneAwaySearchSettlementRecord) {
        guard !phoneAwaySettlements.contains(where: { $0.runID == settlement.runID }) else { return }
        phoneAwaySettlements.append(settlement)
    }

    mutating func append(_ outcome: SheepSearchOutcome) {
        if outcome.origin == .sunrise {
            guard !outcomes.contains(where: { $0.id == outcome.id }) else { return }
        } else {
            guard !outcomes.contains(where: { $0.runID == outcome.runID }) else { return }
        }
        outcomes.append(outcome)
        // The mapped-bonus field is retained for legacy Wind Down outcomes only.
        // New Phone Away searches consume the separate meter before settlement.
        if let sheepID = outcome.sheepID {
            if !foundSheepIDs.contains(sheepID) {
                foundSheepIDs.append(sheepID)
            }
            switch outcome.origin {
            case .phoneBreak:
                phoneBreakConsecutiveNoFinds = 0
            case .windDown:
                consecutiveNoFinds = 0
            case .sunrise, .starter, .onboardingPractice, .slumberParty, .unspecified:
                break
            }
        } else {
            switch outcome.origin {
            case .phoneBreak:
                phoneBreakConsecutiveNoFinds += 1
            case .windDown:
                consecutiveNoFinds += 1
            case .sunrise, .starter, .onboardingPractice, .slumberParty, .unspecified:
                break
            }
        }
        totalTrailDistance += outcome.trailDistance
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, outcomes, foundSheepIDs, consecutiveNoFinds, phoneBreakConsecutiveNoFinds, totalTrailDistance
        case showExactOdds, trailMap, phoneAwaySettlements
    }

    init(
        schemaVersion: Int,
        outcomes: [SheepSearchOutcome],
        foundSheepIDs: [String],
        consecutiveNoFinds: Int,
        phoneBreakConsecutiveNoFinds: Int = 0,
        totalTrailDistance: Double,
        showExactOdds: Bool,
        trailMap: SheepTrailMapState = SheepTrailMapState(),
        phoneAwaySettlements: [PhoneAwaySearchSettlementRecord] = []
    ) {
        self.schemaVersion = schemaVersion
        self.outcomes = outcomes
        self.foundSheepIDs = foundSheepIDs
        self.consecutiveNoFinds = consecutiveNoFinds
        self.phoneBreakConsecutiveNoFinds = max(0, phoneBreakConsecutiveNoFinds)
        self.totalTrailDistance = totalTrailDistance
        self.showExactOdds = showExactOdds
        self.trailMap = trailMap
        self.phoneAwaySettlements = phoneAwaySettlements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: Self.currentSchemaVersion,
            outcomes: try container.decodeIfPresent([SheepSearchOutcome].self, forKey: .outcomes) ?? [],
            foundSheepIDs: try container.decodeIfPresent([String].self, forKey: .foundSheepIDs) ?? [],
            consecutiveNoFinds: try container.decodeIfPresent(Int.self, forKey: .consecutiveNoFinds) ?? 0,
            phoneBreakConsecutiveNoFinds: try container.decodeIfPresent(Int.self, forKey: .phoneBreakConsecutiveNoFinds) ?? 0,
            totalTrailDistance: try container.decodeIfPresent(Double.self, forKey: .totalTrailDistance) ?? 0,
            showExactOdds: try container.decodeIfPresent(Bool.self, forKey: .showExactOdds) ?? false,
            trailMap: try container.decodeIfPresent(SheepTrailMapState.self, forKey: .trailMap) ?? SheepTrailMapState(),
            phoneAwaySettlements: try container.decodeIfPresent([PhoneAwaySearchSettlementRecord].self, forKey: .phoneAwaySettlements) ?? []
        )
    }
}
