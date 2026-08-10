import XCTest

final class QuietNoteTextTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "counting-sheep-quiet-note-tests")!
        defaults.removePersistentDomain(forName: "counting-sheep-quiet-note-tests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "counting-sheep-quiet-note-tests")
        defaults = nil
        super.tearDown()
    }

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

    func testSavedTextUsesTheExistingSharedStorageContract() {
        let saved = QuietNoteText.save("  Leave the phone by the door.  ", to: defaults)

        XCTAssertEqual(saved, "Leave the phone by the door.")
        XCTAssertEqual(QuietNoteText.savedText(from: defaults), saved)
        XCTAssertEqual(defaults.string(forKey: QuietNoteText.storageKey), saved)
    }

    func testWidgetEditorURLIsOnlyAcceptedForTheQuietNoteRoute() {
        XCTAssertTrue(QuietNoteText.isEditorURL(QuietNoteText.editorURL))
        XCTAssertFalse(QuietNoteText.isEditorURL(URL(string: "countingsheep://home")!))
        XCTAssertFalse(QuietNoteText.isEditorURL(URL(string: "otherapp://quiet-note")!))
    }
}
