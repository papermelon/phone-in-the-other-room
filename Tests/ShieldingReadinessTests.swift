import XCTest

final class ShieldingReadinessTests: XCTestCase {
    func testReadyExplainsSelectedApps() {
        XCTAssertEqual(ShieldingReadiness.ready.title, "App shielding is ready")
        XCTAssertTrue(ShieldingReadiness.ready.detail.contains("quiet windows"))
    }

    func testNoSelectionIsActionable() {
        XCTAssertNotEqual(ShieldingReadiness.noSelection, .ready)
        XCTAssertTrue(ShieldingReadiness.noSelection.detail.contains("at least one"))
    }

    func testDeniedKeepsPhoneAwayFallbackAvailable() {
        XCTAssertTrue(ShieldingReadiness.denied.detail.contains("phone-away"))
    }
}
