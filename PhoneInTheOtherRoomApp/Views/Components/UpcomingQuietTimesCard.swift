import SwiftUI

/// The secondary planning route stays available when the main action is Wind Down.
struct UpcomingQuietTimesCard: View {
    var nextPeriod: WindDownSchedulePeriod?
    var purpose: OfflinePurposeProfile = .defaultProfile
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            PixelCard {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "timer")
                        .font(AppTypography.headline)
                        .foregroundStyle(AppColors.grass)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Phone Away").font(AppTypography.headline)
                        Text(summary).font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                        Text("Plan time for yourself")
                            .font(AppTypography.caption.weight(.semibold))
                            .foregroundStyle(AppColors.grass)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                }
                .foregroundStyle(AppColors.ink)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your Phone Away plans and start options")
        .orientationTourTarget(.phoneAway)
    }

    private var summary: String {
        guard let nextPeriod else { return purpose.inAppDisplayPhrase }
        return "Next: \(nextPeriod.occurrence.interval.start.formatted(date: .abbreviated, time: .shortened))"
    }
}

#Preview("Phone Away planning") {
    UpcomingQuietTimesCard(nextPeriod: nil, purpose: .init(category: .read), action: {})
        .padding(AppSpacing.md)
        .background(AppColors.paper)
}

#Preview("Phone Away at large text") {
    UpcomingQuietTimesCard(nextPeriod: nil, action: {})
        .environment(\.dynamicTypeSize, .accessibility3)
        .padding(AppSpacing.md)
        .background(AppColors.paper)
}
