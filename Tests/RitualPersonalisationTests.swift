import XCTest

final class RitualPersonalisationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_057_600)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func state(mode: WindDownRoutinePhase = .morning) -> RitualPersonalisation {
        var state = RitualPersonalisation()
        var preferences = NightWatchPreferences.defaults
        preferences.morningRoutine = [.suggested(.stretch, phase: .morning), .suggested(.read, phase: .morning)]
        let kind: RitualGoalKind = mode == .morning ? .lessRushed : .unwind
        state.setGoal(RitualGoal(mode: mode, kind: kind, wording: kind.title, now: now.addingTimeInterval(-10 * 86_400)),
                      preferences: preferences, support: WindDownHabitPlan(), now: now.addingTimeInterval(-10 * 86_400))
        return state
    }

    private func note(_ state: RitualPersonalisation, daysAgo: Int, answer: RitualExperienceAnswer = .partly,
                      obstacle: WindDownObstacle? = .tooMuch, planID: UUID? = nil) -> WindDownHabitReflection {
        let date = now.addingTimeInterval(-Double(daysAgo) * 86_400)
        var note = WindDownHabitReflection(day: date, obstacle: obstacle, calendar: calendar, mode: state.goal!.mode)
        note.experience = RitualExperienceFeedback(planID: planID ?? state.currentPlan!.id, answer: answer,
                                                   recordedAt: date, timeZoneIdentifier: "UTC")
        return note
    }

    func testSkippingAndLegacyDataDoNotCreateGoals() throws {
        let empty = RitualPersonalisation()
        XCTAssertNil(empty.goal)
        XCTAssertNil(empty.currentPlan)
        XCTAssertNil(RitualPersonalisationRules.visibleSuggestion(empty, now: now))
        let legacy = try JSONDecoder().decode(WindDownHabitReflection.self, from: Data(#"{"day":0,"ease":"hard","obstacle":"tooMuch"}"#.utf8))
        XCTAssertNil(legacy.experience)
        XCTAssertEqual(legacy.mode, .evening)
        XCTAssertNil(try JSONDecoder().decode(WindDownHabitPlan.self, from: Data("{}".utf8)).morningCue)
    }

    func testCustomGoalIsBoundedAndNotClassified() {
        let goal = RitualGoal(mode: .morning, kind: .personal, wording: "  " + String(repeating: "🌙", count: 160), now: now)
        XCTAssertEqual(goal.wording.count, 120)
        XCTAssertEqual(goal.kind, .personal)
        XCTAssertNil(goal.kind.proposedActivity)
        XCTAssertFalse(RitualGoalKind.unwind.supports(.morning))
        XCTAssertFalse(RitualGoalKind.lessScrolling.supports(.evening))
    }

    func testTwoDistinctExplicitDaysYieldOneSuggestionWithExactEvidence() throws {
        var state = state()
        let notes = [note(state, daysAgo: 2), note(state, daysAgo: 1)]
        let history = WindDownHabitReflectionHistory(entries: notes)
        RitualPersonalisationRules.refresh(&state, history: history, now: now)
        let suggestion = try XCTUnwrap(RitualPersonalisationRules.visibleSuggestion(state, now: now))
        XCTAssertEqual(suggestion.action, .simplify)
        XCTAssertEqual(Set(suggestion.evidenceIDs), Set(notes.compactMap { $0.experience?.id }))
        XCTAssertEqual(suggestion.targetPlanID, state.currentPlan?.id)
        let snapshot = state
        RitualPersonalisationRules.refresh(&state, history: history, now: now)
        XCTAssertEqual(state, snapshot)
    }

    func testSameDaySparseSuccessfulUnknownConflictingAndUnlinkedFeedbackGiveNoTrend() {
        for answers: [(RitualExperienceAnswer, RitualExperienceAnswer)] in [[(.yes, .yes)], [(.notSure, .notSure)], [(.partly, .yes)]] {
            var state = state()
            let pair = answers[0]
            let history = WindDownHabitReflectionHistory(entries: [note(state, daysAgo: 2, answer: pair.0), note(state, daysAgo: 1, answer: pair.1)])
            RitualPersonalisationRules.refresh(&state, history: history, now: now)
            XCTAssertNil(RitualPersonalisationRules.visibleSuggestion(state, now: now))
        }
        var state = state()
        var notes = [note(state, daysAgo: 1), note(state, daysAgo: 1)]
        RitualPersonalisationRules.refresh(&state, history: WindDownHabitReflectionHistory(entries: notes), now: now)
        XCTAssertTrue(state.suggestions.isEmpty)
        notes = [note(state, daysAgo: 2), note(state, daysAgo: 1)]
        notes[0].experience?.planID = nil
        RitualPersonalisationRules.refresh(&state, history: WindDownHabitReflectionHistory(entries: notes), now: now)
        XCTAssertTrue(state.suggestions.isEmpty)
    }

    func testNeededPhoneNeverSuggestsRemovingProtection() {
        var state = state()
        let original = state.currentPlan
        let history = WindDownHabitReflectionHistory(entries: [note(state, daysAgo: 2, obstacle: .neededPhone), note(state, daysAgo: 1, obstacle: .neededPhone)])
        RitualPersonalisationRules.refresh(&state, history: history, now: now)
        XCTAssertTrue(state.suggestions.isEmpty)
        XCTAssertEqual(state.currentPlan, original)
    }

    func testRushedFeedbackCanSimplifyButTimingAndUnclassifiedFeedbackCannot() {
        for obstacle in [WindDownObstacle.rushed, .timing, .other] {
            var state = state()
            let history = WindDownHabitReflectionHistory(entries: [note(state, daysAgo: 2, obstacle: obstacle), note(state, daysAgo: 1, obstacle: obstacle)])
            RitualPersonalisationRules.refresh(&state, history: history, now: now)
            XCTAssertEqual(state.suggestions.first?.action, obstacle == .rushed ? .simplify : nil)
        }
    }

    func testForgottenCueAndUnappealingActivityOfferSpecificEdits() {
        for pair: (WindDownObstacle, RitualAdjustmentAction) in [(.forgot, .cue), (.notAppealing, .swapActivity)] {
            var state = state()
            let history = WindDownHabitReflectionHistory(entries: [note(state, daysAgo: 2, obstacle: pair.0), note(state, daysAgo: 1, obstacle: pair.0)])
            RitualPersonalisationRules.refresh(&state, history: history, now: now)
            XCTAssertEqual(state.suggestions.first?.action, pair.1)
        }
    }

    func testPlanOrGoalChangeRetiresSuggestionWithoutReattributingFeedback() throws {
        var state = state()
        let oldPlan = state.currentPlan!
        let history = WindDownHabitReflectionHistory(entries: [note(state, daysAgo: 2), note(state, daysAgo: 1)])
        RitualPersonalisationRules.refresh(&state, history: history, now: now)
        var preferences = oldPlan.preferences
        preferences.morningQuietMinutes += 5
        state.reconcile(preferences: preferences, support: oldPlan.support, now: now)
        RitualPersonalisationRules.refresh(&state, history: history, now: now)
        XCTAssertNotEqual(state.currentPlan?.id, oldPlan.id)
        XCTAssertEqual(state.plans.first, oldPlan)
        XCTAssertNil(RitualPersonalisationRules.visibleSuggestion(state, now: now))
        state.setGoal(nil, preferences: preferences, support: oldPlan.support, now: now)
        XCTAssertNil(state.goal)
        XCTAssertNil(state.currentPlan)
    }

    func testRejectedActionDoesNotReturnWithFreshEvidenceOrAfterRetention() throws {
        var state = state()
        var history = WindDownHabitReflectionHistory(entries: [note(state, daysAgo: 2), note(state, daysAgo: 1)])
        RitualPersonalisationRules.refresh(&state, history: history, now: now)
        let id = try XCTUnwrap(state.suggestions.first?.id)
        XCTAssertTrue(RitualPersonalisationRules.respond(&state, suggestionID: id, status: .dismissed, now: now))
        history.upsert(note(state, daysAgo: 0))
        RitualPersonalisationRules.refresh(&state, history: history, now: now)
        XCTAssertNil(RitualPersonalisationRules.visibleSuggestion(state, now: now))
        state.prune(now: now.addingTimeInterval(91 * 86_400))
        XCTAssertTrue(state.suggestions.isEmpty)
        XCTAssertEqual(state.rejectedActions, [.simplify])
        XCTAssertNotNil(state.currentPlan)
    }

    func testDeferralExpiryAndDeletedEvidence() throws {
        var state = state()
        let history = WindDownHabitReflectionHistory(entries: [note(state, daysAgo: 2), note(state, daysAgo: 1)])
        RitualPersonalisationRules.refresh(&state, history: history, now: now)
        let id = try XCTUnwrap(state.suggestions.first?.id)
        XCTAssertTrue(RitualPersonalisationRules.respond(&state, suggestionID: id, status: .deferred, now: now))
        XCTAssertNil(RitualPersonalisationRules.visibleSuggestion(state, now: now.addingTimeInterval(6 * 86_400)))
        XCTAssertEqual(RitualPersonalisationRules.visibleSuggestion(state, now: now.addingTimeInterval(7 * 86_400))?.id, id)
        XCTAssertNil(RitualPersonalisationRules.visibleSuggestion(state, now: now.addingTimeInterval(14 * 86_400)))
        RitualPersonalisationRules.refresh(&state, history: WindDownHabitReflectionHistory(), now: now)
        XCTAssertEqual(state.suggestions.first?.status, .superseded)
    }

    func testCadenceActiveSuppressionDismissalAndSuccessfulRoutine() {
        var state = state()
        XCTAssertTrue(state.invitationAvailable(now: now, isActive: false))
        XCTAssertFalse(state.invitationAvailable(now: now, isActive: true))
        state.postponeInvitation(now: now)
        XCTAssertFalse(state.invitationAvailable(now: now.addingTimeInterval(6 * 86_400), isActive: false))
        state.postponeInvitation(now: now, worked: true)
        XCTAssertFalse(state.invitationAvailable(now: now.addingTimeInterval(27 * 86_400), isActive: false))
        state.invitationsEnabled = false
        XCTAssertFalse(state.invitationAvailable(now: now.addingTimeInterval(40 * 86_400), isActive: false))
    }

    func testEveningAndMorningSameDayDoNotOverwriteAcrossTravel() throws {
        var morning = note(state(), daysAgo: 0)
        let evening = WindDownHabitReflection(day: now, ease: .easy, calendar: calendar)
        var history = WindDownHabitReflectionHistory(entries: [morning, evening], calendar: calendar)
        XCTAssertEqual(history.entries.count, 2)
        morning.experience?.answer = .yes
        history.upsert(morning, calendar: calendar)
        var travel = calendar
        travel.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let decoded = try JSONDecoder().decode(WindDownHabitReflectionHistory.self, from: JSONEncoder().encode(history))
        XCTAssertEqual(decoded.entry(for: morning.displayDay(in: travel), calendar: travel, mode: .morning)?.experience?.answer, .yes)
        XCTAssertEqual(decoded.entry(for: evening.displayDay(in: travel), calendar: travel)?.ease, .easy)
    }

    func testFutureCivilDayAndInvalidTimeZoneAreNotEvidence() {
        for zone in ["UTC", "Invalid/Zone"] {
            var state = state()
            var notes = [note(state, daysAgo: -1), note(state, daysAgo: -2)]
            for i in notes.indices {
                notes[i].experience?.recordedAt = now
                notes[i].experience?.timeZoneIdentifier = zone
            }
            RitualPersonalisationRules.refresh(&state, history: WindDownHabitReflectionHistory(entries: notes), now: now)
            XCTAssertTrue(state.suggestions.isEmpty)
        }
    }

    func testOldAndFutureReportsDoNotDriveSuggestions() {
        for offsets in [[29, 30], [-1, -2]] {
            var state = state()
            let history = WindDownHabitReflectionHistory(entries: offsets.map { note(state, daysAgo: $0) })
            RitualPersonalisationRules.refresh(&state, history: history, now: now)
            XCTAssertTrue(state.suggestions.isEmpty)
        }
    }

    func testJournalRoundTripPreservesRevisionAndEvidence() throws {
        var state = state()
        RitualPersonalisationRules.refresh(&state, history: WindDownHabitReflectionHistory(entries: [note(state, daysAgo: 1), note(state, daysAgo: 2)]), now: now)
        XCTAssertEqual(try JSONDecoder().decode(RitualPersonalisation.self, from: JSONEncoder().encode(state)), state)
        XCTAssertTrue(AccountFarmLocalKeys.all.contains(RitualPersonalisation.storageKey))
        XCTAssertTrue(CountingSheepOwnedStorage.standardKeys.contains(RitualPersonalisation.storageKey))
        XCTAssertFalse(FarmSaveDocument.keys.contains(RitualPersonalisation.storageKey))
    }
}
