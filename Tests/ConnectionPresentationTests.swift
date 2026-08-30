import XCTest

final class ConnectionPresentationTests: XCTestCase {
    private let now = Date(timeIntervalSinceReferenceDate: 123_456)

    func testRequestedWithReadableDataIsAvailable() {
        XCTAssertEqual(
            HealthSleepConnectionPresentation.resolve(
                HealthSleepConnectionObservation(
                    isAvailable: true,
                    localRequestState: .requested,
                    latestSampleDate: now.addingTimeInterval(-86_400),
                    lastCheckedAt: now
                )
            ),
            .dataAvailable(
                sampleDate: now.addingTimeInterval(-86_400),
                checkedAt: now
            )
        )
    }

    func testNoRequestWithoutObservedDataOffersConnect() {
        XCTAssertEqual(
            HealthSleepConnectionPresentation.resolve(
                HealthSleepConnectionObservation(
                    isAvailable: true,
                    localRequestState: .notRequested
                )
            ),
            .connect
        )
    }

    func testOldDataWithErrorStaysDatedAndStale() {
        XCTAssertEqual(
            HealthSleepConnectionPresentation.resolve(
                HealthSleepConnectionObservation(
                    isAvailable: true,
                    localRequestState: .requested,
                    latestSampleDate: now.addingTimeInterval(-172_800),
                    lastCheckedAt: now.addingTimeInterval(-60),
                    lastQueryError: "HealthKit was unavailable"
                )
            ),
            .staleData(
                sampleDate: now.addingTimeInterval(-172_800),
                checkedAt: now.addingTimeInterval(-60),
                error: "HealthKit was unavailable"
            )
        )
    }

    func testEmptyCompletedQueryIsNotDenied() {
        XCTAssertEqual(
            HealthSleepConnectionPresentation.resolve(
                HealthSleepConnectionObservation(
                    isAvailable: true,
                    localRequestState: .requested,
                    lastCheckedAt: now
                )
            ),
            .noData(checkedAt: now)
        )
    }

    func testUnavailableAndLoadingStates() {
        XCTAssertEqual(
            HealthSleepConnectionPresentation.resolve(
                HealthSleepConnectionObservation(
                    isAvailable: false,
                    localRequestState: .notRequested
                )
            ),
            .unavailable
        )
        XCTAssertEqual(
            HealthSleepConnectionPresentation.resolve(
                HealthSleepConnectionObservation(
                    isAvailable: true,
                    localRequestState: .requested,
                    isQueryInFlight: true,
                    latestSampleDate: now
                )
            ),
            .checking(cachedSampleDate: now)
        )
    }

    func testOnlyCurrentRefreshGenerationMayUpdatePresentation() {
        XCTAssertFalse(
            HealthSleepConnectionPresentation.acceptsCompletion(
                generation: 2,
                currentGeneration: 3
            )
        )
        XCTAssertTrue(
            HealthSleepConnectionPresentation.acceptsCompletion(
                generation: 3,
                currentGeneration: 3
            )
        )
    }

    func testScreenTimePresentationDoesNotClaimShielding() {
        XCTAssertEqual(
            ScreenTimeConnectionPresentation.resolve(
                authorization: .notDetermined,
                selectionSummary: nil
            ),
            .connect
        )
        XCTAssertEqual(
            ScreenTimeConnectionPresentation.resolve(
                authorization: .denied,
                selectionSummary: nil
            ),
            .needsAttention
        )
        XCTAssertEqual(
            ScreenTimeConnectionPresentation.resolve(
                authorization: .approved,
                selectionSummary: nil
            ),
            .chooseSelection
        )
        XCTAssertEqual(
            ScreenTimeConnectionPresentation.resolve(
                authorization: .approved,
                selectionSummary: "2 apps, 1 category"
            ),
            .configured(selectionSummary: "2 apps, 1 category")
        )
    }
}
