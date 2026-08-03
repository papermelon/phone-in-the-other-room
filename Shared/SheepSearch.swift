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
}

enum SheepCatalog {
    static let all: [SheepDefinition] = [
        SheepDefinition(id: "mabel", name: "Mabel", rarity: .common, habitat: .starterPasture, breed: .commonWhite, assetName: "sheep/sheep_common", accessory: "a blue ribbon", posterClue: "Last seen beside the water trough.", story: "Mabel likes a quiet path and a warm barn corner."),
        SheepDefinition(id: "pippin", name: "Pippin", rarity: .common, habitat: .starterPasture, breed: .spotted, assetName: "sheep/sheep_spotted", accessory: "round glasses", posterClue: "Last seen with a mouthful of clover.", story: "Pippin always stops to read the field signs."),
        SheepDefinition(id: "bramble", name: "Bramble", rarity: .common, habitat: .starterPasture, breed: .fluffy, assetName: "sheep/sheep_fluffy", accessory: "a green neckerchief", posterClue: "Last seen near the low fence.", story: "Bramble knows every friendly gate in the pasture."),
        SheepDefinition(id: "clementine", name: "Clementine", rarity: .common, habitat: .sunriseHill, breed: .cream, assetName: "sheep/sheep_cream", accessory: "a sunflower pin", posterClue: "Last seen where the first light reaches the grass.", story: "Clementine follows the morning light home."),
        SheepDefinition(id: "oat", name: "Oat", rarity: .common, habitat: .storybookBarn, breed: .merino, assetName: "sheep/sheep_merino", accessory: "a little book satchel", posterClue: "Last seen outside the storybook barn.", story: "Oat settles whenever someone makes room for a page or two."),
        SheepDefinition(id: "midnight", name: "Midnight", rarity: .uncommon, habitat: .moonMeadow, breed: .black, assetName: "sheep/sheep_black", accessory: "a silver bell", posterClue: "Last seen under the moon meadow gate.", story: "Midnight travels quietly when the evening grows still."),
        SheepDefinition(id: "juniper", name: "Juniper", rarity: .uncommon, habitat: .fenceLine, breed: .cream, assetName: "sheep/sheep_cream", accessory: "a pair of amber spectacles", posterClue: "Last seen following the fence-line trail.", story: "Juniper likes a clear boundary and a patient shepherd."),
        SheepDefinition(id: "hazel", name: "Hazel", rarity: .uncommon, habitat: .sunflowerField, breed: .spotted, assetName: "sheep/sheep_spotted", accessory: "a yellow hat", posterClue: "Last seen beyond the sunflower field.", story: "Hazel wanders farther when the day begins gently."),
        SheepDefinition(id: "ramsey", name: "Ramsey", rarity: .uncommon, habitat: .farField, breed: .guardian, assetName: "sheep/sheep_guardian", accessory: "a red wool scarf", posterClue: "Last seen past the far-field marker.", story: "Ramsey is brave about long trails and quiet rooms."),
        SheepDefinition(id: "luna", name: "Luna", rarity: .rare, habitat: .moonMeadow, breed: .merino, assetName: "sheep/sheep_merino", accessory: "a crescent-moon necklace", posterClue: "Last seen where the grass turns blue at dusk.", story: "Luna only comes close when the night has been given room."),
        SheepDefinition(id: "marigold", name: "Marigold", rarity: .rare, habitat: .sunriseHill, breed: .fluffy, assetName: "sheep/sheep_fluffy", accessory: "a flower crown", posterClue: "Last seen on the highest sunrise path.", story: "Marigold follows a steady morning all the way home."),
        SheepDefinition(id: "wisp", name: "Wisp", rarity: .legendary, habitat: .highMoor, breed: .night, assetName: "sheep/sheep_night", accessory: "a starry cape", posterClue: "Last seen above the high moor.", story: "Wisp appears when Ollie has followed a very long, patient trail."),
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

    static let empty = SheepSearchEvidence(
        windDownMinutes: 0,
        morningQuietMinutes: 0,
        plannedWindDownMinutes: 30,
        plannedMorningQuietMinutes: 30,
        startedNearSchedule: false,
        shieldingObserved: false,
        placementConfirmed: false,
        recentProtectedNights: 0,
        optionalBonusPoints: 0
    )
}

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
    let createdAt: Date
}

struct SheepSearchState: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var outcomes: [SheepSearchOutcome]
    var foundSheepIDs: [String]
    var consecutiveNoFinds: Int
    var totalTrailDistance: Double
    var showExactOdds: Bool

    static let empty = SheepSearchState(
        schemaVersion: currentSchemaVersion,
        outcomes: [],
        foundSheepIDs: [],
        consecutiveNoFinds: 0,
        totalTrailDistance: 0,
        showExactOdds: false
    )

    var lastOutcome: SheepSearchOutcome? { outcomes.last }

    mutating func append(_ outcome: SheepSearchOutcome) {
        guard !outcomes.contains(where: { $0.runID == outcome.runID }) else { return }
        outcomes.append(outcome)
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
        let encounterOdds = min(0.92, baseOdds + droughtBonus)
        let guaranteed = protectedNightNumber <= starterGuaranteeRuns
            || state.consecutiveNoFinds >= hardGuaranteeAfterNoFinds
        let generator = DeterministicSheepRandom(seed: seed ?? stableSeed(runID: runID, protectedNightNumber: protectedNightNumber))
        let shouldFind = guaranteed || generator.value() < encounterOdds

        let eligible = SheepCatalog.eligible(for: protectedNightNumber)
            .filter { !state.foundSheepIDs.contains($0.id) }
        let candidatePool = eligible.isEmpty ? SheepCatalog.eligible(for: protectedNightNumber) : eligible
        let selected = shouldFind ? weightedSheep(from: candidatePool, score: score, random: generator) : nil
        let result: SheepSearchOutcome.Result = selected == nil ? .trailOnly : .found
        let distance = (Double(evidence.windDownMinutes + evidence.morningQuietMinutes) * 0.08)
            + Double(score) * 0.015

        let outcome = SheepSearchOutcome(
            id: UUID(),
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
            createdAt: now
        )
        return SheepSearchCalculation(outcome: outcome, score: score)
    }

    private static func ratio(_ value: Int, planned: Int) -> Double {
        guard planned > 0 else { return 0 }
        return min(1, max(0, Double(value) / Double(planned)))
    }

    private static func weightedSheep(
        from candidates: [SheepDefinition],
        score: Int,
        random: DeterministicSheepRandom
    ) -> SheepDefinition? {
        guard !candidates.isEmpty else { return nil }
        let weights = candidates.map { sheep -> Double in
            let rarityPenalty = Double(sheep.rarity.rank) * 0.28
            let strengthBonus = Double(score) / 100 * Double(sheep.rarity.rank) * 0.32
            return max(0.08, 1 - rarityPenalty + strengthBonus)
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
