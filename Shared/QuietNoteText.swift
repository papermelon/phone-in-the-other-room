import Foundation

/// Normalizes the short note that a person deliberately places on their Lock Screen.
/// The limit keeps the accessory-rectangular widget readable without changing the
/// person's private Wind Down purpose. The explicit widget note is shared only
/// through the existing App Group so the app editor and extension stay in sync.
enum QuietNoteText {
    static let defaultText = "Put your phone to bed. Wake up before it does."
    static let maximumLength = 80
    static let storageKey = "ollie.quietNote.text"
    static let widgetKind = "com.ngawangchime.countingsheep.quiet-note"
    static let editorURL = URL(string: "countingsheep://quiet-note") ?? URL(fileURLWithPath: "/")

    static func normalized(_ rawText: String?) -> String {
        guard let rawText else { return defaultText }

        let collapsed = rawText
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return defaultText }

        return String(collapsed.prefix(maximumLength))
    }

    static var savedText: String? {
        savedText(from: UserDefaults(suiteName: ScreenTimeSharedStorage.appGroupIdentifier))
    }

    static func savedText(from defaults: UserDefaults?) -> String? {
        guard let value = defaults?.string(forKey: storageKey) else { return nil }
        return normalized(value)
    }

    @discardableResult
    static func save(_ rawText: String, to defaults: UserDefaults? = UserDefaults(suiteName: ScreenTimeSharedStorage.appGroupIdentifier)) -> String {
        let value = normalized(rawText)
        defaults?.set(value, forKey: storageKey)
        return value
    }

    static func isEditorURL(_ url: URL) -> Bool {
        url.scheme == editorURL.scheme && url.host == editorURL.host
    }
}
