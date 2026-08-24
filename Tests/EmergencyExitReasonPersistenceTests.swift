import XCTest

final class EmergencyExitReasonPersistenceTests: XCTestCase {
    func testReasonUsesAnIPhoneLocalOllieKeyByRunWithoutChangingSharedRunShape() {
        let runID = UUID()
        XCTAssertEqual(
            EmergencyExitReasonStorage.key(for: runID),
            "ollie.emergencyExit.reason.\(runID.uuidString)"
        )
    }
}
