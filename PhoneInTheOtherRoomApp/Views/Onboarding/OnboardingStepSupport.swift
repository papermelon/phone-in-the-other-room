import SwiftUI

func onboardingTitle(eyebrow: String, title: String, detail: String? = nil) -> some View {
    VStack(alignment: .leading, spacing: AppSpacing.xs) {
        Text(eyebrow)
            .font(pixelFont(.caption))
            .foregroundStyle(AppColors.grass)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        Text(title)
            .font(AppTypography.title)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
        if let detail, !detail.isEmpty {
            Text(detail)
                .font(AppTypography.body)
                .foregroundStyle(AppColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
