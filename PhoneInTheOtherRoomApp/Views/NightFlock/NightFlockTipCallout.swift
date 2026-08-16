import SwiftUI

struct NightFlockTipCallout: View {
    @ObservedObject var viewModel: NightFlockViewModel
    let tip: NightFlockOrientationTip
    let title: String
    let message: String

    var body: some View {
        if !viewModel.orientationState.seenTips.contains(tip) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AppColors.amber)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title).font(AppTypography.caption.weight(.semibold))
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Dismiss tip") {
                        viewModel.markNightFlockTipSeen(tip)
                    }
                    .font(AppTypography.caption.weight(.semibold))
                }
            }
            .padding(AppSpacing.sm)
            .background(AppColors.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .contain)
        }
    }
}
