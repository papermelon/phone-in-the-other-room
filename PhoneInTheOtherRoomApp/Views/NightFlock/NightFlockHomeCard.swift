import SwiftUI

struct NightFlockHomeCard: View {
    let summary: NightFlockHomeSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "person.3.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.lavender)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(summary.challengeDay.map { "SLUMBER PARTY · DAY \($0) OF 7" } ?? "SLUMBER PARTY")
                        .font(pixelFont(.caption2))
                        .foregroundStyle(AppColors.grass)
                    if summary.title != "Slumber Party" {
                        Text(summary.title)
                            .font(AppTypography.body)
                    }
                    Text(summary.detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.muted)
            }
            .foregroundStyle(AppColors.ink)
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                PixelPanelShape(cut: 7)
                    .fill(AppColors.panel)
                    .overlay(PixelPanelShape(cut: 7).stroke(AppColors.stroke.opacity(0.7), lineWidth: 1.5))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the invite-only Slumber Party pasture under Farm")
    }
}
