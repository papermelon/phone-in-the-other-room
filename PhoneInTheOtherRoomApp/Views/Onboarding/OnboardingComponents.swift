import SwiftUI

struct OnboardingProgressHeader: View {
    let step: CountingSheepOnboardingStep
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .frame(width: 44, height: 44)
            }
            .opacity(step == .welcome ? 0 : 1)
            .disabled(step == .welcome)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("COUNTING SHEEP")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                ProgressView(value: step.progress)
                    .tint(AppColors.grass)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(step.rawValue + 1) / \(CountingSheepOnboardingStep.allCases.count)")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .monospacedDigit()
        }
        .foregroundStyle(AppColors.ink)
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled = true

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.right")
            }
            .font(AppTypography.headline)
            .padding(.horizontal, AppSpacing.md)
            .frame(minHeight: 46)
        }
        .buttonStyle(OnboardingPrimaryButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.vertical, 11)
            .padding(.horizontal, AppSpacing.md)
            .background(AppColors.grass.opacity(configuration.isPressed ? 0.88 : 1))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(AppColors.stroke.opacity(0.9), lineWidth: 2))
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.99 : 1)
    }
}

struct OnboardingChoiceCard: View {
    let title: String
    let detail: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.title3.weight(.black))
                    .foregroundStyle(isSelected ? AppColors.paper : AppColors.grass)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.headline)
                        .foregroundStyle(isSelected ? AppColors.paper : AppColors.ink)
                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(isSelected ? AppColors.paper.opacity(0.86) : AppColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: AppSpacing.xs)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppColors.paper : AppColors.muted)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? AppColors.grass : AppColors.surface,
                in: RoundedRectangle(cornerRadius: AppRadius.lg)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.stroke.opacity(isSelected ? 0.8 : 0.25), lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct OnboardingTimeline: View {
    let draft: OnboardingDraft

    var body: some View {
        HStack(spacing: 0) {
            timelineItem(icon: "moon.zzz.fill", title: "Wind down", detail: "\(draft.windDownMinutes)m")
            Image(systemName: "arrow.right")
                .foregroundStyle(AppColors.muted)
                .padding(.horizontal, AppSpacing.xs)
            timelineItem(icon: "bed.double.fill", title: "Phone rests", detail: "Overnight")
            Image(systemName: "arrow.right")
                .foregroundStyle(AppColors.muted)
                .padding(.horizontal, AppSpacing.xs)
            timelineItem(icon: "sun.max.fill", title: "Morning quiet", detail: "\(draft.morningQuietMinutes)m")
        }
        .padding(AppSpacing.sm)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.lg))
    }

    private func timelineItem(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.grass)
            Text(title)
                .font(AppTypography.caption)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .foregroundStyle(AppColors.muted)
        }
        .frame(maxWidth: .infinity)
    }
}
