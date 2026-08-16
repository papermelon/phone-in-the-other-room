import XCTest

final class NightFlockDiagnosticsTests: XCTestCase {
    func testFlagResolutionAcceptsOnlyExplicitYesAndNo() {
        XCTAssertEqual(NightFlockFeatureFlagResolution.resolve(rawValue: "YES"), .enabled)
        XCTAssertEqual(NightFlockFeatureFlagResolution.resolve(rawValue: " no "), .disabled)
        XCTAssertEqual(NightFlockFeatureFlagResolution.resolve(rawValue: "true"), .invalid)
        XCTAssertEqual(NightFlockFeatureFlagResolution.resolve(rawValue: nil), .invalid)
    }

    func testDisabledFlagDoesNotMisdiagnosePlaceholderCredentials() {
        let diagnostics = NightFlockDiagnostics.initial(
            featureFlag: .disabled,
            configuration: .invalid(.missingPublishableKey)
        )

        XCTAssertEqual(diagnostics.featureFlag, .disabled)
        XCTAssertEqual(diagnostics.configuration, .notEvaluated)
        XCTAssertEqual(diagnostics.surface, .unavailable)
    }

    func testInvalidFlagIsSeparatelyDiagnosedAsConfigurationFailure() {
        let diagnostics = NightFlockDiagnostics.initial(
            featureFlag: .invalid,
            configuration: .valid
        )

        XCTAssertEqual(diagnostics.featureFlag, .invalid)
        XCTAssertEqual(diagnostics.configuration, .invalid(.invalidFeatureFlag))
    }

    func testActiveWindDownSuppressesSurfaceWithoutChangingConfiguration() {
        let initial = NightFlockDiagnostics.initial(
            featureFlag: .enabled,
            configuration: .valid,
            accountState: .linked
        )
        let suppressed = initial.resolvingSurface(activeWindDown: true)

        XCTAssertEqual(suppressed.surface, .suppressedForActiveWindDown)
        XCTAssertEqual(suppressed.featureFlag, .enabled)
        XCTAssertEqual(suppressed.configuration, .valid)
        XCTAssertEqual(suppressed.accountState, .linked)
    }

    func testEnabledInvalidConfigurationKeepsSurfaceUnavailable() {
        let diagnostics = NightFlockDiagnostics.initial(
            featureFlag: .enabled,
            configuration: .invalid(.missingURL)
        ).resolvingSurface(activeWindDown: false)

        XCTAssertEqual(diagnostics.surface, .unavailable)
    }

    func testAccountStateUpdateRemainsIndependentFromSurfacePolicy() {
        let diagnostics = NightFlockDiagnostics.initial(
            featureFlag: .enabled,
            configuration: .valid
        ).updatingAccountState(.linked)

        XCTAssertEqual(diagnostics.accountState, .linked)
        XCTAssertEqual(diagnostics.surface, .available)
    }

    func testV2StateKeepsActiveWindDownSuppression() {
        let diagnostics = NightFlockDiagnostics.initial(
            featureFlag: .enabled,
            configuration: .valid,
            accountState: .linked
        )
        XCTAssertEqual(diagnostics.resolvingSurface(activeWindDown: true).surface, .suppressedForActiveWindDown)
    }
}
