import SwiftUI

struct CompletionView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var revealResult = false

    private var minutes: Int { viewModel.activeRun?.creditedQuietMinutes ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PixelCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            OllieRitualView(state: .completed)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("A SHEPHERDING NIGHT")
                                    .font(pixelFont(.caption))
                                    .foregroundStyle(AppColors.grass)
                                Text("Ollie brought the trail home.")
                                    .font(pixelFont(.title2))
                                Text("You kept \(minutes) minutes phone-free around sleep.")
                                    .font(pixelFont(.body))
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                        }
                    }
                }

                if let plan = viewModel.activeRun?.nightWatchPlan {
                    PixelCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("LAST NIGHT'S WIND DOWN")
                                .font(pixelFont(.caption))
                                .foregroundStyle(AppColors.grass)
                            quietTimeRow(
                                icon: "moon.zzz.fill",
                                title: "Wind-down",
                                value: "\(viewModel.activeRun?.creditedWindDownMinutes ?? 0) min",
                                detail: plan.eveningActivity.shortTitle
                            )
                            quietTimeRow(
                                icon: "sun.max.fill",
                                title: "After waking",
                                value: "\(viewModel.activeRun?.creditedMorningQuietMinutes ?? 0) min",
                                detail: plan.morningActivity.shortTitle
                            )
                        }
                    }
                }

                NightWatchReceiptCard(
                    run: viewModel.activeRun,
                    sleepSummary: viewModel.lastNightSleep,
                    sleepAuthorization: viewModel.sleepAuthorization,
                    screenTimeAuthorization: viewModel.screenTimeAuthorization
                )

                if revealResult {
                    if let run = viewModel.activeRun,
                       let outcome = viewModel.latestSheepSearchOutcome,
                       outcome.runID == run.id {
                        WindDownFindRevealCard(outcome: outcome)
                    }
                    flockArrivalCard
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            revealResult = true
                        }
                    } label: {
                        Label("See what Ollie brought home", systemImage: "gift.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PixelPrimaryButtonStyle())
                }

                NavigationLink("See your nights") {
                    FocusStatsView()
                        .environmentObject(viewModel)
                }
                .buttonStyle(PixelChipButtonStyle(isSelected: false))

                Button("Done for now") { viewModel.resetSetup() }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(PixelPrimaryButtonStyle())
            }
            .padding(16)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .onAppear(perform: viewModel.refreshSleepSummary)
    }

    private var flockArrivalCard: some View {
        PixelCard {
            HStack(spacing: 14) {
                PixelAssetImage(name: AssetSlot.Sheep.common)
                    .frame(width: 70, height: 70)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("A SHEEP SETTLED IN")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("Your flock has \(viewModel.coordinator.progress.totalCompletedRuns) sheep.")
                        .font(pixelFont(.title3))
                    Text("One equal sheep for one protected night.")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func quietTimeRow(icon: String, title: String, value: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.grass)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(pixelFont(.body))
                Text(detail)
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.secondaryText)
            }
            Spacer()
            Text(value)
                .font(pixelFont(.caption))
        }
    }

}

private struct WindDownFindRevealCard: View {
    let outcome: SheepSearchOutcome

    private var sheep: SheepDefinition? {
        outcome.sheepID.flatMap(SheepCatalog.definition)
    }

    var body: some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                PixelAssetImage(name: sheep?.assetName ?? AssetSlot.Dog.proud)
                    .frame(width: 76, height: 76)
                    .accessibilityLabel(sheep?.name ?? "Ollie")
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(sheep == nil ? "OLLIE FOUND THE TRAIL" : "A SHEEP FOUND ITS WAY HOME")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(sheep.map { "Meet \($0.name)" } ?? "The trail is still growing")
                        .font(AppTypography.headline)
                    Text(sheep?.story ?? "Ollie left a quiet clue for another night.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                    Text("Trail: \(String(format: "%.1f km", outcome.trailDistance))")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
