import SwiftUI

struct NightFlockHomeCard: View {
    let summary: NightFlockHomeSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PixelCard {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "person.3.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppColors.lavender)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(summary.challengeDay.map { "SLUMBER PARTY · DAY \($0) OF 7" } ?? "SLUMBER PARTY")
                            .font(pixelFont(.caption2))
                            .foregroundStyle(AppColors.grass)
                        Text(summary.title)
                            .font(AppTypography.headline)
                        Text(summary.detail)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the invite-only Slumber Party pasture under Farm")
    }
}
