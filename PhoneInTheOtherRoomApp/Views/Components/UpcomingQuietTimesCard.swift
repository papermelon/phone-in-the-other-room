import SwiftUI

struct UpcomingQuietTimesCard: View {
    var nextPeriod: WindDownSchedulePeriod?
    var additionalCount: Int
    var immediateStartMinutes: Int?
    var scheduledStart: WindDownStartContext?
    var windDownIsReady: Bool
    var trailMapPresentation: SheepTrailMapPresentation?
    var protectionPresentation: HomeProtectionStartPresentation
    var action: () -> Void
    var startNow: () -> Void
    var startScheduled: (UUID) -> Void = { _ in }
    var showsQuickStartActions = true

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Button(action: action) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.title2.weight(.black))
                        .foregroundStyle(AppColors.grass)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Phone Away")
                            .font(AppTypography.headline)
                        Text(summary)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: AppSpacing.xxs) {
                        Text("Plan")
                            .font(AppTypography.caption.weight(.bold))
                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppColors.muted)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens your Phone Away schedule")

            if let trailMapPresentation {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "map.fill")
                        .foregroundStyle(AppColors.grass)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(trailMapPresentation.title)
                            .font(AppTypography.body)
                        Text(trailMapPresentation.detail)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            if showsQuickStartActions, let scheduledStart {
                scheduledAction(scheduledStart)
            }
            if showsQuickStartActions, let immediateStartMinutes {
                Button(action: startNow) {
                    Label("Start now · \(immediateStartMinutes) min", systemImage: "timer")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                .accessibilityHint("Starts Phone Away without changing Wind Down")
            }
        }
        .orientationTourTarget(.phoneAway)
    }

    @ViewBuilder
    private func scheduledAction(_ context: WindDownStartContext) -> some View {
        let presentation: (label: String, icon: String, hint: String) = {
            switch protectionPresentation {
            case let .repair(title, detail):
                return (title, "shield.lefthalf.filled", detail)
            case .ready:
                return ("Start scheduled \(context.title)", "play.fill", "Starts the scheduled Phone Away period")
            }
        }()
        Button {
            guard let sourceID = context.sourceID else { return }
            startScheduled(sourceID)
        } label: {
            Label(presentation.label, systemImage: presentation.icon)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(PixelChipButtonStyle(isSelected: false))
        .accessibilityHint(presentation.hint)
    }

    private var summary: String {
        guard let nextPeriod else {
            return additionalCount == 0
                ? "Start now or plan a Phone Away period outside your usual Wind Down."
                : "Your next Phone Away period is being tended by Ollie."
        }
        let start = nextPeriod.occurrence.interval.start.formatted(date: .abbreviated, time: .shortened)
        let count: String
        switch additionalCount {
        case 0: count = "No Phone Away periods"
        case 1: count = "1 Phone Away period"
        default: count = "\(additionalCount) Phone Away periods"
        }
        return "Next: \(start) · \(count)"
    }
}

#Preview("Phone Away search progress") {
    UpcomingQuietTimesCard(
        nextPeriod: nil,
        additionalCount: 0,
        immediateStartMinutes: 30,
        scheduledStart: nil,
        windDownIsReady: false,
        trailMapPresentation: SheepTrailMapPresentation.home(availableBonusPercentagePoints: 5),
        protectionPresentation: .ready(selectionSummary: "2 apps"),
        action: {},
        startNow: {}
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Extra quiet · Wind Down soon") {
    UpcomingQuietTimesCard(
        nextPeriod: nil,
        additionalCount: 0,
        immediateStartMinutes: nil,
        scheduledStart: nil,
        windDownIsReady: true,
        trailMapPresentation: nil,
        protectionPresentation: .ready(selectionSummary: "2 apps"),
        action: {},
        startNow: {}
    )
    .padding()
    .background(AppColors.paper)
}
