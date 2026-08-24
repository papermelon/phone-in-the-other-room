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
            detail: "When Wind Down reaches 420 eligible phone-away minutes, Ollie gets one separate look. Screen-Free Morning does not change that result."
        ),
        Source(
            id: .sunrise,
            title: "Sunrise Trail",
            detail: "Every 100 actual eligible Screen-Free Morning minutes gives 1 wool and one independent look."
        ),
        Source(
            id: .phoneBreak,
            title: "Phone Away",
            detail: "Every separate 100 completed Phone Away minutes gives Ollie another independent look."
        )
    ]

    static let rulesTitle = "How Ollie’s searches work"
    static let rulesDetail = "Sunrise Trail and Phone Away keep their own counters. Their first three looks each bring a missing sheep home. After that, each track uses its own 20%, 30%, 40%, then 50% ladder; four clues in a row make that track’s next look a homecoming. Wind Down stays separate."
}
