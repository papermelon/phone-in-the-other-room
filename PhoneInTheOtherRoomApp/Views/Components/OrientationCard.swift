import SwiftUI

struct CountingSheepOrientationCard: View {
    let state: CountingSheepOrientationState
    let onReviewWindDown: () -> Void
    let onStartPractice: () -> Void
    let onSeeNights: () -> Void
    let onVisitFarm: () -> Void
    let onDismiss: () -> Void
    let onSkip: () -> Void

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "map.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppColors.grass)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("A LITTLE ORIENTATION")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text(title)
                            .font(AppTypography.headline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: AppSpacing.xs)
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Put orientation away for now")
                }

                Text(message)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                tabGuide
                action

                HStack(spacing: AppSpacing.md) {
                    Button("Not now", action: onDismiss)
                        .font(AppTypography.caption.weight(.semibold))
                        .frame(minHeight: 44)
                    Button("Explore on my own", action: onSkip)
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(AppColors.muted)
                        .frame(minHeight: 44)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        if !state.milestones.contains(.windDownSaved) {
            return "A small map for your first Wind Down"
        }
        if !state.milestones.contains(.practiceStarted) {
            return "Your Wind Down plan is saved"
        }
        if !state.milestones.contains(.practiceCompleted) {
            return "Ollie is keeping your practice quiet"
        }
        if !state.milestones.contains(.practiceRecordViewed) {
            return "Your practice has a record"
        }
        return "The pasture is ready when you are"
    }

    private var message: String {
        if !state.milestones.contains(.windDownSaved) {
            return "Home starts Wind Down and shows tonight’s plan. Nights keeps your records. Farm shows Ollie’s sheep search. Settings changes your plan and connections."
        }
        if !state.milestones.contains(.practiceStarted) {
            return "When you’re ready, try five minutes of practice quiet. It is real quiet time, but not a protected night."
        }
        if !state.milestones.contains(.practiceCompleted) {
            return "This is real quiet time. Nothing else is needed while Ollie keeps watch."
        }
        if !state.milestones.contains(.practiceRecordViewed) {
            return "Your five-minute practice quiet appears in Nights as a factual record. It does not add a protected night or start Ollie’s sheep search."
        }
        return "Farm is Ollie’s sheep-search home. Only eligible completed protected nights move the search; practice quiet and one-time quiet periods stay separate."
    }

    @ViewBuilder
    private var action: some View {
        if !state.milestones.contains(.windDownSaved) {
            Button(action: onReviewWindDown) {
                Label("Review tonight’s Wind Down", systemImage: "moon.stars.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PixelPrimaryButtonStyle())
            .accessibilityHint("Opens the real Wind Down screen so you can review and save tonight’s plan")
        } else if !state.milestones.contains(.practiceStarted) {
            Button(action: onStartPractice) {
                Label("Start practice quiet", systemImage: "timer")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PixelPrimaryButtonStyle())
            .accessibilityHint("Creates and starts a real five-minute practice quiet period with the normal confirmation")
        } else if !state.milestones.contains(.practiceCompleted) {
            Text("Practice quiet is separate from protected-night progress.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if !state.milestones.contains(.practiceRecordViewed) {
            Button(action: onSeeNights) {
                Label("See this record in Nights", systemImage: "book.closed.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PixelPrimaryButtonStyle())
            .accessibilityHint("Opens the factual practice record in Nights")
        } else if !state.milestones.contains(.farmExplored) {
            Button(action: onVisitFarm) {
                Label("Visit Ollie’s Farm", systemImage: "leaf.fill")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(PixelPrimaryButtonStyle())
            .accessibilityHint("Opens Farm, where Ollie’s sheep search lives")
        } else {
            Text("Home is for Wind Down. Nights is for records. Farm is for Ollie’s sheep search. Settings is for changes.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tabGuide: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            alignment: .leading,
            spacing: AppSpacing.xs
        ) {
            orientationTab("Home", detail: "Your real Wind Down", icon: "house.fill")
            orientationTab("Nights", detail: "Your factual record", icon: "moon.stars.fill")
            orientationTab("Farm", detail: "Ollie’s sheep search", icon: "leaf.fill")
            orientationTab("Settings", detail: "Change your plan", icon: "gearshape.fill")
        }
    }

    private func orientationTab(_ title: String, detail: String, icon: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(AppTypography.caption.weight(.semibold))
                Text(detail).font(AppTypography.caption).foregroundStyle(AppColors.muted)
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(AppColors.grass)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct OrientationRecordPrompt: View {
    let onSeeNights: () -> Void

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Label("YOUR PRACTICE RECORD", systemImage: "book.closed.fill")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Five minutes of quiet, recorded plainly.")
                    .font(AppTypography.headline)
                Text("This is real quiet time, separate from protected-night progress and Ollie’s sheep search.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                Button("See it in Nights", action: onSeeNights)
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
    }
}

#Preview("Fresh orientation") {
    CountingSheepOrientationCard(
        state: .fresh,
        onReviewWindDown: {}, onStartPractice: {}, onSeeNights: {}, onVisitFarm: {},
        onDismiss: {}, onSkip: {}
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Practice completed") {
    let state: CountingSheepOrientationState = {
        var value = CountingSheepOrientationState.fresh
        value.mark(.homeExplained)
        value.mark(.windDownSaved)
        value.mark(.practiceStarted)
        value.mark(.practiceCompleted)
        return value
    }()
    CountingSheepOrientationCard(
        state: state,
        onReviewWindDown: {}, onStartPractice: {}, onSeeNights: {}, onVisitFarm: {},
        onDismiss: {}, onSkip: {}
    )
    .padding()
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}

#Preview("Partially completed") {
    let state: CountingSheepOrientationState = {
        var value = CountingSheepOrientationState.fresh
        value.mark(.homeExplained)
        value.mark(.windDownSaved)
        return value
    }()
    CountingSheepOrientationCard(
        state: state,
        onReviewWindDown: {}, onStartPractice: {}, onSeeNights: {}, onVisitFarm: {},
        onDismiss: {}, onSkip: {}
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Dismissed") {
    CountingSheepOrientationCard(
        state: CountingSheepOrientationState(
            status: .dismissed,
            milestones: [.homeExplained]
        ),
        onReviewWindDown: {}, onStartPractice: {}, onSeeNights: {}, onVisitFarm: {},
        onDismiss: {}, onSkip: {}
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Practice active") {
    let state: CountingSheepOrientationState = {
        var value = CountingSheepOrientationState.fresh
        value.mark(.homeExplained)
        value.mark(.windDownSaved)
        value.recordPracticeRun(UUID())
        return value
    }()
    CountingSheepOrientationCard(
        state: state,
        onReviewWindDown: {}, onStartPractice: {}, onSeeNights: {}, onVisitFarm: {},
        onDismiss: {}, onSkip: {}
    )
    .padding()
    .background(AppColors.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}

#Preview("Completed orientation") {
    CountingSheepOrientationCard(
        state: CountingSheepOrientationState(
            status: .completed,
            milestones: Set(CountingSheepOrientationMilestone.allCases)
        ),
        onReviewWindDown: {}, onStartPractice: {}, onSeeNights: {}, onVisitFarm: {},
        onDismiss: {}, onSkip: {}
    )
    .padding()
    .background(AppColors.paper)
}
