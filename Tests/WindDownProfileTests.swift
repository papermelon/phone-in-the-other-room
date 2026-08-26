import XCTest

final class WindDownProfileTests: XCTestCase {
    func testRefinedQuestionCopyPreservesCategoricalMeaning() {
        XCTAssertEqual(
            WindDownProfileQuestion.morningChecking.title,
            "After waking, when do you usually first check your phone?"
        )
        XCTAssertEqual(
            WindDownMorningCheck.allCases.map(\.title),
            ["Within 5 minutes", "Within 15 minutes", "Within 30 minutes", "Later than that"]
        )
        XCTAssertEqual(
            WindDownOvernightLocation.allCases.map(\.title),
            ["In bed with me", "Within arm’s reach", "Elsewhere in my room", "Outside my room"]
        )
        XCTAssertEqual(
            WindDownAwayFriction.questionnaireChoices.map(\.title),
            [
                "I reach for it without thinking",
                "There’s always one more thing to watch or read",
                "Messages or notifications pull me back",
                "I’m not ready to end the day yet",
                "My schedule changes too much for a routine",
                "Something else"
            ]
        )
        XCTAssertEqual(
            WindDownDesiredChange.questionnaireChoices.map(\.title),
            [
                "I stop scrolling earlier",
                "My phone stops coming to bed with me",
                "I wake without checking it immediately",
                "I feel more in control of when I’m online",
                "All of these, really"
            ]
        )
    }

    func testAnswersMapDeterministicallyToANonClinicalStartingPoint() {
        XCTAssertEqual(
            CountingSheepOnboarding.profileQuestions,
            [.bedtimeDelay, .automaticReaching, .morningChecking, .overnightLocation, .awayFriction, .desiredChange]
        )
        let answers = WindDownProfileAnswer(
            bedtimeHour: 22,
            bedtimeMinute: 15,
            wakeHour: 6,
            wakeMinute: 30,
            phoneUsePattern: .beforeBed,
            awayFriction: .hardToStopFeed,
            eveningActivities: [.read, .makeTea],
            morningActivities: [.openCurtains],
            desiredWindDownMinutes: 45,
            bedtimeDelay: .mostNights,
            mainFriction: .hardToStopFeed
        )

        let first = WindDownProfileMapper.recommendation(for: answers)
        let second = WindDownProfileMapper.recommendation(for: answers)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.kind, .oneMoreThing)
        XCTAssertEqual(first.displayName, "Wind Down starting point")
        XCTAssertEqual(first.guidanceIDs, ["phone-bed", "quiet-hour", "bed-as-cue"])
        XCTAssertEqual(first.wearableItemID, WelcomeRewardCatalog.finishedShepherdWearableIDs[0])
        XCTAssertEqual(first.desiredWindDownMinutes, 45)
        XCTAssertEqual(first.eveningRoutine.map(\.activity), [.read, .makeTea])
        XCTAssertFalse(first.noticed.isEmpty)
        XCTAssertFalse(first.summary.lowercased().contains("insomnia"))
        XCTAssertFalse(first.summary.lowercased().contains("sleep type"))
    }

    func testMissingAnswersNeverBecomeBehavioralClaims() throws {
        var answers = WindDownProfileAnswer.defaults
        XCTAssertEqual(WindDownProfileMapper.kind(for: answers), .gentleBeginning)
        answers.phoneUsePattern = .bothEdges
        answers.awayFriction = .hardToStopFeed
        XCTAssertEqual(WindDownProfileMapper.kind(for: answers), .gentleBeginning)

        let encoded = try JSONEncoder().encode(answers)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        for key in ["bedtimeDelay", "automaticReaching", "morningChecking", "overnightLocation", "mainFriction", "desiredChange"] {
            XCTAssertNil(object[key], key)
        }
    }

    func testEveryPrimaryPatternRequiresExplicitSupportingEvidence() throws {
        let cases: [(WindDownProfileKind, (inout WindDownProfileAnswer) -> Void)] = [
            (.automaticReach, { $0.automaticReaching = .almostAutomatically }),
            (.oneMoreThing, { $0.bedtimeDelay = .mostNights }),
            (.messagePull, { $0.mainFriction = .messages }),
            (.variableNights, { $0.mainFriction = .irregularDays }),
            (.morningMagnet, { $0.morningChecking = .immediately }),
            (.bedsideDefault, { $0.overnightLocation = .inBed }),
            (.gentleBeginning, { $0.mainFriction = .noDifficulty })
        ]
        for (kind, configure) in cases {
            var answers = WindDownProfileAnswer.defaults
            configure(&answers)
            let recommendation = WindDownProfileMapper.recommendation(for: answers)

            XCTAssertEqual(recommendation.kind, kind)
            XCTAssertFalse(recommendation.guidanceIDs.isEmpty)
            XCTAssertTrue(recommendation.guidanceIDs.allSatisfy { id in
                WindDownGuidanceLibrary.items.contains { $0.id == id }
            })
            XCTAssertTrue(recommendation.eveningRoutine.count <= WindDownRoutineStep.maximumEveningCount)
            XCTAssertTrue(recommendation.morningRoutine.count <= WindDownRoutineStep.maximumMorningCount)
        }
    }

    func testIndependentEvidenceCanSupportASecondaryPattern() {
        var answers = WindDownProfileAnswer.defaults
        answers.mainFriction = .irregularDays
        answers.overnightLocation = .inBed

        let recommendation = WindDownProfileMapper.recommendation(for: answers)

        XCTAssertEqual(recommendation.kind, .variableNights)
        XCTAssertEqual(recommendation.secondaryKind, .bedsideDefault)
        XCTAssertEqual(recommendation.noticed.count, 2)
        XCTAssertEqual(
            recommendation.summary,
            "Your evenings don’t always follow the same clock, and your phone tends to stay close when it’s time to sleep."
        )
        XCTAssertEqual(
            recommendation.suggestedStrategy,
            "Start with one familiar cue. Even when bedtime moves around, keep one small phone-away moment consistent."
        )
        XCTAssertEqual(
            recommendation.noticed,
            [
                "Your schedule changes from night to night.",
                "Your phone usually spends the night nearby."
            ]
        )
    }

    func testTieBreakingIsDeterministicAndMainFrictionCanChooseTheWinner() {
        var tied = WindDownProfileAnswer.defaults
        tied.automaticReaching = .almostAutomatically
        tied.bedtimeDelay = .mostNights
        XCTAssertEqual(WindDownProfileMapper.kind(for: tied), .automaticReach)

        tied.mainFriction = .hardToStopFeed
        XCTAssertEqual(WindDownProfileMapper.kind(for: tied), .oneMoreThing)
        XCTAssertEqual(
            WindDownProfileMapper.recommendation(for: tied),
            WindDownProfileMapper.recommendation(for: tied)
        )
    }

    func testDesiredChangeNeverInventsAnUnsupportedProblem() {
        var answers = WindDownProfileAnswer.defaults
        answers.desiredChange = .reduceMessagePull

        XCTAssertEqual(WindDownProfileMapper.kind(for: answers), .gentleBeginning)
        XCTAssertNil(WindDownProfileMapper.recommendation(for: answers).secondaryKind)

        answers.desiredChange = .allOfThese
        XCTAssertEqual(WindDownProfileMapper.kind(for: answers), .gentleBeginning)
        XCTAssertNil(WindDownProfileMapper.recommendation(for: answers).secondaryKind)
    }

    func testSomethingElseDoesNotInventAProblem() {
        var answers = WindDownProfileAnswer.defaults
        answers.mainFriction = .somethingElse

        XCTAssertEqual(WindDownProfileMapper.kind(for: answers), .gentleBeginning)
        XCTAssertNil(WindDownProfileMapper.recommendation(for: answers).secondaryKind)
    }

    func testRefinedMorningAndLocationLabelsRetainDeterministicWeights() {
        var morning = WindDownProfileAnswer.defaults
        morning.morningChecking = .firstFewMinutes
        XCTAssertEqual(WindDownProfileMapper.kind(for: morning), .morningMagnet)

        var bedside = WindDownProfileAnswer.defaults
        bedside.overnightLocation = .elsewhereInBedroom
        XCTAssertEqual(WindDownProfileMapper.kind(for: bedside), .bedsideDefault)

        var laterAndOutside = WindDownProfileAnswer.defaults
        laterAndOutside.morningChecking = .afterMorningActivity
        laterAndOutside.overnightLocation = .anotherRoom
        XCTAssertEqual(WindDownProfileMapper.kind(for: laterAndOutside), .gentleBeginning)
    }

    func testCosmeticsAreIndependentOfEveryBehavioralPattern() {
        var reaching = WindDownProfileAnswer.defaults
        reaching.automaticReaching = .often
        var messages = WindDownProfileAnswer.defaults
        messages.mainFriction = .messages

        XCTAssertNotEqual(WindDownProfileMapper.kind(for: reaching), WindDownProfileMapper.kind(for: messages))
        XCTAssertEqual(
            WindDownProfileMapper.recommendation(for: reaching).wearableItemID,
            WindDownProfileMapper.recommendation(for: messages).wearableItemID
        )
    }

    func testAnswersStayLocalAndOmitSensitiveFields() throws {
        let encoded = try JSONEncoder().encode(WindDownProfileAnswer.defaults)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let forbidden = ["diagnosis", "medication", "insomnia", "score", "freeText", "notes"]

        XCTAssertFalse(object.keys.contains { key in
            forbidden.contains { key.lowercased().contains($0) }
        })
    }

    func testLegacyAnswersDecodeWithoutInferringExplicitBehavioralFields() throws {
        let legacy = Data(#"{"bedtimeHour":22,"bedtimeMinute":15,"wakeHour":6,"wakeMinute":30,"phoneUsePattern":"beforeBed","awayFriction":"habitReach","eveningActivities":["read"],"morningActivities":["openCurtains"],"desiredWindDownMinutes":30}"#.utf8)

        let answers = try JSONDecoder().decode(WindDownProfileAnswer.self, from: legacy)

        XCTAssertEqual(answers.phoneUsePattern, .beforeBed)
        XCTAssertEqual(answers.awayFriction, .habitReach)
        XCTAssertNil(answers.bedtimeDelay)
        XCTAssertNil(answers.mainFriction)
        XCTAssertEqual(WindDownProfileMapper.kind(for: answers), .gentleBeginning)
    }

    func testLegacyNoDifficultyValueRemainsDecodableAndDistinctFromSomethingElse() throws {
        let legacy = Data(#"{"mainFriction":"noDifficulty"}"#.utf8)

        let answers = try JSONDecoder().decode(WindDownProfileAnswer.self, from: legacy)

        XCTAssertEqual(answers.mainFriction, .noDifficulty)
        XCTAssertNotEqual(answers.mainFriction, .somethingElse)
        XCTAssertEqual(WindDownProfileMapper.kind(for: answers), .gentleBeginning)
    }

    func testLegacyRecommendationDecodesWithoutInventingASecondaryPattern() throws {
        let original = WindDownProfileMapper.recommendation(for: .defaults)
        var legacy = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any]
        )
        legacy["kind"] = WindDownProfileKind.eveningScreens.rawValue
        legacy.removeValue(forKey: "secondaryKind")
        legacy.removeValue(forKey: "noticed")
        legacy.removeValue(forKey: "suggestedStrategy")

        let restored = try JSONDecoder().decode(
            WindDownProfileRecommendation.self,
            from: JSONSerialization.data(withJSONObject: legacy)
        )

        XCTAssertEqual(restored.kind, .eveningScreens)
        XCTAssertNil(restored.secondaryKind)
        XCTAssertTrue(restored.noticed.isEmpty)
        XCTAssertEqual(restored.wearableItemID, original.wearableItemID)
    }

    func testRecommendationContainsNoDisplayedNumericScore() throws {
        var answers = WindDownProfileAnswer.defaults
        answers.automaticReaching = .often
        let recommendation = WindDownProfileMapper.recommendation(for: answers)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(recommendation)) as? [String: Any]
        )

        XCTAssertFalse(object.keys.contains { $0.localizedCaseInsensitiveContains("score") })
        XCTAssertFalse(recommendation.summary.contains("/10"))
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
