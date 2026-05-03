import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var pingBannerVisible = false

    var body: some View {
        NavigationStack {
            ZStack {
                OlliePalette.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        header
                        IsometricFocusYardView(
                            state: viewModel.activeRun?.state ?? .setup,
                            bucket: viewModel.coordinator.proximityState.bucket,
                            distanceMeters: viewModel.coordinator.proximityState.distanceMeters
                        )

                        if let run = viewModel.activeRun, run.state == .completed {
                            CompletionView()
                        } else if let run = viewModel.activeRun, run.state == .endedEarly {
                            EarlyEndView()
                        } else if viewModel.isRunning {
                            ActiveRunView()
                        } else {
                            FocusRunSetupView()
                        }

                        HStack(alignment: .top, spacing: 12) {
                            progressPanel
                            rewardPreview
                        }
                        EventTickerView(events: viewModel.coordinator.events)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 28)
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
                Text("Phone in the Other Room cannot silently toggle Focus. Turn it on from Control Center or run your Shortcut first, then continue.")
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

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            OllieSpriteView(mood: viewModel.activeRun?.state.ollieMood ?? .waiting, size: 66)
            VStack(alignment: .leading, spacing: 6) {
                Text("Phone in the Other Room")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text("Send Ollie on a Focus Run.")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
            }
            Spacer()
        }
        .padding(.top, 10)
    }

    private var progressPanel: some View {
        GamePanelView(title: "Progress") {
            let progress = viewModel.coordinator.progress
            VStack(alignment: .leading, spacing: 6) {
                Text(progress.levelTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(progress.totalCompletedRuns) runs")
                Text("\(progress.totalFocusMinutes) focus min")
                Text("Streak \(progress.currentStreak)")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var rewardPreview: some View {
        NavigationLink {
            RewardShelfView()
        } label: {
            GamePanelView(title: "Shelf") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(viewModel.coordinator.rewards.count)")
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(.white)
                    Text("collectibles")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PingPulseOverlay: View {
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.black)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Phone heard the whistle")
                        .font(.headline.weight(.black))
                    Text("Ping sound and haptic sent.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.black.opacity(0.64))
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.black)
            .padding(16)
            .background(OlliePalette.amber, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 22)
            .padding(.top, 10)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}
