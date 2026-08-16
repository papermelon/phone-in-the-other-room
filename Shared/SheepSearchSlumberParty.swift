import Foundation

extension SheepSearchEngine {
    /// A guaranteed Slumber Party find that never consumes protected-night or
    /// Phone Away guarantees. The grant identity keeps settlement idempotent.
    static func calculateSlumberParty(
        grantID: UUID,
        protectedNightNumber: Int,
        state: SheepSearchState,
        trackedSheepID: String? = nil,
        now: Date = Date(),
        seed: UInt64? = nil
    ) -> SheepSearchCalculation {
        if let existing = state.slumberPartyOutcome(for: grantID) {
            return SheepSearchCalculation(outcome: existing, score: existing.trailStrength)
        }

        let generator = DeterministicSheepRandom(
            seed: seed ?? stableSeed(runID: grantID, protectedNightNumber: max(1, protectedNightNumber))
        )
        let eligible = SheepCatalog.eligible(for: max(1, protectedNightNumber))
            .filter { !state.foundSheepIDs.contains($0.id) }
        let candidatePool = eligible.isEmpty
            ? SheepCatalog.eligible(for: max(1, protectedNightNumber))
            : eligible
        let selected = weightedSheep(
            from: candidatePool,
            score: 80,
            trackedSheepID: trackedSheepID,
            random: generator
        )
        let outcome = SheepSearchOutcome(
            id: grantID,
            runID: grantID,
            origin: .slumberParty,
            protectedNightNumber: max(0, protectedNightNumber),
            result: selected == nil ? .trailOnly : .found,
            sheepID: selected?.id,
            rarity: selected?.rarity,
            habitat: selected?.habitat,
            trailStrength: 80,
            encounterOdds: 1,
            trailDistance: 0,
            consecutiveNoFinds: 0,
            bonusPoints: 0,
            trailMapBonusPercentagePoints: 0,
            createdAt: now
        )
        return SheepSearchCalculation(outcome: outcome, score: 80)
    }
}
