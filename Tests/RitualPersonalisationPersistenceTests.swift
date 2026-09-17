#if FARM_SAVE_SERVICE_TESTS
import XCTest

final class RitualPersonalisationPersistenceTests: XCTestCase {
    private func fixture(_ run: (PersistenceService, UserDefaults, URL) throws -> Void) throws {
        let suite = "PersonalisationTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        try run(PersistenceService(defaults: defaults, farmSaveDirectory: directory), defaults, directory)
    }

    func testOwnerAndLineageFenceGuestAccountASignedOutAndAccountB() throws {
        try fixture { persistence, _, _ in
            let guest = try persistence.personalisationEditToken()
            var state = RitualPersonalisation()
            state.setGoal(RitualGoal(mode: .morning, kind: .personal, wording: "Guest words", now: Date()),
                          preferences: .defaults, support: WindDownHabitPlan(), now: Date())
            try persistence.savePersonalisation(state, token: guest)
            let a = UUID(), b = UUID()
            try persistence.farmSaveStore.activate(.account(a))
            XCTAssertNil(try persistence.loadPersonalisation().goal)
            XCTAssertThrowsError(try persistence.savePersonalisation(state, token: guest))
            let tokenA = try persistence.personalisationEditToken()
            state.goals = [RitualGoal(mode: .morning, kind: .personal, wording: "Account A words", now: Date())]
            try persistence.savePersonalisation(state, token: tokenA)
            try persistence.farmSaveStore.activate(.signedOut)
            XCTAssertThrowsError(try persistence.loadPersonalisation())
            XCTAssertThrowsError(try persistence.savePersonalisation(state, token: tokenA))
            try persistence.farmSaveStore.finishCredentialRemoval()
            try persistence.farmSaveStore.activate(.guest)
            XCTAssertEqual(try persistence.loadPersonalisation().goal?.wording, "Guest words")
            try persistence.farmSaveStore.activate(.account(b))
            XCTAssertNil(try persistence.loadPersonalisation().goal)
            XCTAssertThrowsError(try persistence.savePersonalisation(state, token: tokenA))
            try persistence.farmSaveStore.activate(.account(a))
            XCTAssertEqual(try persistence.loadPersonalisation().goal?.wording, "Account A words")
        }
    }

    func testStaleJournalPlanSupportAndReflectionEditorsCannotOverwrite() throws {
        try fixture { persistence, _, _ in
            let first = try persistence.personalisationEditToken()
            var state = RitualPersonalisation()
            try persistence.savePersonalisation(state, token: first)
            XCTAssertThrowsError(try persistence.savePersonalisation(state, token: first))
            var token = try persistence.personalisationEditToken()
            var preferences = persistence.nightWatchPreferences
            preferences.morningQuietMinutes += 5
            persistence.nightWatchPreferences = preferences
            XCTAssertThrowsError(try persistence.savePersonalisation(state, token: token))
            token = try persistence.personalisationEditToken()
            try persistence.saveWindDownHabitPlan(WindDownHabitPlan(cue: "After dinner"), identity: token.identity)
            XCTAssertThrowsError(try persistence.savePersonalisation(state, token: token))
            token = try persistence.personalisationEditToken()
            try persistence.saveWindDownHabitReflections(WindDownHabitReflectionHistory(entries: [.init(day: Date(), ease: .easy)]), identity: token.identity)
            state.invitationsEnabled = false
            XCTAssertThrowsError(try persistence.savePersonalisation(state, token: token))
            XCTAssertTrue(try persistence.loadPersonalisation().invitationsEnabled)
        }
    }

    func testAtomicJournalReflectionAndSupportSaveSurvivesRelaunch() throws {
        try fixture { persistence, defaults, directory in
            let state = RitualPersonalisation()
            let history = WindDownHabitReflectionHistory(entries: [.init(day: Date(), ease: .easy)])
            let support = WindDownHabitPlan(morningCue: "After I open the curtains")
            try persistence.savePersonalisation(state, token: persistence.personalisationEditToken(), reflections: history, support: support)
            let reopened = PersistenceService(defaults: defaults, farmSaveDirectory: directory)
            XCTAssertEqual(try reopened.loadPersonalisation(), state)
            XCTAssertEqual(try reopened.loadWindDownHabitReflections(), history)
            XCTAssertEqual(try reopened.loadWindDownHabitPlan(), support)
        }
    }

    func testCorruptAndFutureJournalPreservesHealthySiblingValues() throws {
        try fixture { persistence, _, _ in
            let support = WindDownHabitPlan(cue: "After dinner")
            try persistence.saveWindDownHabitPlan(support, identity: persistence.windDownHabitIdentity())
            let corrupt = Data("unreadable".utf8)
            try persistence.farmSaveStore.setLocalData(corrupt, for: RitualPersonalisation.storageKey)
            XCTAssertThrowsError(try persistence.loadPersonalisation())
            XCTAssertEqual(try persistence.loadWindDownHabitPlan(), support)
            try persistence.saveWindDownHabitReflections(WindDownHabitReflectionHistory(entries: [.init(day: Date(), ease: .easy)]), identity: persistence.windDownHabitIdentity())
            XCTAssertEqual(persistence.farmSaveStore.localData(for: RitualPersonalisation.storageKey), corrupt)
            var future = RitualPersonalisation(); future.schemaVersion = 99
            try persistence.farmSaveStore.setLocalData(JSONEncoder().encode(future), for: RitualPersonalisation.storageKey)
            XCTAssertThrowsError(try persistence.loadPersonalisation())
            XCTAssertEqual(try persistence.loadWindDownHabitPlan(), support)
        }
    }

    func testRejectedAtomicWriteLeavesSiblingNotesUntouched() throws {
        try fixture { persistence, _, _ in
            let token = try persistence.personalisationEditToken()
            try persistence.saveWindDownHabitPlan(WindDownHabitPlan(cue: "New cue"), identity: token.identity)
            let history = WindDownHabitReflectionHistory(entries: [.init(day: Date(), ease: .hard)])
            XCTAssertThrowsError(try persistence.savePersonalisation(RitualPersonalisation(), token: token, reflections: history))
            XCTAssertTrue(try persistence.loadWindDownHabitReflections().entries.isEmpty)
            XCTAssertNil(persistence.farmSaveStore.localData(for: RitualPersonalisation.storageKey))
        }
    }
}
#endif
