import XCTest

final class OllieCompanionAnimationTests: XCTestCase {
    func testGentleScheduleSeparatesSingleGestureVariationsWithNeutralHolds() {
        let actions = OllieCompanionAnimationSchedule.gentle.segments.map(\.action)
        let singleGestureActions: Set<OllieCompanionAction> = [.headTilt, .earTuck, .tongueGreeting]

        for (index, action) in actions.enumerated() where singleGestureActions.contains(action) {
            if index > 0 { XCTAssertEqual(actions[index - 1], .neutral) }
            if index < actions.count - 1 { XCTAssertEqual(actions[index + 1], .neutral) }
        }
    }

    func testProductionScheduleShowsFirstGestureAndCompleteSequenceWithinFortySeconds() {
        let schedule = OllieCompanionAnimationSchedule.gentle
        let firstGestureAt = schedule.segments.prefix { $0.action == .neutral }
            .reduce(0) { $0 + $1.duration }

        XCTAssertLessThanOrEqual(firstGestureAt, 1)
        XCTAssertEqual(schedule.action(at: firstGestureAt), .headTilt)
        XCTAssertEqual(schedule.cycleDuration, 39.39, accuracy: 0.000_001)
        XCTAssertLessThan(schedule.cycleDuration, 40)

        var elapsed: TimeInterval = 0
        var reachedActions = [schedule.action(at: elapsed)]
        while let next = schedule.nextTransition(after: elapsed), next < schedule.cycleDuration {
            reachedActions.append(schedule.action(at: next))
            elapsed = next
        }
        XCTAssertEqual(reachedActions, schedule.segments.map(\.action))
    }

    func testScheduleContainsFiveSecondRestSequenceWithoutTongueGreeting() {
        let schedule = OllieCompanionAnimationSchedule.gentle
        let actions = schedule.segments.map(\.action)
        let restSequence = actions.firstIndex(of: .settleToRest)!...actions.firstIndex(of: .rise)!

        XCTAssertEqual(Array(actions[restSequence]), [.settleToRest, .resting, .rise])
        XCTAssertEqual(schedule.segments.first(where: { $0.action == .resting })?.duration, 5)
        XCTAssertFalse(Array(actions[restSequence]).contains(.tongueGreeting))
    }

    func testSpriteManifestSelectsFramesAtExactBoundaries() {
        let earTuck = OllieCompanionSpriteManifest.production.sequence(for: .earTuck)!

        XCTAssertEqual(earTuck.frame(at: 0)?.poseIdentifier, 1)
        XCTAssertEqual(earTuck.frame(at: 0.159_999)?.poseIdentifier, 1)
        XCTAssertEqual(earTuck.frame(at: 0.16)?.poseIdentifier, 2)
        XCTAssertEqual(earTuck.frame(at: 0.32)?.poseIdentifier, 3)
        XCTAssertNil(earTuck.frame(at: 0.60))
    }

    func testGentleScheduleUsesCompleteAuthoredSequenceDurations() {
        let schedule = OllieCompanionAnimationSchedule.gentle
        let manifest = OllieCompanionSpriteManifest.production

        for segment in schedule.segments where segment.action != .neutral {
            guard let sequence = manifest.sequence(for: segment.action) else {
                XCTFail("Missing sequence for \(segment.action.rawValue)")
                continue
            }
            XCTAssertEqual(
                segment.duration,
                sequence.duration,
                accuracy: 0.000_001,
                "\(segment.action.rawValue) must not cut off or outlast its authored frames"
            )
        }
    }

    func testNextWakesAreStrictlyAfterEveryScheduleAndSpriteBoundary() {
        let schedule = OllieCompanionAnimationSchedule.gentle
        var elapsed: TimeInterval = 0
        for _ in 0..<(schedule.segments.count * 2) {
            let next = schedule.nextTransition(after: elapsed)!
            XCTAssertGreaterThan(next, elapsed)
            elapsed = next
        }

        for sequence in OllieCompanionSpriteManifest.production.sequences.values {
            var actionElapsed: TimeInterval = 0
            while let next = sequence.nextFrameTransition(after: actionElapsed) {
                XCTAssertGreaterThan(next, actionElapsed)
                actionElapsed = next
            }
        }
    }

    func testInvalidDurationsAndElapsedValuesResolveSafely() {
        let schedule = OllieCompanionAnimationSchedule(segments: [
            .init(.neutral, duration: .infinity), .init(.headTilt, duration: -1), .init(.neutral, duration: 2)
        ])

        XCTAssertEqual(schedule.segments.count, 1)
        XCTAssertEqual(schedule.frame(at: .nan), .neutral)
        XCTAssertNil(schedule.nextTransition(after: .infinity))
    }

    func testIncompleteRestGroupDisablesEveryRestAction() {
        let manifest = OllieCompanionSpriteManifest.production
        var available = manifest.requiredAssetNames(for: .resting, accessoryItemID: nil)!
        available.remove("dog/dog_ollie_motion_pose_07")
        available.remove("dog/dog_ollie_motion_pose_11")

        XCTAssertFalse(manifest.canRender(action: .settleToRest, accessoryItemID: nil, availableAssetNames: available))
        XCTAssertFalse(manifest.canRender(action: .resting, accessoryItemID: nil, availableAssetNames: available))
        XCTAssertFalse(manifest.canRender(action: .rise, accessoryItemID: nil, availableAssetNames: available))
    }

    func testPauseThenResumeRestartsAtNeutralInsteadOfMidAction() {
        let schedule = OllieCompanionAnimationSchedule(segments: [
            .init(.neutral, duration: 1), .init(.headTilt, duration: 1)
        ])
        let start: TimeInterval = 100
        var playback = OllieCompanionAnimationPlayback()

        playback.resume(at: start)
        XCTAssertEqual(playback.frame(at: start + 1.2, schedule: schedule).action, .headTilt)
        playback.pause(at: start + 1.2, schedule: schedule)
        XCTAssertEqual(playback.frozenFrame.action, .headTilt)

        playback.resume(at: start + 10)
        XCTAssertEqual(playback.frame(at: start + 10, schedule: schedule).action, .neutral)
    }

    func testReducedMotionNeverKeepsAnAnimatedPose() {
        let schedule = OllieCompanionAnimationSchedule(segments: [
            .init(.neutral, duration: 1), .init(.headTilt, duration: 1)
        ])
        let start: TimeInterval = 100
        var playback = OllieCompanionAnimationPlayback()

        playback.resume(at: start)
        XCTAssertEqual(playback.frame(at: start + 1.2, schedule: schedule).action, .headTilt)
        playback.settleForReducedMotion()

        XCTAssertEqual(playback.frozenFrame, .neutral)
        XCTAssertNil(playback.elapsed(at: start + 2))
    }
}
