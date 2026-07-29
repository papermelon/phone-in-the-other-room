import Foundation

enum OfflinePurposeCategory: String, Codable, CaseIterable, Identifiable {
    case rest
    case read
    case create
    case connect
    case move
    case prepare
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rest: return "Simply rest"
        case .read: return "Read"
        case .create: return "Create something"
        case .connect: return "Be present with people"
        case .move: return "Move gently"
        case .prepare: return "Prepare for tomorrow"
        case .custom: return "Something personal"
        }
    }

    fileprivate var displaySubject: String {
        switch self {
        case .rest: return "rest"
        case .read: return "reading"
        case .create: return "creating something"
        case .connect: return "being present with people"
        case .move: return "gentle movement"
        case .prepare: return "preparing for tomorrow"
        case .custom: return "something that matters to you"
        }
    }
}

struct OfflinePurposeProfile: Codable, Equatable {
    static let maximumCustomTextLength = 80
    static let defaultProfile = OfflinePurposeProfile(category: .rest)

    var category: OfflinePurposeCategory
    private(set) var customText: String?
    var allowsCustomTextInNotifications: Bool

    init(
        category: OfflinePurposeCategory = .rest,
        customText: String? = nil,
        allowsCustomTextInNotifications: Bool = false
    ) {
        self.category = category
        self.customText = Self.normalizedCustomText(customText)
        self.allowsCustomTextInNotifications = allowsCustomTextInNotifications
    }

    var inAppDisplayPhrase: String {
        "Making room for \(displaySubject)"
    }

    var completionPhrase: String {
        "You made room for \(displaySubject)."
    }

    var reminderPhrase: String {
        guard
            allowsCustomTextInNotifications,
            category == .custom,
            let customText
        else {
            return "Make a little room for quiet."
        }

        return "Make a little room for \(customText)."
    }

    private var displaySubject: String {
        if category == .custom, let customText {
            return customText
        }
        return category.displaySubject
    }

    private static func normalizedCustomText(_ text: String?) -> String? {
        guard let text else { return nil }

        let collapsedWhitespace = text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !collapsedWhitespace.isEmpty else { return nil }

        return String(collapsedWhitespace.prefix(maximumCustomTextLength))
    }

    private enum CodingKeys: String, CodingKey {
        case category
        case customText
        case allowsCustomTextInNotifications
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            category: try container.decode(OfflinePurposeCategory.self, forKey: .category),
            customText: try container.decodeIfPresent(String.self, forKey: .customText),
            allowsCustomTextInNotifications: try container.decodeIfPresent(
                Bool.self,
                forKey: .allowsCustomTextInNotifications
            ) ?? false
        )
    }
}
