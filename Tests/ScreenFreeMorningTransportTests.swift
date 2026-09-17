import XCTest

final class ScreenFreeMorningTransportTests: XCTestCase {
    func testLegacyWatchMessageDecodesWithoutMorningProjection() throws {
        let message = WatchMessage(type: .focusRunStateUpdate)
        guard var object = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(message)
        ) as? [String: Any] else {
            return XCTFail("Expected a Watch message object")
        }
        object.removeValue(forKey: "screenFreeMorning")
        let decoded = try JSONDecoder().decode(
            WatchMessage.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertNil(decoded.screenFreeMorning)
    }

    func testMorningWatchProjectionCarriesTimeAndStatusOnly() {
        let now = Date(timeIntervalSince1970: 3_000)
        let occurrence = MorningQuietOccurrence(
            scheduledStart: now,
            scheduledEnd: now.addingTimeInterval(30 * 60),
            actualStart: now,
            outcome: .active
        )
        let message = WatchMessage(
            type: .focusRunStateUpdate,
            screenFreeMorning: ScreenFreeMorningPresentation(occurrence: occurrence, at: now.addingTimeInterval(60))
        )
        XCTAssertEqual(message.screenFreeMorning?.status, .active)
        XCTAssertEqual(message.screenFreeMorning?.endsAt, occurrence.scheduledEnd)
        XCTAssertNil(message.reward)
    }

    func testLegacyWatchPlacementPayloadNormalizesToTimerBeforePresentation() {
        let startedAt = Date(timeIntervalSince1970: 4_000)
        let legacyRun = FocusRun(
            plannedDurationSeconds: 30 * 60,
            startedAt: startedAt,
            state: .waitingForPhoneAway,
            guardKind: .watchPlacement
        )
        let message = WatchMessage(
            type: .startFocusRun,
            run: legacyRun,
            tokenData: Data([1, 2, 3])
        )

        let normalized = message.normalizedForCurrentRelease

        XCTAssertEqual(normalized.run?.guardKind, .honorTimer)
        XCTAssertEqual(normalized.run?.placementStatus, .notRequired)
        XCTAssertEqual(normalized.run?.phoneAwayValidatedAt, startedAt)
        XCTAssertEqual(normalized.run?.state, .running)
        XCTAssertFalse(normalized.isRetiredNearbyInteractionMessage)
    }

    func testPhoneAndWatchRoutingRejectDecodedNearbyInteractionMessageKinds() {
        let retiredTypes: [WatchMessageType] = [
            .nearbyDiscoveryToken,
            .nearbyDiscoveryTokenAcknowledged,
            .distanceCheckRequest,
            .distanceCheckEnded,
            .watchDistanceReading,
            .proximityStateUpdate,
            .calibrationUpdate
        ]

        for type in retiredTypes {
            let message = WatchMessage(type: type)
            XCTAssertTrue(
                message.isRetiredNearbyInteractionMessage,
                "Expected \(type.rawValue) to remain decode-only"
            )
            XCTAssertNil(
                message.routedForCurrentRelease,
                "Expected phone and Watch routing to reject \(type.rawValue)"
            )
        }
    }

    func testCurrentReleaseRoutingNormalizesLegacyRunBeforeDelivery() throws {
        let startedAt = Date(timeIntervalSince1970: 5_000)
        let legacyRun = FocusRun(
            plannedDurationSeconds: 30 * 60,
            startedAt: startedAt,
            state: .waitingForPhoneAway,
            guardKind: .watchPlacement
        )

        let routed = try XCTUnwrap(
            WatchMessage(type: .startFocusRun, run: legacyRun).routedForCurrentRelease
        )

        XCTAssertEqual(routed.run?.guardKind, .honorTimer)
        XCTAssertEqual(routed.run?.state, .running)
    }
}
