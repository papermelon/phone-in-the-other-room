#if DEBUG
import Foundation

enum ScreenbookScenarioKind: String, CaseIterable, Codable {
    case onboardingWelcome = "iphone.onboarding.welcome.default"
    case configuredHome = "iphone.home.configured.default"
    case interactiveHome = "iphone.home.interactive.default"
    case activeWindDown = "iphone.home.active-wind-down.default"
    case activePhoneAway = "iphone.home.active-phone-away.default"
    case slumberPartyNoRound = "iphone.slumber-party.membership-no-round.default"
    case slumberPartyBetweenRounds = "iphone.slumber-party.membership-between-rounds.default"
    case slumberPartySharedHabitsSummary = "iphone.slumber-party.shared-habits-summary.default"
    case slumberPartySharedHabitsConsent = "iphone.slumber-party.shared-habits-consent.default"
    case earlyEnd = "iphone.home.early-end.default"
    case populatedFarm = "iphone.farm.populated.default"
}

struct ScreenbookCopySource: Codable {
    let file: String
    let symbol: String
}

struct ScreenbookCopyRecord: Codable {
    let id: String
    let rendered: String
    let authored: String
    let kind: String
    let source: ScreenbookCopySource
    let status: String
    let parameters: [String: String]

    static func stable(
        _ token: AppCopyToken,
        file: String,
        symbol: String,
        kind: String = "visible"
    ) -> Self {
        Self(
            id: token.id,
            rendered: token.value,
            authored: token.value,
            kind: kind,
            source: ScreenbookCopySource(file: file, symbol: symbol),
            status: "stable",
            parameters: [:]
        )
    }

    static func provisional(
        id: String,
        rendered: String,
        authored: String? = nil,
        file: String,
        symbol: String,
        parameters: [String: String] = [:]
    ) -> Self {
        Self(
            id: id,
            rendered: rendered,
            authored: authored ?? rendered,
            kind: "visible",
            source: ScreenbookCopySource(file: file, symbol: symbol),
            status: "provisional",
            parameters: parameters
        )
    }
}

struct ScreenbookScenario: Codable {
    let id: String
    let title: String
    let description: String
    let surface: String
    let journey: String
    let route: String
    let state: String
    let tags: [String]
    let fixtureVersion: Int
    let captureProfile: String
    let captureProvenance: String
    let dependencies: [String]
    let copy: [ScreenbookCopyRecord]
    let warnings: [String]
}

struct ScreenbookRegistryManifest: Codable {
    let schemaVersion: Int
    let captureProfile: String
    let scenarios: [ScreenbookScenario]
}
#endif
