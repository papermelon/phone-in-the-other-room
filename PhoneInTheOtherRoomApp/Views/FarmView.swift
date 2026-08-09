import SwiftUI

/// The shipping Farm reads only the persisted sheep-search field book and the
/// authoritative protected-night count. Legacy Farm, currency, and mock data
/// remain outside this release surface.
struct FarmView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    var body: some View {
        ShippingFarmContent(
            searchState: viewModel.sheepSearchState,
            protectedNightCount: viewModel.coordinator.progress.totalCompletedRuns
        )
        .navigationTitle("Farm")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.markOrientation(.farmExplored) }
    }
}

struct ShippingFarmContent: View {
    let searchState: SheepSearchState
    let protectedNightCount: Int

    private var homeSheep: [SheepDefinition] {
        let persistedIDs = searchState.foundSheepIDs
        let outcomeIDs = searchState.outcomes.compactMap { outcome in
            outcome.result == .found ? outcome.sheepID : nil
        }
        var seen = Set<String>()
        return (persistedIDs + outcomeIDs).compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return SheepCatalog.definition(for: id)
        }
    }

    private var latestArrival: (SheepDefinition, SheepSearchOutcome)? {
        guard let outcome = searchState.outcomes.last(where: { $0.result == .found }),
              let sheepID = outcome.sheepID,
              let sheep = SheepCatalog.definition(for: sheepID)
        else { return nil }
        return (sheep, outcome)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FarmHeader(count: homeSheep.count)

                ShippingFarmHeroScene(sheep: latestArrival?.0)

                FarmArrivalCard(
                    sheep: latestArrival?.0,
                    outcome: latestArrival?.1
                )

                SettledFlockPreview(
                    count: homeSheep.count,
                    foundSheep: homeSheep
                )

                TrailMapStatusCard(map: searchState.trailMap)

                SheepFieldBoard(
                    searchState: searchState,
                    protectedNightNumber: max(1, protectedNightCount)
                )
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppColors.paper.ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }
}

private struct TrailMapStatusCard: View {
    let map: SheepTrailMapState

    var body: some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "map.fill")
                    .font(.title2)
                    .foregroundStyle(AppColors.grass)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("OLLIE'S TRAIL MAP")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text(map.pendingMappedMinutes == 0
                        ? "No quiet minutes are mapped yet."
                        : map.pendingMappedMinutes.description + " quiet minutes mapped toward a future sheep search. One-time quiet never starts a search by itself.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if map.availableBonusPercentagePoints > 0 {
                        Text("Up to +" + map.availableBonusPercentagePoints.description + " percentage points ready")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.grass)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(map.pendingMappedMinutes == 0
                ? "Ollie's trail map. No quiet minutes are mapped yet."
                : "Ollie's trail map. " + map.pendingMappedMinutes.description + " quiet minutes mapped for a future search.")
        }
    }
}

private struct FarmHeader: View {
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("YOUR FLOCK")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
                Text("Sheep who have come home")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Flock: \(count) sheep")
        }
    }
}

private struct SettledFlockPreview: View {
    let count: Int
    let foundSheep: [SheepDefinition]

    private var visibleSheep: [SheepDefinition] { Array(foundSheep.prefix(24)) }

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text("THE FLOCK")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Spacer(minLength: AppSpacing.sm)
                    Text("\(count) in the pasture")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }

                if !visibleSheep.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 30, maximum: 42), spacing: AppSpacing.xs)],
                        spacing: AppSpacing.xs
                    ) {
                        ForEach(visibleSheep) { sheep in
                            PixelAssetImage(name: sheep.assetName)
                                .frame(width: 34, height: 30)
                                .accessibilityHidden(true)
                        }
                    }
                } else {
                    Text("No sheep have come home yet. Ollie’s search moves only after eligible completed protected nights.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.secondaryText)
                }

                if foundSheep.count > visibleSheep.count {
                    Text("and \(foundSheep.count - visibleSheep.count) others in the flock")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(count == 0
                ? "The flock is empty. Ollie is still following the trails."
                : "Flock of \(count) sheep")
        }
    }
}

#Preview("Farm empty") {
    NavigationStack {
        ShippingFarmContent(searchState: .empty, protectedNightCount: 0)
            .navigationTitle("Farm")
    }
}

#Preview("Farm populated · Reduce Motion") {
    NavigationStack {
        ShippingFarmContent(searchState: FarmPreviewData.populatedState, protectedNightCount: 2)
            .navigationTitle("Farm")
    }
    .transaction { transaction in
        transaction.disablesAnimations = true
    }
    .environment(\.sizeCategory, .accessibilityExtraExtraLarge)
}

private enum FarmPreviewData {
    static var populatedState: SheepSearchState {
        var state = SheepSearchState.empty
        state.foundSheepIDs = ["mabel", "pippin"]
        state.outcomes = [
            SheepSearchOutcome(
                id: UUID(), runID: UUID(), protectedNightNumber: 2, result: .found,
                sheepID: "pippin", rarity: .common, habitat: .starterPasture,
                trailStrength: 64, encounterOdds: 1, trailDistance: 3.4,
                consecutiveNoFinds: 0, bonusPoints: 0, createdAt: Date()
            )
        ]
        state.trailMap.credit(runID: UUID(), minutes: 30)
        return state
    }
}
