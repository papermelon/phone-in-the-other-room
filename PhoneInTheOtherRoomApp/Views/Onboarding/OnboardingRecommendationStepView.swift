import SwiftUI

struct OnboardingRecommendationStep: View {
    let recommendation: WindDownProfileRecommendation
    var showsSourcesLink = true

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            onboardingTitle(
                eyebrow: FirstRunGuideCopy.recommendationEyebrow,
                title: FirstRunGuideCopy.recommendationTitle,
                detail: FirstRunGuideCopy.recommendationDetail
            )

            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(recommendation.kind.title)
                        .font(AppTypography.headline)
                    Text(recommendation.summary)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(guidanceItems) { item in
                    PixelCard {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(item.title)
                                .font(AppTypography.headline)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(item.body)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(WindDownGuidanceSourcePresentation.combinedLabel(for: item))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.title). \(item.body). \(WindDownGuidanceSourcePresentation.combinedLabel(for: item))")
                }
            }

            if showsSourcesLink {
                NavigationLink {
                    WindDownGuideView()
                } label: {
                    Text(FirstRunGuideCopy.aboutIdeasAndSources)
                        .font(AppTypography.body)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityHint("Opens the local source library")
            }

            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(FirstRunGuideCopy.recommendedRoutine)
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    routineGroup("Evening", steps: [WindDownRoutineStep.phoneAwayTitle] + recommendation.eveningRoutine.map(\.title))
                    Divider()
                    routineGroup("Morning", steps: recommendation.morningRoutine.map(\.title))
                    Text("Quiet before bed: \(QuietTimeDurationOptions.label(for: recommendation.desiredWindDownMinutes)).")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let wearable = recommendation.wearableItem {
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(FirstRunGuideCopy.freeWearable)
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text(wearable.title)
                            .font(AppTypography.headline)
                        Text("This welcome gift waits in Farm. Claiming it later does not spend wool.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var guidanceItems: [WindDownGuidanceItem] {
        recommendation.guidanceIDs.compactMap { id in
            WindDownGuidanceLibrary.items.first { $0.id == id }
        }
    }

    private func routineGroup(_ title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppTypography.body.weight(.semibold))
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                Text("\(index + 1). \(step)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Recommendation") {
    ScrollView {
        OnboardingRecommendationStep(
            recommendation: WindDownProfileMapper.recommendation(for: .defaults)
        )
        .padding()
    }
    .background(AppColors.paper)
}

#Preview("Recommendation · morning reach · large type") {
    var answers = WindDownProfileAnswer.defaults
    answers = WindDownProfileAnswer(
        bedtimeHour: 23,
        bedtimeMinute: 0,
        wakeHour: 7,
        wakeMinute: 0,
        phoneUsePattern: .afterWaking,
        awayFriction: .morningCheck,
        eveningActivities: [.read],
        morningActivities: [.openCurtains, .morningWalk],
        desiredWindDownMinutes: 30
    )
    return ScrollView {
        OnboardingRecommendationStep(
            recommendation: WindDownProfileMapper.recommendation(for: answers)
        )
        .padding()
    }
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}
