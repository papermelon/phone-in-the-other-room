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
                Picker("Trail Notes filter", selection: $filter) {
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

                NavigationLink("See the Trail Board") { TrailBoardView() }
                    .buttonStyle(PixelChipButtonStyle(isSelected: false))
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xxl)
        }
        .background(AppColors.paper.ignoresSafeArea())
        .navigationTitle("Ollie’s Trail Notes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        PixelCard {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                PixelAssetImage(name: AssetSlot.Dog.proud)
                    .frame(width: 72, height: 72)
                    .accessibilityLabel("Ollie with the Trail Notes")
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("OLLIE’S TRAIL NOTES")
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Text("Every homecoming and every clue, kept by the night that found it.")
                        .font(AppTypography.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(viewModel.sheepSearchState.outcomes.count) notes · \(viewModel.farmState.discoveries.count) sheep known")
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
                Text("The first page is waiting.")
                    .font(AppTypography.headline)
                Text("A protected Wind Down will give Ollie a trail to record.")
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
                Text(outcome.result == .found ? displayName : "The trail continues")
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
        case (.trailOnly, _): return "Clue saved for another quiet night"
        case (.found, .pending): return "Waiting at The Barn gate"
        case (.found, .sold): return "Discovery kept · sheep moved on"
        case (.found, .active): return "Living in the active flock"
        case (.found, nil): return "Homecoming recorded"
        }
    }

    private var originLine: String {
        let date = outcome.createdAt.formatted(date: .abbreviated, time: .omitted)
        return outcome.origin == .phoneBreak
            ? "Phone Break bonus search · \(date)"
            : "Wind Down \(outcome.protectedNightNumber) · \(date)"
    }
}

#Preview("Ollie’s Trail Notes") {
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
