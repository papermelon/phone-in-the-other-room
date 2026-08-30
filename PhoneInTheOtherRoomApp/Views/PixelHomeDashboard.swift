import SwiftUI

enum PixelHomeDashboardDestination: Equatable {
    case setup
    case timing
    case quietTimeSchedule
    case protectionRepair
    case quickStartError
}

enum HomeScrollViewportCoordinateSpace {
    static let name = "CountingSheepHomeScrollViewport"
}

struct PixelHomeDashboard: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @ObservedObject private var watch: WatchConnectivityManager
    @Binding private var destination: PixelHomeDashboardDestination?
    private let homeScrollViewportSize: CGSize

    init(
        watch: WatchConnectivityManager = .shared,
        destination: Binding<PixelHomeDashboardDestination?>,
        homeScrollViewportSize: CGSize = .zero
    ) {
        self._watch = ObservedObject(initialValue: watch)
        self._destination = destination
        self.homeScrollViewportSize = homeScrollViewportSize
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            firstRunCards
            PixelHomeDashboardContent(
            progress: viewModel.coordinator.progress,
            preferences: viewModel.nightWatchPreferences,
            purpose: viewModel.offlinePurpose,
            watchReachable: watch.isReachable,
            canBeginNow: viewModel.currentPrimaryWindDownStartContext != nil,
            isNFCTagReady: viewModel.hasRegisteredNFCTag,
            windDownStartContext: viewModel.currentPrimaryWindDownStartContext,
            primaryWindDownPeriod: viewModel.homePrimaryWindDownPeriod,
            phoneAwayStartContext: viewModel.currentPhoneAwayStartContext,
            nextUpcoming: viewModel.nextUpcomingAdditionalQuietPeriod,
            upcomingAdditionalCount: viewModel.upcomingAdditionalQuietPeriods.count,
            immediateAdditionalQuietMinutes: viewModel.immediateAdditionalQuietMinutes,
            phoneBreakMeterMinutes: viewModel.sheepSearchState.trailMap.pendingMappedMinutes,
            ollieAccessoryItemID: viewModel.farmState.equipment.ollieAccessoryItemID,
            homeScrollViewportSize: homeScrollViewportSize,
            nightFlockSummary: viewModel.nightFlockViewModel.homeSummary,
            nightFlockViewModel: viewModel.nightFlockViewModel,
            homeGuidanceItem: viewModel.homeGuidanceItem,
            protectionPresentation: HomeProtectionStartPresentation.resolve(
                readiness: viewModel.shieldingReadiness,
                selectionSummary: viewModel.shieldingSelectionSummary
            ),
            onPrimaryAction: {
                let methodIsReady = viewModel.selectedGuardKind != .nfcTag
                    || viewModel.hasRegisteredNFCTag
                if viewModel.hasConfiguredNightWatch
                    && viewModel.currentPrimaryWindDownStartContext != nil
                    && methodIsReady {
                    let presented = viewModel.requestStartNightWatch(
                        sourceID: viewModel.currentPrimaryWindDownStartContext?.sourceID
                    )
                    if !presented { destination = .quickStartError }
                } else {
                    destination = .setup
                }
            },
            onRepairProtection: { destination = .protectionRepair },
            onSetup: { destination = .setup },
            onEditTiming: { destination = .timing },
            onQuietTimeSchedule: { destination = .quietTimeSchedule },
            onStartNow: {
                let started = viewModel.startNewOneTimeAdditionalQuietNow()
                if !started {
                    destination = .quickStartError
                }
            },
            onStartScheduled: { sourceID in
                let presented = viewModel.requestStartNightWatch(sourceID: sourceID)
                if !presented { destination = .quickStartError }
            },
            onGuidanceShown: { item in viewModel.markHomeGuidanceShown(item) },
            onDismissGuidance: { item in viewModel.dismissHomeGuidance(item) },
            onOpenNightFlock: { partyID in
                NotificationCenter.default.post(
                    name: .countingSheepShowNightFlock,
                    object: partyID ?? viewModel.nightFlockViewModel.homeSummary?.destinationPartyID
                )
            }
        )
        }
    }

    @ViewBuilder
    private var firstRunCards: some View {
        let step = viewModel.orientationState.currentStep.normalized
        if viewModel.orientationState.isGuideActive, step == .practiceReward {
            FirstRunPracticeRewardCard(
                grantedNewSheep: viewModel.lastPracticeGrantBroughtSheep,
                onSeeFarm: {
                    viewModel.markPracticeRewardRoutedToFarm()
                    viewModel.advanceOrientationTour()
                    NotificationCenter.default.post(name: .countingSheepShowFarm, object: nil)
                },
                onSkip: viewModel.skipOrientationLesson
            )
        }
        if viewModel.orientationState.isGuideActive, step == .slumberParty {
            FirstRunSlumberPartyIntroCard(
                isAvailable: viewModel.nightFlockViewModel.featureEnabled,
                onCreate: {
                    viewModel.advanceOrientationTour()
                    NotificationCenter.default.post(name: .countingSheepShowNightFlock, object: nil)
                },
                onJoin: {
                    viewModel.advanceOrientationTour()
                    NotificationCenter.default.post(name: .countingSheepShowNightFlock, object: "join")
                },
                onLater: {
                    if !viewModel.nightFlockViewModel.featureEnabled {
                        viewModel.acknowledgeSlumberPartyUnavailable()
                    }
                    viewModel.skipOrientationLesson()
                }
            )
        }
        if viewModel.orientationState.isGuideActive, step == .completion {
            PixelCard {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(FirstRunGuideCopy.title(for: .completion))
                        .font(AppTypography.headline)
                    Text(FirstRunGuideCopy.message(for: .completion))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Done") {
                        viewModel.completeOrientationTour()
                    }
                    .buttonStyle(PixelChipButtonStyle(isSelected: true))
                    .frame(minHeight: 44)
                }
            }
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
    var primaryWindDownPeriod: WindDownSchedulePeriod? = nil
    var phoneAwayStartContext: WindDownStartContext?
    var nextUpcoming: WindDownSchedulePeriod?
    var upcomingAdditionalCount: Int
    var immediateAdditionalQuietMinutes: Int?
    var phoneBreakMeterMinutes: Int
    var ollieAccessoryItemID: String? = nil
    var homeScrollViewportSize: CGSize = .zero
    var nightFlockSummary: NightFlockHomeSummary? = nil
    var nightFlockViewModel: NightFlockViewModel? = nil
    var homeGuidanceItem: WindDownGuidanceItem? = nil
    var protectionPresentation: HomeProtectionStartPresentation
    var onPrimaryAction: () -> Void
    var onRepairProtection: () -> Void = {}
    var onSetup: () -> Void = {}
    var onEditTiming: () -> Void
    var onQuietTimeSchedule: () -> Void
    var onStartNow: () -> Void
    var onStartScheduled: (UUID) -> Void = { _ in }
    var onGuidanceShown: (WindDownGuidanceItem) -> Void = { _ in }
    var onDismissGuidance: (WindDownGuidanceItem) -> Void = { _ in }
    var onOpenNightFlock: (UUID?) -> Void = { _ in }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            HomeWindDownSummary(
                preferences: preferences,
                canBeginNow: canBeginNow,
                isNFCTagReady: isNFCTagReady,
                primaryWindDownPeriod: primaryWindDownPeriod,
                phoneAwayStartContext: phoneAwayStartContext,
                immediatePhoneAwayMinutes: immediateAdditionalQuietMinutes,
                protectionPresentation: protectionPresentation,
                onPrimaryAction: onPrimaryAction,
                onRepairProtection: onRepairProtection,
                onSetup: onSetup,
                onEdit: onEditTiming,
                onPhoneAwayStartNow: onStartNow,
                onPhoneAwayScheduled: onStartScheduled,
                content: .timing
            )

            HomeWelcomeHero(
                accessoryItemID: ollieAccessoryItemID,
                scrollViewportSize: homeScrollViewportSize
            )

            HomeWindDownSummary(
                preferences: preferences,
                canBeginNow: canBeginNow,
                isNFCTagReady: isNFCTagReady,
                primaryWindDownPeriod: primaryWindDownPeriod,
                phoneAwayStartContext: phoneAwayStartContext,
                immediatePhoneAwayMinutes: immediateAdditionalQuietMinutes,
                protectionPresentation: protectionPresentation,
                onPrimaryAction: onPrimaryAction,
                onRepairProtection: onRepairProtection,
                onSetup: onSetup,
                onEdit: onEditTiming,
                onPhoneAwayStartNow: onStartNow,
                onPhoneAwayScheduled: onStartScheduled,
                content: .actions
            )

            if shouldLeadWithSlumberParty, let nightFlockViewModel {
                SlumberPartyHomeSection(viewModel: nightFlockViewModel, openParty: onOpenNightFlock)
            } else if let nightFlockSummary {
                NightFlockHomeCard(
                    summary: nightFlockSummary,
                    context: .home,
                    action: { onOpenNightFlock(nil) }
                )
            }

            UpcomingQuietTimesCard(
                nextPeriod: nextUpcoming,
                additionalCount: upcomingAdditionalCount,
                immediateStartMinutes: immediateAdditionalQuietMinutes,
                scheduledStart: phoneAwayStartContext,
                windDownIsReady: canBeginNow,
                trailMapPresentation: SheepTrailMapPresentation.home(
                    pendingMappedMinutes: phoneBreakMeterMinutes,
                    protectedWindDownCount: progress.totalCompletedRuns
                ),
                protectionPresentation: protectionPresentation,
                action: onQuietTimeSchedule,
                startNow: onStartNow,
                startScheduled: onStartScheduled,
                showsQuickStartActions: false
            )

            if preferences.guardKind == .watchPlacement {
                watchStatus
            }

            if let guidance = homeGuidanceItem {
                WindDownGuideCard(item: guidance, compact: true) {
                    onDismissGuidance(guidance)
                }
                .onAppear { onGuidanceShown(guidance) }
            }

            NavigationLink("About these ideas and sources") {
                WindDownGuideView()
            }
            .font(AppTypography.caption.weight(.semibold))
            .foregroundStyle(AppColors.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var shouldLeadWithSlumberParty: Bool {
        guard let nightFlockViewModel else { return false }
        return nightFlockViewModel.featureEnabled && nightFlockViewModel.usesSlumberPartyV4
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
                protectionPresentation: .repair(title: "Choose apps to pause", detail: ShieldingReadiness.noSelection.detail),
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
                protectionPresentation: .ready(selectionSummary: "2 apps, 1 category"),
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
                protectionPresentation: .ready(selectionSummary: "2 apps"),
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
                protectionPresentation: .repair(title: "Set up app protection", detail: ShieldingReadiness.authorizationRequired.detail),
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
