import SwiftUI

func onboardingTitle(eyebrow: String, title: String, detail: String) -> some View {
    VStack(alignment: .leading, spacing: AppSpacing.xs) {
        Text(eyebrow)
            .font(pixelFont(.caption))
            .foregroundStyle(AppColors.grass)
        Text(title)
            .font(AppTypography.display(30))
        Text(detail)
            .font(AppTypography.body)
            .foregroundStyle(AppColors.muted)
    }
}
