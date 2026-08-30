import SwiftUI

struct NightFlockHomeCard: View {
    let summary: NightFlockHomeSummary
    var context: NightFlockHomeCardContext = .home
    let action: () -> Void

    private var presentation: NightFlockV4BridgePresentation {
        .make(from: summary, context: context)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "person.3.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppColors.lavender)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(presentation.eyebrow)
                        .font(pixelFont(.caption2))
                        .foregroundStyle(AppColors.grass)
                    Text(presentation.title)
                        .font(AppTypography.body)
                    Text(presentation.detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
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
        .accessibilityHint(context == .home ? "Opens Slumber Party" : "Opens Slumber Party from your Farm")
    }
}
