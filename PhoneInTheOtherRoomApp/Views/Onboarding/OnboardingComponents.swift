import SwiftUI

struct OnboardingProgressHeader: View {
    let draft: OnboardingDraft
    var showsBack = false
    let onBack: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var stageNumber: Int { draft.currentStageNumber }
    private var stageCount: Int { draft.stageCount }

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack {
                backButton
                Spacer(minLength: AppSpacing.sm)
                Text("COUNTING SHEEP")
                    .font(pixelFont(dynamicTypeSize.isAccessibilitySize ? .caption2 : .caption))
                    .foregroundStyle(AppColors.grass)
                    .multilineTextAlignment(.center)
                Spacer(minLength: AppSpacing.sm)
                Color.clear.frame(width: 44, height: 44)
            }

            HStack(spacing: 6) {
                ForEach(1...stageCount, id: \.self) { number in
                    Capsule()
                        .fill(number <= stageNumber ? AppColors.grass : AppColors.surfaceMuted)
                        .frame(maxWidth: .infinity, minHeight: 5, maxHeight: 5)
                }
            }
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 260)
            .animation(reduceMotion ? nil : AppMotion.progress, value: stageNumber)
            .accessibilityHidden(true)

            Text("\(draft.step.title.uppercased()) · STAGE \(stageNumber) OF \(stageCount)")
                .font(pixelFont(.caption2))
                .foregroundStyle(AppColors.muted)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Counting Sheep setup, \(draft.step.title), stage \(stageNumber) of \(stageCount)")
    }

    @ViewBuilder
    private var backButton: some View {
        if showsBack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .black))
                    .frame(width: 44, height: 44)
                    .background(AppColors.surface, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(AppColors.stroke.opacity(0.18), lineWidth: 1.5)
                    }
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.ink)
            .accessibilityLabel("Back to the previous page")
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
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
                    .fixedSize(horizontal: false, vertical: true)
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
                        .fixedSize(horizontal: false, vertical: true)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(AppTypography.caption)
                            .foregroundStyle(isSelected ? AppColors.paper.opacity(0.86) : AppColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: AppSpacing.xs)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppColors.paper : AppColors.muted)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                verticalTimeline
            } else {
                ViewThatFits(in: .horizontal) {
                    horizontalTimeline
                    verticalTimeline
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.lg))
    }

    private var horizontalTimeline: some View {
            HStack(spacing: 0) {
                timelineItem(icon: "moon.zzz.fill", title: "Quiet before bed", detail: "\(draft.windDownMinutes)m")
                timelineArrow
                timelineItem(icon: "bed.double.fill", title: "Phone away", detail: "Overnight")
                timelineArrow
                timelineItem(icon: "sun.max.fill", title: "Quiet after waking", detail: "\(draft.morningQuietMinutes)m")
            }
    }

    private var verticalTimeline: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            timelineRow(icon: "moon.zzz.fill", title: "Quiet before bed", detail: "\(draft.windDownMinutes)m")
            timelineRow(icon: "bed.double.fill", title: "Phone away", detail: "Overnight")
            timelineRow(icon: "sun.max.fill", title: "Quiet after waking", detail: "\(draft.morningQuietMinutes)m")
        }
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
        OnboardingProgressHeader(draft: OnboardingDraft(), showsBack: false, onBack: {})
        OnboardingProgressHeader(draft: OnboardingDraft(step: .quiet), showsBack: true, onBack: {})
        OnboardingProgressHeader(draft: OnboardingDraft(step: .ready), showsBack: true, onBack: {})
    }
    .padding()
    .background(AppColors.paper)
}
