import SwiftUI

struct CompletionView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var celebrate = false

    private var minutes: Int {
        Int((viewModel.activeRun?.plannedDurationSeconds ?? 0) / 60)
    }

    private var earnedStar: FocusStarTier? {
        viewModel.coordinator.progress.todayRecord.bestStar
    }

    var body: some View {
        VStack(spacing: 16) {
            GamePanelView(title: "Run complete", prominence: .hero) {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 14) {
                        OllieSpriteView(mood: .proud, size: 96)
                            .scaleEffect(celebrate ? 1.06 : 1)
                            .idleBob()
                            .accessibilityLabel("Ollie, looking proud")
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You did it. Ollie's tail is wagging.")
                                .font(.title2.weight(.black))
                                .foregroundStyle(.white)
                            Text("Your phone stayed away for \(minutes) minutes.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.70))
                            if let earnedStar {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(focusStarColor(for: earnedStar))
                                        .accessibilityHidden(true)
                                    Text("\(earnedStar.title) focus star today")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white.opacity(0.82))
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    celebrationStars
                        .accessibilityHidden(true)
                }
            }
            RewardRevealView(reward: viewModel.coordinator.latestReward)
            HStack {
                NavigationLink("View Reward Shelf") {
                    RewardShelfView()
                        .environmentObject(viewModel)
                }
                Button("Start another run") { viewModel.resetSetup() }
            }
            .buttonStyle(PixelButtonStyle(tint: OlliePalette.success))
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62).repeatCount(2, autoreverses: true)) {
                celebrate = true
            }
        }
    }

    private var celebrationStars: some View {
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: "sparkle")
                    .font(.caption.weight(.black))
                    .foregroundStyle(OlliePalette.amber)
                    .opacity(celebrate ? 1 : 0.2)
                    .offset(y: celebrate ? CGFloat(index % 2 == 0 ? -4 : 4) : 0)
                    .animation(
                        .easeInOut(duration: 0.45).delay(Double(index) * 0.08),
                        value: celebrate
                    )
            }
        }
    }
}
