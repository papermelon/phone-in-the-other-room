import XCTest

final class PersonalShieldTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_900_000_000)

    private func session(role: QuietTimeShieldRole = .primaryWindDown, owner: String = "guest:lineage") -> PersonalShieldSession {
        PersonalShieldSession(id: UUID(), owner: owner, interval: DateInterval(start: now, duration: 3600),
            role: role, bedtime: now.addingTimeInterval(1800), morningStart: now.addingTimeInterval(3000),
            steps: [PersonalShieldStep(id: UUID(), title: "Brush my teeth"), PersonalShieldStep(id: UUID(), title: "Read 10 pages")],
            morningSteps: [PersonalShieldStep(id: UUID(), title: "Drink a glass of water")],
            goal: "Time for myself", morningGoal: "An unhurried morning")
    }

    func testMorningHandoffHasDistinctConfirmationAndMorningAction() {
        let value = session()
        let overnight = now.addingTimeInterval(2000)
        XCTAssertNotEqual(value.confirmationPhrase(at: overnight, morningIntent: .startNow), value.phrase(at: overnight))
        var request = PersonalShieldSheet(sessionID: value.id, owner: value.owner, action: .endSession,
            phrase: "Start my morning", mode: .primaryWindDown, morningIntent: .startNow)
        XCTAssertFalse(request.requiresTypedPhrase)
        XCTAssertEqual(request.confirmationTitle, "Start Screen-Free Morning")
        request.morningIntent = .skipToday
        XCTAssertTrue(request.requiresTypedPhrase)
        XCTAssertEqual(value.confirmationPhrase(at: overnight, morningIntent: .skipToday), "Skip my morning today")
        request.morningIntent = nil
        XCTAssertTrue(request.requiresTypedPhrase, "Ordinary exits retain their challenge")
        XCTAssertEqual(value.listButton(at: now.addingTimeInterval(3100)), "My morning")
    }

    func testChecksAreReversibleAndSleepReplacesBroadGoal() throws {
        var value = session()
        XCTAssertEqual(value.phrase(at: now), "Brush my teeth")
        XCTAssertTrue(value.toggle(value.steps[0].id, at: now))
        XCTAssertEqual(value.phrase(at: now), "Read 10 pages")
        XCTAssertTrue(value.summary(at: now).contains("✓ Brush my teeth"))
        XCTAssertTrue(value.toggle(value.steps[1].id, at: now))
        XCTAssertEqual(value.title(at: now), "Time for sleep")
        XCTAssertEqual(value.phrase(at: now), "Put my phone away for sleep")
        let restored = try JSONDecoder().decode(PersonalShieldSession.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(restored, value)
        XCTAssertTrue(value.toggle(value.steps[1].id, at: now))
        XCTAssertEqual(value.title(at: now), "My Wind Down")
        XCTAssertFalse(value.toggle(value.steps[1].id, at: value.interval.end))
        XCTAssertEqual(value.phrase(at: now.addingTimeInterval(2000)), "Put my phone away for sleep")
    }

    func testMorningAndPhoneAwayDoNotInheritSleepOrEveningChecks() {
        var value = session()
        for step in value.steps { _ = value.toggle(step.id, at: now) }
        let morning = now.addingTimeInterval(3100)
        XCTAssertEqual(value.phrase(at: morning), "Drink a glass of water")
        XCTAssertEqual(value.visibleSteps(at: morning).filter(\.checked).count, 0)
        XCTAssertTrue(value.toggle(value.morningSteps[0].id, at: morning))
        XCTAssertEqual(value.phrase(at: morning), "An unhurried morning")
        var tasks = session(role: .additionalQuiet)
        for step in tasks.steps { _ = tasks.toggle(step.id, at: now) }
        XCTAssertEqual(tasks.title(at: now), "Tasks checked off")
        XCTAssertEqual(tasks.listButton(at: now), "My tasks")
        XCTAssertFalse(tasks.isSleepTime(at: morning))
        XCTAssertFalse(session().steps.contains(where: \.checked))
    }

    func testPhraseMatchingKeepsWordsNumbersAndUnicode() {
        XCTAssertTrue(PersonalShieldPhrase.matches("  READ   10 pages!! ", phrase: "Read 10 pages"))
        XCTAssertTrue(PersonalShieldPhrase.matches("Set out tomorrows clothes", phrase: "Set out tomorrow’s clothes"))
        XCTAssertTrue(PersonalShieldPhrase.matches("ＣＡＦÉ", phrase: "Cafe\u{301}"))
        XCTAssertFalse(PersonalShieldPhrase.matches("read 100 pages", phrase: "Read 10 pages"))
        XCTAssertFalse(PersonalShieldPhrase.matches("readpages", phrase: "Read pages"))
        XCTAssertFalse(PersonalShieldPhrase.matches("...", phrase: "!"))
        XCTAssertFalse(PersonalShieldPhrase.matches("", phrase: "Read"))
    }

    func testPersonalExitIsFreshOneUseAndCannotReplaceItsPhrase() {
        let id = UUID()
        var machine = EmergencyExitChallengeMachine()
        _ = machine.begin(for: id, phrase: "Read 10 pages")
        XCTAssertFalse(machine.consumeConfirmation(for: id))
        XCTAssertFalse(machine.submitReason("x", for: id))
        XCTAssertFalse(machine.submitConfirmation("Read 11 pages", for: id))
        XCTAssertTrue(machine.submitConfirmation("read 10 pages.", for: id))
        XCTAssertTrue(machine.consumeConfirmation(for: id))
        XCTAssertFalse(machine.consumeConfirmation(for: id))
        _ = machine.begin(for: id, phrase: "Read 10 pages")
        XCTAssertFalse(machine.challenge?.canConfirm == true)
        XCTAssertFalse(machine.submitConfirmation("Read 10 pages", for: UUID()))
        XCTAssertNil(machine.challenge)
    }

    func testRouteIsOneUseBoundedAndRejectsOtherOwnersRevisionsAndOccurrences() throws {
        let suite = "personal-shield-test-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let value = session()
        let projection = PersonalShieldProjection(session: value, scheduleID: value.id, revision: 2, epoch: 3)
        let snapshot = QuietTimeShieldPresentationSnapshot(runID: value.id, revision: 1, registryRevision: 2,
            registryEpoch: 3, role: .primaryWindDown, protectedSessionInterval: value.interval,
            windDownInterval: value.interval, morningQuietInterval: value.interval, updatedAt: now)
        defaults.set(try JSONEncoder().encode(snapshot), forKey: QuietTimeShieldPresentationStorage.scheduleKey)
        PersonalShieldStorage.save(projection, to: defaults)
        XCTAssertTrue(PersonalShieldStorage.request(.briefAccess, in: defaults, at: now))
        let route = try XCTUnwrap(PersonalShieldStorage.consumeRoute(from: defaults))
        XCTAssertTrue(route.matches(projection, at: now.addingTimeInterval(120)))
        XCTAssertFalse(route.matches(projection, at: now.addingTimeInterval(121)))
        XCTAssertFalse(route.matches(projection, at: now.addingTimeInterval(-1)))
        XCTAssertNil(PersonalShieldStorage.consumeRoute(from: defaults))
        XCTAssertFalse(route.matches(.init(session: value, scheduleID: value.id, revision: 3, epoch: 3), at: now))
        XCTAssertFalse(route.matches(.init(session: value, scheduleID: value.id, revision: 2, epoch: 4), at: now))
        XCTAssertFalse(route.matches(.init(session: session(owner: "account:B"), scheduleID: value.id, revision: 2, epoch: 3), at: now))
        XCTAssertFalse(PersonalShieldStorage.request(.endSession, in: defaults, at: now))
        XCTAssertFalse(PersonalShieldStorage.request(.checklist, in: defaults, at: value.interval.end))
        PersonalShieldStorage.clear(from: defaults)
        XCTAssertNil(PersonalShieldStorage.projection(from: defaults))
    }

    func testEmptyAndLongTasksKeepExactPersonalWords() {
        XCTAssertEqual(PersonalShieldSession.taskTitles(["  Read 10 pages  ", "", "Make tea", "Ignored"]), ["Read 10 pages", "Make tea"])
        var value = session(role: .additionalQuiet)
        let title = String(repeating: "A", count: 120)
        value.steps = [PersonalShieldStep(id: UUID(), title: title), PersonalShieldStep(id: UUID(), title: "Make tea")]
        XCTAssertEqual(value.phrase(at: now), title)
        XCTAssertTrue(value.summary(at: now).contains(title))
        value.steps = []
        XCTAssertEqual(value.title(at: now), "My Phone Away")
        XCTAssertFalse(value.isSleepTime(at: now))
        let emptyMorning = PersonalShieldSession(id: UUID(), owner: "guest", interval: value.interval,
            role: .primaryWindDown, bedtime: now, morningStart: now, steps: [], morningSteps: [],
            goal: "Evening only", morningGoal: nil)
        XCTAssertEqual(emptyMorning.summary(at: now), "Screen-Free Morning is on.")
        XCTAssertEqual(emptyMorning.phrase(at: now), "Put my phone away")
        value.steps = [PersonalShieldStep(id: UUID(), title: "...")]
        XCTAssertEqual(value.phrase(at: now), "Time for myself")
    }
}
