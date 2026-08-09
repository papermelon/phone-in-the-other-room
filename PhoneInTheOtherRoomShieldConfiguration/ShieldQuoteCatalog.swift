import Foundation

struct ShieldQuote: Equatable {
    enum Theme: String {
        case rest
        case technology
        case attention
        case presence
        case habits
        case time
        case stillness
    }

    let id: String
    let quote: String
    let author: String
    let source: String
    let theme: Theme
}
enum ShieldQuoteCatalog {
    // These short excerpts were checked against the named primary or
    // author-authorized source. Keep the catalogue finite and local.
    static let entries: [ShieldQuote] = [
        ShieldQuote(
            id: "thoreau-deliberately",
            quote: "I went to the woods because I wished to live deliberately.",
            author: "Henry David Thoreau",
            source: "Walden",
            theme: .presence
        ),
        ShieldQuote(
            id: "emerson-pace",
            quote: "Adopt the pace of Nature: her secret is patience.",
            author: "Ralph Waldo Emerson",
            source: "Education",
            theme: .rest
        ),
        ShieldQuote(
            id: "wordsworth-calm",
            quote: "Ne’er saw I, never felt, a calm so deep!",
            author: "William Wordsworth",
            source: "Composed upon Westminster Bridge",
            theme: .stillness
        ),
        ShieldQuote(
            id: "housman-be-still",
            quote: "Be still, my soul, be still.",
            author: "A. E. Housman",
            source: "Be Still, My Soul, Be Still",
            theme: .stillness
        ),
        ShieldQuote(
            id: "johnson-silence",
            quote: "Here bathe your soul in silence.",
            author: "James Weldon Johnson",
            source: "Deep in the Quiet Wood",
            theme: .rest
        ),
        ShieldQuote(
            id: "berry-still-water",
            quote: "I come into the presence of still water.",
            author: "Wendell Berry",
            source: "The Peace of Wild Things",
            theme: .rest
        ),
        ShieldQuote(
            id: "odell-interiority",
            quote: "I think interiority is really underrated right now.",
            author: "Jenny Odell",
            source: "The Guardian interview",
            theme: .attention
        ),
        ShieldQuote(
            id: "turkle-solitude",
            quote: "One start toward reclaiming conversation is to reclaim solitude.",
            author: "Sherry Turkle",
            source: "Reclaiming Conversation",
            theme: .technology
        ),
        ShieldQuote(
            id: "clear-designer",
            quote: "Be the designer of your world and not merely the consumer of it.",
            author: "James Clear",
            source: "Atomic Habits",
            theme: .habits
        ),
        ShieldQuote(
            id: "newport-good-life",
            quote: "The key is building a good life.",
            author: "Cal Newport",
            source: "Approach Technology Like the Amish",
            theme: .technology
        ),
        ShieldQuote(
            id: "burkeman-time",
            quote: "You don’t need to fight time.",
            author: "Oliver Burkeman",
            source: "You Don’t Need to Fight Time",
            theme: .time
        ),
        ShieldQuote(
            id: "roethke-waking",
            quote: "I wake to sleep, and take my waking slow.",
            author: "Theodore Roethke",
            source: "The Waking",
            theme: .rest
        )
    ]

    static func quote(for date: Date, calendar: Calendar = .current) -> ShieldQuote {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return entries[index(forDayOrdinal: day, count: entries.count)]
    }

    static func index(forDayOrdinal day: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let remainder = (day * 5 + 3) % count
        return remainder >= 0 ? remainder : remainder + count
    }
}
