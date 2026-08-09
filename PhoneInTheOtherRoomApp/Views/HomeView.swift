import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var pingBannerVisible = false
    @State private var selectedTab: MainAppTab = .home
    @State private var navigationIdentity = UUID()

    var body: some View {
        ZStack {
            AppColors.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                NavigationStack {
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
                    .alert("App shielding needs a quick check", isPresented: Binding(
                        get: { viewModel.shieldingPreflightMessage != nil },
                        set: { if !$0 { viewModel.shieldingPreflightMessage = nil } }
                    )) {
                        Button("Keep phone-away mode", role: .cancel) {
                            viewModel.shieldingEnabled = false
                            UserDefaults.standard.set(false, forKey: QuietTimeShieldingService.enabledKey)
                        }
                        Button("OK") { viewModel.shieldingPreflightMessage = nil }
                    } message: {
                        Text(viewModel.shieldingPreflightMessage ?? "")
                    }
                    .onAppear {
                        viewModel.applyShortcutPreparationIfNeeded()
                        routePendingNotificationIfNeeded()
                        returnToActiveWindDownIfNeeded()
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
                        if isRunning { select(.home) }
                    }
                    .onChange(of: scenePhase) { _, phase in
                        if phase == .active, viewModel.isRunning { select(.home) }
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
                            .presentationDetents([.medium])
                            .presentationDragIndicator(.visible)
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
                .id(navigationIdentity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showChrome {
                    shellFooter
                }
            }
        }
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
        .background(AppColors.paper.opacity(0.98))
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
            ActiveRunView()
        } else {
            switch selectedTab {
            case .home:
                PixelHomeDashboard()
                    .environmentObject(viewModel)
            case .nights:
                FocusStatsView()
                    .environmentObject(viewModel)
            case .farm:
                FarmView()
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
        selectedTab = tab
        navigationIdentity = UUID()
    }

    private func returnToActiveWindDownIfNeeded() {
        guard viewModel.isRunning, selectedTab != .home else { return }
        select(.home)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(AppColors.lavender)
                Text("Wind Down")
                    .font(AppTypography.caption.weight(.bold))
                if let end = run?.nightWatchPlan?.nextTransition(after: Date()) ?? run?.plannedEndAt {
                    Text(timerInterval: Date()...max(Date(), end), countsDown: true, showsHours: true)
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
        .accessibilityHint("Returns to the live Wind Down journey")
    }
}

private struct WindDownStartSheet: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dismiss) private var dismiss

    private var usesNFC: Bool { viewModel.selectedGuardKind == .nfcTag }

    private var heading: String {
        if viewModel.pendingNightWatchIsAdditionalQuiet {
            return viewModel.pendingNightWatchTitle ?? "A little one-time quiet."
        }
        return usesNFC ? "Tap in when you are ready." : "Give the evening a little room."
    }

    private var explanation: String {
        if viewModel.pendingNightWatchIsAdditionalQuiet {
            let end = viewModel.pendingNightWatchEndsAt?.formatted(date: .omitted, time: .shortened) ?? "the saved end time"
            let protection = viewModel.willShieldPendingNightWatch
                ? " Your apps to rest will be limited until then."
                : " No apps will be limited."
            return "This quiet time ends at \(end). Only the time from when you start is counted. It stays separate from protected nights and Ollie’s sheep search.\(protection)"
        }
        guard viewModel.willShieldPendingNightWatch else {
            return "Wind Down will keep time and record your quiet. No apps will be limited."
        }
        return usesNFC
            ? "Your apps to rest will be limited after you tap your Wind Down tag and through morning quiet. Counting Sheep stays available."
            : "Your apps to rest will be limited from Wind Down start through morning quiet. Counting Sheep stays available."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("START WIND DOWN")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(heading)
                        .font(AppTypography.title)
                    Text(explanation)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)

                    Toggle("Show progress on the Lock Screen", isOn: $viewModel.liveActivityChoiceForNextRun)
                        .font(AppTypography.body)
                        .tint(AppColors.grass)

                    if !viewModel.nfcStatus.isEmpty {
                        Text(viewModel.nfcStatus)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }

                    Button {
                        viewModel.confirmNightWatchStart()
                    } label: {
                        Label(
                            viewModel.isScanningNFCForStart
                                ? "Waiting for your tag…"
                                : (usesNFC ? "Tap Wind Down tag to start" : "Start now"),
                            systemImage: usesNFC ? "dot.radiowaves.left.and.right" : "iphone.slash"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelPrimaryButtonStyle())
                    .disabled(viewModel.isScanningNFCForStart)

                    Button("Cancel") {
                        viewModel.cancelNightWatchStart()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.muted)
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColors.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelNightWatchStart()
                        dismiss()
                    }
                }
            }
        }
    }
}
