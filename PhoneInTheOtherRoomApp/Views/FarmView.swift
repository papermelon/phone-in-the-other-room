import SwiftUI

/// The shipping Farm surface is a quiet record of the flock that has arrived.
///
/// This intentionally consumes only the real sheep-search field book. The old
/// MVP farm used capacity slots, coins, missions, and upgrades; none of those
/// concepts belong in the release Farm.
struct FarmView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel

    private var searchState: SheepSearchState { viewModel.sheepSearchState }

    private var flock: [SheepDefinition] {
        searchState.foundSheepIDs.compactMap(SheepCatalog.definition)
    }

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
                ShippingFarmHeroScene(sheep: latestArrival, flockCount: protectedNightCount)
                SettledFlockPreview(count: protectedNightCount)

                if flock.isEmpty {
                    FarmEmptyState(protectedNightCount: protectedNightCount)
                } else {
                    FarmArrivalNote(sheep: latestArrival)
                    FarmFieldNotes(sheep: flock)
                }
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
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.ink)
            }
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

private struct FarmArrivalNote: View {
    let sheep: SheepDefinition?

    var body: some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: "pawprint.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColors.grass)
                    .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("THE LATEST ARRIVAL")
                        .font(pixelFont(.caption2))
                        .foregroundStyle(AppColors.grass)
                    Text(sheep.map { "\($0.name) is home." } ?? "The flock is growing.")
                        .font(AppTypography.headline)
                    Text("One protected night, one equal sheep.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }
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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xs), count: 6), spacing: AppSpacing.xs) {
                    ForEach(0..<visibleCount, id: \.self) { index in
                        PixelAssetImage(name: AssetSlot.Sheep.common)
                            .frame(height: 34)
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
                Text(protectedNightCount == 0 ? "There are no slots to fill and nothing to buy. Ollie will welcome the flock when it arrives." : "Each protected night settles one equal sheep. Ollie keeps the field notes here when a named arrival is found.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }
}

private struct FarmFieldNotes: View {
    let sheep: [SheepDefinition]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("FIELD NOTES")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.grass)
            }

            LazyVStack(spacing: AppSpacing.sm) {
                ForEach(sheep) { item in
                    NavigationLink(destination: FarmSheepDetailView(sheep: item)) {
                        FarmFieldNoteRow(sheep: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct FarmFieldNoteRow: View {
    let sheep: SheepDefinition

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            PixelAssetImage(name: sheep.assetName)
                .frame(width: 64, height: 64)
                .padding(AppSpacing.xs)
                .background(AppColors.wool.opacity(0.46), in: RoundedRectangle(cornerRadius: AppRadius.md))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(sheep.name)
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                Text(sheep.story)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.muted)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: AppSpacing.xs)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.grass)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.panel, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .stroke(AppColors.stroke.opacity(0.25), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("View \(sheep.name)'s story")
    }
}

private struct FarmSheepDetailView: View {
    let sheep: SheepDefinition

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                PixelCard {
                    VStack(spacing: AppSpacing.sm) {
                        PixelAssetImage(name: sheep.assetName)
                            .frame(height: 160)
                            .accessibilityLabel(sheep.name)
                        Text(sheep.name)
                            .font(AppTypography.display(30))
                        Text("A sheep settled in.")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                    }
                    .frame(maxWidth: .infinity)
                }

                PixelCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("A QUIET STORY")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text(sheep.story)
                            .font(AppTypography.body)
                        if let accessory = sheep.accessory {
                            Text("A small mark: \(accessory).")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.muted)
                        }
                    }
                }
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle(sheep.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Farm") {
    NavigationStack {
        FarmView()
            .environmentObject(FocusRunViewModel())
    }
}
