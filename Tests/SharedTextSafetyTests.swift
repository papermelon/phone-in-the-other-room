import XCTest

final class SharedTextSafetyTests: XCTestCase {
    func testConsentIsPartitionedByImmutableAccount() {
        let first = UUID(), second = UUID()
        let defaults = UserDefaults(suiteName: "SharedTextSafetyTests.\(UUID())")!
        defaults.set(SharedTextSafety.version, forKey: SharedTextSafety.consentKey(ownerID: first))
        XCTAssertEqual(defaults.integer(forKey: SharedTextSafety.consentKey(ownerID: first)), 1)
        XCTAssertEqual(defaults.integer(forKey: SharedTextSafety.consentKey(ownerID: second)), 0)
    }

    func testOnlyReviewErrorsMayCarryAnExactConfirmationToken() {
        let token = String(repeating: "a", count: 64)
        for code in ["shared_text_consent_required", "shared_text_review_required", "shared_text_rejected", "shared_text_unavailable", "shared_text_too_large"] {
            let body = Data("{\"code\":\"\(code)\",\"reviewToken\":\"\(token)\"}".utf8)
            let error = NightFlockRemoteError.decode(statusCode: 422, data: body)
            XCTAssertEqual(error.reviewToken, code == "shared_text_review_required" ? token : nil)
            XCTAssertFalse(error.allowsSchemaFallback)
            XCTAssertEqual(error.retryable, code == "shared_text_unavailable")
        }
        for token in ["", "bad", String(repeating: "a", count: 65), String(repeating: "Z", count: 64)] {
            let error = NightFlockRemoteError.decode(statusCode: 422,
                data: Data("{\"code\":\"shared_text_review_required\",\"reviewToken\":\"\(token)\"}".utf8))
            XCTAssertNil(error.reviewToken)
        }
    }

    func testAnOutageRetriesWithoutAuthenticationOrAccountMutation() {
        let error = NightFlockRemoteError.decode(statusCode: 503,
            data: Data(#"{"code":"shared_text_unavailable","retryable":false}"#.utf8))
        XCTAssertTrue(error.retryable)
        XCTAssertEqual(error.recovery, .retry)
        XCTAssertTrue(error.errorDescription?.contains("confirm sharing") == true)
        let recovery = NightFlockAuthenticationRecoveryPolicy.decide(remoteCode: error.code, lane: .outbox(schema: 4),
            session: .linked, expectedIdentity: .valid(UUID()))
        XCTAssertEqual(recovery.action, .none)
        XCTAssertTrue(recovery.preservesAllOutboxes)
        XCTAssertTrue(recovery.preservesRunContexts)
    }
}
