import XCTest

final class QuietNoteTextTests: XCTestCase {
    func testMissingOrWhitespaceOnlyTextUsesTheDefault() {
        XCTAssertEqual(QuietNoteText.normalized(nil), QuietNoteText.defaultText)
        XCTAssertEqual(QuietNoteText.normalized(" \n\t "), QuietNoteText.defaultText)
    }

    func testWhitespaceAndNewlinesCollapseToSingleSpaces() {
        XCTAssertEqual(
            QuietNoteText.normalized("Put\n your\tphone  to bed."),
            "Put your phone to bed."
        )
    }

    func testTextIsLimitedByUnicodeCharacters() {
        let input = String(repeating: "a", count: QuietNoteText.maximumLength + 12)

        XCTAssertEqual(
            QuietNoteText.normalized(input).count,
            QuietNoteText.maximumLength
        )
    }

    func testEmojiAndNonLatinTextRemainIntact() {
        let input = "🌙 放下手机，给夜晚一点安静。"

        XCTAssertEqual(QuietNoteText.normalized(input), input)
    }
}
