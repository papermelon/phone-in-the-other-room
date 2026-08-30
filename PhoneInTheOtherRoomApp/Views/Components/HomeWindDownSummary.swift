import SwiftUI

/// Home keeps tonight's planned ritual visible without making a past receipt a
/// second scorecard. The resolved schedule period supplies every displayed time.
struct HomeWindDownSummary: View {
    enum Content: Equatable {
        case all
        case timing
        case actions
    }

    private enum StartAction {
        case windDown
        case scheduledPhoneAway(WindDownStartContext)
        case immediatePhoneAway(minutes: Int)
    }

    var preferences: NightWatchPreferences
    var canBeginNow: Bool
    var isNFCTagReady: Bool
    var primaryWindDownPeriod: WindDownSchedulePeriod?
    var phoneAwayStartContext: WindDownStartContext? = nil
    var immediatePhoneAwayMinutes: Int? = nil
    var protectionPresentation: HomeProtectionStartPresentation
    var onPrimaryAction: () -> Void
    var onRepairProtection: () -> Void
    var onSetup: () -> Void
    var onEdit: () -> Void
    var onPhoneAwayStartNow: () -> Void = {}
    var onPhoneAwayScheduled: (UUID) -> Void = { _ in }
    var content: Content = .all

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isExpanded = false

    @ViewBuilder
    var body: some View {
        if showsContent {
            Group {
                if preferences.isConfigured {
                    configuredSummary
                } else {
                    setupSummary
                }
            }
            .modifier(OptionalOrientationTarget(target: orientationTarget))
        }
    }

    private var orientationTarget: OrientationTourTarget? {
        if preferences.isConfigured {
            return content == .actions ? nil : .homePlan
        }
        return content == .timing ? nil : .homePlan
    }

    private var showsContent: Bool {
        if preferences.isConfigured {
            guard content == .actions else { return true }
            return configuredActionIsVisible
        }
        return content != .timing
    }

    @ViewBuilder
    private var configuredSummary: some View {
        if content != .actions {
            timingCard
        }
        if content != .timing {
            configuredActions
        }
    }

    private var configuredActionIsVisible: Bool {
        if case .repair = protectionPresentation { return true }
        if canBeginNow, !canStartWithCurrentMethod { return true }
        return primaryStartAction != nil
    }

    @ViewBuilder
    private var configuredActions: some View {
        if case let .repair(title, detail) = protectionPresentation {
            repairAction(title: title, detail: detail)
        } else if canBeginNow, !canStartWithCurrentMethod {
            Button("Set up Wind Down tag", action: onSetup)
                .buttonStyle(PixelChipButtonStyle(isSelected: false))
                .frame(maxWidth: .infinity, minHeight: 44)
        } else if let primaryStartAction {
            PrimaryGreenCTA(
                eyebrow: primaryEyebrow(for: primaryStartAction),
                title: primaryTitle(for: primaryStartAction),
                subtitle: primarySubtitle(for: primaryStartAction),
                icon: primaryIcon(for: primaryStartAction),
                assetName: primaryAsset(for: primaryStartAction),
                action: { perform(primaryStartAction) }
            )
        }
    }

    private var setupSummary: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("WIND DOWN")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Make a little room for quiet")
                    .font(AppTypography.headline)
                Text("Choose when your phone goes away and wakes up. You can add a few private ideas, too.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Set up Wind Down", action: onSetup)
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var timingCard: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if let plan = primaryWindDownPlan {
                    timingHeader(plan: plan)

                    timingCells(plan: plan)

                    DisclosureGroup(isExpanded: $isExpanded) {
                        expandedDetails(plan: plan)
                    } label: {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("PHONE TIMING & DETAILS")
                                .font(pixelFont(.caption2))
                                .foregroundStyle(AppColors.grass)
                            Text("Away \(OllieFormat.time(plan.phoneAwayTime)) · wakes \(OllieFormat.time(plan.plan.protectedUntil))")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(AppColors.grass)
                } else {
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(timingHeading)
                                .font(pixelFont(.caption))
                                .foregroundStyle(AppColors.grass)
                            Text("Your next plan is being prepared")
                                .font(AppTypography.headline)
                        }
                        Spacer(minLength: AppSpacing.sm)
                        Image(systemName: "moon.stars.fill")
                            .font(.title2.weight(.black))
                            .foregroundStyle(AppColors.lavender)
                            .accessibilityHidden(true)
                    }
                    Button("Edit Wind Down", action: onEdit)
                        .font(AppTypography.caption.weight(.bold))
                        .foregroundStyle(AppColors.grass)
                        .frame(minHeight: 44)
                        .accessibilityHint("Opens your Wind Down plan")
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private func timingCells(plan: (plan: NightWatchPlan, phoneAwayTime: Date)) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                timingCell(icon: "moon.zzz.fill", label: "Before bed", minutes: plan.plan.windDownMinutes)
                timingCell(icon: "sun.max.fill", label: "After waking", minutes: plan.plan.morningQuietMinutes)
            }
        } else {
            HStack(spacing: AppSpacing.sm) {
                timingCell(icon: "moon.zzz.fill", label: "Before bed", minutes: plan.plan.windDownMinutes)
                timingCell(icon: "sun.max.fill", label: "After waking", minutes: plan.plan.morningQuietMinutes)
            }
        }
    }

    @ViewBuilder
    private func timingHeader(plan: (plan: NightWatchPlan, phoneAwayTime: Date)) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(timingHeading)
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                timingHeaderValue(label: "Bed", time: plan.plan.intendedBedtime)
                timingHeaderValue(label: "You wake", time: plan.plan.wakeTime)
            }
        } else {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(timingHeading)
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("\(OllieFormat.time(plan.plan.intendedBedtime)) – \(OllieFormat.time(plan.plan.wakeTime))")
                        .font(pixelFont(.title3))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: AppSpacing.sm)
                Image(systemName: "moon.stars.fill")
                    .font(.title2.weight(.black))
                    .foregroundStyle(AppColors.lavender)
                    .accessibilityHidden(true)
            }
        }
    }

    private func timingHeaderValue(label: String, time: Date) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
            Text(OllieFormat.time(time).replacingOccurrences(of: " ", with: "\u{00A0}"))
                .font(AppTypography.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timingCell(icon: String, label: String, minutes: Int) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.lavender)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                Text("\(minutes) min")
                    .font(AppTypography.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
    }

    @ViewBuilder
    private func expandedDetails(plan: (plan: NightWatchPlan, phoneAwayTime: Date)) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    detailValue(label: "Bed", time: plan.plan.intendedBedtime)
                    detailValue(label: "You wake", time: plan.plan.wakeTime)
                    detailValue(label: "Phone away", time: plan.phoneAwayTime)
                    detailValue(label: "Phone wakes", time: plan.plan.protectedUntil)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        detailValue(label: "Bed", time: plan.plan.intendedBedtime)
                        detailValue(label: "You wake", time: plan.plan.wakeTime)
                        detailValue(label: "Phone away", time: plan.phoneAwayTime)
                        detailValue(label: "Phone wakes", time: plan.plan.protectedUntil)
                    }
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack(spacing: AppSpacing.md) {
                            detailValue(label: "Bed", time: plan.plan.intendedBedtime)
                            detailValue(label: "You wake", time: plan.plan.wakeTime)
                        }
                        HStack(spacing: AppSpacing.md) {
                            detailValue(label: "Phone away", time: plan.phoneAwayTime)
                            detailValue(label: "Phone wakes", time: plan.plan.protectedUntil)
                        }
                    }
                }
            }

            Button("Edit Wind Down", action: onEdit)
                .font(AppTypography.caption.weight(.bold))
                .foregroundStyle(AppColors.grass)
                .frame(minHeight: 44)
                .accessibilityHint("Opens your Wind Down plan")
        }
        .padding(.top, AppSpacing.xs)
    }

    private var primaryStartAction: StartAction? {
        guard protectionIsReady else { return nil }
        if canBeginNow, canStartWithCurrentMethod {
            return .windDown
        }
        if let phoneAwayStartContext, phoneAwayStartContext.sourceID != nil {
            return .scheduledPhoneAway(phoneAwayStartContext)
        }
        if let immediatePhoneAwayMinutes, immediatePhoneAwayMinutes > 0 {
            return .immediatePhoneAway(minutes: immediatePhoneAwayMinutes)
        }
        return nil
    }

    private func primaryEyebrow(for action: StartAction) -> String {
        switch action {
        case .windDown: return timingHeading
        case .scheduledPhoneAway, .immediatePhoneAway: return "PHONE AWAY"
        }
    }

    private func primaryTitle(for action: StartAction) -> String {
        switch action {
        case .windDown: return "Start Wind Down"
        case .scheduledPhoneAway, .immediatePhoneAway: return "Start Phone Away"
        }
    }

    private func primarySubtitle(for action: StartAction) -> String {
        switch action {
        case .windDown:
            if let phoneWake = primaryWindDownPlan?.plan.protectedUntil {
                return "Phone wakes at \(OllieFormat.time(phoneWake))."
            }
            return "Start your Wind Down."
        case let .scheduledPhoneAway(context):
            return "Start \(context.title)."
        case let .immediatePhoneAway(minutes):
            return "\(minutes) min of phone-away time."
        }
    }

    private func primaryIcon(for action: StartAction) -> String {
        switch action {
        case .windDown: return "door.left.hand.open"
        case .scheduledPhoneAway, .immediatePhoneAway: return "timer"
        }
    }

    private func primaryAsset(for action: StartAction) -> String? {
        switch action {
        case .windDown:
            return AssetSlot.Home.door
        case .scheduledPhoneAway, .immediatePhoneAway:
            return nil
        }
    }

    private func perform(_ action: StartAction) {
        switch action {
        case .windDown:
            onPrimaryAction()
        case let .scheduledPhoneAway(context):
            guard let sourceID = context.sourceID else { return }
            onPhoneAwayScheduled(sourceID)
        case .immediatePhoneAway:
            onPhoneAwayStartNow()
        }
    }

    private func repairAction(title: String, detail: String) -> some View {
        Button(action: onRepairProtection) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(AppColors.lavender)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.body.weight(.semibold))
                    Text(detail)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: AppSpacing.xs)
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColors.muted)
                    .accessibilityHidden(true)
            }
            .padding(AppSpacing.sm)
            .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityHint("Opens focused app protection repair. It will not start Wind Down.")
    }

    private var canStartWithCurrentMethod: Bool {
        preferences.guardKind != .nfcTag || isNFCTagReady
    }

    private var protectionIsReady: Bool {
        if case .ready = protectionPresentation { return true }
        return false
    }

    private var primaryWindDownPlan: (plan: NightWatchPlan, phoneAwayTime: Date)? {
        guard let primaryWindDownPeriod else { return nil }
        let phoneAwayTime = primaryWindDownPeriod.occurrence.interval.start
        return (
            WindDownScheduleEngine.plan(
                for: primaryWindDownPeriod,
                preferences: preferences,
                startedAt: phoneAwayTime
            ),
            phoneAwayTime
        )
    }

    private var timingHeading: String {
        HomeStartRoutingPolicy.windDownHeading(
            intendedBedtime: primaryWindDownPlan?.plan.intendedBedtime
        )
    }

    private func detailValue(label: String, time: Date) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
            Text(dynamicTypeSize.isAccessibilitySize
                ? OllieFormat.time(time).replacingOccurrences(of: " ", with: "\u{00A0}")
                : OllieFormat.time(time)
            )
                .font(AppTypography.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func homeWindDownSummaryPreviewPeriod() -> WindDownSchedulePeriod {
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    return WindDownSchedulePeriod(
        occurrence: WindDownOccurrence(
            routineID: UUID(),
            role: .primarySleepBookend,
            interval: DateInterval(start: start, duration: 10_800)
        ),
        title: "Tonight's Wind Down",
        recurring: true
    )
}

private let homeWindDownSummaryPreviewPreferences = NightWatchPreferences(
    bedtimeHour: 23,
    bedtimeMinute: 0,
    wakeHour: 7,
    wakeMinute: 0,
    windDownMinutes: 30,
    morningQuietMinutes: 30,
    eveningActivity: .read,
    morningActivity: .openCurtains,
    guardKind: .honorTimer,
    isConfigured: true
)

private func homeWindDownSummaryPreview(
    configured: Bool = true,
    canBeginNow: Bool = false,
    showsPhoneAway: Bool = false,
    needsRepair: Bool = false
) -> some View {
    HomeWindDownSummary(
        preferences: configured ? homeWindDownSummaryPreviewPreferences : .defaults,
        canBeginNow: canBeginNow,
        isNFCTagReady: configured,
        primaryWindDownPeriod: configured ? homeWindDownSummaryPreviewPeriod() : nil,
        phoneAwayStartContext: showsPhoneAway
            ? WindDownStartContext(
                sourceID: UUID(),
                kind: .oneTimeQuiet,
                title: "Phone Away",
                interval: DateInterval(start: .now, duration: 1_800)
            )
            : nil,
        protectionPresentation: needsRepair
            ? .repair(
                title: "Choose apps to pause",
                detail: ShieldingReadiness.noSelection.detail
            )
            : .ready(selectionSummary: "2 apps"),
        onPrimaryAction: {},
        onRepairProtection: {},
        onSetup: {},
        onEdit: {}
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Home Wind Down · eligible") {
    homeWindDownSummaryPreview(canBeginNow: true)
}

#Preview("Home Wind Down · Phone Away") {
    homeWindDownSummaryPreview(showsPhoneAway: true)
}

#Preview("Home Wind Down · setup") {
    homeWindDownSummaryPreview(configured: false)
}

#Preview("Home Wind Down · repair") {
    homeWindDownSummaryPreview(canBeginNow: true, needsRepair: true)
}
