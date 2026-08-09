import XCTest

final class FocusRunLiveActivityPushContractTests: XCTestCase {
    func testTerminalPresentationsStayFactualAndDistinct() {
        let completed = FocusRunLiveActivityTerminalStatus.completed.presentation
        let endedEarly = FocusRunLiveActivityTerminalStatus.endedEarly.presentation

        XCTAssertEqual(completed.headline, "QUIET TIME COMPLETE")
        XCTAssertEqual(completed.message, "Ollie kept the quiet. Nice work.")
        XCTAssertEqual(endedEarly.headline, "QUIET TIME ENDED")
        XCTAssertNotEqual(endedEarly, completed)

        for copy in [completed.headline, completed.message, endedEarly.headline, endedEarly.message] {
            let lowercased = copy.lowercased()
            XCTAssertFalse(lowercased.contains("sheep found"))
            XCTAssertFalse(lowercased.contains("found a sheep"))
            XCTAssertFalse(lowercased.contains("reward resolved"))
        }
    }

    func testRunSyncRoundTripsWithoutActivityKitToken() throws {
        let sync = FocusRunCloudSync(
            runID: UUID(),
            installationID: UUID(),
            plannedEndAt: Date(timeIntervalSince1970: 1_800_000_000),
            observedAt: Date(timeIntervalSince1970: 1_799_999_000),
            status: .active,
            runRevision: 1,
            appVersion: "0.1.0",
            idempotencyKey: "run-sync-idempotency"
        )

        let data = try JSONEncoder().encode(sync)
        let decoded = try JSONDecoder().decode(FocusRunCloudSync.self, from: data)

        XCTAssertEqual(decoded, sync)
        XCTAssertEqual(decoded.schemaVersion, FocusRunCloudSync.currentSchemaVersion)
    }

    func testRegistrationRoundTripsWithoutLosingRunAssociation() throws {
        let installationID = UUID()
        let registration = FocusRunLiveActivityPushRegistration(
            runID: UUID(),
            activityID: "activity-1",
            pushToken: "a1b2c3",
            plannedEndAt: Date(timeIntervalSince1970: 1_800_000_000),
            observedAt: Date(timeIntervalSince1970: 1_799_999_000),
            environment: .sandbox,
            installationID: installationID,
            runRevision: 3,
            tokenGeneration: 2,
            idempotencyKey: "registration-idempotency",
            phase: .windDown,
            bedtimeAt: Date(timeIntervalSince1970: 1_800_001_000),
            wakeAt: Date(timeIntervalSince1970: 1_800_029_800),
            morningQuietEndsAt: Date(timeIntervalSince1970: 1_800_031_600),
            eveningActivityTitle: "Read",
            morningActivityTitle: "Open curtains"
        )

        let data = try JSONEncoder().encode(registration)
        let decoded = try JSONDecoder().decode(FocusRunLiveActivityPushRegistration.self, from: data)

        XCTAssertEqual(decoded, registration)
        XCTAssertEqual(decoded.schemaVersion, FocusRunLiveActivityPushRegistration.currentSchemaVersion)
        XCTAssertEqual(decoded.installationID, installationID)
        XCTAssertEqual(decoded.phase, .windDown)
        XCTAssertEqual(decoded.eveningActivityTitle, "Read")
        XCTAssertEqual(decoded.morningActivityTitle, "Open curtains")
    }

    func testCancellationRoundTripsWithIdempotencyIdentity() throws {
        let cancellation = FocusRunLiveActivityCancellation(
            runID: UUID(),
            activityID: "activity-2",
            reason: .endedEarly,
            occurredAt: Date(timeIntervalSince1970: 1_800_000_100),
            installationID: UUID(),
            runRevision: 4,
            idempotencyKey: "cancellation-idempotency"
        )

        let data = try JSONEncoder().encode(cancellation)
        let decoded = try JSONDecoder().decode(FocusRunLiveActivityCancellation.self, from: data)

        XCTAssertEqual(decoded, cancellation)
    }

    func testVersionOneRegistrationStillDecodes() throws {
        let runID = UUID()
        let json = """
        {
          "schemaVersion": 1,
          "runID": "\(runID.uuidString)",
          "activityID": "legacy-activity",
          "pushToken": "a1b2c3",
          "plannedEndAt": 821692800,
          "observedAt": 821691800,
          "environment": "sandbox"
        }
        """

        let decoded = try JSONDecoder().decode(
            FocusRunLiveActivityPushRegistration.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(decoded.runID, runID)
        XCTAssertNil(decoded.installationID)
        XCTAssertNil(decoded.idempotencyKey)
    }

#if canImport(ActivityKit)
    func testLegacyContentStateStillDecodesWithoutTerminalStatus() throws {
        let json = """
        {
          "plannedEndAt": 800000000,
          "isComplete": false,
          "phase": "windDown",
          "bedtimeAt": 800000100,
          "wakeAt": 800028900,
          "morningQuietEndsAt": 800030700,
          "eveningActivityTitle": "Read",
          "morningActivityTitle": "Open curtains"
        }
        """

        let decoded = try JSONDecoder().decode(
            FocusRunLiveActivityAttributes.ContentState.self,
            from: Data(json.utf8)
        )

        XCTAssertFalse(decoded.isComplete)
        XCTAssertEqual(decoded.phase, .windDown)
        XCTAssertNil(decoded.terminalStatus)
    }
#endif
}
