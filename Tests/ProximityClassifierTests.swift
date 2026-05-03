import XCTest

final class ProximityClassifierTests: XCTestCase {
    func testSustainedOtherRoomValidatesOnlyAfterRequiredSamples() {
        let classifier = ProximityClassifier()
        let now = Date()
        let readings = [
            ProximityReading(distanceMeters: 8.4, timestamp: now, source: .nearbyInteraction),
            ProximityReading(distanceMeters: 8.7, timestamp: now, source: .nearbyInteraction)
        ]
        let context = ProximityClassifierContext(now: now, watchReachable: true, nearbySupported: true, demoMode: false, currentRunState: .waitingForPhoneAway, plannedEndAt: nil, phoneAwayValidated: false)
        let state = classifier.classify(readings: readings, previous: nil, context: context)
        XCTAssertEqual(state.bucket, .doorway)

        let sustained = readings + [ProximityReading(distanceMeters: 9.1, timestamp: now, source: .nearbyInteraction)]
        let sustainedState = classifier.classify(readings: sustained, previous: state, context: context)
        XCTAssertEqual(sustainedState.bucket, .probablyOtherRoom)
        XCTAssertTrue(classifier.shouldValidatePhoneAway(readings: sustained, state: sustainedState))
    }

    func testOneNoisyCloseReadingDoesNotWarn() {
        let classifier = ProximityClassifier()
        let now = Date()
        let readings = [
            ProximityReading(distanceMeters: 8.8, timestamp: now, source: .nearbyInteraction),
            ProximityReading(distanceMeters: 9.0, timestamp: now, source: .nearbyInteraction),
            ProximityReading(distanceMeters: 1.2, timestamp: now, source: .nearbyInteraction)
        ]
        let state = ProximityState(bucket: .sameRoom, distanceMeters: 1.2, confidence: .medium, source: .nearbyInteraction, lastUpdated: now, statusText: "", detailText: "")
        XCTAssertFalse(classifier.shouldWarnPhoneTooClose(readings: readings, state: state))
    }

    func testDemoModeUsesMediumConfidence() {
        let classifier = ProximityClassifier()
        let now = Date()
        let reading = ProximityReading(distanceMeters: 9.5, timestamp: now, source: .demo)
        let context = ProximityClassifierContext(now: now, watchReachable: false, nearbySupported: false, demoMode: true, currentRunState: .demo, plannedEndAt: nil, phoneAwayValidated: false)
        let state = classifier.classify(readings: [reading], previous: nil, context: context)
        XCTAssertEqual(state.bucket, .demo)
        XCTAssertEqual(state.confidence, .medium)
    }
}
