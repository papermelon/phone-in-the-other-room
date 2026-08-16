import SwiftUI

struct OnboardingProgressHeader: View {
    let step: CountingSheepOnboardingStep
    var showsBack = false
    let onBack: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var stepNumber: Int { step.visibleIndex + 1 }
    private var stepCount: Int { CountingSheepOnboardingStep.visibleSteps.count }

    var body: some View {
        ZStack(alignment: .leading) {
            VStack(spacing: AppSpacing.xs) {
                Text("COUNTING SHEEP")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)

                HStack(spacing: 6) {
                    ForEach(Array(CountingSheepOnboardingStep.visibleSteps.enumerated()), id: \.element.id) { index, _ in
                        Capsule()
                            .fill(index <= step.visibleIndex ? AppColors.grass : AppColors.surfaceMuted)
                            .frame(maxWidth: .infinity, minHeight: 5, maxHeight: 5)
                    }
                }
                .frame(maxWidth: 224)
                .animation(reduceMotion ? nil : AppMotion.progress, value: step)
                .accessibilityHidden(true)

                Text("STEP \(stepNumber) OF \(stepCount)")
                    .font(pixelFont(.caption2))
                    .foregroundStyle(AppColors.muted)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)

            if showsBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.black))
                        .frame(width: 40, height: 40)
                        .background(AppColors.surface, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(AppColors.stroke.opacity(0.18), lineWidth: 1.5)
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.ink)
                .accessibilityLabel("Back to \(previousStepTitle)")
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 64)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Counting Sheep setup, step \(stepNumber) of \(stepCount), \(step.title)")
    }

    private var previousStepTitle: String {
        guard step.visibleIndex > 0 else { return "the previous step" }
        return CountingSheepOnboardingStep.visibleSteps[step.visibleIndex - 1].title
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                timelineItem(icon: "moon.zzz.fill", title: "Quiet before bed", detail: "\(draft.windDownMinutes)m")
                timelineArrow
                timelineItem(icon: "bed.double.fill", title: "Phone away", detail: "Overnight")
                timelineArrow
                timelineItem(icon: "sun.max.fill", title: "Quiet after waking", detail: "\(draft.morningQuietMinutes)m")
            }
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                timelineRow(icon: "moon.zzz.fill", title: "Quiet before bed", detail: "\(draft.windDownMinutes)m")
                timelineRow(icon: "bed.double.fill", title: "Phone away", detail: "Overnight")
                timelineRow(icon: "sun.max.fill", title: "Quiet after waking", detail: "\(draft.morningQuietMinutes)m")
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.lg))
    }

    private var timelineArrow: some View {
        Image(systemName: "arrow.right")
            .foregroundStyle(AppColors.muted)
            .padding(.horizontal, AppSpacing.xs)
            .accessibilityHidden(true)
    }

    private func timelineRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.grass)
                .frame(width: 24)
            Text(title)
                .font(AppTypography.caption)
            Spacer(minLength: AppSpacing.sm)
            Text(detail)
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .foregroundStyle(AppColors.muted)
        }
        .frame(minHeight: 44)
    }

    private func timelineItem(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.grass)
            Text(title)
                .font(AppTypography.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(detail)
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .foregroundStyle(AppColors.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
    }
}

#Preview("Onboarding progress") {
    VStack(spacing: AppSpacing.xl) {
        OnboardingProgressHeader(step: .welcome, showsBack: false, onBack: {})
        OnboardingProgressHeader(step: .quiet, showsBack: true, onBack: {})
        OnboardingProgressHeader(step: .ready, showsBack: true, onBack: {})
    }
    .padding()
    .background(AppColors.paper)
}
