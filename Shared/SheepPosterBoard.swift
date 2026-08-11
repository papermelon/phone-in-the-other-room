import Foundation

/// The Trail Board is a presentation of the persisted search history. It
/// deliberately has no progression or economy side effects.
enum SheepPosterFilter: String, CaseIterable, Identifiable {
    case missing
    case home
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .missing: return "Still searching"
        case .home: return "Home"
        case .all: return "All trails"
        }
    }
}

enum SheepPosterSelection {
    static func posters(
        for state: SheepSearchState,
        protectedNightNumber: Int,
        filter: SheepPosterFilter
    ) -> [SheepDefinition] {
        let eligible = SheepCatalog.eligible(for: max(1, protectedNightNumber))
        let foundIDs = Set(state.foundSheepIDs)

        switch filter {
        case .missing:
            return eligible.filter { !foundIDs.contains($0.id) }
        case .home:
            return eligible.filter { foundIDs.contains($0.id) }
        case .all:
            return eligible
        }
    }
}
