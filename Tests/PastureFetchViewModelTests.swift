import XCTest

@MainActor final class PastureFetchViewModelTests: XCTestCase {
    private let ollie = PastureSceneEntityID.ollie(pastureIndex: 0)

    func testExplicitPlayExplainsActiveSessionPauseAndResumesAfterSession() {
        let scene = PastureSceneController()
        func configure(active: Bool) {
            scene.configure(activeSheep: [], pastureCount: 1, layoutSeed: 1,
                            activePastureIndex: 0, persistedSnapshot: nil,
                            reduceMotion: true, isWindDownActive: active, onPersist: { _ in })
        }
        configure(active: true)
        let positions = scene.positions
        scene.fetch()
        XCTAssertTrue(scene.showsPlayPaused)
        XCTAssertFalse(scene.fetchGame.isPresented)
        scene.showsPlayPaused = false
        scene.gather()
        XCTAssertTrue(scene.showsPlayPaused)
        XCTAssertNil(scene.playMessage)
        XCTAssertEqual(scene.positions, positions)

        configure(active: false)
        XCTAssertFalse(scene.showsPlayPaused)
        scene.fetch()
        XCTAssertTrue(scene.fetchGame.isPresented)
        configure(active: true)
        XCTAssertFalse(scene.fetchGame.isPresented, "Starting a session still cancels play")
        scene.stop()
    }

    func testTapAndCancelledAimDoNotThrowButSwipeStartsOnlyOneRound() {
        let model = PastureFetchViewModel()
        model.begin(positions: [ollie: .init(x: 0.8, y: 0.7)], ollie: ollie, reduceMotion: false)
        model.flickBall(translation: .init(x: 0, y: 0), predictedTranslation: .init(x: 0, y: 0))
        XCTAssertTrue(model.isReady)
        XCTAssertNil(model.frame)
        let travel = PastureScenePoint(x: -0.2, y: -0.2)
        model.updateAim(translation: travel, predictedTranslation: travel)
        XCTAssertNotNil(model.aim)
        model.cancelAim()
        XCTAssertNil(model.aim)
        XCTAssertTrue(model.isReady)
        model.flickBall(translation: travel, predictedTranslation: travel)
        XCTAssertFalse(model.isReady)
        XCTAssertNotNil(model.frame)
        model.updateAim(translation: travel, predictedTranslation: travel)
        XCTAssertNil(model.aim)
        model.stop()
        model.flickBall(translation: travel, predictedTranslation: travel)
        XCTAssertNil(model.frame)
    }

    func testSleepingOllieWakesInPlaceBeforeThrowIsAllowed() async throws {
        let model = PastureFetchViewModel()
        let resting = "dog/dog_ollie_motion_pose_09"
        let position = PastureScenePoint(x: 0.8, y: 0.7)
        model.begin(positions: [ollie: position], ollie: ollie, reduceMotion: false, restingAsset: resting)
        XCTAssertFalse(model.isReady)
        XCTAssertEqual(model.wakeAssetName, resting)
        model.throwBall(at: .init(x: 0.2, y: 0.6))
        XCTAssertNil(model.frame)
        XCTAssertEqual(model.positions[ollie], position)
        for _ in 0..<30 where !model.isReady { try await Task.sleep(for: .milliseconds(50)) }
        XCTAssertTrue(model.isReady)
        XCTAssertNil(model.wakeAssetName)
        XCTAssertEqual(model.positions[ollie], position)
        model.throwBall(at: .init(x: 0.2, y: 0.6))
        XCTAssertNotNil(model.frame)
        model.stop()
    }

    func testCancellingWakeCannotStartAThrowOrReviveOldScene() async throws {
        let model = PastureFetchViewModel()
        model.begin(positions: [ollie: .init(x: 0.8, y: 0.7)], ollie: ollie,
                    reduceMotion: true, restingAsset: "dog/dog_ollie_motion_pose_09")
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.wakeAssetName, "dog/dog_ollie_motion_pose_09")
        model.stop()
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertFalse(model.isPresented)
        XCTAssertNil(model.wakeAssetName)
        XCTAssertNil(model.frame)
    }

    func testOnlyOneThrowUntilReturnAndStopCancelsRound() async throws {
        let model = PastureFetchViewModel()
        model.begin(positions: [ollie: .init(x: 0.8, y: 0.7)], ollie: ollie, reduceMotion: false)
        model.throwBall(at: .init(x: 0.2, y: 0.6))
        XCTAssertFalse(model.isReady)
        try await Task.sleep(for: .milliseconds(80))
        let elapsed = model.elapsed
        model.throwBall(at: .init(x: 0.8, y: 0.6))
        XCTAssertEqual(model.elapsed, elapsed, "A second throw must not restart the clock")
        model.stop()
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertFalse(model.isPresented)
        XCTAssertNil(model.frame)
        XCTAssertTrue(model.positions.isEmpty)
        model.throwBall(at: .init(x: 0.2, y: 0.6))
        XCTAssertNil(model.frame, "A stopped scene cannot start a throw")
    }

    func testNewSceneCannotReceiveCancelledRoundUpdates() async throws {
        let model = PastureFetchViewModel()
        model.begin(positions: [ollie: .init(x: 0.8, y: 0.7)], ollie: ollie, reduceMotion: false)
        model.throwBall(at: .init(x: 0.2, y: 0.6))
        let next = PastureSceneEntityID.ollie(pastureIndex: 1)
        model.begin(positions: [next: .init(x: 0.7, y: 0.7)], ollie: next, reduceMotion: true)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.positions.count, 1)
        XCTAssertNotNil(model.positions[next])
        XCTAssertTrue(model.isReady)
        XCTAssertNil(model.frame)
        model.stop()
    }
    func testPracticeScoresAtLandingCompletesAfterHandoffAndRejectsPresets() throws {
        let model = PastureFetchViewModel()
        model.begin(positions: [ollie: .init(x: 0.8, y: 0.7)], ollie: ollie, reduceMotion: true)
        var completions: [PastureFetchPractice] = []
        model.startPractice { completions.append($0) }
        model.throwBall(at: PastureFetchPractice.targets[0].point)
        XCTAssertNil(model.frame)
        for (index, target) in PastureFetchPractice.targets.enumerated() {
            let start = try XCTUnwrap(model.positions[ollie])
            let travel = PastureScenePoint(x: (target.point.x - model.origin.x) / 1.35,
                                           y: (target.point.y - model.origin.y) / 1.35)
            model.flickBall(translation: travel, predictedTranslation: travel)
            let round = PastureFetchRound(origin: model.origin, target: target.point, ollieStart: start)
            model.advance(round: round, elapsed: round.flightDuration - 0.01, delta: 0, ollie: ollie)
            XCTAssertEqual(model.practice?.scores.count, index)
            model.advance(round: round, elapsed: round.flightDuration, delta: 0, ollie: ollie)
            model.advance(round: round, elapsed: round.flightDuration + 0.01, delta: 0, ollie: ollie)
            XCTAssertEqual(model.practice?.scores.count, index + 1)
            XCTAssertEqual(model.practiceTarget, target, "Keep the ring on the landing until handoff")
            XCTAssertTrue(completions.isEmpty)
            model.advance(round: round, elapsed: round.duration, delta: 0, ollie: ollie)
        }
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.score, 15)
        XCTAssertFalse(model.canThrow)
        model.aimBall(heading: 0, strength: 30, launch: true)
        XCTAssertTrue(model.isReady)
        model.startPractice { completions.append($0) }
        XCTAssertEqual(model.practice?.scores.count, 0)
        model.aimBall(heading: -90, strength: 60, launch: true)
        XCTAssertFalse(model.isReady)
        model.stop()
        XCTAssertEqual(completions.count, 1, "Abandoned rounds do not publish a best")
        XCTAssertNil(model.practice)
    }

    func testReduceMotionRefreshKeepsPracticeButActiveSessionStillCancelsIt() {
        let scene = PastureSceneController()
        func configure(active: Bool) {
            scene.configure(activeSheep: [], pastureCount: 1, layoutSeed: 1,
                            activePastureIndex: 0, persistedSnapshot: nil,
                            reduceMotion: true, isWindDownActive: active, onPersist: { _ in })
        }
        configure(active: false)
        scene.fetch()
        scene.fetchGame.startPractice { _ in XCTFail("An interrupted round cannot publish a best") }
        configure(active: false)
        XCTAssertNotNil(scene.fetchGame.practice)
        XCTAssertTrue(scene.fetchGame.isPresented)
        configure(active: true)
        XCTAssertFalse(scene.fetchGame.isPresented)
        XCTAssertNil(scene.fetchGame.practice)
        scene.stop()
    }

}
