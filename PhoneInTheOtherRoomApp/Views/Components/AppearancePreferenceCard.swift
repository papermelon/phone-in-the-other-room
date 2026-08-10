import SwiftUI

struct AppearancePreferenceCard: View {
    let preference: AppAppearancePreference
    let onSelect: (AppAppearancePreference) -> Void

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Appearance")
                    .font(AppTypography.headline)
                Text("Neither selected follows your iPhone.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                Text("Wind Down stays dark.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppSpacing.sm) {
                        appearanceButton(.light)
                        appearanceButton(.dark)
                    }
                    VStack(spacing: AppSpacing.xs) {
                        appearanceButton(.light)
                        appearanceButton(.dark)
                    }
                }
            }
        }
    }

    private func appearanceButton(_ option: AppAppearancePreference) -> some View {
        let isSelected = preference == option
        return Button {
            onSelect(
                AppAppearancePreference.selection(
                    afterTapping: option,
                    from: preference
                )
            )
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Text(option == .light ? "Light Mode" : "Dark Mode")
                    .font(AppTypography.body.weight(.semibold))
                Spacer(minLength: AppSpacing.xs)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body.weight(.bold))
                }
            }
            .foregroundStyle(isSelected ? Color.white : AppColors.ink)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(
                isSelected ? AppColors.grass : AppColors.surfaceMuted,
                in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(
                        isSelected ? AppColors.grass : AppColors.stroke.opacity(0.35),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option == .light ? "Light Mode" : "Dark Mode")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Appearance · automatic") {
    AppearancePreferenceCard(preference: .automatic, onSelect: { _ in })
        .padding()
        .background(AppColors.paper)
}

#Preview("Appearance · explicit dark") {
    AppearancePreferenceCard(preference: .dark, onSelect: { _ in })
        .padding()
        .background(AppColors.paper)
        .preferredColorScheme(.dark)
}

#Preview("Appearance · accessibility text") {
    AppearancePreferenceCard(preference: .light, onSelect: { _ in })
        .padding()
        .background(AppColors.paper)
        .environment(\.dynamicTypeSize, .accessibility2)
}
