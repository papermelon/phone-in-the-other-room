import SwiftUI

struct SheepSearchOutcomeCard: View {
    let outcome: SheepSearchOutcome
    let showExactOdds: Bool

    private var sheep: SheepDefinition? {
        outcome.sheepID.flatMap(SheepCatalog.definition)
    }

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    PixelAssetImage(name: sheep?.assetName ?? AssetSlot.Dog.proud)
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(outcome.result == .found ? "A SHEEP FOUND ITS WAY HOME" : "OLLIE FOUND THE TRAIL")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text(
                            sheep.map { "Meet \($0.name)" }
                                ?? "No sheep tonight, but the trail is growing"
                        )
                            .font(AppTypography.headline)
                        Text(
                            sheep?.story
                                ?? "Ollie searched \(distanceLabel) and left a clue for the next quiet night."
                        )
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                        if let accessory = sheep?.accessory {
                            Text("Look for \(accessory).")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.grass)
                        }
                    }
                }

                HStack(spacing: AppSpacing.md) {
                    metric("Trail", value: distanceLabel)
                    metric("Strength", value: strengthLabel)
                    if let rarity = outcome.rarity {
                        metric("Rarity", value: rarity.title)
                    }
                }

                if showExactOdds {
                    Text("Encounter odds: \(Int((outcome.encounterOdds * 100).rounded()))%")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else {
                    Text("Trail strength is shown without exact odds. You can turn them on in More.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    private var distanceLabel: String {
        String(format: "%.1f km", outcome.trailDistance)
    }

    private var strengthLabel: String {
        switch outcome.trailStrength {
        case 0..<35: return "Faint"
        case 35..<60: return "Promising"
        case 60..<80: return "Strong"
        default: return "Very strong"
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title.uppercased())
                .font(pixelFont(.caption))
                .foregroundStyle(AppColors.muted)
            Text(value)
                .font(AppTypography.caption.weight(.semibold))
        }
    }
}

struct SheepWantedPostersCard: View {
    let searchState: SheepSearchState
    let protectedNightNumber: Int

    private var activePosters: [SheepDefinition] {
        SheepCatalog.eligible(for: max(1, protectedNightNumber))
            .filter { !searchState.foundSheepIDs.contains($0.id) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("OLLIE'S WANTED POSTERS")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Spacer()
                    Text("\(searchState.foundSheepIDs.count) found")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                if activePosters.isEmpty {
                    Text("The pasture is quiet for now. New posters will arrive as Ollie follows more trails.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                } else {
                    ForEach(activePosters) { sheep in
                        HStack(spacing: AppSpacing.sm) {
                            PixelAssetImage(name: sheep.assetName)
                                .frame(width: 42, height: 42)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(sheep.name)
                                    .font(AppTypography.headline)
                                Text("\(sheep.breed.title) · \(sheep.rarity.title) · \(sheep.habitat.title)")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.muted)
                                if let accessory = sheep.accessory {
                                    Text(accessory)
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.grass)
                                }
                            }
                            Spacer()
                            Text(sheep.posterClue)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.secondaryText)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 140, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }
}

#Preview("Found") {
    SheepSearchOutcomeCard(
        outcome: SheepSearchOutcome(
            id: UUID(),
            runID: UUID(),
            protectedNightNumber: 3,
            result: .found,
            sheepID: "mabel",
            rarity: .common,
            habitat: .starterPasture,
            trailStrength: 72,
            encounterOdds: 0.68,
            trailDistance: 4.2,
            consecutiveNoFinds: 0,
            bonusPoints: 2,
            createdAt: Date()
        ),
        showExactOdds: false
    )
    .padding()
    .background(AppColors.paper)
}
