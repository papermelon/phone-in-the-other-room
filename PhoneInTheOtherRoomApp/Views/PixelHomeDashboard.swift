import SwiftUI

struct PixelHomeDashboard: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @ObservedObject private var watch: WatchConnectivityManager
    @State private var showRunSetup = false
    @State private var showTimingEditor = false
    @State private var showQuietTimeSchedule = false
    @State private var showQuickStartError = false

    init(watch: WatchConnectivityManager = .shared) {
        self._watch = ObservedObject(initialValue: watch)
    }

    var body: some View {
        PixelHomeDashboardContent(
            progress: viewModel.coordinator.progress,
            preferences: viewModel.nightWatchPreferences,
            purpose: viewModel.offlinePurpose,
            watchReachable: watch.isReachable,
            canBeginNow: viewModel.currentPrimaryWindDownStartContext != nil,
            isNFCTagReady: viewModel.hasRegisteredNFCTag,
            windDownStartContext: viewModel.currentPrimaryWindDownStartContext,
            phoneAwayStartContext: viewModel.currentPhoneAwayStartContext,
            nextUpcoming: viewModel.nextUpcomingAdditionalQuietPeriod,
            upcomingAdditionalCount: viewModel.upcomingAdditionalQuietPeriods.count,
            immediateAdditionalQuietMinutes: viewModel.immediateAdditionalQuietMinutes,
            phoneBreakMeterMinutes: viewModel.sheepSearchState.trailMap.pendingMappedMinutes,
            nightFlockSummary: viewModel.nightFlockViewModel.homeSummary,
            onPrimaryAction: {
                let methodIsReady = viewModel.selectedGuardKind != .nfcTag
                    || viewModel.hasRegisteredNFCTag
                if viewModel.hasConfiguredNightWatch
                    && viewModel.currentPrimaryWindDownStartContext != nil
                    && methodIsReady {
                    viewModel.requestStartNightWatch(
                        sourceID: viewModel.currentPrimaryWindDownStartContext?.sourceID
                    )
                } else {
                    showRunSetup = true
                }
            },
            onEditTiming: { showTimingEditor = true },
            onQuietTimeSchedule: { showQuietTimeSchedule = true },
            onStartNow: {
                let started: Bool
                if let context = viewModel.currentPhoneAwayStartContext {
                    viewModel.requestStartNightWatch(sourceID: context.sourceID)
                    started = viewModel.showNightWatchStartPrompt
                } else {
                    started = viewModel.startNewOneTimeAdditionalQuietNow()
                }
                if !started {
                    showQuickStartError = true
                }
            },
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
        .alert("Phone Away could not start", isPresented: $showQuickStartError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.windDownScheduleError ?? "Try again after the current phone-away time ends.")
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
    var windDownStartContext: WindDownStartContext?
    var phoneAwayStartContext: WindDownStartContext?
    var nextUpcoming: WindDownSchedulePeriod?
    var upcomingAdditionalCount: Int
    var immediateAdditionalQuietMinutes: Int?
    var phoneBreakMeterMinutes: Int
    var nightFlockSummary: NightFlockHomeSummary? = nil
    var onPrimaryAction: () -> Void
    var onEditTiming: () -> Void
    var onQuietTimeSchedule: () -> Void
    var onStartNow: () -> Void
    var onOpenNightFlock: () -> Void = {}

    private var latestNight: DailyFocusRecord? { progress.recentFocusRecords.first }
    private var homeGuidance: WindDownGuidanceItem? {
        guard preferences.isConfigured else { return nil }
        return WindDownGuidanceLibrary.homeGuidance(
            eveningRoutine: preferences.eveningRoutine,
            morningRoutine: preferences.morningRoutine
        )
    }

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
                icon: "door.left.hand.open",
                assetName: AssetSlot.Home.door,
                action: onPrimaryAction
            )

            if let guidance = homeGuidance {
                WindDownGuideCard(item: guidance, compact: true)
            }

            if let nightFlockSummary {
                NightFlockHomeCard(summary: nightFlockSummary, action: onOpenNightFlock)
            }

            UpcomingQuietTimesCard(
                nextPeriod: nextUpcoming,
                additionalCount: upcomingAdditionalCount,
                immediateStartMinutes: preferences.isConfigured && !canBeginNow && phoneAwayStartContext == nil
                    ? immediateAdditionalQuietMinutes
                    : nil,
                scheduledStart: phoneAwayStartContext,
                windDownIsReady: canBeginNow,
                trailMapPresentation: SheepTrailMapPresentation.home(
                    pendingMappedMinutes: phoneBreakMeterMinutes,
                    protectedWindDownCount: progress.totalCompletedRuns
                ),
                action: onQuietTimeSchedule,
                startNow: onStartNow
            )

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
        return canBeginNow ? AppCopy.ConfiguredHome.startButton.value : "Plan Wind Down"
    }

    private var primaryEyebrow: String? {
        guard canBeginNow, windDownStartContext != nil else { return nil }
        return nil
    }

    private var primarySubtitle: String {
        guard preferences.isConfigured else { return "Choose when Wind Down runs" }
        return scheduleLabel
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
                    Text("Latest Wind Down · \(latestNight.completedFocusMinutes) quiet minutes")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                } else {
                    Text("Your first completed Wind Down will appear in Nights.")
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
                windDownStartContext: nil,
                phoneAwayStartContext: nil,
                nextUpcoming: nil,
                upcomingAdditionalCount: 0,
                immediateAdditionalQuietMinutes: nil,
                phoneBreakMeterMinutes: 0,
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

#Preview("Configured home · Wind Down soon") {
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
                windDownStartContext: nil,
                phoneAwayStartContext: nil,
                nextUpcoming: nil,
                upcomingAdditionalCount: 0,
                immediateAdditionalQuietMinutes: nil,
                phoneBreakMeterMinutes: PhoneAwaySearchMeter.maximumMinutes,
                nightFlockSummary: .invitation,
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

#Preview("Phone Away scheduled and secondary") {
    let now = Date()
    NavigationStack {
        ScrollView {
            PixelHomeDashboardContent(
                progress: .empty,
                preferences: .defaults,
                purpose: OfflinePurposeProfile(category: .read),
                watchReachable: false,
                canBeginNow: false,
                isNFCTagReady: true,
                windDownStartContext: nil,
                phoneAwayStartContext: WindDownStartContext(
                    sourceID: UUID(),
                    kind: .oneTimeQuiet,
                    title: "A little room",
                    interval: DateInterval(start: now.addingTimeInterval(-60), end: now.addingTimeInterval(20 * 60))
                ),
                nextUpcoming: nil,
                upcomingAdditionalCount: 1,
                immediateAdditionalQuietMinutes: nil,
                phoneBreakMeterMinutes: PhoneAwaySearchMeter.maximumMinutes,
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

#Preview("Phone Away start now · secondary") {
    NavigationStack {
        ScrollView {
            PixelHomeDashboardContent(
                progress: .empty,
                preferences: NightWatchPreferences.defaults,
                purpose: OfflinePurposeProfile(category: .read),
                watchReachable: false,
                canBeginNow: false,
                isNFCTagReady: true,
                windDownStartContext: nil,
                phoneAwayStartContext: nil,
                nextUpcoming: nil,
                upcomingAdditionalCount: 0,
                immediateAdditionalQuietMinutes: 30,
                phoneBreakMeterMinutes: 0,
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
