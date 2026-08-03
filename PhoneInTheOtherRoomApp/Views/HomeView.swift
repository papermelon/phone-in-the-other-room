import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pingBannerVisible = false
    @State private var selectedTab: MainAppTab = .home

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.paper.ignoresSafeArea()
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

                    if showChrome {
                        CountingSheepBottomBar(selectedTab: $selectedTab)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 6)
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
            }
            .onReceive(NotificationCenter.default.publisher(for: .countingSheepNotificationDestination)) { notification in
                guard let destination = notification.object as? NotificationDestination else { return }
                switch destination {
                case .home, .activeRun:
                    selectedTab = .home
                case .nights, .morningReflection:
                    selectedTab = .nights
                }
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
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func routePendingNotificationIfNeeded() {
        guard let destination = PhoneNotificationService.shared.consumePendingDestination() else { return }
        switch destination {
        case .home, .activeRun:
            selectedTab = .home
        case .nights, .morningReflection:
            selectedTab = .nights
        }
    }

    @ViewBuilder
    private var content: some View {
        if let run = viewModel.activeRun, run.state == .completed {
            CompletionView()
        } else if let run = viewModel.activeRun, run.state == .endedEarly {
            EarlyEndView()
        } else if viewModel.isRunning {
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
        viewModel.activeRun == nil && !viewModel.isRunning
    }

    private var contentUsesOwnScroll: Bool {
        // Active and terminal ritual screens own their compact layout/receipt
        // scroll. Wrapping them in the shell ScrollView makes the live journey
        // feel like a long document and can push the exit controls below the
        // viewport on smaller phones.
        guard showChrome else { return true }
        return selectedTab != .home
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
