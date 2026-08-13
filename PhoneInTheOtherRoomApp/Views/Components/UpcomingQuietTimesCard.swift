import SwiftUI

struct UpcomingQuietTimesCard: View {
    var nextPeriod: WindDownSchedulePeriod?
    var additionalCount: Int
    var immediateStartMinutes: Int?
    var trailMapPresentation: SheepTrailMapPresentation?
    var action: () -> Void
    var startNow: () -> Void

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Button(action: action) {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.title2.weight(.black))
                            .foregroundStyle(AppColors.grass)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("Phone Break schedule")
                                .font(AppTypography.headline)
                            Text(summary)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppColors.muted)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens your scheduled Phone Breaks")

                if let trailMapPresentation {
                    Divider()
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

                if let immediateStartMinutes {
                    Button(action: startNow) {
                        Label("Start \(immediateStartMinutes)-minute Phone Break", systemImage: "timer")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .accessibilityHint("Starts a separate Phone Break without changing Wind Down")
                }
            }
        }
    }

    private var summary: String {
        guard let nextPeriod else {
            return additionalCount == 0
                ? "Start a Phone Break now or schedule one outside your usual Wind Down."
                : "Your next Phone Break is being tended by Ollie."
        }
        let start = nextPeriod.occurrence.interval.start.formatted(date: .abbreviated, time: .shortened)
        let count: String
        switch additionalCount {
        case 0: count = "No Phone Breaks"
        case 1: count = "1 Phone Break"
        default: count = "\(additionalCount) Phone Breaks"
        }
        return "Next: \(start) · \(count)"
    }
}

#Preview("Extra quiet · mapped trail") {
    UpcomingQuietTimesCard(
        nextPeriod: nil,
        additionalCount: 0,
        immediateStartMinutes: 30,
        trailMapPresentation: SheepTrailMapPresentation.home(availableBonusPercentagePoints: 5),
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
        trailMapPresentation: nil,
        action: {},
        startNow: {}
    )
    .padding()
    .background(AppColors.paper)
}
