import Foundation

/// Fail-closed Slumber Party configuration facts safe to show in the internal QA lane.
enum NightFlockFeatureFlagResolution: Equatable, Sendable {
    case enabled
    case disabled
    case invalid

    static func resolve(rawValue: String?) -> NightFlockFeatureFlagResolution {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "YES": return .enabled
        case "NO": return .disabled
        default: return .invalid
        }
    }
}

enum NightFlockConfigurationIssue: Equatable, Sendable {
    case invalidFeatureFlag
    case missingURL
    case malformedURL
    case missingPublishableKey
    case nonPublishableKey
    case unavailable
}

enum NightFlockConfigurationReadiness: Equatable, Sendable {
    case notEvaluated
    case valid
    case invalid(NightFlockConfigurationIssue)
}

enum NightFlockSurfaceState: Equatable, Sendable {
    case unavailable
    case available
    case suppressedForActiveWindDown
}

struct NightFlockDiagnostics: Equatable, Sendable {
    let featureFlag: NightFlockFeatureFlagResolution
    let configuration: NightFlockConfigurationReadiness
    let surface: NightFlockSurfaceState
    let accountState: NightFlockAccountState

    static func initial(
        featureFlag: NightFlockFeatureFlagResolution,
        configuration: NightFlockConfigurationReadiness,
        accountState: NightFlockAccountState = .anonymous
    ) -> NightFlockDiagnostics {
        let resolvedConfiguration: NightFlockConfigurationReadiness
        switch featureFlag {
        case .enabled:
            resolvedConfiguration = configuration
        case .disabled:
            resolvedConfiguration = .notEvaluated
        case .invalid:
            resolvedConfiguration = .invalid(.invalidFeatureFlag)
        }
        let surface: NightFlockSurfaceState = featureFlag == .enabled && resolvedConfiguration == .valid
            ? .available
            : .unavailable
        return NightFlockDiagnostics(
            featureFlag: featureFlag,
            configuration: resolvedConfiguration,
            surface: surface,
            accountState: accountState
        )
    }

    func resolvingSurface(activeWindDown: Bool) -> NightFlockDiagnostics {
        let surface: NightFlockSurfaceState
        if featureFlag == .enabled, configuration == .valid {
            surface = activeWindDown ? .suppressedForActiveWindDown : .available
        } else {
            surface = .unavailable
        }
        return NightFlockDiagnostics(
            featureFlag: featureFlag,
            configuration: configuration,
            surface: surface,
            accountState: accountState
        )
    }

    func updatingAccountState(_ accountState: NightFlockAccountState) -> NightFlockDiagnostics {
        NightFlockDiagnostics(
            featureFlag: featureFlag,
            configuration: configuration,
            surface: surface,
            accountState: accountState
        )
    }
}
