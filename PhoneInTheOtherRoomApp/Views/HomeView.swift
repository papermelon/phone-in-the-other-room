import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var pingBannerVisible = false
    @State private var selectedTab: MainAppTab = .home

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.paper.ignoresSafeArea()
                VStack(spacing: 0) {
                    if showChrome, selectedTab != .farm {
                        CountingSheepTopBar(progress: viewModel.coordinator.progress, showCapacity: selectedTab == .home)
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
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(10)
                }
            }
            .alert("Turn on Focus Mode for this run?", isPresented: $viewModel.showFocusModePrompt) {
                Button("Skip", role: .cancel) {
                    viewModel.startRun(focusAccepted: false)
                }
                Button("I've Turned It On") {
                    viewModel.startRun(focusAccepted: true)
                }
            } message: {
                Text("Counting Sheep cannot silently toggle Focus. Turn it on from Control Center or run your Shortcut first, then continue.")
            }
            .onAppear {
                viewModel.applyShortcutPreparationIfNeeded()
            }
            .onChange(of: viewModel.coordinator.pingPulseCount) { _, count in
                guard count > 0 else { return }
                showPingBanner()
            }
            .toolbar(.hidden, for: .navigationBar)
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
            case .farm:
                FarmOverviewScreen()
            case .friends:
                FriendsOverviewScreen()
            case .stats:
                FocusStatsView()
                    .environmentObject(viewModel)
            case .shop:
                ShopPlaceholderScreen()
            }
        }
    }

    private var showChrome: Bool {
        viewModel.activeRun == nil && !viewModel.isRunning
    }

    private var contentUsesOwnScroll: Bool {
        guard showChrome else { return false }
        return selectedTab != .home
    }

    private func showPingBanner() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            pingBannerVisible = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut(duration: 0.22)) {
                pingBannerVisible = false
            }
        }
    }
}
