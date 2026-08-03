import SwiftUI

struct CompletionView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

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
                                Text(viewModel.activeRun?.nightWatchPlan?.role == .additionalQuiet
                                    ? "You kept \(minutes) minutes in a bounded quiet period."
                                    : "You kept \(minutes) minutes phone-free around sleep.")
                                    .font(pixelFont(.body))
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                        }
                    }
                }

                NightWatchReceiptCard(
                    run: viewModel.activeRun,
                    sleepSummary: viewModel.lastNightSleep,
                    sleepAuthorization: viewModel.sleepAuthorization,
                    screenTimeAuthorization: viewModel.screenTimeAuthorization
                )

                if let run = viewModel.activeRun, run.isProgressionEligibleNightWatch {
                    NavigationLink {
                        WindDownRevealView(
                            outcome: viewModel.latestSheepSearchOutcome?.runID == run.id
                                ? viewModel.latestSheepSearchOutcome
                                : nil,
                            flockCount: viewModel.coordinator.progress.totalCompletedRuns
                        )
                    } label: {
                        Label("Open Ollie's field note", systemImage: "gift.fill")
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

}

private struct WindDownRevealView: View {
    let outcome: SheepSearchOutcome?
    let flockCount: Int

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            if let outcome {
                WindDownFindRevealCard(outcome: outcome)
            } else {
                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("OLLIE KEPT THE TRAIL")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text("A quiet clue for another night")
                            .font(AppTypography.headline)
                        Text("Tonight's receipt is saved. Ollie will keep looking for a named arrival as the flock grows.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                }
            }

            NavigationLink {
                FlockSettlementView(count: flockCount)
            } label: {
                Text("Settle the flock")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PixelPrimaryButtonStyle())
        }
        .padding(AppSpacing.md)
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Ollie's field note")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FlockSettlementView: View {
    let count: Int

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            PixelCard {
                VStack(spacing: AppSpacing.md) {
                    PixelAssetImage(name: AssetSlot.Sheep.common)
                        .frame(width: 120, height: 120)
                        .accessibilityHidden(true)
                    Text("A SHEEP SETTLED IN")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("Your flock has \(count) sheep.")
                        .font(AppTypography.display(28))
                    Text("One equal sheep for one protected night.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("The flock")
        .navigationBarTitleDisplayMode(.inline)
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
