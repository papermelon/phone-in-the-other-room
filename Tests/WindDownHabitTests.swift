import XCTest

final class WindDownHabitTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var day: Date { Date(timeIntervalSince1970: 1_800_057_600) }

    func testDefaultAndMissingPlanFieldsAreNeutral() throws {
        let plan = try JSONDecoder().decode(WindDownHabitPlan.self, from: Data("{}".utf8))

        XCTAssertEqual(plan, WindDownHabitPlan())
        XCTAssertNil(plan.cue)
        XCTAssertNil(plan.preparation)
        XCTAssertNil(plan.smallerActivity)
        XCTAssertFalse(plan.hasSmallerVersion)
        XCTAssertEqual(plan.phonePlacement, .anotherRoom)
        XCTAssertFalse(plan.useSmallerVersionNextTime)
        XCTAssertNil(plan.smallerVersionSelectionID)
    }

    func testPlanTrimsCapsGraphemesAndPreservesInteriorTyping() {
        var plan = WindDownHabitPlan(
            cue: "  After  brushing my teeth \n",
            preparation: String(repeating: "🌙", count: 125),
            smallerActivity: String(repeating: "🌙", count: 125)
        )

        XCTAssertEqual(plan.cue, "After  brushing my teeth")
        XCTAssertEqual(plan.preparation?.count, WindDownHabitPlan.maximumContextLength)
        XCTAssertEqual(plan.smallerActivity?.count, WindDownHabitPlan.maximumActivityLength)
        XCTAssertNil(WindDownHabitPlan(preparation: " \n\t").preparation)
        plan.cue = "  After dinner  "
        XCTAssertEqual(plan.normalized().cue, "After dinner")
        XCTAssertEqual(plan.cue, "  After dinner  ")
    }

    func testPlanDecodeNormalizesAndRoundTrips() throws {
        let data = Data(#"{"cue":"  After dinner ","preparation":"  Put out my book ","smallerActivity":" One paragraph "}"#.utf8)
        let plan = try JSONDecoder().decode(WindDownHabitPlan.self, from: data)

        XCTAssertEqual(plan.cue, "After dinner")
        XCTAssertEqual(plan.preparation, "Put out my book")
        XCTAssertEqual(plan.smallerActivity, "One paragraph")
        XCTAssertEqual(try roundTrip(plan), plan)
        XCTAssertTrue(plan.hasSmallerVersion)
    }

    func testReflectionMissingFieldsAndFutureChoicesDecodeSafely() throws {
        let empty = try JSONDecoder().decode(WindDownHabitReflection.self, from: Data("{}".utf8))
        let undated = try JSONDecoder().decode(
            WindDownHabitReflection.self,
            from: Data(#"{"ease":"hard","obstacle":"forgot"}"#.utf8)
        )
        let future = try JSONDecoder().decode(
            WindDownHabitReflection.self,
            from: Data(#"{"day":0,"ease":"futureChoice","obstacle":"futureChoice"}"#.utf8)
        )

        XCTAssertTrue(empty.isEmpty)
        XCTAssertTrue(undated.isEmpty)
        XCTAssertTrue(future.isEmpty)
        XCTAssertEqual(empty.day, .distantPast)
        XCTAssertEqual(
            try JSONDecoder().decode(WindDownHabitReflectionHistory.self, from: Data("{}".utf8)),
            WindDownHabitReflectionHistory()
        )
    }

    func testReflectionCanRecordEitherAnswerWithoutASession() throws {
        let reflection = WindDownHabitReflection(day: day, ease: .notTried, calendar: calendar)
        let obstacleOnly = WindDownHabitReflection(day: day, obstacle: .neededPhone, calendar: calendar)

        XCTAssertFalse(reflection.isEmpty)
        XCTAssertFalse(obstacleOnly.isEmpty)
        XCTAssertEqual(reflection.id, calendar.startOfDay(for: day))
        XCTAssertEqual(try roundTrip(reflection), reflection)
        XCTAssertEqual(try roundTrip(obstacleOnly), obstacleOnly)
    }

    func testHistoryNormalizesReplacesAndClearsTheSameDay() {
        let morning = calendar.startOfDay(for: day).addingTimeInterval(8 * 3_600)
        let evening = morning.addingTimeInterval(12 * 3_600)
        var history = WindDownHabitReflectionHistory(calendar: calendar)
        history.upsert(.init(day: morning, ease: .mixed, calendar: calendar), calendar: calendar)
        history.upsert(.init(day: evening, ease: .hard, obstacle: .tooMuch, calendar: calendar), calendar: calendar)

        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(history.entries.first?.day, calendar.startOfDay(for: morning))
        XCTAssertEqual(history.entry(for: morning, calendar: calendar)?.ease, .hard)
        XCTAssertEqual(history.entry(for: evening, calendar: calendar)?.obstacle, .tooMuch)

        history.upsert(.init(day: evening, calendar: calendar), calendar: calendar)
        XCTAssertNil(history.entry(for: morning, calendar: calendar))
        XCTAssertTrue(history.entries.isEmpty)
    }

    func testHistoryInitializerDeduplicatesAndHonorsAnEmptyReplacement() {
        let midnight = calendar.startOfDay(for: day)
        let entries: [WindDownHabitReflection] = [
            .init(day: midnight.addingTimeInterval(3_600), ease: .easy, calendar: calendar),
            .init(day: midnight.addingTimeInterval(7_200), ease: .hard, calendar: calendar),
            .init(day: midnight.addingTimeInterval(86_400), ease: .mixed, calendar: calendar),
            .init(day: midnight.addingTimeInterval(10_800), calendar: calendar)
        ]
        let history = WindDownHabitReflectionHistory(entries: entries, calendar: calendar)

        XCTAssertEqual(history.entries.count, 1)
        XCTAssertNil(history.entry(for: midnight, calendar: calendar))
        XCTAssertEqual(history.entries.first?.ease, .mixed)
    }

    func testHistoryKeepsNewest45AndRoundTripsWithoutChangingStoredDay() throws {
        let entries = (0..<50).map { offset in
            WindDownHabitReflection(day: day.addingTimeInterval(Double(offset) * 86_400), ease: .easy, calendar: calendar)
        }
        var history = WindDownHabitReflectionHistory(entries: Array(entries.reversed()), calendar: calendar)

        XCTAssertEqual(history.entries.count, 45)
        XCTAssertEqual(history.entries.first?.day, calendar.startOfDay(for: entries[49].day))
        XCTAssertNil(history.entry(for: entries[4].day, calendar: calendar))
        XCTAssertEqual(try roundTrip(history), history)

        history.upsert(.init(day: day.addingTimeInterval(50 * 86_400), ease: .mixed, calendar: calendar), calendar: calendar)
        XCTAssertEqual(history.entries.count, 45)
        XCTAssertNil(history.entry(for: entries[5].day, calendar: calendar))
    }

    func testReflectionKeepsItsCivilDayWhenTravelingFromSingaporeToLosAngeles() throws {
        let singapore = calendar(in: "Asia/Singapore")
        let losAngeles = calendar(in: "America/Los_Angeles")
        let civilDay = NightFlockLocalDate(year: 2026, month: 9, day: 8)
        let singaporeDay = try XCTUnwrap(civilDay.date(in: singapore.timeZone.identifier, calendar: singapore))
        let losAngelesDay = try XCTUnwrap(civilDay.date(in: losAngeles.timeZone.identifier, calendar: losAngeles))
        let reflection = WindDownHabitReflection(day: singaporeDay, ease: .easy, calendar: singapore)
        let history = try roundTrip(WindDownHabitReflectionHistory(entries: [reflection], calendar: singapore))

        XCTAssertEqual(history.entries.first?.localDate, civilDay)
        XCTAssertEqual(history.entries.first?.day, singaporeDay)
        XCTAssertEqual(history.entries.first?.displayDay(in: losAngeles), losAngelesDay)
        XCTAssertEqual(history.entry(for: losAngelesDay, calendar: losAngeles), reflection)
        XCTAssertNil(history.entry(for: singaporeDay, calendar: losAngeles))
        XCTAssertEqual(WindDownHabitReflectionHistory(entries: history.entries, calendar: losAngeles), history)
    }

    func testSameCivilDayAcrossTimeZonesReplacesAndClearsOneReflection() throws {
        let singapore = calendar(in: "Asia/Singapore")
        let losAngeles = calendar(in: "America/Los_Angeles")
        let civilDay = NightFlockLocalDate(year: 2026, month: 9, day: 8)
        let firstDay = try XCTUnwrap(civilDay.date(in: singapore.timeZone.identifier, calendar: singapore))
        let secondDay = try XCTUnwrap(civilDay.date(in: losAngeles.timeZone.identifier, calendar: losAngeles))
        let first = WindDownHabitReflection(day: firstDay, ease: .easy, calendar: singapore)
        let second = WindDownHabitReflection(day: secondDay, ease: .hard, calendar: losAngeles)
        var history = WindDownHabitReflectionHistory(entries: [first, second], calendar: losAngeles)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(history.entries, [second])
        XCTAssertEqual(try roundTrip(history).entries, [second])
        history.upsert(first, calendar: singapore)
        XCTAssertEqual(history.entries, [first])
        history.upsert(.init(day: secondDay, calendar: losAngeles), calendar: losAngeles)
        XCTAssertTrue(history.entries.isEmpty)
    }

    func testLegacyReflectionDoesNotInventAnOriginalCivilDayOrTimeZone() throws {
        let original = WindDownHabitReflection(day: day, ease: .mixed, calendar: calendar(in: "Asia/Singapore"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        object.removeValue(forKey: "localDate")
        let decoded = try JSONDecoder().decode(WindDownHabitReflection.self, from: JSONSerialization.data(withJSONObject: object))

        XCTAssertNil(decoded.localDate)
        XCTAssertEqual(decoded.day, original.day)
        XCTAssertEqual(decoded.displayDay(in: calendar(in: "America/Los_Angeles")), original.day)
        XCTAssertEqual(try roundTrip(decoded), decoded)
    }

    func testInvalidCivilDateIsRejectedInsteadOfSilentlyChangingTheDay() {
        let data = Data(#"{"day":0,"localDate":{"year":2026,"month":2,"day":31},"ease":"easy"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(WindDownHabitReflection.self, from: data))
    }

    func testEachObstacleOffersAnExplicitNonMutatingAdjustment() {
        let expected: [WindDownObstacle: WindDownHabitEditFocus] = [
            .forgot: .cue, .tooMuch: .smallerVersion, .rushed: .smallerVersion, .notAppealing: .activity,
            .neededPhone: .access, .timing: .activity, .other: .preparation
        ]

        for obstacle in WindDownObstacle.allCases {
            XCTAssertEqual(obstacle.editFocus, expected[obstacle])
            XCTAssertFalse(obstacle.title.isEmpty)
            XCTAssertFalse(obstacle.adjustmentTitle.isEmpty)
            XCTAssertFalse(obstacle.adjustmentBody.isEmpty)
        }
        XCTAssertTrue(WindDownObstacle.timing.adjustmentBody.contains("Plan"))
        XCTAssertTrue(WindDownStartingEase.allCases.allSatisfy { !$0.title.isEmpty })
    }

    func testSmallerVersionChangesOnlyEveningInvitations() throws {
        let original = plan()
        let support = WindDownHabitPlan(cue: "After dinner", smallerActivity: "Read one paragraph")
        let snapshot = WindDownHabitRules.planForStart(original, support: support, useSmallerVersion: true)

        XCTAssertEqual(snapshot.eveningRoutine.count, 1)
        XCTAssertEqual(snapshot.eveningRoutine.first?.phase, .evening)
        XCTAssertEqual(snapshot.eveningRoutine.first?.kind, .custom)
        XCTAssertEqual(snapshot.eveningRoutine.first?.customText, "Read one paragraph")
        XCTAssertEqual(snapshot.eveningCueText, "Read one paragraph")
        XCTAssertEqual(snapshot.eveningActivityTitle, "Read one paragraph")
        XCTAssertTrue(snapshot.usesSmallerRoutine)
        XCTAssertNil(snapshot.eveningNotificationActivityTitle(allowsPersonalText: false))

        var unchangedFields = snapshot
        unchangedFields.eveningRoutine = original.eveningRoutine
        unchangedFields.eveningCueText = original.eveningCueText
        unchangedFields.usesSmallerRoutine = original.usesSmallerRoutine
        unchangedFields.smallerRoutineSelectionID = original.smallerRoutineSelectionID
        XCTAssertEqual(unchangedFields, original)
        XCTAssertEqual(try roundTrip(snapshot), snapshot)
        XCTAssertEqual(
            snapshot,
            WindDownHabitRules.planForStart(original, support: support, useSmallerVersion: true)
        )
    }

    func testNoSmallerSelectionOrInvitationLeavesPlanUnchanged() {
        let original = plan()
        XCTAssertFalse(original.usesSmallerRoutine)
        XCTAssertEqual(
            WindDownHabitRules.planForStart(
                original, support: .init(smallerActivity: "Read one paragraph"), useSmallerVersion: false
            ),
            original
        )
        for text in [nil, "", " \n", "Put the phone away"] as [String?] {
            let support = WindDownHabitPlan(smallerActivity: text, useSmallerVersionNextTime: true)
            XCTAssertFalse(support.hasSmallerVersion)
            XCTAssertFalse(support.useSmallerVersionNextTime)
            XCTAssertEqual(
                WindDownHabitRules.planForStart(original, support: support, useSmallerVersion: true),
                original
            )
        }
    }

    func testSmallerVersionDoesNotChangeAnAdditionalQuietPlan() {
        let original = NightWatchPlan.additionalQuiet(start: day, end: day.addingTimeInterval(1_800))
        XCTAssertEqual(
            WindDownHabitRules.planForStart(
                original,
                support: .init(smallerActivity: "Read one paragraph", phonePlacement: .accessibleNearby),
                useSmallerVersion: true
            ),
            original
        )
    }

    func testSmallerInvitationUsesLegacyLimitAndSurvivesRoundTrip() throws {
        let support = WindDownHabitPlan(smallerActivity: String(repeating: "a", count: 120))
        let snapshot = WindDownHabitRules.planForStart(plan(), support: support, useSmallerVersion: true)

        XCTAssertEqual(support.smallerActivity?.count, WindDownHabitPlan.maximumActivityLength)
        XCTAssertEqual(WindDownHabitRules.smallerActivityInvitation(for: support)?.count, PhoneFreeCue.maximumTextLength)
        XCTAssertEqual(snapshot.eveningCueText, snapshot.eveningRoutine.first?.customText)
        XCTAssertEqual(try roundTrip(snapshot), snapshot)
    }

    func testPlacementAndNextStartChoiceRoundTripWithoutChangingTiming() throws {
        let support = WindDownHabitPlan(
            smallerActivity: "Read one paragraph",
            phonePlacement: .accessibleNearby,
            useSmallerVersionNextTime: true
        )
        XCTAssertEqual(try roundTrip(support), support)
        XCTAssertTrue(support.useSmallerVersionNextTime)
        XCTAssertNotNil(support.smallerVersionSelectionID)

        let original = plan()
        let snapshot = WindDownHabitRules.planForStart(original, support: support, useSmallerVersion: false)
        XCTAssertEqual(snapshot.phonePlacement, .accessibleNearby)
        var unchangedFields = snapshot
        unchangedFields.phonePlacement = original.phonePlacement
        XCTAssertEqual(unchangedFields, original)
    }

    func testClearingSmallerActivityClearsNextStartChoiceWhenNormalized() {
        var support = WindDownHabitPlan(smallerActivity: "Read one paragraph", useSmallerVersionNextTime: true)
        support.smallerActivity = " \n "

        XCTAssertFalse(support.normalized().useSmallerVersionNextTime)
        XCTAssertFalse(support.normalized().hasSmallerVersion)
        XCTAssertNil(support.normalized().smallerVersionSelectionID)
    }

    func testLegacyPlanMissingHabitFieldsPreservesTimingAndRoutines() throws {
        let original = plan()
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any]
        )
        object.removeValue(forKey: "phonePlacement")
        object.removeValue(forKey: "usesSmallerRoutine")
        object.removeValue(forKey: "smallerRoutineSelectionID")
        let decoded = try JSONDecoder().decode(
            NightWatchPlan.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(decoded.phonePlacement, .anotherRoom)
        XCTAssertFalse(decoded.usesSmallerRoutine)
        XCTAssertNil(decoded.smallerRoutineSelectionID)
        XCTAssertEqual(decoded, original)
    }

    func testPhoneAndWatchMessagesRoundTripTheChosenInvitationWithoutAddingEvidence() throws {
        let support = WindDownHabitPlan(
            smallerActivity: "Read one paragraph", phonePlacement: .accessibleNearby, useSmallerVersionNextTime: true
        )
        let snapshot = WindDownHabitRules.planForStart(plan(), support: support, useSmallerVersion: true)
        let run = FocusRun(
            plannedDurationSeconds: snapshot.protectedUntil.timeIntervalSince(day),
            startedAt: day,
            state: .running,
            guardKind: .honorTimer,
            nightWatchPlan: snapshot
        )
        for type in [WatchMessageType.startFocusRun, .focusRunStateUpdate, .endFocusRunEarly, .stopFocusRun] {
            let message = WatchMessage(type: type, run: run, sentAt: day)
            let decoded = try XCTUnwrap(WatchMessageCodec.message(from: WatchMessageCodec.dictionary(from: message)))

            XCTAssertEqual(decoded.type, type)
            XCTAssertEqual(decoded.run, run)
            XCTAssertEqual(decoded.run?.nightWatchPlan?.phonePlacement, .accessibleNearby)
            XCTAssertEqual(decoded.run?.nightWatchPlan?.usesSmallerRoutine, true)
            XCTAssertEqual(decoded.run?.nightWatchPlan?.smallerRoutineSelectionID, support.smallerVersionSelectionID)
            XCTAssertNil(decoded.run?.phoneAwayValidatedAt)
            XCTAssertEqual(decoded.run?.completedSuccessfully, false)
            XCTAssertTrue(decoded.run?.earnedRewardIDs.isEmpty == true)
        }
    }

    func testLegacyWatchPayloadWithoutHabitFieldsStillDecodes() throws {
        let original = plan()
        let run = FocusRun(
            plannedDurationSeconds: original.protectedUntil.timeIntervalSince(day),
            startedAt: day,
            state: .running,
            guardKind: .honorTimer,
            nightWatchPlan: original
        )
        let message = WatchMessage(type: .focusRunStateUpdate, run: run, sentAt: day)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(message)) as? [String: Any]
        )
        var runObject = try XCTUnwrap(object["run"] as? [String: Any])
        var planObject = try XCTUnwrap(runObject["nightWatchPlan"] as? [String: Any])
        planObject.removeValue(forKey: "phonePlacement")
        planObject.removeValue(forKey: "usesSmallerRoutine")
        planObject.removeValue(forKey: "smallerRoutineSelectionID")
        runObject["nightWatchPlan"] = planObject
        object["run"] = runObject
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try XCTUnwrap(WatchMessageCodec.message(from: ["payload": legacyData]))

        XCTAssertEqual(decoded.run, run)
        XCTAssertEqual(decoded.run?.nightWatchPlan?.phonePlacement, .anotherRoom)
        XCTAssertEqual(decoded.run?.nightWatchPlan?.usesSmallerRoutine, false)
        XCTAssertNil(decoded.run?.nightWatchPlan?.smallerRoutineSelectionID)
    }

    func testPrimarySummaryUsesPlacementWithoutLeakingCustomActivityWhenPrivate() {
        var primary = plan()
        primary.phonePlacement = .accessibleNearby
        XCTAssertTrue(primary.eveningRoutineSummary(allowsPersonalText: true).hasPrefix(primary.phonePlacement.actionCue))
        XCTAssertEqual(primary.eveningRoutineSummary(allowsPersonalText: false), primary.phonePlacement.actionCue)
        XCTAssertFalse(primary.eveningRoutineSummary(allowsPersonalText: false).contains("Draw a cat"))

        var additional = NightWatchPlan.additionalQuiet(start: day, end: day.addingTimeInterval(1_800))
        additional.phonePlacement = .accessibleNearby
        XCTAssertEqual(additional.eveningRoutineSummary(allowsPersonalText: false), WindDownRoutineStep.phoneAwayTitle)
    }

    func testSelectionIdentitySurvivesNormalizationAndChangesForANewChoice() throws {
        let first = WindDownHabitPlan(smallerActivity: "One paragraph", useSmallerVersionNextTime: true)
        let firstID = try XCTUnwrap(first.smallerVersionSelectionID)
        XCTAssertEqual(first.normalized().smallerVersionSelectionID, firstID)
        XCTAssertEqual(try roundTrip(first).smallerVersionSelectionID, firstID)
        let snapshot = WindDownHabitRules.planForStart(plan(), support: first, useSmallerVersion: true)
        XCTAssertEqual(snapshot.smallerRoutineSelectionID, firstID)

        var cleared = first
        cleared.useSmallerVersionNextTime = false
        cleared = cleared.normalized()
        XCTAssertNil(cleared.smallerVersionSelectionID)
        cleared.useSmallerVersionNextTime = true
        let next = cleared.normalized()
        XCTAssertNotNil(next.smallerVersionSelectionID)
        XCTAssertNotEqual(next.smallerVersionSelectionID, snapshot.smallerRoutineSelectionID)
    }

    func testLegacyPendingChoiceReceivesAnIdentityThatCanBePersisted() throws {
        let data = Data(#"{"smallerActivity":"One paragraph","useSmallerVersionNextTime":true}"#.utf8)
        let decoded = try JSONDecoder().decode(WindDownHabitPlan.self, from: data)
        let identity = try XCTUnwrap(decoded.smallerVersionSelectionID)

        XCTAssertTrue(decoded.useSmallerVersionNextTime)
        XCTAssertEqual(decoded.normalized().smallerVersionSelectionID, identity)
        XCTAssertEqual(try roundTrip(decoded).smallerVersionSelectionID, identity)
    }

    private func plan() -> NightWatchPlan {
        NightWatchPlan(
            intendedBedtime: day.addingTimeInterval(3_600),
            wakeTime: day.addingTimeInterval(9 * 3_600),
            protectedUntil: day.addingTimeInterval(10 * 3_600),
            windDownMinutes: 30,
            morningQuietMinutes: 60,
            eveningActivity: .read,
            morningActivity: .openCurtains,
            eveningRoutine: [.suggested(.read, phase: .evening), .custom("Draw a cat", phase: .evening)],
            morningRoutine: [.suggested(.openCurtains, phase: .morning), .custom("Have breakfast", phase: .morning)],
            calendar: calendar
        )
    }

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }

    private func calendar(in timeZoneIdentifier: String) -> Calendar {
        var result = calendar
        result.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return result
    }
}
