import SwiftUI

/// The shipping Farm surface is a quiet record of the flock that has arrived.
///
/// This intentionally consumes only the real sheep-search field book. The old
/// MVP farm used capacity slots, coins, missions, and upgrades; none of those
/// concepts belong in the release Farm.
struct FarmView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    private var searchState: SheepSearchState { viewModel.sheepSearchState }

    private var protectedNightCount: Int {
        viewModel.coordinator.progress.totalCompletedRuns
    }

    private var latestArrival: SheepDefinition? {
        guard let outcome = searchState.outcomes.last(where: { $0.sheepID != nil }) else { return nil }
        return outcome.sheepID.flatMap(SheepCatalog.definition)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FarmHeader(count: protectedNightCount)
                ShippingFarmHeroScene(
                    sheep: latestArrival,
                    flockCount: protectedNightCount
                )
                SettledFlockPreview(count: protectedNightCount)

                if protectedNightCount == 0 {
                    FarmEmptyState(protectedNightCount: protectedNightCount)
                }

                SheepPosterBoard(
                    searchState: searchState,
                    protectedNightNumber: max(1, protectedNightCount)
                )
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Farm")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
    }
}

private struct FarmHeader: View {
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("YOUR FARM")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("A place for the flock")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .layoutPriority(1)
            Spacer(minLength: AppSpacing.sm)
            VStack(alignment: .trailing, spacing: AppSpacing.xxs) {
                Text("\(count)")
                    .font(PixelTypography.mono(.title))
                    .foregroundStyle(AppColors.grass)
                Text("sheep")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
            .frame(minWidth: 58)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Flock: \(count) sheep")
        }
    }
}

private struct SettledFlockPreview: View {
    let count: Int

    private var visibleCount: Int { min(max(count, 0), 24) }

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("THE FLOCK")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Spacer()
                    Text("\(count) settled")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 30, maximum: 42), spacing: AppSpacing.xs)],
                    spacing: AppSpacing.xs
                ) {
                    ForEach(0..<visibleCount, id: \.self) { index in
                        PixelAssetImage(name: AssetSlot.Sheep.common)
                            .frame(width: 34, height: 30)
                            .accessibilityHidden(true)
                            .accessibilityIdentifier("settled-sheep-\(index)")
                    }
                }
                if count > visibleCount {
                    Text("and \(count - visibleCount) more in the pasture")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Flock of \(count) equal sheep")
        }
    }
}

private struct FarmEmptyState: View {
    let protectedNightCount: Int

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Image(systemName: "moon.stars.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.grass)
                Text(protectedNightCount == 0 ? "Your first sheep will settle in after a protected night." : "The flock is growing quietly.")
                    .font(AppTypography.headline)
                Text(protectedNightCount == 0 ? "There are no slots to fill and nothing to buy. Ollie will welcome the flock when it arrives." : "Each protected night settles one equal sheep. Ollie keeps the missing posters here as the search unfolds.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }
}

#Preview("Farm") {
    NavigationStack {
        FarmView()
            .environmentObject(FocusRunViewModel())
    }
}
