import Foundation

enum AppAppearancePreference: String, Codable, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    static let key = "ollie.appearance.preference"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var detail: String {
        switch self {
        case .automatic:
            return "Follow iPhone appearance, with dark mode during a ready or active Wind Down."
        case .light:
            return "Keep Counting Sheep light, including during Wind Down."
        case .dark:
            return "Keep Counting Sheep dark, including onboarding and Wind Down."
        }
    }

    /// Explicit appearance choices behave like two independent switches: tapping
    /// the active choice returns to the system preference, while tapping the other
    /// choice selects it.
    static func selection(afterTapping tapped: Self, from current: Self) -> Self {
        switch tapped {
        case .automatic:
            return .automatic
        case .light, .dark:
            return current == tapped ? .automatic : tapped
        }
    }

    func resolution(isWindDownReadyOrActive: Bool) -> AppAppearanceResolution {
        switch self {
        case .automatic:
            return isWindDownReadyOrActive ? .dark : .system
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum AppAppearanceResolution: Equatable {
    case system
    case light
    case dark
}
