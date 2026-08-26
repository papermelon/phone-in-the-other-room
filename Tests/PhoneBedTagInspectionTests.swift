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

    func testNormalPairingRejectsOccupiedCountingSheepCredentials() {
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

    func testReinstallOrUpdateRecoveryWorksWithAnEmptyLocalLibrary() {
        XCTAssertEqual(
            PhoneBedTagProvisionPolicy.resolve(
                intent: .settingsResetAndPair,
                inspection: .credential(digest: "credential-from-another-install"),
                activeCredentialDigests: [],
                retiredCredentialDigests: []
            ),
            .resetRequired(digest: "credential-from-another-install")
        )
    }

    func testForgottenCredentialUsesTheSameExplicitRecoveryDecision() {
        XCTAssertEqual(
            PhoneBedTagProvisionPolicy.resolve(
                intent: .settingsResetAndPair,
                inspection: .credential(digest: "forgotten"),
                activeCredentialDigests: [],
                retiredCredentialDigests: ["forgotten"]
            ),
            .resetRequired(digest: "forgotten")
        )
    }

    func testRecoveryRequiresTheSameCredentialToBePresentForTheWriteSession() {
        XCTAssertEqual(
            PhoneBedTagProvisionPolicy.resolve(
                intent: .settingsResetAndPair,
                inspection: .credential(digest: "candidate"),
                activeCredentialDigests: [],
                retiredCredentialDigests: [],
                expectedCredentialDigest: "candidate"
            ),
            .mayProceed
        )
        XCTAssertEqual(
            PhoneBedTagProvisionPolicy.resolve(
                intent: .settingsResetAndPair,
                inspection: .credential(digest: "different-tag"),
                activeCredentialDigests: [],
                retiredCredentialDigests: [],
                expectedCredentialDigest: "candidate"
            ),
            .abort
        )
        XCTAssertEqual(
            PhoneBedTagProvisionPolicy.resolve(
                intent: .settingsResetAndPair,
                inspection: .empty,
                activeCredentialDigests: [],
                retiredCredentialDigests: [],
                expectedCredentialDigest: "candidate"
            ),
            .abort
        )
    }

    func testResetFlowPairsBlankTagsNormallyAndRejectsForeignContents() {
        XCTAssertEqual(
            PhoneBedTagProvisionPolicy.resolve(
                intent: .settingsResetAndPair,
                inspection: .empty,
                activeCredentialDigests: [],
                retiredCredentialDigests: []
            ),
            .mayProceed
        )
        XCTAssertEqual(
            PhoneBedTagProvisionPolicy.resolve(
                intent: .settingsResetAndPair,
                inspection: .foreign,
                activeCredentialDigests: [],
                retiredCredentialDigests: []
            ),
            .abort
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
                error: .none,
                isCountingSheepCredential: false
            ),
            .foreign
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
