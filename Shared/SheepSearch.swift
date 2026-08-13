import Foundation

enum SheepRarity: String, Codable, CaseIterable, Identifiable {
    case common
    case uncommon
    case rare
    case legendary

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var minimumProtectedNights: Int {
        switch self {
        case .common: return 1
        case .uncommon: return 4
        case .rare: return 10
        case .legendary: return 25
        }
    }

    var rank: Int {
        switch self {
        case .common: return 0
        case .uncommon: return 1
        case .rare: return 2
        case .legendary: return 3
        }
    }
}

enum SheepHabitat: String, Codable, CaseIterable, Identifiable {
    case starterPasture
    case fenceLine
    case farField
    case moonMeadow
    case sunriseHill
    case storybookBarn
    case sunflowerField
    case highMoor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .starterPasture: return "Starter pasture"
        case .fenceLine: return "Fence-Line Pasture"
        case .farField: return "Far Field"
        case .moonMeadow: return "Moon Meadow"
        case .sunriseHill: return "Sunrise Hill"
        case .storybookBarn: return "Storybook Barn"
        case .sunflowerField: return "Sunflower Field"
        case .highMoor: return "High Moor"
        }
    }
}

enum SheepBreed: String, Codable, CaseIterable, Identifiable {
    case commonWhite
    case cream
    case fluffy
    case black
    case spotted
    case merino
    case night
    case guardian

    var id: String { rawValue }

    var title: String {
        switch self {
        case .commonWhite: return "Common White"
        case .cream: return "Cream"
        case .fluffy: return "Fluffy"
        case .black: return "Black"
        case .spotted: return "Spotted"
        case .merino: return "Merino"
        case .night: return "Night"
        case .guardian: return "Guardian"
        }
    }
}

struct SheepDefinition: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let rarity: SheepRarity
    let habitat: SheepHabitat
    let breed: SheepBreed
    let assetName: String
    let accessory: String?
    let posterClue: String
    let story: String

    func assetName(for woolState: SheepWoolVisualState) -> String {
        "sheep/sheep_\(id)_\(woolState.rawValue)"
    }
}

enum SheepCatalog {
    static let all: [SheepDefinition] = [
        SheepDefinition(id: "mabel", name: "Mabel", rarity: .common, habitat: .starterPasture, breed: .commonWhite, assetName: "sheep/sheep_mabel_wool_ready", accessory: "a blue ribbon", posterClue: "Last seen beside the water trough.", story: "Mabel likes a quiet path and a warm barn corner."),
        SheepDefinition(id: "pippin", name: "Pippin", rarity: .common, habitat: .starterPasture, breed: .spotted, assetName: "sheep/sheep_pippin_wool_ready", accessory: "round glasses", posterClue: "Last seen with a mouthful of clover.", story: "Pippin always stops to read the field signs."),
        SheepDefinition(id: "bramble", name: "Bramble", rarity: .common, habitat: .starterPasture, breed: .fluffy, assetName: "sheep/sheep_bramble_wool_ready", accessory: "a green neckerchief", posterClue: "Last seen near the low fence.", story: "Bramble knows every friendly gate in the pasture."),
        SheepDefinition(id: "clementine", name: "Clementine", rarity: .common, habitat: .sunriseHill, breed: .cream, assetName: "sheep/sheep_clementine_wool_ready", accessory: "a sunflower pin", posterClue: "Last seen where the first light reaches the grass.", story: "Clementine follows the morning light home."),
        SheepDefinition(id: "oat", name: "Oat", rarity: .common, habitat: .storybookBarn, breed: .merino, assetName: "sheep/sheep_oat_wool_ready", accessory: "a little book satchel", posterClue: "Last seen outside the storybook barn.", story: "Oat settles whenever someone makes room for a page or two."),
        SheepDefinition(id: "midnight", name: "Midnight", rarity: .uncommon, habitat: .moonMeadow, breed: .black, assetName: "sheep/sheep_midnight_wool_ready", accessory: "a silver bell", posterClue: "Last seen under the moon meadow gate.", story: "Midnight travels quietly when the evening grows still."),
        SheepDefinition(id: "juniper", name: "Juniper", rarity: .uncommon, habitat: .fenceLine, breed: .cream, assetName: "sheep/sheep_juniper_wool_ready", accessory: "a pair of amber spectacles", posterClue: "Last seen following the fence-line trail.", story: "Juniper likes a clear boundary and a patient shepherd."),
        SheepDefinition(id: "hazel", name: "Hazel", rarity: .uncommon, habitat: .sunflowerField, breed: .spotted, assetName: "sheep/sheep_hazel_wool_ready", accessory: "a yellow hat", posterClue: "Last seen beyond the sunflower field.", story: "Hazel wanders farther when the day begins gently."),
        SheepDefinition(id: "ramsey", name: "Ramsey", rarity: .uncommon, habitat: .farField, breed: .guardian, assetName: "sheep/sheep_ramsey_wool_ready", accessory: "a red wool scarf", posterClue: "Last seen past the far-field marker.", story: "Ramsey is brave about long trails and quiet rooms."),
        SheepDefinition(id: "luna", name: "Luna", rarity: .rare, habitat: .moonMeadow, breed: .merino, assetName: "sheep/sheep_luna_wool_ready", accessory: "a crescent-moon necklace", posterClue: "Last seen where the grass turns blue at dusk.", story: "Luna only comes close when the night has been given room."),
        SheepDefinition(id: "marigold", name: "Marigold", rarity: .rare, habitat: .sunriseHill, breed: .fluffy, assetName: "sheep/sheep_marigold_wool_ready", accessory: "a flower crown", posterClue: "Last seen on the highest sunrise path.", story: "Marigold follows a steady morning all the way home."),
        SheepDefinition(id: "wisp", name: "Wisp", rarity: .legendary, habitat: .highMoor, breed: .night, assetName: "sheep/sheep_wisp_wool_ready", accessory: "a starry cape", posterClue: "Last seen above the high moor.", story: "Wisp appears when Ollie has followed a very long, patient trail."),
    ]

    static let starterIDs: Set<String> = ["mabel", "pippin", "bramble", "clementine", "oat"]

    private static let posterArrivalNights: [String: Int] = [
        "juniper": 4,
        "midnight": 6,
        "hazel": 7,
        "ramsey": 8,
        "luna": 10,
        "marigold": 14,
        "wisp": 25
    ]

    static func definition(for id: String) -> SheepDefinition? {
        all.first { $0.id == id }
    }

    static func arrivalNight(for sheep: SheepDefinition) -> Int {
        if starterIDs.contains(sheep.id) { return 1 }
        return posterArrivalNights[sheep.id] ?? sheep.rarity.minimumProtectedNights
    }

    static func eligible(for protectedNightNumber: Int) -> [SheepDefinition] {
        available(for: protectedNightNumber)
    }

    static func available(for protectedNightNumber: Int) -> [SheepDefinition] {
        all.filter { sheep in
            arrivalNight(for: sheep) <= protectedNightNumber
        }
    }
}

struct SheepSearchEvidence: Codable, Equatable {
    var windDownMinutes: Int
    var morningQuietMinutes: Int
    var plannedWindDownMinutes: Int
    var plannedMorningQuietMinutes: Int
    var startedNearSchedule: Bool
    var shieldingObserved: Bool
    var placementConfirmed: Bool
    var recentProtectedNights: Int
    var optionalBonusPoints: Int
    var trailMapBonusPercentagePoints: Int

    static let empty = SheepSearchEvidence(
        windDownMinutes: 0,
        morningQuietMinutes: 0,
        plannedWindDownMinutes: 30,
        plannedMorningQuietMinutes: 30,
        startedNearSchedule: false,
        shieldingObserved: false,
        placementConfirmed: false,
        recentProtectedNights: 0,
        optionalBonusPoints: 0,
        trailMapBonusPercentagePoints: 0
    )
}

struct SheepSearchCalculation: Equatable {
    let outcome: SheepSearchOutcome
    let score: Int
}

enum SheepSearchEngine {
    static let starterGuaranteeRuns = 3
    static let hardGuaranteeAfterNoFinds = 4

    static func calculate(
        runID: UUID,
        protectedNightNumber: Int,
        evidence: SheepSearchEvidence,
        state: SheepSearchState,
        trackedSheepID: String? = nil,
        now: Date = Date(),
        seed: UInt64? = nil
    ) -> SheepSearchCalculation {
        if let existing = state.outcomes.first(where: { $0.runID == runID }) {
            return SheepSearchCalculation(outcome: existing, score: existing.trailStrength)
        }

        let windDownRatio = ratio(evidence.windDownMinutes, planned: evidence.plannedWindDownMinutes)
        let morningRatio = ratio(evidence.morningQuietMinutes, planned: evidence.plannedMorningQuietMinutes)
        var score = 0
        score += Int((windDownRatio * 30).rounded())
        score += Int((morningRatio * 25).rounded())
        if evidence.startedNearSchedule { score += 10 }
        if evidence.shieldingObserved { score += 10 }
        if evidence.placementConfirmed { score += 8 }
        score += min(12, max(0, evidence.recentProtectedNights))
        let optionalBonus = min(10, max(0, evidence.optionalBonusPoints))
        score += optionalBonus
        score = min(100, max(0, score))

        let baseOdds = 0.20 + Double(score) * 0.006
        let droughtBonus = Double(min(state.consecutiveNoFinds, hardGuaranteeAfterNoFinds)) * 0.08
        let oddsBeforeMap = min(0.92, baseOdds + droughtBonus)
        let guaranteed = protectedNightNumber <= starterGuaranteeRuns
            || state.consecutiveNoFinds >= hardGuaranteeAfterNoFinds
            // Phone Away runs now resolve through their own meter. Keep the legacy
        // evidence field decodable, but do not let new Wind Down searches
        // consume or apply it.
        let appliedMapPoints = 0
        let encounterOdds = oddsBeforeMap
        let generator = DeterministicSheepRandom(seed: seed ?? stableSeed(runID: runID, protectedNightNumber: protectedNightNumber))
        let shouldFind = guaranteed || generator.value() < encounterOdds

        let eligible = SheepCatalog.eligible(for: protectedNightNumber)
            .filter { !state.foundSheepIDs.contains($0.id) }
        let candidatePool = eligible.isEmpty ? SheepCatalog.eligible(for: protectedNightNumber) : eligible
        let selected = shouldFind
            ? weightedSheep(
                from: candidatePool,
                score: score,
                trackedSheepID: trackedSheepID,
                random: generator
            )
            : nil
        let result: SheepSearchOutcome.Result = selected == nil ? .trailOnly : .found
        let distance = (Double(evidence.windDownMinutes + evidence.morningQuietMinutes) * 0.08)
            + Double(score) * 0.015

        let outcome = SheepSearchOutcome(
            // New outcomes use the run identity so reconciliation remains stable even if
            // settlement is retried before the first persistence write completes.
            id: runID,
            runID: runID,
            protectedNightNumber: protectedNightNumber,
            result: result,
            sheepID: selected?.id,
            rarity: selected?.rarity,
            habitat: selected?.habitat,
            trailStrength: score,
            encounterOdds: guaranteed ? 1 : encounterOdds,
            trailDistance: max(0.1, distance),
            consecutiveNoFinds: state.consecutiveNoFinds,
            bonusPoints: optionalBonus,
            trailMapBonusPercentagePoints: appliedMapPoints,
            createdAt: now
        )
        return SheepSearchCalculation(outcome: outcome, score: score)
    }

    static func calculatePhoneBreak(
        runID: UUID,
        protectedNightNumber: Int,
        state: SheepSearchState,
        trackedSheepID: String? = nil,
        now: Date = Date(),
        seed: UInt64? = nil
    ) -> SheepSearchCalculation {
        if let existing = state.phoneBreakOutcome(for: runID) {
            return SheepSearchCalculation(outcome: existing, score: existing.trailStrength)
        }

        let drought = max(0, state.phoneBreakConsecutiveNoFinds)
        let guaranteed = drought >= 4
        let encounterOdds = guaranteed
            ? 1.0
            : [0.20, 0.30, 0.40, 0.50][min(drought, 3)]
        let generator = DeterministicSheepRandom(
            seed: seed ?? stablePhoneBreakSeed(runID: runID, protectedNightNumber: protectedNightNumber)
        )
        let shouldFind = guaranteed || generator.value() < encounterOdds
        let eligible = SheepCatalog.eligible(for: max(1, protectedNightNumber))
            .filter { !state.foundSheepIDs.contains($0.id) }
        let candidatePool = eligible.isEmpty
            ? SheepCatalog.eligible(for: max(1, protectedNightNumber))
            : eligible
        let selected = shouldFind
            ? weightedSheep(
                from: candidatePool,
                score: 50,
                trackedSheepID: trackedSheepID,
                random: generator
            )
            : nil
        let outcome = SheepSearchOutcome(
            id: runID,
            runID: runID,
            origin: .phoneBreak,
            protectedNightNumber: max(0, protectedNightNumber),
            result: selected == nil ? .trailOnly : .found,
            sheepID: selected?.id,
            rarity: selected?.rarity,
            habitat: selected?.habitat,
            trailStrength: 50,
            encounterOdds: encounterOdds,
            trailDistance: 1.0,
            consecutiveNoFinds: drought,
            bonusPoints: 0,
            trailMapBonusPercentagePoints: 0,
            createdAt: now
        )
        return SheepSearchCalculation(outcome: outcome, score: 50)
    }

    private static func ratio(_ value: Int, planned: Int) -> Double {
        guard planned > 0 else { return 0 }
        return min(1, max(0, Double(value) / Double(planned)))
    }

    private static func weightedSheep(
        from candidates: [SheepDefinition],
        score: Int,
        trackedSheepID: String?,
        random: DeterministicSheepRandom
    ) -> SheepDefinition? {
        guard !candidates.isEmpty else { return nil }
        let weights = candidates.map { sheep -> Double in
            let rarityPenalty = Double(sheep.rarity.rank) * 0.28
            let strengthBonus = Double(score) / 100 * Double(sheep.rarity.rank) * 0.32
            let baseWeight = max(0.08, 1 - rarityPenalty + strengthBonus)
            return sheep.id == trackedSheepID ? baseWeight * 3 : baseWeight
        }
        let total = weights.reduce(0, +)
        var cursor = random.value() * total
        for (index, weight) in weights.enumerated() {
            cursor -= weight
            if cursor <= 0 { return candidates[index] }
        }
        return candidates.last
    }

    private static func stableSeed(runID: UUID, protectedNightNumber: Int) -> UInt64 {
        var value: UInt64 = UInt64(protectedNightNumber) &* 1_000_003
        for scalar in runID.uuidString.unicodeScalars {
            value = value &* 31 &+ UInt64(scalar.value)
        }
        return value
    }

    private static func stablePhoneBreakSeed(runID: UUID, protectedNightNumber: Int) -> UInt64 {
        stableSeed(runID: runID, protectedNightNumber: protectedNightNumber) ^ 0x50484F4E4542524B
    }
}

private final class DeterministicSheepRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xA5A5_A5A5_A5A5_A5A5 : seed
    }

    func value() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        return Double(state >> 11) / Double(1 << 53)
    }
}
