import SwiftUI

struct PixelHomeDashboard: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @ObservedObject private var watch: WatchConnectivityManager
    @State private var showRunSetup = false
    @State private var showTimingEditor = false
    @State private var showQuietTimeSchedule = false

    init(watch: WatchConnectivityManager = .shared) {
        self._watch = ObservedObject(initialValue: watch)
    }

    var body: some View {
        PixelHomeDashboardContent(
            progress: viewModel.coordinator.progress,
            preferences: viewModel.nightWatchPreferences,
            purpose: viewModel.offlinePurpose,
            watchReachable: watch.isReachable,
            canBeginNow: viewModel.canBeginNightWatchNow,
            isNFCTagReady: viewModel.hasRegisteredNFCTag,
            startContext: viewModel.currentWindDownStartContext,
            nextUpcoming: viewModel.nextUpcomingQuietPeriod,
            upcomingAdditionalCount: viewModel.upcomingAdditionalQuietPeriods.count,
            mappedBonusPercentagePoints: viewModel.sheepSearchState.trailMap.availableBonusPercentagePoints,
            nightFlockSummary: viewModel.nightFlockViewModel.homeSummary,
            onPrimaryAction: {
                let methodIsReady = viewModel.selectedGuardKind != .nfcTag
                    || viewModel.hasRegisteredNFCTag
                if viewModel.hasConfiguredNightWatch
                    && viewModel.canBeginNightWatchNow
                    && methodIsReady {
                    viewModel.requestStartNightWatch(
                        sourceID: viewModel.currentWindDownStartContext?.sourceID
                    )
                } else {
                    showRunSetup = true
                }
            },
            onEditTiming: { showTimingEditor = true },
            onQuietTimeSchedule: { showQuietTimeSchedule = true },
            onStartNow: { _ = viewModel.startNewOneTimeAdditionalQuietNow() },
            onOpenNightFlock: {
                NotificationCenter.default.post(name: .countingSheepShowNightFlock, object: nil)
            }
        )
        .navigationDestination(isPresented: $showRunSetup) {
            FocusRunSetupView()
                .environmentObject(viewModel)
        }
        .navigationDestination(isPresented: $showTimingEditor) {
            WindDownTimingView()
                .environmentObject(viewModel)
        }
        .navigationDestination(isPresented: $showQuietTimeSchedule) {
            WindDownScheduleView()
                .environmentObject(viewModel)
        }
    }
}

private struct PixelHomeDashboardContent: View {
    var progress: UserProgress
    var preferences: NightWatchPreferences
    var purpose: OfflinePurposeProfile
    var watchReachable: Bool
    var canBeginNow: Bool
    var isNFCTagReady: Bool
    var startContext: WindDownStartContext?
    var nextUpcoming: WindDownSchedulePeriod?
    var upcomingAdditionalCount: Int
    var mappedBonusPercentagePoints: Int
    var nightFlockSummary: NightFlockHomeSummary? = nil
    var onPrimaryAction: () -> Void
    var onEditTiming: () -> Void
    var onQuietTimeSchedule: () -> Void
    var onStartNow: () -> Void
    var onOpenNightFlock: () -> Void = {}

    private var latestNight: DailyFocusRecord? { progress.recentFocusRecords.first }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            NightWatchOverviewBlock(
                preferences: preferences,
                latestNight: latestNight,
                onEdit: onEditTiming
            )

            HomeOllieIdleView()
                .accessibilityLabel("Ollie is ready for tonight's Wind Down")

            VStack(spacing: AppSpacing.sm) {
                Text(purpose.inAppDisplayPhrase)
                    .font(AppTypography.headline)
                    .multilineTextAlignment(.center)
                Text(AppCopy.ConfiguredHome.quietStatement.value)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .multilineTextAlignment(.center)
            }

            PrimaryGreenCTA(
                eyebrow: primaryEyebrow,
                title: primaryTitle,
                subtitle: primarySubtitle,
                icon: startContext?.isAdditionalQuiet == true ? "timer" : "door.left.hand.open",
                assetName: startContext?.isAdditionalQuiet == true ? nil : AssetSlot.Home.door,
                action: onPrimaryAction
            )

            if mappedBonusPercentagePoints > 0 {
                Label(
                    "Ollie has \(mappedBonusPercentagePoints) mapped clue\(mappedBonusPercentagePoints == 1 ? "" : "s") ready for tonight.",
                    systemImage: "map.fill"
                )
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.grass)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Up to plus \(mappedBonusPercentagePoints) percentage points mapped for the next search")
            }

            UpcomingQuietTimesCard(
                nextPeriod: nextUpcoming,
                additionalCount: upcomingAdditionalCount,
                showStartNow: preferences.isConfigured && !canBeginNow,
                action: onQuietTimeSchedule,
                startNow: onStartNow
            )

            if let nightFlockSummary {
                NightFlockHomeCard(summary: nightFlockSummary, action: onOpenNightFlock)
            }

            if preferences.guardKind == .watchPlacement {
                watchStatus
            }
        }
    }

    private var primaryTitle: String {
        if !preferences.isConfigured { return "Set up Wind Down" }
        if preferences.guardKind == .nfcTag, !isNFCTagReady {
            return "Set up Wind Down tag"
        }
        if let startContext, canBeginNow {
            switch startContext.kind {
            case .practice:
                return "Start \(startContext.durationMinutes)-minute practice"
            case .oneTimeQuiet:
                return "Start one-time quiet"
            case .repeatingQuiet:
                return "Start extra quiet"
            case .primary:
                break
            }
        }
        return canBeginNow ? AppCopy.ConfiguredHome.startButton.value : "Review Wind Down"
    }

    private var primaryEyebrow: String? {
        guard canBeginNow, let startContext else { return nil }
        switch startContext.kind {
        case .practice: return "PRACTICE QUIET · \(startContext.durationMinutes) MIN"
        case .oneTimeQuiet: return "ONE-TIME QUIET"
        case .repeatingQuiet: return "EXTRA QUIET"
        case .primary: return nil
        }
    }

    private var primarySubtitle: String {
        guard preferences.isConfigured else { return "Choose when Wind Down runs" }
        guard canBeginNow, let startContext, startContext.isAdditionalQuiet else {
            return scheduleLabel
        }
        let end = OllieFormat.time(startContext.interval.end)
        if startContext.isPractice {
            return "Ends at \(end) · separate from protected nights"
        }
        return "\(startContext.title) · ends at \(end)"
    }

    private var scheduleLabel: String {
        let bedtime = preferences.bedtimeDate().formatted(date: .omitted, time: .shortened)
        let phoneWakeDate = Calendar.current.date(
            byAdding: .minute,
            value: preferences.morningQuietMinutes,
            to: preferences.wakeDate()
        ) ?? preferences.wakeDate()
        let phoneWake = phoneWakeDate.formatted(date: .omitted, time: .shortened)
        return "Bed \(bedtime) · phone wakes \(phoneWake)"
    }

    private var watchStatus: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "applewatch")
                .foregroundStyle(AppColors.grass)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(watchReachable ? "Watch check is ready" : "Open the Watch app for placement")
                    .font(AppTypography.body)
                Text("The Watch is only used for one brief Wind Down check.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

private struct NightWatchOverviewBlock: View {
    var preferences: NightWatchPreferences
    var latestNight: DailyFocusRecord?
    var onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("TONIGHT")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text(preferences.isConfigured ? scheduleLabel : "Make a little room for quiet")
                            .font(pixelFont(.title3))
                    }
                    Spacer()
                    Image(systemName: "moon.stars.fill")
                        .font(.title2.weight(.black))
                        .foregroundStyle(AppColors.lavender)
                }

                HStack(spacing: AppSpacing.sm) {
                    quietPeriod(
                        icon: "moon.zzz.fill",
                        label: "Before bed",
                        minutes: preferences.windDownMinutes
                    )
                    quietPeriod(
                        icon: "sun.max.fill",
                        label: "After waking",
                        minutes: preferences.morningQuietMinutes
                    )
                }

                if let latestNight {
                    Text("Latest protected night · \(latestNight.completedFocusMinutes) quiet minutes")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else {
                    Text("Your first protected night will appear in Nights after you complete Wind Down.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens your Wind Down and sleep window")
        .orientationTourTarget(.homePlan)
    }

    private var scheduleLabel: String {
        let bedtime = preferences.bedtimeDate().formatted(date: .omitted, time: .shortened)
        let wake = preferences.wakeDate().formatted(date: .omitted, time: .shortened)
        return "\(bedtime) – \(wake)"
    }

    private func quietPeriod(icon: String, label: String, minutes: Int) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.grass)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(label)
                    .font(AppTypography.caption)
                Text("\(minutes) min")
                    .font(AppTypography.headline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
    }
}

private struct UpcomingQuietTimesCard: View {
    var nextPeriod: WindDownSchedulePeriod?
    var additionalCount: Int
    var showStartNow: Bool
    var action: () -> Void
    var startNow: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Button(action: action) {
                PixelCard {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.title2.weight(.black))
                            .foregroundStyle(AppColors.grass)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text("Upcoming quiet times")
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
            }
            .buttonStyle(.plain)

            if showStartNow {
                Button("Start now", action: startNow)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .accessibilityHint("Starts a one-time quiet period without changing your schedule")
            }
        }
        .accessibilityHint("Opens your finite list of once and repeating quiet times")
    }

    private var summary: String {
        guard let nextPeriod else {
            return additionalCount == 0
                ? "Add a one-time quiet period outside your usual Wind Down."
                : "Your next quiet time is being tended by Ollie."
        }
        let start = nextPeriod.occurrence.interval.start.formatted(date: .abbreviated, time: .shortened)
        let count = additionalCount == 1 ? "1 one-time quiet period" : "\(additionalCount) one-time quiet periods"
        return "Next: \(start) · \(count)"
    }
}

#Preview("Quiet home") {
    NavigationStack {
        ScrollView {
            PixelHomeDashboardContent(
                progress: .empty,
                preferences: .defaults,
                purpose: OfflinePurposeProfile(category: .read),
                watchReachable: false,
                canBeginNow: false,
                isNFCTagReady: false,
                startContext: nil,
                nextUpcoming: nil,
                upcomingAdditionalCount: 0,
                mappedBonusPercentagePoints: 0,
                onPrimaryAction: {},
                onEditTiming: {},
                onQuietTimeSchedule: {},
                onStartNow: {}
            )
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper)
    }
}

#Preview("Configured quiet home") {
    let preferences = NightWatchPreferences(
        bedtimeHour: 23,
        bedtimeMinute: 0,
        wakeHour: 7,
        wakeMinute: 0,
        windDownMinutes: 180,
        morningQuietMinutes: 180,
        eveningActivity: .read,
        morningActivity: .openCurtains,
        guardKind: .honorTimer,
        isConfigured: true
    )
    NavigationStack {
        ScrollView {
            PixelHomeDashboardContent(
                progress: .empty,
                preferences: preferences,
                purpose: OfflinePurposeProfile(category: .read),
                watchReachable: false,
                canBeginNow: false,
                isNFCTagReady: false,
                startContext: nil,
                nextUpcoming: nil,
                upcomingAdditionalCount: 0,
                mappedBonusPercentagePoints: 3,
                onPrimaryAction: {},
                onEditTiming: {},
                onQuietTimeSchedule: {},
                onStartNow: {}
            )
            .padding(AppSpacing.md)
        }
        .background(AppColors.paper)
    }
}
