import SwiftUI

struct AccountSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(AppTypography.body)
            .foregroundStyle(isEnabled ? AppColors.ink : AppColors.muted)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, AppSpacing.md).padding(.vertical, AppSpacing.xs)
            .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).stroke(AppColors.stroke, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct AccountPrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(AppTypography.body.weight(.semibold))
            .foregroundStyle(colorScheme == .dark ? AppColors.paper : AppColors.ink)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(AppSpacing.sm)
            .background(AppColors.grassLight, in: RoundedRectangle(cornerRadius: AppRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).stroke(AppColors.stroke, lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.6)
    }
}

/// Navigation and secondary actions should not compete with the filled primary action.
struct AccountRowLabel: View {
    let title: String
    let symbol: String
    var detail: String? = nil
    var destructive = false

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: symbol)
                .foregroundStyle(destructive ? AppColors.destructive : AppColors.grass)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title).font(AppTypography.body)
                if let detail {
                    Text(detail).font(AppTypography.caption).foregroundStyle(AppColors.secondaryText)
                }
            }
            Spacer(minLength: AppSpacing.sm)
            Image(systemName: "chevron.right").font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText).accessibilityHidden(true)
        }
        .foregroundStyle(destructive ? AppColors.destructive : AppColors.ink)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct AccountTextButtonStyle: ButtonStyle {
    var destructive = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(AppTypography.body)
            .foregroundStyle(destructive ? AppColors.destructive : AppColors.ink)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}
