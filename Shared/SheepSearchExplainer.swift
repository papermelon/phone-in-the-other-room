import Foundation

/// Release-facing explanation of the three independent ways Ollie can make a
/// note. It deliberately describes phone-away time, not sleep or private
/// Screen-Free Morning details.
enum SheepSearchExplainerPresentation {
    struct Source: Equatable, Identifiable {
        let id: SheepSearchOrigin
        let title: String
        let detail: String
    }

    static let sources: [Source] = [
        Source(
            id: .windDown,
            title: "Wind Down",
            detail: "A completed Wind Down with at least 420 eligible phone-away minutes gives Ollie one look. Screen-Free Morning does not change it."
        ),
        Source(
            id: .sunrise,
            title: "Screen-Free Morning",
            detail: "Each 100 eligible Screen-Free Morning minutes gives 1 wool and one separate look."
        ),
        Source(
            id: .phoneBreak,
            title: "Phone Away",
            detail: "Every separate 100 completed Phone Away minutes gives Ollie another independent look."
        )
    ]

    static let rulesTitle = "How Ollie’s searches work"
    static let rulesDetail = "Screen-Free Morning and Phone Away keep separate counters. Their first three looks each bring a missing sheep home. After that, each source uses its own 20%, 30%, 40%, then 50% chance; four clues in a row make that source’s next look a homecoming. Wind Down stays separate."
}
