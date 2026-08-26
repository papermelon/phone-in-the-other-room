import SwiftUI

private enum TrailNotesFilter: String, CaseIterable, Identifiable {
    case all, homecomings, clues
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All notes"
        case .homecomings: return "Homecomings"
        case .clues: return "Clues"
        }
    }
}

struct TrailNotesArchiveView: View {
    @EnvironmentObject private var viewModel: FocusRunViewModel
    @State private var filter: TrailNotesFilter = .all

    private var outcomes: [SheepSearchOutcome] {
        viewModel.sheepSearchState.outcomes.reversed().filter { outcome in
            switch filter {
            case .all: return true
            case .homecomings: return outcome.result == .found
            case .clues: return outcome.result == .trailOnly
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                Picker("Search Journal filter", selection: $filter) {
                    ForEach(TrailNotesFilter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                if outcomes.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(outcomes) { outcome in
                            NavigationLink {
                                WindDownRevealView(
                                    outcome: outcome,
                                    showExactOdds: viewModel.sheepSearchState.showExactOdds,
                                    farmState: viewModel.farmState
                                )
                            } label: {
                                TrailNoteRow(outcome: outcome, farmState: viewModel.farmState)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                NavigationLink("Open Ollie’s Search") { TrailBoardView() }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Search Journal")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                PixelAssetImage(name: AssetSlot.Dog.proud)
                    .frame(width: 72, height: 72)
                    .accessibilityLabel("Ollie with the Search Journal")
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("SEARCH JOURNAL")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("Homecomings and clues Ollie brought home.")
                        .font(AppTypography.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(viewModel.sheepSearchState.outcomes.count) entries · \(viewModel.farmState.discoveries.count) sheep known")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    private var emptyState: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Image(systemName: "note.text")
                    .font(.title2)
                    .foregroundStyle(AppColors.grass)
                Text("No Search Journal entry saved.")
                    .font(AppTypography.headline)
                Text("Wind Down, Sunrise Trail, and Phone Away can each leave a homecoming or clue here.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }
}

private struct TrailNoteRow: View {
    let outcome: SheepSearchOutcome
    let farmState: FarmState

    private var definition: SheepDefinition? {
        outcome.sheepID.flatMap(SheepCatalog.definition)
    }
    private var ownedStatus: FlockSheepStatus? {
        farmState.sheep.first { $0.sourceOutcomeID == outcome.id }?.status
    }
    private var displayName: String {
        farmState.sheep.first { $0.sourceOutcomeID == outcome.id }?.displayName
            ?? definition?.name
            ?? "Homecoming"
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .fill(AppColors.grass.opacity(0.12))
                if let definition {
                    PixelAssetImage(name: definition.assetName)
                        .padding(5)
                } else {
                    Image(systemName: "pawprint.fill")
                        .foregroundStyle(AppColors.grass)
                }
            }
            .frame(width: 68, height: 68)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(outcome.result == .found ? displayName : "Search continues")
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.ink)
                Text(originLine)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryText)
                Text(statusLine)
                    .font(AppTypography.caption)
                    .foregroundStyle(outcome.result == .found ? AppColors.success : AppColors.grass)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(AppColors.muted)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg)
                .stroke(AppColors.stroke.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var statusLine: String {
        switch (outcome.result, ownedStatus) {
        case (.trailOnly, _): return "Clue saved for another night"
        case (.found, .pending): return "Waiting at The Barn gate"
        case (.found, .sold): return "Discovery kept · sheep moved on"
        case (.found, .active): return "Living in the active flock"
        case (.found, nil): return "Homecoming recorded"
        }
    }

    private var originLine: String {
        SheepSearchPresentation.originLine(for: outcome)
    }
}

#Preview("Search Journal") {
    NavigationStack {
        VStack(spacing: AppSpacing.sm) {
            ForEach(FarmPreviewData.searchState.outcomes.reversed()) {
                TrailNoteRow(outcome: $0, farmState: FarmPreviewData.fullState)
            }
        }
        .padding()
        .background(AppColors.paper)
    }
}
