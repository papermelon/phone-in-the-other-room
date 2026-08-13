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
    @State private var homeNavigationPath = NavigationPath()
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
            .accessibilityHidden(isOrientationTourPresented)
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
        .onReceive(NotificationCenter.default.publisher(for: .countingSheepShowNightFlock)) { _ in
            guard !viewModel.isRunning else { return }
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
                resetNavigation(for: .farm)
                routeToHome()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, viewModel.isRunning { routeToHome() }
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
                if isOrientationTourPresented,
                   let anchor = targets[activeOrientationTarget] {
                    CountingSheepOrientationTourOverlay(
                        step: viewModel.orientationState.currentStep,
                        targetFrame: proxy[anchor],
                        onBack: viewModel.moveBackInOrientationTour,
                        onNext: advanceOrientationTour,
                        onSkip: viewModel.dismissOrientation
                    )
                    .zIndex(50)
                }
            }
        }
        .sheet(isPresented: $showOrientationPracticeOffer) {
            CountingSheepPracticeOfferSheet(
                onStartPractice: startOrientationPractice,
                onMaybeLater: { showOrientationPracticeOffer = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
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
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var tabContent: some View {
        ZStack {
            VStack(spacing: 0) {
                if showChrome {
                    CountingSheepTopBar()
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                }

                if contentUsesOwnScroll {
                    content
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

    private var isOrientationTourPresented: Bool {
        viewModel.isOrientationActive
            && !viewModel.isRunning
            && selectedTab == .home
    }

    private var activeOrientationTarget: OrientationTourTarget {
        switch viewModel.orientationState.currentStep {
        case .home: return .homePlan
        case .start: return .startAction
        case .navigation: return .navigation
        }
    }

    private func advanceOrientationTour() {
        if viewModel.orientationState.currentStep == .navigation {
            viewModel.completeOrientationTour()
            showOrientationPracticeOffer = true
        } else {
            viewModel.advanceOrientationTour()
        }
    }

    private func startOrientationPractice() {
        showOrientationPracticeOffer = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            _ = viewModel.startOrientationPractice()
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
        if let run = viewModel.activeRun, run.state == .completed {
            CompletionView()
        } else if let run = viewModel.activeRun, run.state == .endedEarly {
            EarlyEndView()
        } else if viewModel.isRunning && (selectedTab == .home || viewModel.activeRun?.isNightWatch != true) {
            ActiveRunView(now: activeRunNow)
        } else {
            switch selectedTab {
            case .home:
                PixelHomeDashboard(watch: dashboardWatch)
                    .environmentObject(viewModel)
            case .nights:
                FocusStatsView()
                    .environmentObject(viewModel)
            case .farm:
                FarmView(
                    pastureVisitSeed: farmVisitSeed,
                    opensNightFlock: $opensNightFlock
                )
                    .environmentObject(viewModel)
            case .settings:
                SettingsView()
                    .environmentObject(viewModel)
            }
        }
    }

    private var showChrome: Bool {
        guard viewModel.activeRun?.state != .completed,
              viewModel.activeRun?.state != .endedEarly else { return false }
        return !viewModel.isRunning || viewModel.activeRun?.isNightWatch == true
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

    private func select(_ tab: MainAppTab) {
        let isReselection = selectedTab == tab
        if tab == .farm {
            farmVisitSeed = UInt64.random(in: UInt64.min...UInt64.max)
        }
        selectedTab = tab
        if tab == .home || isReselection {
            resetNavigation(for: tab)
        }
    }

    private func routeToHome() {
        guard viewModel.isRunning else { return }
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
