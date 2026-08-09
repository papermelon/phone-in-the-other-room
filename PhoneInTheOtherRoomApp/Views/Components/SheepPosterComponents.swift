import SwiftUI

enum SheepPosterStatus: Equatable {
    case missing
    case found
}

struct SheepFieldBoard: View {
    let searchState: SheepSearchState
    let protectedNightNumber: Int

    @State private var filter: SheepPosterFilter = .missing

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Picker("Field board", selection: $filter) {
                ForEach(SheepPosterFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Field board filter")

            SheepPosterCarousel(
                searchState: searchState,
                protectedNightNumber: protectedNightNumber,
                filter: filter,
                title: filter == .missing ? "OLLIE'S SEARCHING TRAILS" : "OLLIE'S FIELD BOARD"
            )
        }
    }
}

struct SheepPosterCarousel: View {
    let searchState: SheepSearchState
    let protectedNightNumber: Int
    var filter: SheepPosterFilter = .missing
    var title = "OLLIE'S SEARCHING TRAILS"

    @State private var availableWidth: CGFloat = 0

    private var posters: [SheepDefinition] {
        SheepPosterSelection.posters(
            for: searchState,
            protectedNightNumber: protectedNightNumber,
            filter: filter
        )
    }

    var body: some View {
        PixelCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(pixelFont(.caption))
                        .foregroundStyle(AppColors.grass)
                    Spacer(minLength: AppSpacing.sm)
                    Text(footerCount)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                }

                if posters.isEmpty {
                    emptyState
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: AppSpacing.sm) {
                        ForEach(posters) { sheep in
                                SheepPosterCard(
                                    sheep: sheep,
                                    status: status(for: sheep),
                                    outcome: latestOutcome(for: sheep),
                                    showExactOdds: searchState.showExactOdds,
                                    isNew: isNewPoster(sheep)
                                )
                                .frame(width: posterWidth)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollIndicators(.hidden)
                    .contentMargins(.horizontal, 2, for: .scrollContent)
                    .accessibilityLabel("Sheep field notes")

                    Text(browseLabel)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: SheepPosterBoardWidthKey.self, value: proxy.size.width)
            }
        }
        .onPreferenceChange(SheepPosterBoardWidthKey.self) { width in
            guard width > 0, abs(width - availableWidth) > 0.5 else { return }
            availableWidth = width
        }
    }

    private var posterWidth: CGFloat {
        let width = availableWidth > 0 ? availableWidth : 280
        return min(300, max(240, width * 0.84))
    }

    private var footerCount: String {
        switch filter {
        case .missing: return String(posters.count) + " searching"
        case .home: return String(posters.count) + " home"
        case .all: return String(posters.count) + " in field book"
        }
    }

    private var browseLabel: String {
        "Swipe to browse " + String(posters.count) + " " + (posters.count == 1 ? "field note" : "field notes")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Image(systemName: filter == .home ? "house.fill" : "pawprint.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppColors.grass)
            Text(
                filter == .home
                    ? "No sheep are home yet."
                    : "The pasture is quiet for now. Ollie is still following the trails."
            )
                .font(AppTypography.body)
            Text("Each completed Wind Down gives the search another night to move forward.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.muted)
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private func status(for sheep: SheepDefinition) -> SheepPosterStatus {
        searchState.foundSheepIDs.contains(sheep.id) ? .found : .missing
    }

    private func latestOutcome(for sheep: SheepDefinition) -> SheepSearchOutcome? {
        searchState.outcomes.last { $0.sheepID == sheep.id }
    }

    private func isNewPoster(_ sheep: SheepDefinition) -> Bool {
        guard filter == .missing,
              protectedNightNumber > 1,
              !SheepCatalog.starterIDs.contains(sheep.id)
        else { return false }
        return SheepCatalog.arrivalNight(for: sheep) == protectedNightNumber - 1
    }
}

private struct SheepPosterBoardWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SheepPosterCard: View {
    let sheep: SheepDefinition
    let status: SheepPosterStatus
    let outcome: SheepSearchOutcome?
    let showExactOdds: Bool
    var isNew = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(status == .found ? "HOME" : "STILL SEARCHING")
                    .font(pixelFont(.title3))
                    .tracking(1.2)
                    .foregroundStyle(AppColors.bark)
                Spacer(minLength: AppSpacing.xs)
                if isNew {
                    Text("NEW TRAIL")
                        .font(pixelFont(.caption2))
                        .foregroundStyle(AppColors.berry)
                }
            }

            Text("OLLIE'S TRAIL NOTE")
                .font(pixelFont(.caption2))
                .foregroundStyle(AppColors.bark.opacity(0.8))

            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(AppColors.wool.opacity(0.42))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .stroke(AppColors.bark.opacity(0.72), lineWidth: 2)
                    }
                PixelAssetImage(name: sheep.assetName)
                    .padding(AppSpacing.sm)
                    .frame(maxWidth: .infinity)
                Image(systemName: status == .found ? "checkmark.seal.fill" : "pawprint.fill")
                    .font(.title2.weight(.black))
                    .foregroundStyle(status == .found ? AppColors.success : AppColors.grass)
                    .padding(AppSpacing.sm)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1.25, contentMode: .fit)

            Text(sheep.name)
                .font(pixelFont(.title2))
                .foregroundStyle(AppColors.bark)
                .lineLimit(2)

            HStack(spacing: AppSpacing.xs) {
                posterChip(sheep.breed.title)
                posterChip(sheep.rarity.title)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("TRAIL CLUE")
                    .font(pixelFont(.caption2))
                    .foregroundStyle(AppColors.bark.opacity(0.75))
                Text(sheep.posterClue.replacingOccurrences(of: "Last seen ", with: ""))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.bark)
                if let accessory = sheep.accessory {
                    Text("Mark: " + accessory)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.grass)
                }
                if status == .found {
                    Text(sheep.story)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.bark.opacity(0.82))
                }
            }

            HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(status == .found ? "HOME IN THE FLOCK" : "TRAIL")
                        .font(pixelFont(.caption2))
                        .foregroundStyle(AppColors.bark.opacity(0.75))
                    Text(trailValue)
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(AppColors.bark)
                }
                Spacer(minLength: 0)
                if status == .missing {
                    Text("STILL ON THE TRAIL")
                        .font(pixelFont(.caption2))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(AppColors.grass)
                } else {
                    Text("HOME WITH THE FLOCK")
                        .font(pixelFont(.caption2))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(AppColors.success)
                }
            }

            if status == .found {
                Text("HOME IN THE FLOCK")
                    .font(pixelFont(.caption))
                    .foregroundStyle(AppColors.success)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xxs)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(AppColors.success, lineWidth: 2)
                    }
                    .rotationEffect(.degrees(-4))
            }
        }
        .padding(AppSpacing.md)
        .foregroundStyle(AppColors.bark)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(AppColors.surfaceMuted)
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .stroke(AppColors.bark.opacity(0.72), lineWidth: 2)
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var trailValue: String {
        guard let outcome else {
            return status == .found ? "Home in the flock" : "Waiting for Ollie's next run"
        }
        if status == .found {
            return "Night " + String(outcome.protectedNightNumber) + " · " + distanceLabel(outcome.trailDistance)
        }
        return showExactOdds
            ? String(Int((outcome.encounterOdds * 100).rounded())) + "% chance"
            : strengthLabel(outcome.trailStrength)
    }

    private var accessibilityLabel: String {
        let state = status == .found ? "home" : "still searching"
        return state + " field note for " + sheep.name + ", " + sheep.breed.title + " breed, " + sheep.rarity.title + " rarity. " + sheep.posterClue
    }

    private func posterChip(_ value: String) -> some View {
        Text(value.uppercased())
            .font(pixelFont(.caption2))
            .foregroundStyle(AppColors.bark)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xxs)
            .background(AppColors.wool.opacity(0.72), in: Capsule())
    }

    private func distanceLabel(_ distance: Double) -> String {
        String(format: "%.1f km", distance)
    }

    private func strengthLabel(_ strength: Int) -> String {
        switch strength {
        case 0..<35: return "Faint trail"
        case 35..<60: return "Promising trail"
        case 60..<80: return "Strong trail"
        default: return "Very strong trail"
        }
    }
}

#Preview("Searching field board") {
    SheepPosterCarousel(
        searchState: .empty,
        protectedNightNumber: 1
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Home field note") {
    SheepPosterCard(
        sheep: SheepCatalog.all[0],
        status: .found,
        outcome: SheepSearchOutcome(
            id: UUID(),
            runID: UUID(),
            protectedNightNumber: 3,
            result: .found,
            sheepID: "mabel",
            rarity: .common,
            habitat: .starterPasture,
            trailStrength: 72,
            encounterOdds: 1,
            trailDistance: 4.2,
            consecutiveNoFinds: 0,
            bonusPoints: 2,
            createdAt: Date()
        ),
        showExactOdds: false
    )
    .frame(width: 280)
    .padding()
    .background(AppColors.paper)
}
