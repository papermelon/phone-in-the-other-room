import XCTest

final class WindDownStartSourcePolicyTests: XCTestCase {
    func testEligibleOneTimeSourceIsRetainedThroughPreflight() {
        let oneTimeID = UUID()
        let period = WindDownSchedulePeriod(
            occurrence: WindDownOccurrence(
                id: oneTimeID,
                routineID: oneTimeID,
                role: .primarySleepBookend,
                interval: DateInterval(
                    start: Date(timeIntervalSince1970: 1_000),
                    end: Date(timeIntervalSince1970: 4_000)
                )
            ),
            title: "Tonight's Wind Down",
            recurring: false
        )

        XCTAssertEqual(
            WindDownStartSourcePolicy.sourceID(explicitSourceID: nil, eligible: period),
            oneTimeID
        )
        XCTAssertEqual(
            WindDownStartSourcePolicy.sourceID(explicitSourceID: oneTimeID, eligible: period),
            oneTimeID
        )
    }

    func testTransientManualStartHasNoSavedSourceToConsume() {
        XCTAssertNil(WindDownStartSourcePolicy.sourceID(explicitSourceID: nil, eligible: nil))
    }
}
