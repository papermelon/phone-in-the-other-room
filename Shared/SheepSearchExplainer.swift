import Foundation

/// Release-facing explanation of the three independent ways Ollie searches.
/// It deliberately describes eligible elapsed time, not sleep or continuous
/// physical placement.
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
            detail: "Every seven hours of Wind Down timer credit opens a search, including overnight time. Shorter sessions carry forward; brief access is excluded. The first three searches bring a sheep home; later searches keep their own chance and clue protection."
        ),
        Source(
            id: .sunrise,
            title: "Screen-Free Morning",
            detail: "Each 100 eligible elapsed minutes gives 1 wool and one separate search. The first three bring a sheep home; later searches follow 20%, 30%, 40%, then 50%, with the next search guaranteed after four clues."
        ),
        Source(
            id: .phoneBreak,
            title: "Phone Away",
            detail: "Every 100 minutes of Phone Away credit opens a separate search. Shorter sessions carry forward, including early finishes; brief access is excluded. The first three bring a sheep home; later searches follow 20%, 30%, 40%, then 50%, with the next search guaranteed after four clues."
        )
    ]

    static let rulesTitle = "Three ways Ollie searches"
    static let rulesDetail = "Wind Down, Screen-Free Morning, and Phone Away keep separate records, guarantees, chances, and clue counts. Favouring a missing sheep changes which sheep Ollie is more likely to bring home after a successful find; it does not make a find more likely."
}
