import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var pingBannerVisible = false
    @State private var showOrientationPracticeOffer = false
    @State private var selectedTab: MainAppTab
    @State private var farmVisitSeed: UInt64
    @State private var opensNightFlock = false
    @State private var nightFlockPartyID: UUID?
    @State private var homeScrollViewportSize = CGSize.zero
    @State private var homeNavigationPath = NavigationPath()
    /// Dashboard destinations belong to the persistent Home shell, so a
    /// successful admission can dismiss the exact pushed route before the
    /// dashboard is replaced by the active session surface.
    @State private var homeDashboardDestination: PixelHomeDashboardDestination?
    @State private var nightsNavigationPath = NavigationPath()
    @State private var farmNavigationPath = NavigationPath()
    @State private var settingsNavigationPath = NavigationPath()
    private let activeRunNow: Date?
    private let dashboardWatch: WatchConnectivityManager
    private let allowsLaunchRouting: Bool

    init(
        initialTab: MainAppTab = .home,
        farmVisitSeed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max),
        activeRunNow: Date? = nil,
        dashboardWatch: WatchConnectivityManager = .shared,
        allowsLaunchRouting: Bool = true
    ) {
        _selectedTab = State(initialValue: initialTab)
        _farmVisitSeed = State(initialValue: farmVisitSeed)
        self.activeRunNow = activeRunNow
        self.dashboardWatch = dashboardWatch
        self.allowsLaunchRouting = allowsLaunchRouting
    }

    var body: some View {
        ZStack {
            shellBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                selectedTabNavigationStack
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showChrome {
                    shellFooter
                }
            }
            .accessibilityHidden(isOrientationCoachPresented)
        }
        .alert("Turn on Sleep Focus?", isPresented: $viewModel.showFocusModePrompt) {
            Button("Skip", role: .cancel) {
                viewModel.startRun(focusAccepted: false)
            }
            Button("I've Turned It On") {
                viewModel.startRun(focusAccepted: true)
            }
        } message: {
            Text("Counting Sheep can't turn on Sleep Focus for you. You can switch it on in Control Center, then continue.")
        }
                    .onAppear {
                        guard allowsLaunchRouting else { return }
                        viewModel.applyShortcutPreparationIfNeeded()
                        routePendingNotificationIfNeeded()
                        restoreFirstRunSurface()
        }
        .onReceive(NotificationCenter.default.publisher(for: .countingSheepNotificationDestination)) { notification in
            guard let destination = notification.object as? NotificationDestination else { return }
            switch destination {
            case .home, .activeRun:
                select(.home)
            case .nights, .morningReflection:
                if viewModel.isRunning { select(.home) } else { select(.nights) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .countingSheepShowFarm)) { _ in
            select(.farm)
        }
        .onReceive(NotificationCenter.default.publisher(for: .countingSheepShowNightFlock)) { notification in
            guard !viewModel.isRunning else { return }
            viewModel.nightFlockViewModel.prefersJoinEntry = (notification.object as? String) == "join"
            nightFlockPartyID = notification.object as? UUID
            select(.farm)
            opensNightFlock = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .countingSheepShowNights)) { _ in
            if viewModel.activeRun?.state == .completed || viewModel.activeRun?.state == .endedEarly {
                viewModel.resetSetup()
            }
            select(.nights)
        }
        .onReceive(NotificationCenter.default.publisher(for: .countingSheepShowHome)) { _ in
            select(.home)
        }
        .onChange(of: viewModel.isRunning) { _, isRunning in
            if isRunning {
                opensNightFlock = false
                nightFlockPartyID = nil
                resetNavigation(for: .farm)
                routeToHome()
            }
        }
        .onChange(of: viewModel.homeStartAdmission) { _, admission in
            guard let admission,
                  HomeStartRoutingPolicy.shouldRoute(
                    admission: admission,
                    activeRunID: viewModel.activeRun?.id
                  ) else { return }
            routeToHome()
            viewModel.consumeHomeStartAdmission(admission)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            viewModel.refreshConnectionsAfterForeground()
            viewModel.reloadCurrentPurposeCue()
            if viewModel.isRunning { routeToHome() }
        }
        .onChange(of: viewModel.coordinator.pingPulseCount) { _, count in
            guard count > 0 else { return }
            showPingBanner()
        }
        .sheet(isPresented: $viewModel.showQRCodeScanner) {
            PhoneBedScannerSheet(
                isPresented: $viewModel.showQRCodeScanner,
                status: viewModel.qrCodeStatus,
                onCode: viewModel.acceptQRCode
            )
        }
        .sheet(isPresented: $viewModel.showNightWatchStartPrompt) {
            WindDownStartSheet()
                .environmentObject(viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .overlayPreferenceValue(OrientationTourTargetPreferenceKey.self) { targets in
            GeometryReader { proxy in
                if shouldPresentOrientationCoach {
                    let frame = targets[activeOrientationTarget].map { proxy[$0] }
                    CountingSheepOrientationTourOverlay(
                        step: viewModel.orientationState.currentStep,
                        targetFrame: frame,
                        context: viewModel.firstRunAdvanceContext,
                        onBack: viewModel.moveBackInOrientationTour,
                        onNext: advanceOrientationTour,
                        onSkip: viewModel.skipOrientationLesson
                    )
                    .zIndex(50)
                }
            }
        }
        .sheet(isPresented: $showOrientationPracticeOffer) {
            CountingSheepPracticeOfferSheet(
                onStartPractice: startOrientationPractice,
                onSkip: {
                    showOrientationPracticeOffer = false
                    viewModel.dismissPracticeOffer()
                },
                onMaybeLater: {
                    showOrientationPracticeOffer = false
                    viewModel.dismissOrientation()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: viewModel.orientationState.currentStep) { _, step in
            guard viewModel.orientationState.isGuideActive else { return }
            recordVisibleFarmLesson(step.normalized)
            restoreFirstRunSurface()
        }
        .onChange(of: viewModel.orientationState.status) { _, _ in
            restoreFirstRunSurface()
        }
    }

    @ViewBuilder
    private var selectedTabNavigationStack: some View {
        switch selectedTab {
        case .home:
            tabNavigationStack(path: $homeNavigationPath)
        case .nights:
            tabNavigationStack(path: $nightsNavigationPath)
        case .farm:
            tabNavigationStack(path: $farmNavigationPath)
        case .settings:
            tabNavigationStack(path: $settingsNavigationPath)
        }
    }

    private func tabNavigationStack(path: Binding<NavigationPath>) -> some View {
        NavigationStack(path: path) {
            tabContent
                .navigationDestination(isPresented: dashboardDestinationBinding(for: .setup)) {
                    FocusRunSetupView()
                        .environmentObject(viewModel)
                }
                .navigationDestination(isPresented: dashboardDestinationBinding(for: .timing)) {
                    WindDownTimingView()
                        .environmentObject(viewModel)
                }
                .navigationDestination(isPresented: dashboardDestinationBinding(for: .quietTimeSchedule)) {
                    WindDownScheduleView()
                        .environmentObject(viewModel)
                }
                .navigationDestination(isPresented: dashboardDestinationBinding(for: .protectionRepair)) {
                    ScreenTimeProtectionRepairView()
                        .environmentObject(viewModel)
                }
                .alert("The session could not start", isPresented: dashboardDestinationBinding(for: .quickStartError)) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(viewModel.windDownScheduleError
                        ?? (viewModel.nightWatchStartStatus.isEmpty
                            ? "Please try again."
                            : viewModel.nightWatchStartStatus))
                }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func dashboardDestinationBinding(
        for route: PixelHomeDashboardDestination
    ) -> Binding<Bool> {
        Binding(
            get: { homeDashboardDestination == route },
            set: { isPresented in
                if isPresented {
                    homeDashboardDestination = route
                } else if homeDashboardDestination == route {
                    homeDashboardDestination = nil
                }
            }
        )
    }

    private var tabContent: some View {
        ZStack {
            VStack(spacing: 0) {
                if showHeaderChrome {
                    CountingSheepTopBar()
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                    if viewModel.orientationState.shouldShowContinueCard(
                        isCoachMarkPresented: isOrientationCoachPresented
                    ) {
                        FirstRunContinueCard(
                            title: FirstRunGuideCopy.continueCardTitle(for: viewModel.orientationState.activeChapter),
                            detail: FirstRunGuideCopy.continueCardDetail(
                                for: viewModel.orientationState.activeChapter,
                                step: viewModel.orientationState.currentStep
                            ),
                            onResume: resumeFirstRunGuide,
                            onDismiss: viewModel.dismissFirstRunContinueCard
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    }
                }

                if contentUsesOwnScroll {
                    content
                } else if selectedTab == .home {
                    GeometryReader { viewportProxy in
                        ScrollView {
                            VStack(spacing: 18) {
                                content
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, showChrome ? 20 : 12)
                            .padding(.bottom, 18)
                        }
                        .coordinateSpace(name: HomeScrollViewportCoordinateSpace.name)
                        .onAppear { homeScrollViewportSize = viewportProxy.size }
                        .onChange(of: viewportProxy.size) { _, size in
                            homeScrollViewportSize = size
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            content
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, showChrome ? 20 : 12)
                        .padding(.bottom, 18)
                    }
                }
            }

            if pingBannerVisible {
                PingPulseOverlay()
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .opacity.combined(with: .scale(scale: 0.96))
                    )
                    .zIndex(10)
            }
        }
    }

    private var shouldPresentOrientationCoach: Bool {
        viewModel.isOrientationActive
            && !viewModel.isRunning
            && viewModel.orientationState.presentationState == .active
            && FirstRunJourney.usesCoachMark(viewModel.orientationState.currentStep)
            && selectedTab == tab(for: FirstRunJourney.surface(for: viewModel.orientationState.currentStep))
    }

    private var isOrientationCoachPresented: Bool { shouldPresentOrientationCoach }

    private var activeOrientationTarget: OrientationTourTarget {
        switch viewModel.orientationState.currentStep.normalized {
        case .home: return .homePlan
        case .start: return .startAction
        case .phoneAway, .navigation: return .phoneAway
        case .rootTabs: return .navigation
        case .farmMeetSheep: return .farmPasture
        case .farmCapacity: return .farmCapacity
        case .farmWool, .farmShear, .farmCurrency: return .farmWool
        case .farmClaimWearable, .farmEquipWearable, .farmShop: return .farmShop
        case .farmSearch: return .farmSearch
        case .settings: return .settingsWindDown
        case .nights: return .nightsRecord
        default: return .homePlan
        }
    }

    private func tab(for surface: FirstRunSurface) -> MainAppTab {
        switch surface {
        case .home: return .home
        case .farm: return .farm
        case .settings: return .settings
        case .nights: return .nights
        }
    }

    private func advanceOrientationTour() {
        viewModel.advanceOrientationTour()
        restoreFirstRunSurface()
    }

    private func resumeFirstRunGuide() {
        viewModel.resumeOrientation()
        restoreFirstRunSurface()
    }

    private func restoreFirstRunSurface() {
        guard viewModel.orientationState.isGuideActive else { return }
        guard let destination = FirstRunJourney.resumeDestination(for: viewModel.orientationState) else {
            return
        }
        if destination.resetNavigation {
            resetNavigation(for: tab(for: destination.surface))
        }
        select(tab(for: destination.surface), resetIfReselected: false)
        showOrientationPracticeOffer = destination.presentPracticeOffer && !viewModel.isRunning
    }

    private func startOrientationPractice() {
        showOrientationPracticeOffer = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            _ = viewModel.startOrientationPractice()
        }
    }

    private func recordVisibleFarmLesson(_ step: CountingSheepOrientationStep) {
        switch step {
        case .farmMeetSheep: viewModel.recordFirstRunFarmAction(.metSheep)
        case .farmCapacity: viewModel.recordFirstRunFarmAction(.sawCapacity)
        case .farmWool: viewModel.recordFirstRunFarmAction(.sawWool)
        case .farmShop: viewModel.recordFirstRunFarmAction(.visitedShop)
        case .farmSearch: viewModel.recordFirstRunFarmAction(.visitedSearch)
        default: break
        }
    }

    private var shellBackground: Color {
        isActiveWindDown && selectedTab == .home
            ? AppColors.activeWindDownBackground
            : AppColors.paper
    }

    private var isActiveWindDown: Bool {
        viewModel.isRunning && viewModel.activeRun?.isNightWatch == true
    }

    private var shellFooter: some View {
        VStack(spacing: AppSpacing.xs) {
            if viewModel.isRunning, selectedTab != .home {
                ActiveWindDownReturnBar(run: viewModel.activeRun) {
                    select(.home)
                }
            }
            CountingSheepBottomBar(selectedTab: Binding(
                get: { selectedTab },
                set: { select($0) }
            ))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(
            (isActiveWindDown && selectedTab == .home
                ? AppColors.activeWindDownBackground
                : AppColors.paper
            ).opacity(0.98)
        )
    }

    private func routePendingNotificationIfNeeded() {
        guard let destination = PhoneNotificationService.shared.consumePendingDestination() else { return }
        switch destination {
        case .home, .activeRun:
            select(.home)
        case .nights, .morningReflection:
            if viewModel.isRunning { select(.home) } else { select(.nights) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if selectedTab == .home {
            homeContent
        } else {
            switch selectedTab {
            case .home:
                EmptyView()
            case .nights:
                FocusStatsView()
                    .environmentObject(viewModel)
            case .farm:
                FarmView(
                    pastureVisitSeed: farmVisitSeed,
                    opensNightFlock: $opensNightFlock,
                    nightFlockPartyID: $nightFlockPartyID
                )
                    .environmentObject(viewModel)
            case .settings:
                SettingsView()
                    .environmentObject(viewModel)
            }
        }
    }

    @ViewBuilder
    private var homeContent: some View {
        switch viewModel.homeReceiptRoute {
        case .activeScreenFreeMorning(let occurrenceID):
            if let occurrence = viewModel.screenFreeMorningOccurrences.first(where: { $0.id == occurrenceID }) {
                ScreenFreeMorningView(occurrence: occurrence)
            } else {
                PixelHomeDashboard(
                    watch: dashboardWatch,
                    destination: $homeDashboardDestination,
                    homeScrollViewportSize: homeScrollViewportSize
                )
                .environmentObject(viewModel)
            }
        case .deferredScreenFreeMorning(let occurrenceID, let unreadRunID):
            VStack(spacing: AppSpacing.md) {
                if let occurrence = viewModel.screenFreeMorningOccurrences.first(where: { $0.id == occurrenceID }) {
                    HomeDeferredScreenFreeMorningCard(occurrence: occurrence)
                }
                if let unreadRunID { HomeWindDownReceiptRecoveryCard(runID: unreadRunID) }
                PixelHomeDashboard(
                    watch: dashboardWatch,
                    destination: $homeDashboardDestination,
                    homeScrollViewportSize: homeScrollViewportSize
                )
                .environmentObject(viewModel)
            }
        case .terminalWindDownReceipt:
            if viewModel.activeRun?.state == .completed {
                CompletionView()
            } else {
                EarlyEndView()
            }
        case .activeWindDown:
            ActiveRunView(now: activeRunNow)
        case .unreadWindDownReceipt(let runID):
            HomeWindDownReceiptRecoveryCard(runID: runID)
        case .dashboard:
            VStack(spacing: AppSpacing.md) {
                if viewModel.orientationState.completedChapters.contains(.homeBasics),
                   !viewModel.orientationState.deferredChapters.contains(.homeBasics),
                   !viewModel.orientationState.completedChapters.contains(.farmTour) {
                    FirstRunHomeChapterHandoffCard(
                        onExplore: viewModel.dismissHomeHandoff,
                        onPractice: { showOrientationPracticeOffer = true }
                    )
                }
                PixelHomeDashboard(
                    watch: dashboardWatch,
                    destination: $homeDashboardDestination,
                    homeScrollViewportSize: homeScrollViewportSize
                )
                .environmentObject(viewModel)
            }
        }
    }

    private var showChrome: Bool {
        guard viewModel.activeRun?.state != .completed,
              viewModel.activeRun?.state != .endedEarly else { return false }
        return !viewModel.isRunning || viewModel.activeRun?.isNightWatch == true
    }

    /// Active runs already provide their own compact title and journey header.
    /// Keeping the general brand bar above them creates a large empty band,
    /// especially in Light Mode, while the tab bar still needs to remain.
    private var showHeaderChrome: Bool {
        showChrome && !(viewModel.isRunning && selectedTab == .home)
    }

    private var contentUsesOwnScroll: Bool {
        // Active and terminal ritual screens own their compact layout/receipt
        // scroll. Wrapping them in the shell ScrollView makes the live journey
        // feel like a long document and can push the exit controls below the
        // viewport on smaller phones.
        if viewModel.activeRun?.state == .completed || viewModel.activeRun?.state == .endedEarly { return true }
        if viewModel.isRunning && selectedTab == .home { return true }
        return selectedTab != .home
    }

    private func select(_ tab: MainAppTab, resetIfReselected: Bool = true) {
        let isReselection = selectedTab == tab
        if tab == .farm, !isReselection {
            farmVisitSeed = UInt64.random(in: UInt64.min...UInt64.max)
        }
        selectedTab = tab
        if tab == .home {
            resetNavigation(for: .home)
        } else if resetIfReselected, isReselection {
            resetNavigation(for: tab)
        }
    }

    private func routeToHome() {
        guard viewModel.isRunning else { return }
        // Clear the Home-owned presentation first. The active surface removes
        // PixelHomeDashboard immediately, so a dashboard-local binding cannot
        // reliably dismiss an already-pushed schedule route.
        homeDashboardDestination = nil
        selectedTab = .home
        resetNavigation(for: .home)
    }

    private func resetNavigation(for tab: MainAppTab) {
        switch tab {
        case .home: homeNavigationPath = NavigationPath()
        case .nights: nightsNavigationPath = NavigationPath()
        case .farm: farmNavigationPath = NavigationPath()
        case .settings: settingsNavigationPath = NavigationPath()
        }
    }

    private func showPingBanner() {
        withAnimation(reduceMotion ? AppMotion.reducedFade : AppMotion.notice) {
            pingBannerVisible = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(reduceMotion ? AppMotion.reducedFade : AppMotion.exit) {
                pingBannerVisible = false
            }
        }
    }
}

private struct HomeDeferredScreenFreeMorningCard: View {
    let occurrence: MorningQuietOccurrence

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("SCREEN-FREE MORNING")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Planned for \(OllieFormat.time(occurrence.scheduledStart))")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                Text("Your phone can stay away for this separate morning window.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HomeWindDownReceiptRecoveryCard: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    let runID: UUID
    @State private var isOpen = false

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("WIND DOWN RECEIPT")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text(receiptText)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                if !isOpen {
                    Button("Show receipt") {
                        isOpen = true
                    }
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .accessibilityHint("Opens this finite Wind Down receipt")
                } else {
                    Button("Done with receipt") {
                        viewModel.revealDeliveredWindDownBenefit(for: runID)
                    }
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .accessibilityHint("Marks this displayed Wind Down receipt as read")
                }
            }
        }
    }

    private var receiptText: String {
        guard isOpen else { return "A Wind Down receipt is ready when you are." }
        guard let outcome = viewModel.sheepSearchOutcome(for: runID) else {
            return "Your qualifying Wind Down was saved."
        }
        return SheepSearchPresentation.journalResultHeadline(for: outcome)
    }
}

private struct ActiveWindDownReturnBar: View {
    let run: FocusRun?
    let now: Date
    let action: () -> Void

    init(run: FocusRun?, now: Date = Date(), action: @escaping () -> Void) {
        self.run = run
        self.now = now
        self.action = action
    }

    private var presentation: ActiveRunPresentation? {
        run.map { ActiveRunPresentation(run: $0, at: now) }
    }

    private var fallbackTitle: String {
        run?.nightWatchPlan?.role == .additionalQuiet ? "Phone Away" : "Wind Down"
    }

    private var fallbackAccessibilityHint: String {
        run?.nightWatchPlan?.role == .additionalQuiet
            ? "Returns to the live Phone Away"
            : "Returns to the live Wind Down journey"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(AppColors.lavender)
                Text(presentation?.returnBarTitle ?? fallbackTitle)
                    .font(AppTypography.caption.weight(.bold))
                if let presentation {
                    let end = presentation.returnBarEndDate
                    Text(timerInterval: now...max(now, end), countsDown: true, showsHours: true)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .monospacedDigit()
                    Text("left")
                        .font(AppTypography.caption)
                }
                Spacer()
                Text("Return")
                    .font(AppTypography.caption.weight(.bold))
                Image(systemName: "arrow.right")
            }
            .foregroundStyle(AppColors.ink)
            .padding(.horizontal, AppSpacing.sm)
            .frame(minHeight: 42)
            .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            presentation.map {
                "\($0.returnBarTitle), \($0.timerAccessibilityLabel(remainingSeconds: max(0, $0.returnBarEndDate.timeIntervalSince(now))))"
        } ?? fallbackTitle
        )
        .accessibilityHint(presentation?.returnBarAccessibilityHint ?? fallbackAccessibilityHint)
    }
}
