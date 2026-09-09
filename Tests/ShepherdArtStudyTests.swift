#if DEBUG
import XCTest

final class ShepherdArtStudyTests: XCTestCase {
    func testStudyAppearanceDoesNotCoupleHeadToClothingHairOrHat() {
        var appearance = ShepherdStudyAppearance.round
        appearance.hat = true
        for head in ShepherdStudySilhouette.allCases {
            appearance.head = head
            XCTAssertEqual(appearance.hair, .long)
            XCTAssertEqual(appearance.outfit, .dress)
            XCTAssertEqual(appearance.eyes, .open)
            XCTAssertTrue(appearance.hat)
        }
    }

    func testHatRemovalRestoresAppearanceWithoutChangingIdentity() {
        let original = ShepherdStudyAppearance.round
        var dressed = original
        dressed.hat = true
        dressed.hat = false
        XCTAssertEqual(dressed, original)
    }

    func testDirectionCycleReturnsToFrontAndRearDoesNotExposeFace() {
        var direction = ShepherdStudyDirection.front
        var visited = Set<ShepherdStudyDirection>()
        for _ in 0..<5 { visited.insert(direction); direction = direction.next }
        XCTAssertEqual(visited.count, 5)
        XCTAssertEqual(direction, .front)
        XCTAssertTrue(ShepherdStudyDirection.back.hidesFace)
        XCTAssertTrue(ShepherdStudyDirection.rearThreeQuarter.hidesFace)
        XCTAssertFalse(ShepherdStudyDirection.side.hidesFace)
    }

    func testReducedMotionAndInactiveSceneAlwaysYieldStillPose() {
        for motion in ShepherdStudyMotion.allCases {
            for time in [0.1, 0.7, 4.4, 100.0] {
                XCTAssertEqual(ShepherdStudyMotionRules.pose(at: time, motion: motion, reduceMotion: true), .still)
                XCTAssertEqual(ShepherdStudyMotionRules.pose(at: time, motion: motion, isActive: false), .still)
            }
        }
    }

    func testWalkingAlwaysHasAGroundedSupportingFoot() {
        for step in 0..<180 {
            let pose = ShepherdStudyMotionRules.pose(at: Double(step) / 180 * ShepherdStudyMotionRules.cycleDuration, motion: .walk)
            XCTAssertTrue(pose.leftFoot.lift == 0 || pose.rightFoot.lift == 0)
            XCTAssertGreaterThanOrEqual(pose.leftFoot.lift, 0)
            XCTAssertLessThanOrEqual(pose.leftFoot.lift, 6)
            XCTAssertLessThanOrEqual(abs(pose.leftFoot.travel), 7.0001)
        }
    }

    func testWalkLoopsWithoutDiscontinuityAndInvalidTimeIsSafe() {
        let first = ShepherdStudyMotionRules.pose(at: 0, motion: .walk)
        let next = ShepherdStudyMotionRules.pose(at: ShepherdStudyMotionRules.cycleDuration, motion: .walk)
        XCTAssertEqual(first, next)
        XCTAssertEqual(ShepherdStudyMotionRules.pose(at: .nan, motion: .walk), .still)
        XCTAssertEqual(ShepherdStudyMotionRules.pose(at: .infinity, motion: .idle), .still)
    }

    func testIdleBlinkIsBriefAndReturnsToOpenEyes() {
        XCTAssertFalse(ShepherdStudyMotionRules.pose(at: 4.3, motion: .idle).eyesClosed)
        XCTAssertTrue(ShepherdStudyMotionRules.pose(at: 4.4, motion: .idle).eyesClosed)
        XCTAssertFalse(ShepherdStudyMotionRules.pose(at: 4.5, motion: .idle).eyesClosed)
    }
}
#endif
