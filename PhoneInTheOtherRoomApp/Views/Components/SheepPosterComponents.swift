import SwiftUI

enum SheepPosterStatus: Equatable {
    case missing
    case found
}

enum SheepPosterFilter: String, CaseIterable, Identifiable {
    case missing
    case home
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .missing: return "Missing"
        case .home: return "Home"
        case .all: return "All"
        }
    }
}

struct SheepPosterBoard: View {
    let searchState: SheepSearchState
    let protectedNightNumber: Int

    @State private var filter: SheepPosterFilter = .missing

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Picker("Poster board", selection: $filter) {
                ForEach(SheepPosterFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Sheep poster board filter")

            SheepPosterCarousel(
                searchState: searchState,
                protectedNightNumber: protectedNightNumber,
                filter: filter,
                title: filter == .missing ? "OLLIE'S MISSING SHEEP" : "OLLIE'S POSTER BOARD"
            )
        }
    }
}

struct SheepPosterCarousel: View {
    let searchState: SheepSearchState
    let protectedNightNumber: Int
    var filter: SheepPosterFilter = .missing
    var title = "OLLIE'S MISSING SHEEP"

    private var posters: [SheepDefinition] {
        let eligible = SheepCatalog.eligible(for: max(1, protectedNightNumber))
        switch filter {
        case .missing:
            return eligible.filter { !searchState.foundSheepIDs.contains($0.id) }
        case .home:
            return eligible.filter { searchState.foundSheepIDs.contains($0.id) }
        case .all:
            return eligible
        }
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
                                .frame(width: 300)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollIndicators(.hidden)
                    .contentMargins(.horizontal, 2, for: .scrollContent)
                    .accessibilityLabel("Sheep posters")

                    Text(browseLabel)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    private var footerCount: String {
        switch filter {
        case .missing: return String(posters.count) + " to find"
        case .home: return String(posters.count) + " home"
        case .all: return String(posters.count) + " shown"
        }
    }

    private var browseLabel: String {
        "Swipe to browse " + String(posters.count) + " " + (posters.count == 1 ? "poster" : "posters")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Image(systemName: filter == .home ? "house.fill" : "pawprint.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppColors.grass)
            Text(
                filter == .home
                    ? "Ollie has not brought a sheep home yet."
                    : "The pasture is quiet for now. New posters arrive as Ollie follows more trails."
            )
                .font(AppTypography.body)
            Text("Every completed Wind Down gives the search another night to move forward.")
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

struct SheepPosterCard: View {
    let sheep: SheepDefinition
    let status: SheepPosterStatus
    let outcome: SheepSearchOutcome?
    let showExactOdds: Bool
    var isNew = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(status == .found ? "FOUND" : "MISSING")
                    .font(pixelFont(.title3))
                    .tracking(1.2)
                    .foregroundStyle(AppColors.bark)
                Spacer(minLength: AppSpacing.xs)
                if isNew {
                    Text("NEW POSTER")
                        .font(pixelFont(.caption2))
                        .foregroundStyle(AppColors.berry)
                }
            }

            Text("OLLIE'S NIGHT RUN")
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
                    .frame(maxWidth: .infinity, maxHeight: 190)
                Image(systemName: status == .found ? "checkmark.seal.fill" : "pawprint.fill")
                    .font(.title2.weight(.black))
                    .foregroundStyle(status == .found ? AppColors.success : AppColors.grass)
                    .padding(AppSpacing.sm)
            }
            .frame(height: 190)

            Text(sheep.name)
                .font(pixelFont(.title2))
                .foregroundStyle(AppColors.bark)
                .lineLimit(2)

            HStack(spacing: AppSpacing.xs) {
                posterChip(sheep.breed.title)
                posterChip(sheep.rarity.title)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text("LAST SEEN")
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
                    Text(status == .found ? "RETURNED HOME" : "TRAIL")
                        .font(pixelFont(.caption2))
                        .foregroundStyle(AppColors.bark.opacity(0.75))
                    Text(trailValue)
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(AppColors.bark)
                }
                Spacer(minLength: 0)
                if status == .missing {
                    Text("BRING THEM HOME")
                        .font(pixelFont(.caption2))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(AppColors.grass)
                } else {
                    Text("OLLIE FOUND THEM")
                        .font(pixelFont(.caption2))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(AppColors.success)
                }
            }

            if status == .found {
                Text("FOUND — HOME")
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
        let state = status == .found ? "found and home" : "missing"
        return state + " sheep poster for " + sheep.name + ", " + sheep.breed.title + " breed, " + sheep.rarity.title + " rarity. " + sheep.posterClue
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

#Preview("Missing poster carousel") {
    SheepPosterCarousel(
        searchState: .empty,
        protectedNightNumber: 1
    )
    .padding()
    .background(AppColors.paper)
}

#Preview("Found poster") {
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
    .frame(width: 300)
    .padding()
    .background(AppColors.paper)
}
