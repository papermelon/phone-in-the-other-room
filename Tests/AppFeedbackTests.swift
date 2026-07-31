import XCTest

final class AppFeedbackTests: XCTestCase {
    func testDraftTrimsMessageAndOptionalEmail() throws {
        let result = try FeedbackDraft(
            category: .bug,
            message: "  The button stayed dim after I saved.  ",
            replyEmail: "  person@example.com ",
            includeDiagnostics: true
        ).validated()

        XCTAssertEqual(result.message, "The button stayed dim after I saved.")
        XCTAssertEqual(result.replyEmail, "person@example.com")
    }

    func testBlankEmailRemainsOptional() throws {
        let result = try FeedbackDraft(
            category: .featureRequest,
            message: "It would help to see tomorrow's start time.",
            replyEmail: "   ",
            includeDiagnostics: false
        ).validated()

        XCTAssertNil(result.replyEmail)
    }

    func testShortAndOversizedMessagesAreRejected() {
        XCTAssertThrowsError(
            try FeedbackDraft(
                category: .general,
                message: "   ",
                replyEmail: "",
                includeDiagnostics: true
            ).validated()
        ) { XCTAssertEqual($0 as? FeedbackValidationError, .messageTooShort) }

        XCTAssertThrowsError(
            try FeedbackDraft(
                category: .general,
                message: "Too short",
                replyEmail: "",
                includeDiagnostics: true
            ).validated()
        ) { XCTAssertEqual($0 as? FeedbackValidationError, .messageTooShort) }

        XCTAssertThrowsError(
            try FeedbackDraft(
                category: .general,
                message: String(repeating: "a", count: 4_001),
                replyEmail: "",
                includeDiagnostics: true
            ).validated()
        ) { XCTAssertEqual($0 as? FeedbackValidationError, .messageTooLong) }
    }

    func testInvalidEmailIsRejected() {
        XCTAssertThrowsError(
            try FeedbackDraft(
                category: .bug,
                message: "The screen did not update after saving.",
                replyEmail: "not-an-email",
                includeDiagnostics: true
            ).validated()
        ) { XCTAssertEqual($0 as? FeedbackValidationError, .invalidEmail) }
    }

    func testAttachmentLimitsAreEnforced() throws {
        let valid = try FeedbackAttachment(
            data: Data(repeating: 1, count: 128),
            filename: "screenshot.jpg"
        )
        XCTAssertEqual(try [FeedbackAttachment]().validatedForFeedback().count, 0)
        XCTAssertEqual(try [valid].validatedForFeedback().count, 1)
        XCTAssertEqual(try [valid, valid, valid].validatedForFeedback().count, 3)
        XCTAssertThrowsError(try [valid, valid, valid, valid].validatedForFeedback()) {
            XCTAssertEqual($0 as? FeedbackValidationError, .tooManyAttachments)
        }
        XCTAssertThrowsError(
            try FeedbackAttachment(
                data: Data(repeating: 1, count: FeedbackAttachment.maximumBytes + 1),
                filename: "large.jpg"
            )
        ) { XCTAssertEqual($0 as? FeedbackValidationError, .attachmentTooLarge) }
    }

    func testReceiptTimestampParsesSupabaseFractionalSeconds() {
        XCTAssertNotNil(FeedbackTimestamp.parse("2026-07-31T19:06:18.331954+00:00"))
        XCTAssertNotNil(FeedbackTimestamp.parse("2026-07-31T19:06:18Z"))
    }
}
