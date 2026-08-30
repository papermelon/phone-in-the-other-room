import SwiftUI

private enum TrailBoardFilter: String, CaseIterable, Identifiable {
    case searching, known, all

    var id: String { rawValue }
    var title: String {
        switch self {
        case .searching: return "Still searching"
        case .known: return "Found"
        case .all: return "All sheep"
        }
    }
}

struct TrailBoardView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var filter: TrailBoardFilter = .searching

    private var protectedNights: Int { viewModel.coordinator.progress.totalCompletedRuns }
    private var discoveredIDs: Set<String> {
        Set(viewModel.farmState.discoveries.map(\.definitionID))
    }
    private var definitions: [SheepDefinition] {
        switch filter {
        case .searching:
            return SheepCatalog.eligible(for: max(1, protectedNights)).filter { !discoveredIDs.contains($0.id) }
        case .known:
            return SheepCatalog.all.filter { discoveredIDs.contains($0.id) }
        case .all:
            return SheepCatalog.all
        }
    }
    private var boardColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                Picker("Ollie’s Search filter", selection: $filter) {
                    ForEach(TrailBoardFilter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                if definitions.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(
                        columns: boardColumns,
                        spacing: AppSpacing.sm
                    ) {
                        ForEach(definitions) { definition in
                            TrailBoardCard(
                                definition: definition,
                                isDiscovered: discoveredIDs.contains(definition.id),
                                isEligible: SheepCatalog.arrivalNight(for: definition) <= max(1, protectedNights),
                                isTracked: viewModel.farmState.trackedSheepDefinitionID == definition.id,
                                isNew: SheepCatalog.arrivalNight(for: definition) == max(1, protectedNights),
                                onTrack: {
                                    viewModel.trackSheepDefinition(
                                        viewModel.farmState.trackedSheepDefinitionID == definition.id
                                            ? nil
                                            : definition.id
                                    )
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Ollie’s Search")
        .navigationBarTitleDisplayMode(.inline)
        .farmActionAlert(viewModel: viewModel)
    }

    private var header: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "binoculars.fill")
                        .font(.title.weight(.bold))
                        .foregroundStyle(AppColors.grass)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("OLLIE’S SEARCH")
                            .font(pixelFont(.caption))
                            .foregroundStyle(AppColors.grass)
                        Text("Choose one missing sheep for Ollie to watch for.")
                            .font(AppTypography.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Ollie may look more closely here after Wind Down, Screen-Free Morning, or Phone Away. Choosing a sheep never guarantees who comes home.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                boardMetric(
                    "\(discoveredIDs.count) / \(SheepCatalog.all.count)",
                    label: "Found",
                    icon: "book.closed.fill"
                )
            }
        }
    }

    private func boardMetric(_ value: String, label: String, icon: String) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .foregroundStyle(AppColors.grass)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(AppTypography.caption.weight(.bold))
                Text(label).font(.caption2).foregroundStyle(AppColors.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(AppSpacing.xs)
        .frame(maxWidth: .infinity)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.md))
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Image(systemName: filter == .known ? "house.fill" : "pawprint.fill")
                    .font(.title2)
                    .foregroundStyle(AppColors.grass)
                Text(filter == .searching ? "Ollie has no new missing sheep to look for yet." : "No sheep are recorded here yet.")
                    .font(AppTypography.headline)
                Text(filter == .searching
                    ? "More sheep become available as completed Wind Downs open new missing-sheep notes."
                    : "Finish Wind Down to begin the Search Journal.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }
}

private struct TrailBoardCard: View {
    let definition: SheepDefinition
    let isDiscovered: Bool
    let isEligible: Bool
    let isTracked: Bool
    let isNew: Bool
    let onTrack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(isDiscovered ? "FOUND" : isEligible ? "STILL MISSING" : "NOT YET AVAILABLE")
                    .font(pixelFont(.caption2))
                    .foregroundStyle(isDiscovered ? AppColors.success : AppColors.bark)
                Spacer()
                if isNew && !isDiscovered {
                    Text("NEW")
                        .font(pixelFont(.caption2))
                        .foregroundStyle(AppColors.berry)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(AppColors.wool.opacity(0.42))
                PixelAssetImage(name: definition.assetName)
                    .saturation(isDiscovered ? 1 : 0)
                    .brightness(isDiscovered ? 0 : -0.35)
                    .opacity(isDiscovered ? 1 : 0.28)
                    .padding(AppSpacing.sm)
                if !isDiscovered {
                    Image(systemName: isEligible ? "pawprint.fill" : "questionmark")
                        .font(.title.weight(.black))
                        .foregroundStyle(AppColors.bark.opacity(0.72))
                }
            }
            .aspectRatio(1.2, contentMode: .fit)
            .accessibilityHidden(true)

            Text(definition.name)
                .font(AppTypography.title)
                .foregroundStyle(AppColors.bark)
                .lineLimit(1)
            Text(definition.rarity.title + " · " + definition.habitat.title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.bark.opacity(0.74))
                .lineLimit(2)
            Text(isEligible ? clue : "Ollie will learn more after future Wind Downs.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.bark)
                .fixedSize(horizontal: false, vertical: true)

            if !isDiscovered && isEligible {
                Button(isTracked ? "Search chosen" : "Choose for Ollie’s Search", action: onTrack)
                    .buttonStyle(PixelChipButtonStyle(isSelected: isTracked))
                    .frame(maxWidth: .infinity)
            } else if isDiscovered {
                Label("Recorded in Search Journal", systemImage: "checkmark.seal.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.success)
            }
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(isTracked ? AppColors.grass : AppColors.bark.opacity(0.28), lineWidth: isTracked ? 2 : 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var clue: String {
        definition.posterClue.replacingOccurrences(of: "Last seen ", with: "Seen ")
    }
}

#Preview("Ollie’s Search") {
    NavigationStack {
        TrailBoardPreview()
    }
}

private struct TrailBoardPreview: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
            TrailBoardCard(
                definition: SheepCatalog.all[5],
                isDiscovered: false,
                isEligible: true,
                isTracked: true,
                isNew: true,
                onTrack: {}
            )
            TrailBoardCard(
                definition: SheepCatalog.all[0],
                isDiscovered: true,
                isEligible: true,
                isTracked: false,
                isNew: false,
                onTrack: {}
            )
        }
        .padding()
        .background(AppColors.paper)
    }
}
