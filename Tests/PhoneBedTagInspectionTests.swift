import XCTest

final class PhoneBedTagInspectionTests: XCTestCase {
    func testUnreadableInspectionAbortsWithoutOverwriting() {
        XCTAssertEqual(
            PhoneBedTagProvisionPolicy.resolve(
                intent: .normalPairing,
                inspection: .unreadable,
                activeCredentialDigests: ["existing"],
                retiredCredentialDigests: []
            ),
            .abort
        )
    }

    func testKnownCredentialIsReportedAsAlreadyPaired() {
        XCTAssertEqual(
            PhoneBedTagProvisionPolicy.resolve(
                intent: .normalPairing,
                inspection: .credential(digest: "existing"),
                activeCredentialDigests: ["existing"],
                retiredCredentialDigests: []
            ),
            .alreadyPaired(digest: "existing")
        )
    }

    func testPreviouslyPairedCredentialIsRejectedAsStale() {
        XCTAssertEqual(
            PhoneBedTagProvisionPolicy.resolve(
                intent: .normalPairing,
                inspection: .credential(digest: "old"),
                activeCredentialDigests: ["active"],
                retiredCredentialDigests: ["old"]
            ),
            .previouslyPaired(digest: "old")
        )
    }

    func testActiveCredentialWinsOverAStaleHistoryEntry() {
        XCTAssertEqual(
            PhoneBedTagProvisionPolicy.resolve(
                intent: .normalPairing,
                inspection: .credential(digest: "active"),
                activeCredentialDigests: ["active"],
                retiredCredentialDigests: ["active"]
            ),
            .alreadyPaired(digest: "active")
        )
    }

    func testOnlyBlankTagMayProceedForNormalPairing() {
        XCTAssertEqual(
            PhoneBedTagProvisionPolicy.resolve(
                intent: .normalPairing,
                inspection: .credential(digest: "other"),
                activeCredentialDigests: ["existing"],
                retiredCredentialDigests: []
            ),
            .abort
        )
        XCTAssertEqual(
            PhoneBedTagProvisionPolicy.resolve(
                intent: .normalPairing,
                inspection: .empty,
                activeCredentialDigests: ["existing"],
                retiredCredentialDigests: []
            ),
            .mayProceed
        )
    }

    func testRetiredTagResyncAllowsOnlyRetiredCredential() {
        XCTAssertEqual(
            PhoneBedTagProvisionPolicy.resolve(
                intent: .settingsRetiredTagResync,
                inspection: .credential(digest: "retired"),
                activeCredentialDigests: ["active"],
                retiredCredentialDigests: ["retired"]
            ),
            .mayProceed
        )
        XCTAssertEqual(
            PhoneBedTagProvisionPolicy.resolve(
                intent: .settingsRetiredTagResync,
                inspection: .credential(digest: "unknown"),
                activeCredentialDigests: ["active"],
                retiredCredentialDigests: ["retired"]
            ),
            .abort
        )
    }

    func testReadErrorWinsOverMessageExceptDocumentedZeroLengthWritableTag() {
        XCTAssertEqual(
            PhoneBedTagReadResolutionPolicy.resolve(
                credentialDigest: "retired",
                error: .unreadable
            ),
            .unreadable
        )
        XCTAssertEqual(
            PhoneBedTagReadResolutionPolicy.resolve(
                credentialDigest: "occupied",
                error: .zeroLengthWritableTag
            ),
            .empty
        )
        XCTAssertEqual(
            PhoneBedTagReadResolutionPolicy.resolve(
                credentialDigest: "occupied",
                error: .none
            ),
            .credential(digest: "occupied")
        )
    }

    func testResyncRejectsUnreadableAndUnknownOccupiedCredentialsForBothSlots() {
        for _ in PhoneBedTagRole.allCases {
            XCTAssertEqual(
                PhoneBedTagProvisionPolicy.resolve(
                    intent: .settingsRetiredTagResync,
                    inspection: .unreadable,
                    activeCredentialDigests: ["active"],
                    retiredCredentialDigests: ["retired"]
                ),
                .abort
            )
            XCTAssertEqual(
                PhoneBedTagProvisionPolicy.resolve(
                    intent: .settingsRetiredTagResync,
                    inspection: .credential(digest: "unknown"),
                    activeCredentialDigests: ["active"],
                    retiredCredentialDigests: ["retired"]
                ),
                .abort
            )
        }
    }

    func testOnlyConfirmedPhysicalWritePermitsPrimaryOrBackupSlotMutation() {
        XCTAssertTrue(PhoneBedTagSlotCommitPolicy.shouldCommit(.physicalWriteSucceeded))
        for outcome in [
            PhoneBedTagSlotCommitOutcome.cancelled,
            .readFailed,
            .queryFailed,
            .writeFailed
        ] {
            XCTAssertFalse(PhoneBedTagSlotCommitPolicy.shouldCommit(outcome))
        }
    }
}
