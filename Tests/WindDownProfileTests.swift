import XCTest

final class WindDownProfileTests: XCTestCase {
    func testAnswersMapDeterministicallyToANonClinicalStartingPoint() {
        XCTAssertEqual(WindDownProfileQuestion.allCases.count, 6)
        let answers = WindDownProfileAnswer(
            bedtimeHour: 22,
            bedtimeMinute: 15,
            wakeHour: 6,
            wakeMinute: 30,
            phoneUsePattern: .beforeBed,
            awayFriction: .hardToStopFeed,
            eveningActivities: [.read, .makeTea],
            morningActivities: [.openCurtains],
            desiredWindDownMinutes: 45
        )

        let first = WindDownProfileMapper.recommendation(for: answers)
        let second = WindDownProfileMapper.recommendation(for: answers)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.kind, .eveningScreens)
        XCTAssertEqual(first.displayName, "Wind Down starting point")
        XCTAssertEqual(first.guidanceIDs, ["phone-bed", "quiet-hour", "bed-as-cue"])
        XCTAssertEqual(first.wearableItemID, "shepherd_moon_coat")
        XCTAssertEqual(first.desiredWindDownMinutes, 45)
        XCTAssertEqual(first.eveningRoutine.map(\.activity), [.read, .makeTea])
        XCTAssertTrue(first.summary.contains("Wind Down starting point"))
        XCTAssertFalse(first.summary.lowercased().contains("insomnia"))
        XCTAssertFalse(first.summary.lowercased().contains("sleep type"))
    }

    func testEachPatternSelectsAFinishedShepherdWearableAndLibraryGuidance() throws {
        let cases: [(WindDownPhoneUsePattern, WindDownProfileKind, String)] = [
            (.beforeBed, .eveningScreens, "shepherd_moon_coat"),
            (.afterWaking, .morningReach, "shepherd_wool_hat"),
            (.bothEdges, .bothEdges, "shepherd_moss_coat"),
            (.irregular, .unevenRhythm, "shepherd_moon_coat")
        ]
        for (pattern, kind, wearableID) in cases {
            var answers = WindDownProfileAnswer.defaults
            answers = WindDownProfileAnswer(
                bedtimeHour: answers.bedtimeHour,
                bedtimeMinute: answers.bedtimeMinute,
                wakeHour: answers.wakeHour,
                wakeMinute: answers.wakeMinute,
                phoneUsePattern: pattern,
                awayFriction: .habitReach,
                eveningActivities: [.journal],
                morningActivities: [.breakfast],
                desiredWindDownMinutes: 30
            )
            let recommendation = WindDownProfileMapper.recommendation(for: answers)
            let item = try XCTUnwrap(FarmShopCatalog.item(for: wearableID))

            XCTAssertEqual(recommendation.kind, kind)
            XCTAssertEqual(recommendation.wearableItemID, wearableID)
            XCTAssertEqual(item.category, .shepherd)
            XCTAssertTrue(WelcomeRewardCatalog.isFinishedShepherdWearable(wearableID))
            XCTAssertFalse(recommendation.guidanceIDs.isEmpty)
            XCTAssertTrue(recommendation.guidanceIDs.allSatisfy { id in
                WindDownGuidanceLibrary.items.contains { $0.id == id }
            })
            XCTAssertTrue(recommendation.eveningRoutine.count <= WindDownRoutineStep.maximumEveningCount)
            XCTAssertTrue(recommendation.morningRoutine.count <= WindDownRoutineStep.maximumMorningCount)
        }
    }

    func testAnswersStayLocalAndOmitSensitiveFields() throws {
        let encoded = try JSONEncoder().encode(WindDownProfileAnswer.defaults)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let forbidden = ["diagnosis", "medication", "insomnia", "score", "freeText", "notes"]

        XCTAssertFalse(object.keys.contains { key in
            forbidden.contains { key.lowercased().contains($0) }
        })
    }

    func testProfileRecordRoundTripsAndClampsWindDownLength() throws {
        let answers = WindDownProfileAnswer(
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            phoneUsePattern: .bothEdges,
            awayFriction: .morningCheck,
            eveningActivities: [.read],
            morningActivities: [.openCurtains],
            desiredWindDownMinutes: 28
        )
        let record = WindDownProfileRecord(
            answers: answers,
            recommendation: WindDownProfileMapper.recommendation(for: answers),
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        let decoded = try JSONDecoder().decode(
            WindDownProfileRecord.self,
            from: JSONEncoder().encode(record)
        )

        XCTAssertEqual(decoded.answers.desiredWindDownMinutes, 30)
        XCTAssertEqual(decoded.schemaVersion, WindDownProfileRecord.currentSchemaVersion)
        XCTAssertEqual(WindDownProfileRecord.storageKey, "ollie.windDown.profile")
    }
}
