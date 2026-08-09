import XCTest

final class ShieldingReadinessTests: XCTestCase {
    func testReadyExplainsSelectedApps() {
        XCTAssertEqual(ShieldingReadiness.ready.title, "Apps to rest are ready")
        XCTAssertTrue(ShieldingReadiness.ready.detail.contains("Wind Down start through morning quiet"))
    }

    func testNoSelectionIsActionable() {
        XCTAssertNotEqual(ShieldingReadiness.noSelection, .ready)
        XCTAssertTrue(ShieldingReadiness.noSelection.detail.contains("at least one"))
    }

    func testDeniedKeepsPhoneAwayFallbackAvailable() {
        XCTAssertTrue(ShieldingReadiness.denied.detail.contains("phone-away"))
    }
}
