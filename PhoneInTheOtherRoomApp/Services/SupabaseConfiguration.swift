import Foundation
import OSLog

struct SupabaseConfiguration: Equatable, Sendable {
    enum ConfigurationError: LocalizedError, Equatable {
        case missingURL
        case malformedURL
        case missingPublishableKey
        case nonPublishableKey

        var errorDescription: String? {
            switch self {
            case .missingURL: return "SUPABASE_URL is missing."
            case .malformedURL: return "SUPABASE_URL must be a valid HTTPS URL."
            case .missingPublishableKey: return "SUPABASE_PUBLISHABLE_KEY is missing."
            case .nonPublishableKey: return "Only an sb_publishable_ key may be used by the app."
            }
        }
    }

    let url: URL
    let publishableKey: String
    let liveActivityPushEnabled: Bool
    let feedbackEnabled: Bool
    let nightFlockEnabled: Bool

    static func nightFlockFeatureFlag(bundle: Bundle = .main) -> NightFlockFeatureFlagResolution {
        let value = bundle.object(forInfoDictionaryKey: "SUPABASE_NIGHT_FLOCK_ENABLED")
        if let bool = value as? Bool {
            return bool ? .enabled : .disabled
        }
        return NightFlockFeatureFlagResolution.resolve(rawValue: value as? String)
    }

    static func nightFlockConfigurationIssue(for error: Error) -> NightFlockConfigurationIssue {
        guard let error = error as? ConfigurationError else { return .unavailable }
        switch error {
        case .missingURL: return .missingURL
        case .malformedURL: return .malformedURL
        case .missingPublishableKey: return .missingPublishableKey
        case .nonPublishableKey: return .nonPublishableKey
        }
    }

    static func load(bundle: Bundle = .main) throws -> SupabaseConfiguration {
        guard let rawURL = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !rawURL.isEmpty,
              !rawURL.contains("YOUR_PROJECT_REF") else {
            throw ConfigurationError.missingURL
        }
        guard let url = URL(string: rawURL), url.scheme == "https", url.host != nil else {
            throw ConfigurationError.malformedURL
        }
        guard let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              !key.isEmpty,
              !key.contains("REPLACE_WITH") else {
            throw ConfigurationError.missingPublishableKey
        }
        guard key.hasPrefix("sb_publishable_") else {
            throw ConfigurationError.nonPublishableKey
        }
        let enabledValue = bundle.object(forInfoDictionaryKey: "SUPABASE_LIVE_ACTIVITY_PUSH_ENABLED")
        let enabled = (enabledValue as? Bool) ?? ((enabledValue as? String)?.uppercased() == "YES")
        let feedbackValue = bundle.object(forInfoDictionaryKey: "SUPABASE_FEEDBACK_ENABLED")
        let feedbackEnabled = (feedbackValue as? Bool)
            ?? ((feedbackValue as? String)?.uppercased() == "YES")
        let nightFlockEnabled = nightFlockFeatureFlag(bundle: bundle) == .enabled
        return SupabaseConfiguration(
            url: url,
            publishableKey: key,
            liveActivityPushEnabled: enabled,
            feedbackEnabled: feedbackEnabled,
            nightFlockEnabled: nightFlockEnabled
        )
    }
}

enum SupabaseConfigurationDiagnostics {
    private static let logger = Logger(
        subsystem: "com.ngawangchime.countingsheep",
        category: "SupabaseConfiguration"
    )

    static func report(_ error: Error) {
#if DEBUG
        logger.error("Supabase disabled: \(error.localizedDescription, privacy: .public)")
#endif
    }
}
