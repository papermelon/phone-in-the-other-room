import Foundation

extension SheepSearchEngine {
    static func calculateStarter(now: Date = Date()) -> SheepSearchCalculation {
        let outcomeID = WelcomeRewardCatalog.starterOutcomeID()
        let definition = WelcomeRewardCatalog.starterDefinition
        let outcome = SheepSearchOutcome(
            id: outcomeID,
            runID: outcomeID,
            origin: .starter,
            protectedNightNumber: 0,
            result: definition == nil ? .trailOnly : .found,
            sheepID: definition?.id,
            rarity: definition?.rarity,
            habitat: definition?.habitat,
            trailStrength: 0,
            encounterOdds: 1,
            trailDistance: 0,
            consecutiveNoFinds: 0,
            bonusPoints: 0,
            trailMapBonusPercentagePoints: 0,
            createdAt: now
        )
        return SheepSearchCalculation(outcome: outcome, score: 0)
    }

    static func calculateOnboardingPractice(
        runID: UUID,
        now: Date = Date()
    ) -> SheepSearchCalculation {
        let definition = WelcomeRewardCatalog.practiceDefinition
        let outcome = SheepSearchOutcome(
            id: runID,
            runID: runID,
            origin: .onboardingPractice,
            protectedNightNumber: 0,
            result: definition == nil ? .trailOnly : .found,
            sheepID: definition?.id,
            rarity: definition?.rarity,
            habitat: definition?.habitat,
            trailStrength: 0,
            encounterOdds: 1,
            trailDistance: 0,
            consecutiveNoFinds: 0,
            bonusPoints: 0,
            trailMapBonusPercentagePoints: 0,
            createdAt: now
        )
        return SheepSearchCalculation(outcome: outcome, score: 0)
    }
}
