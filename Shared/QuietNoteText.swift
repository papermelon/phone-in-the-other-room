import Foundation

/// Normalizes the short note that a person deliberately places on their Lock Screen.
/// The limit keeps the accessory-rectangular widget readable without changing the
/// person's private Wind Down purpose or storing another copy of it.
enum QuietNoteText {
    static let defaultText = "Put your phone to bed. Wake up before it does."
    static let maximumLength = 80

    static func normalized(_ rawText: String?) -> String {
        guard let rawText else { return defaultText }

        let collapsed = rawText
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return defaultText }

        return String(collapsed.prefix(maximumLength))
    }
}
