import XCTest

final class WindDownRoutineTextTests: XCTestCase {
    func testCommitTrimsEdgesButPreservesInternalSpaces() {
        XCTAssertEqual(PhoneFreeCue.normalized("  make  room  "), "make  room")
    }

    func testTrailingEditingSpaceIsOnlyRemovedAtCommit() {
        let draft = "Read a page "
        XCTAssertEqual(PhoneFreeCue.normalized(draft), "Read a page")
        XCTAssertEqual(WindDownRoutineStep.custom(draft, phase: .evening).title, "Read a page")
    }

    func testUnicodeAndLengthRemainSafe() {
        let text = "🐑 make room for 🌙"
        XCTAssertEqual(PhoneFreeCue.normalized(text), text)
        let long = PhoneFreeCue.normalized(String(repeating: "🧡", count: 200))
        XCTAssertEqual(long?.count, PhoneFreeCue.maximumTextLength)
    }

    func testEmptyCustomTextClearsForEitherPhase() {
        XCTAssertNil(PhoneFreeCue.normalized(" \n\t"))
        XCTAssertNil(WindDownRoutineStep.custom("", phase: .evening).customText)
        XCTAssertNil(WindDownRoutineStep.custom("", phase: .morning).customText)
    }
}
