import SwiftUI

struct CompletionRewardCard: View {
    let presentation: CompletionRewardPresentation

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if let sheep = presentation.sheepID.flatMap(SheepCatalog.definition) {
                    PixelAssetImage(name: sheep.assetName)
                        .frame(height: OllieRitualPresentation.cardCompanion.canvasSize)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(sheep.name)
                } else {
                    OllieRitualView(state: .completed, presentation: .inline)
                        .frame(maxWidth: .infinity)
                }
                Text(presentation.headline)
                    .font(AppTypography.title)
                    .fixedSize(horizontal: false, vertical: true)
                Text(presentation.detail)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                if let fraction = presentation.progressFraction, let label = presentation.progressLabel {
                    ProgressView(value: fraction)
                        .tint(AppColors.grass)
                        .accessibilityLabel(label)
                    Text(label)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("Completion · progress carried forward") {
    CompletionRewardCard(presentation: .init(
        outcome: nil,
        credit: FarmCreditReceipt(creditedSeconds: 3600, excludedAccessSeconds: 0, trackingIncomplete: false, migrated: false, outcomeIDs: []),
        isPhoneAway: false, bankedSeconds: 338 * 60
    ))
    .padding(AppSpacing.md)
    .background(AppColors.paper)
}

#Preview("Completion · no credit · large text") {
    CompletionRewardCard(presentation: .init(outcome: nil, credit: nil, isPhoneAway: false))
        .padding(AppSpacing.md)
        .background(AppColors.paper)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Completion · saved sheep") {
    let outcome = SheepSearchOutcome(id: UUID(), runID: UUID(), protectedNightNumber: 3,
        result: .found, sheepID: "clementine", rarity: .common, habitat: .sunriseHill,
        trailStrength: 0, encounterOdds: 0, trailDistance: 0, consecutiveNoFinds: 0,
        bonusPoints: 0, createdAt: Date())
    CompletionRewardCard(presentation: .init(outcome: outcome, credit: nil, isPhoneAway: false))
        .padding(AppSpacing.md)
        .background(AppColors.paper)
}
