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
    @State private var showsRoutineReview = false
    @State private var showsPersonalization = false
    @State private var personalizationStep: OnboardingPersonalizationStep = .startingPoint
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
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            dashboard
        }
    }

    private var dashboard: some View {
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
            immediateAdditionalQuietMinutes: viewModel.immediateAdditionalQuietMinutes,
            ollieAccessoryItemID: viewModel.farmState.equipment.ollieAccessoryItemID,
            homeScrollViewportSize: homeScrollViewportSize,
            nightFlockSummary: viewModel.nightFlockViewModel.homeSummary,
            nightFlockViewModel: viewModel.nightFlockViewModel,
            homeGuidanceItem: viewModel.homeGuidanceItem,
            habitPlan: viewModel.windDownHabitPlan,
            useSmallerVersion: $viewModel.useSmallerWindDownNextTime,
            habitSaveMessage: viewModel.habitSaveMessage,
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
            onEditRoutine: { showsRoutineReview = true },
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
            RitualReflectionInvitation()
            personalization
        }
        .navigationDestination(isPresented: $showsRoutineReview) {
            FocusRunSetupView(initialHabitFocus: .activity)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showsPersonalization) {
            OnboardingPersonalizationView(initialStep: personalizationStep)
                .environmentObject(viewModel)
        }
        .onChange(of: viewModel.habitEditingIdentity) { _, _ in
            showsPersonalization = false
            showsRoutineReview = false
        }
    }

    private var personalization: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                NavigationLink("What I’m working toward") { RitualPersonalisationView() }
                .frame(minHeight: 44)
                Text("An optional goal, a small plan, and a chance to reflect on what helped.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                if viewModel.claimedWelcomeGiftItemID == nil {
                    Button("Choose my welcome gift") {
                        personalizationStep = .welcomeGift
                        showsPersonalization = true
                    }
                    .frame(minHeight: 44)
                }
            }
            .font(AppTypography.body)
            .padding(.top, AppSpacing.sm)
        } label: {
            Text("Make it yours")
                .font(AppTypography.caption.weight(.semibold))
                .frame(minHeight: 44, alignment: .leading)
        }
        .tint(AppColors.grass)
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
    var immediateAdditionalQuietMinutes: Int?
    var ollieAccessoryItemID: String? = nil
    var homeScrollViewportSize: CGSize = .zero
    var nightFlockSummary: NightFlockHomeSummary? = nil
    var nightFlockViewModel: NightFlockViewModel? = nil
    var homeGuidanceItem: WindDownGuidanceItem? = nil
    var habitPlan = WindDownHabitPlan()
    var useSmallerVersion: Binding<Bool> = .constant(false)
    var habitSaveMessage: String? = nil
    var protectionPresentation: HomeProtectionStartPresentation
    var onPrimaryAction: () -> Void
    var onRepairProtection: () -> Void = {}
    var onSetup: () -> Void = {}
    var onEditRoutine: () -> Void = {}
    var onEditTiming: () -> Void
    var onQuietTimeSchedule: () -> Void
    var onStartNow: () -> Void
    var onStartScheduled: (UUID) -> Void = { _ in }
    var onGuidanceShown: (WindDownGuidanceItem) -> Void = { _ in }
    var onDismissGuidance: (WindDownGuidanceItem) -> Void = { _ in }
    var onOpenNightFlock: (UUID?) -> Void = { _ in }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            VStack(spacing: AppSpacing.md) {
                HomeWelcomeHero(
                    title: heroPlan.map { "\($0.windDownMinutes) min before bed" } ?? "Welcome home.",
                    subtitle: heroPlan == nil ? "Ollie saved you a quiet spot." : "Your planned Wind Down",
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
                    phoneAwayPurpose: purpose,
                    protectionPresentation: protectionPresentation,
                    onPrimaryAction: onPrimaryAction,
                    onRepairProtection: onRepairProtection,
                    onSetup: onSetup,
                    onEdit: onEditTiming,
                    onPhoneAwayStartNow: onStartNow,
                    onPhoneAwayScheduled: onStartScheduled,
                    content: .actions
                )

            }
            .padding(AppSpacing.md)
            .background(
                LinearGradient(colors: [AppColors.grass.opacity(0.12), AppColors.paper],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: AppRadius.lg)
            )

            sectionHeading("Your evening", icon: "moon.stars")
            HomeWindDownSummary(
                preferences: preferences,
                canBeginNow: canBeginNow,
                isNFCTagReady: isNFCTagReady,
                primaryWindDownPeriod: primaryWindDownPeriod,
                phoneAwayStartContext: phoneAwayStartContext,
                immediatePhoneAwayMinutes: immediateAdditionalQuietMinutes,
                phoneAwayPurpose: purpose,
                protectionPresentation: protectionPresentation,
                onPrimaryAction: onPrimaryAction,
                onRepairProtection: onRepairProtection,
                onSetup: onSetup,
                onEdit: onEditTiming,
                onPhoneAwayStartNow: onStartNow,
                onPhoneAwayScheduled: onStartScheduled,
                content: .timing
            )

            AutomaticWindDownCard()

            WindDownHabitHomeCard(
                routine: preferences.eveningRoutine,
                plan: habitPlan,
                useSmallerVersion: useSmallerVersion,
                saveMessage: habitSaveMessage,
                onEdit: onEditRoutine
            )

            sectionHeading("Your day", icon: "sun.max")
            UpcomingQuietTimesCard(nextPeriod: nextUpcoming, purpose: purpose, action: onQuietTimeSchedule)

            if nightFlockSummary != nil || nightFlockViewModel?.featureEnabled == true {
                sectionHeading("Offline Together", icon: "person.2")
            }
            if shouldLeadWithSlumberParty, let nightFlockViewModel {
                SlumberPartyHomeSection(viewModel: nightFlockViewModel, openParty: onOpenNightFlock)
            } else if let nightFlockSummary {
                NightFlockHomeCard(summary: nightFlockSummary, context: .home,
                                  action: { onOpenNightFlock(nil) })
            }

            if let nightFlockViewModel, nightFlockViewModel.featureEnabled {
                CampfireHomeEntry(social: nightFlockViewModel)
            }


            if preferences.guardKind == .watchPlacement {
                watchStatus
            }

            if let guidance = homeGuidanceItem {
                WindDownGuideCard(item: guidance, compact: true) {
                    onDismissGuidance(guidance)
                }
                .onAppear { onGuidanceShown(guidance) }
            }

        }
    }

    private var heroPlan: NightWatchPlan? {
        guard preferences.isConfigured, let primaryWindDownPeriod else { return nil }
        return WindDownScheduleEngine.plan(
            for: primaryWindDownPeriod,
            preferences: preferences,
            startedAt: primaryWindDownPeriod.occurrence.interval.start
        )
    }

    private func sectionHeading(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(AppTypography.title)
            .foregroundStyle(AppColors.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
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
                immediateAdditionalQuietMinutes: nil,
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
    .environmentObject(FocusRunViewModel(startsExternalServices: false))
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
                immediateAdditionalQuietMinutes: nil,
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
    .environmentObject(FocusRunViewModel(startsExternalServices: false))
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
                immediateAdditionalQuietMinutes: nil,
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
    .environmentObject(FocusRunViewModel(startsExternalServices: false))
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
                immediateAdditionalQuietMinutes: 30,
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
    .environmentObject(FocusRunViewModel(startsExternalServices: false))
}

struct HomeSocialInfoButton: View {
    let title: String
    let message: String
    @State private var showsInfo = false

    static var slumberParty: Self {
        Self(title: "Slumber Party", message: "Your private, invite-only friend group. Share quiet nights with friends, a partner, or family. Members see only the updates covered by your sharing agreement.")
    }

    static var campfire: Self {
        Self(title: "Campfire", message: "A shared place to go offline with the wider Counting Sheep community. Choose Global to see the global campfire, or view your Slumber Party. Browsing does not share your session; you choose your own visibility separately.")
    }

    var body: some View {
        Button { showsInfo = true } label: {
            Image(systemName: "info.circle")
                .font(AppTypography.headline)
                .foregroundStyle(AppColors.muted)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About \(title)")
        .sheet(isPresented: $showsInfo) {
            ContentFittingGuideSheet {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack {
                        Text(title).font(AppTypography.title)
                        Spacer()
                        Button("Done") { showsInfo = false }
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    Text(message).font(AppTypography.body)
                }
            }
        }
    }
}
