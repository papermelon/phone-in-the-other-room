import SwiftUI

/// A compact factual member card. One chosen identity gives the group a face;
/// activity, live status, and cheers remain the meaningful changing content.
struct SlumberPartyV4MemberCard: View {
    let member: NightFlockV4Membership
    let isYou: Bool
    let presentation: NightFlockV4MemberPresentation
    var onBlock: (() -> Void)? = nil
    var onReport: ((NightFlockReportReason) -> Void)? = nil
    var liveCheerCount: Int = 0
    var onLiveCheer: ((NightFlockV4Cheer) -> Void)? = nil
    var liveCheerState: ((NightFlockV4Cheer) -> NightFlockV4CheerSendState?)? = nil
    /// Optional shared-habits values are supplied from the party archive;
    /// absence remains an observed-data gap, not a member score.
    var sharedSleepSummary: NightFlockSharedHabitPeriodSummary? = nil
    var sharedWindDownSummary: NightFlockSharedHabitPeriodSummary? = nil
    var sharedSleepWeekSummary: NightFlockSharedHabitPeriodSummary? = nil
    var sharedSleepMonthSummary: NightFlockSharedHabitPeriodSummary? = nil
    var showsSharedHabitMetrics = false
    var showsSocialAvatar = false
    var showsActivitySummary = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .center, spacing: AppSpacing.sm) {
                    identity
                    memberHeading
                }
                factualContent
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var identity: some View {
        SlumberPartySocialAvatarView(
            presentation: member.profile.presentation,
            avatarID: SocialAvatarRules.shepherdID,
            size: dynamicTypeSize.isAccessibilitySize ? 72 : 68
        )
    }

    private var memberHeading: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(member.profile.displayName.isEmpty ? "A group member" : member.profile.displayName)
                    .font(AppTypography.headline)
                    .fixedSize(horizontal: false, vertical: true)
                memberBadges
            }
            Spacer(minLength: AppSpacing.xs)
            if !isYou, onBlock != nil || onReport != nil {
                memberSafetyMenu
            }
        }
    }

    private var factualContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if let liveStatusTitle = presentation.liveStatusTitle {
                Text(liveStatusTitle)
                    .font(AppTypography.caption.weight(.semibold))
                    .foregroundStyle(AppColors.ink)
            }
            if showsActivitySummary, let latestActivityLine = presentation.latestActivityLine {
                Text(latestActivityLine)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else if showsActivitySummary, !presentation.hasSharedUpdate,
                      sharedSleepSummary == nil,
                      sharedWindDownSummary == nil {
                Text("No shared moment yet")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
            if showsSharedHabitMetrics {
                sharedHabitMetrics
                if sharedSleepWeekSummary != nil || sharedSleepMonthSummary != nil {
                    sharedSleepHistory
                }
            }
            if presentation.liveCheerCount > 0 {
                Text(presentation.liveCheerCount == 1
                     ? "1 quiet cheer recorded across shared statuses"
                     : "\(presentation.liveCheerCount) quiet cheers recorded across shared statuses")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.grass)
            }
            if !isYou, presentation.canSendLiveCheer, let onLiveCheer {
                liveCheerMenu(onLiveCheer)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var sharedHabitMetrics: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            if sharedSleepSummary == nil && sharedWindDownSummary == nil {
                // One truthful line instead of two identical empty cells. When
                // the card already says "No shared moment yet", say nothing more.
                if showsActivitySummary && (presentation.latestActivityLine != nil || presentation.hasSharedUpdate) {
                    Text("Sleep and Wind Down summaries not shared yet")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    sleepMetric
                    windDownMetric
                }
            } else {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    sleepMetric
                    windDownMetric
                }
            }

        }
        .accessibilityElement(children: .contain)
    }

    private var sleepMetric: some View {
        sharedMetric(
            title: "Sleep",
            summary: sharedSleepSummary,
            emptyTitle: "Not shared yet",
            showsNightEnding: true
        )
    }

    private var windDownMetric: some View {
        sharedMetric(
            title: "Wind Down",
            summary: sharedWindDownSummary,
            emptyTitle: "Not shared yet"
        )
    }

    private var sharedSleepHistory: some View {
        DisclosureGroup("Sleep averages") {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                sharedHistoryRow("7 nights", sharedSleepWeekSummary)
                sharedHistoryRow("30 nights", sharedSleepMonthSummary)
            }
            .padding(.top, AppSpacing.xs)
        }
        .font(AppTypography.caption.weight(.semibold))
    }

    private func sharedHistoryRow(
        _ title: String,
        _ summary: NightFlockSharedHabitPeriodSummary?
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                    Text(summary?.averageMinutes.map(NightFlockSharedHabitPresentation.meanDurationText) ?? "No data")
                        .font(AppTypography.body.weight(.semibold))
                    Text(summary.map { "\($0.coveredNights) of \($0.availableNights) nights" } ?? "No coverage")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                    Text(title)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                    Spacer(minLength: AppSpacing.sm)
                    Text(summary?.averageMinutes.map(NightFlockSharedHabitPresentation.meanDurationText) ?? "No data")
                        .font(AppTypography.caption.weight(.semibold))
                    Text(summary.map { "\($0.coveredNights) of \($0.availableNights) nights" } ?? "No coverage")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func sharedMetric(
        title: String,
        summary: NightFlockSharedHabitPeriodSummary?,
        emptyTitle: String,
        showsNightEnding: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title.uppercased())
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryText)
            Text(summary?.averageMinutes.map(NightFlockSharedHabitPresentation.meanDurationText) ?? emptyTitle)
                .font(AppTypography.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let summary {
                if summary.period != .lastNight {
                    Text("\(summary.coveredNights) of \(summary.availableNights) nights")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
                if showsNightEnding, summary.period == .lastNight {
                    Text("Night ending \(NightFlockSharedHabitPresentation.localDateText(summary.endingOn))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var memberBadges: some View {
        HStack(spacing: AppSpacing.xs) {
            if isYou { memberBadge("You") }
            if member.role == .host { memberBadge("Host") }
        }
    }

    private var memberSafetyMenu: some View {
        Menu {
            if let onReport {
                Menu("Report member") {
                    ForEach(NightFlockReportReason.allCases) { reason in
                        Button(reason.title) {
                            onReport(reason)
                        }
                    }
                }
            }
            if let onBlock {
                Button("Block member", role: .destructive) {
                    onBlock()
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Safety options for \(member.profile.displayName)")
    }

    private func liveCheerMenu(_ onLiveCheer: @escaping (NightFlockV4Cheer) -> Void) -> some View {
        let pendingCheers = NightFlockV4Cheer.allCases.filter { liveCheerState?($0) == .pending }
        let sentCheers = NightFlockV4Cheer.allCases.filter { liveCheerState?($0) == .sent }
        let choices = NightFlockV4Cheer.allCases.filter { cheer in
            let state = liveCheerState?(cheer)
            return state != .pending && state != .sent
        }
        return Menu {
            if !pendingCheers.isEmpty {
                Text("Sending \(pendingCheers.map { liveCheerTitle($0) }.joined(separator: ", "))…")
            }
            if !sentCheers.isEmpty {
                Text("Sent \(sentCheers.map { liveCheerTitle($0) }.joined(separator: ", "))")
            }
            ForEach(choices, id: \.self) { cheer in
                Button(liveCheerTitle(cheer)) {
                    onLiveCheer(cheer)
                }
            }
        } label: {
            Label(liveCheerMenuTitle(pending: pendingCheers, sent: sentCheers), systemImage: "hand.wave")
                .font(AppTypography.caption.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .disabled(choices.isEmpty)
        .accessibilityHint("Records a quiet cheer for this currently shared status.")
    }

    private func liveCheerMenuTitle(
        pending: [NightFlockV4Cheer],
        sent: [NightFlockV4Cheer]
    ) -> String {
        if !pending.isEmpty { return "Sending quiet cheer…" }
        if !sent.isEmpty { return "Quiet cheer sent" }
        return "Send a quiet cheer"
    }

    private func liveCheerTitle(_ cheer: NightFlockV4Cheer) -> String {
        switch cheer {
        case .warmWave: "Warm wave"
        case .moonGlow: "Moon glow"
        case .pawPrint: "Paw print"
        }
    }

    private func memberBadge(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.caption.weight(.semibold))
            .foregroundStyle(AppColors.grass)
    }
}
