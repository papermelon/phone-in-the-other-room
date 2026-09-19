import XCTest

final class CampfireVisibilityTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testMigrationPreservesPrivateChoiceAndNeverEnrollsGlobal() {
        XCTAssertEqual(CampfireVisibilityRules.initialVisibility(saved: nil, hasPrivateAgreement: true), .party)
        XCTAssertEqual(CampfireVisibilityRules.initialVisibility(saved: nil, hasPrivateAgreement: false), .off)
        XCTAssertEqual(CampfireVisibilityRules.initialVisibility(saved: .off, hasPrivateAgreement: true), .off)
    }

    func testPublicPublicationRequiresTheExactAcceptedReceipt() {
        let receipt = CampfireAgreement(id: UUID(), version: 1, revision: 1, enabled: true, acceptedAt: now)
        XCTAssertTrue(CampfireVisibilityRules.permitsPublicPublication(visibility: .global, capturedAgreement: receipt.id, current: receipt))
        for visibility in [CampfireVisibility.off, .party] {
            XCTAssertFalse(CampfireVisibilityRules.permitsPublicPublication(visibility: visibility, capturedAgreement: receipt.id, current: receipt))
        }
        XCTAssertFalse(CampfireVisibilityRules.permitsPublicPublication(visibility: .global, capturedAgreement: UUID(), current: receipt))
        XCTAssertFalse(CampfireVisibilityRules.permitsPublicPublication(visibility: .global, capturedAgreement: nil, current: receipt))
        var revoked = receipt; revoked.enabled = false
        XCTAssertFalse(CampfireVisibilityRules.permitsPublicPublication(visibility: .global, capturedAgreement: receipt.id, current: revoked))
        var future = receipt; future.version = 2
        XCTAssertFalse(CampfireVisibilityRules.permitsPublicPublication(visibility: .global, capturedAgreement: receipt.id, current: future))
    }

    func testShareFromNowRoundsForwardAcrossWirePrecision() {
        let accepted = now.addingTimeInterval(0.123456)
        let start = CampfireVisibilityRules.sharingStart(requested: now.addingTimeInterval(-3600), acceptedAt: accepted)
        XCTAssertGreaterThanOrEqual(start, accepted)
        XCTAssertEqual(start, now.addingTimeInterval(1))
    }

    func testPublicAppearanceContainsNoFarmOrPrivateProfileFields() throws {
        let data = try JSONEncoder().encode(PublicCampfireAppearance())
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), Set(["skinToneID", "hairStyleID", "shepherdOutfitID", "shepherdAccessoryID"]))
    }

    func testOutboxTerminalPrecedenceAndWithdrawalFence() {
        var document = CampfireVisibilityDocument()
        var start = GlobalCampfireCommand(command: "publish")
        start.sourceID = UUID(); start.agreementID = UUID(); start.ended = false
        var end = start; end.id = UUID().uuidString; end.ended = true
        document.enqueue(start); document.enqueue(end); document.enqueue(start)
        XCTAssertEqual(document.commands, [end])
        var off = GlobalCampfireCommand(command: "agreement"); off.enabled = false
        document.enqueue(off)
        XCTAssertEqual(document.commands, [off])
    }

    func testSnapshotFreshnessCannotBeExtendedByAnOldRead() {
        XCTAssertTrue(CampfireVisibilityRules.isFresh(observedAt: now, now: now.addingTimeInterval(20)))
        XCTAssertFalse(CampfireVisibilityRules.isFresh(observedAt: now, now: now.addingTimeInterval(46)))
        XCTAssertFalse(CampfireVisibilityRules.isFresh(observedAt: now.addingTimeInterval(60), now: now))
    }

    func testShareFromNowBindsOnlyAcknowledgedPrivateReceiptAndMembershipEpoch() throws {
        let party = UUID(), epoch = UUID(), run = UUID(), command = UUID().uuidString
        var document = CampfireVisibilityDocument()
        document.runSelections[run] = .init(visibility: .party, partyIDs: [party], effectiveAt: now,
            partyAgreementIDs: [:], partyStartedAt: [:], pendingPartyAgreements: [party: .init(commandID: command, memberEpochID: epoch, revision: 2)])
        let receipt = CampfireAgreement(id: UUID(), version: 2, revision: 2, enabled: true, acceptedAt: now.addingTimeInterval(0.1))
        document.bindPrivateAgreement(partyID: party, memberEpochID: epoch, agreement: receipt)
        XCTAssertNil(document.runSelections[run]?.partyAgreementIDs?[party])
        document.acknowledgePrivateAgreement(commandID: "another-command", partyID: party, conflicted: false)
        XCTAssertEqual(document.runSelections[run]?.pendingPartyAgreements?[party]?.acknowledged, false)
        document.acknowledgePrivateAgreement(commandID: command, partyID: party, conflicted: false)
        document.bindPrivateAgreement(partyID: party, memberEpochID: UUID(), agreement: receipt)
        XCTAssertNil(document.runSelections[run]?.partyAgreementIDs?[party])
        var other = receipt; other.revision = 3
        document.bindPrivateAgreement(partyID: party, memberEpochID: epoch, agreement: other)
        XCTAssertNil(document.runSelections[run]?.partyAgreementIDs?[party])
        document.bindPrivateAgreement(partyID: party, memberEpochID: epoch, agreement: receipt)
        XCTAssertEqual(document.runSelections[run]?.partyAgreementIDs?[party], receipt.id)
        XCTAssertEqual(document.runSelections[run]?.partyStartedAt?[party], now.addingTimeInterval(1))
        document.bindPrivateAgreement(partyID: party, memberEpochID: epoch, agreement: other)
        XCTAssertEqual(document.runSelections[run]?.partyAgreementIDs?[party], receipt.id)
        XCTAssertEqual(try JSONDecoder().decode(CampfireVisibilityDocument.self, from: JSONEncoder().encode(document)), document)
    }

    func testConflictCannotAcquireAPrivateReceiptLater() {
        let party = UUID(), epoch = UUID(), run = UUID(), command = UUID().uuidString
        var document = CampfireVisibilityDocument()
        document.runSelections[run] = .init(visibility: .party, partyIDs: [party], effectiveAt: now,
            partyAgreementIDs: [:], partyStartedAt: [:], pendingPartyAgreements: [party: .init(commandID: command, memberEpochID: epoch, revision: 2)])
        document.acknowledgePrivateAgreement(commandID: command, partyID: party, conflicted: true)
        document.bindPrivateAgreement(partyID: party, memberEpochID: epoch,
            agreement: .init(id: UUID(), version: 2, revision: 2, enabled: true, acceptedAt: now))
        XCTAssertNil(document.runSelections[run]?.partyAgreementIDs?[party])
    }

    func testPublicReceiptBindsOnlyItsExplicitShareCommand() {
        let run = UUID(), command = UUID().uuidString
        var document = CampfireVisibilityDocument()
        document.runSelections[run] = .init(visibility: .global, partyIDs: [], effectiveAt: now, publicAgreementCommandID: command)
        document.selection = document.runSelections[run]
        let receipt = CampfireAgreement(id: UUID(), version: 1, revision: 1, enabled: true, acceptedAt: now.addingTimeInterval(5))
        document.bindPublicAgreement(commandID: "another-command", agreement: receipt)
        XCTAssertNil(document.runSelections[run]?.publicAgreementID)
        document.bindPublicAgreement(commandID: command, agreement: receipt)
        XCTAssertEqual(document.runSelections[run]?.publicAgreementID, receipt.id)
        XCTAssertEqual(document.selection?.publicAgreementID, receipt.id)
        XCTAssertEqual(document.runSelections[run]?.publicStartedAt, now.addingTimeInterval(5))
        document.bindPublicAgreement(commandID: command, agreement: .init(id: UUID(), version: 1, revision: 2, enabled: true, acceptedAt: now))
        XCTAssertEqual(document.runSelections[run]?.publicAgreementID, receipt.id)
    }

    func testOfflineActionsCannotCrowdOutOff() {
        var document = CampfireVisibilityDocument()
        for _ in 0..<60 { XCTAssertTrue(document.enqueue(.init(command: "report"), now: now)) }
        XCTAssertFalse(document.enqueue(.init(command: "report"), now: now))
        var enable = GlobalCampfireCommand(command: "agreement"); enable.enabled = true
        XCTAssertTrue(document.enqueue(enable, now: now))
        var off = GlobalCampfireCommand(command: "agreement"); off.enabled = false
        XCTAssertTrue(document.enqueue(off, now: now))
        XCTAssertFalse(document.commands.contains(enable))
        XCTAssertTrue(document.commands.contains(off))
        off.id = UUID().uuidString
        XCTAssertTrue(document.enqueue(off, now: now))
        XCTAssertEqual(document.commands.filter { $0.command == "agreement" }.count, 1)
    }

    func testExpiredPublicationIsPrunedWithoutLosingWithdrawal() {
        var document = CampfireVisibilityDocument()
        var start = GlobalCampfireCommand(command: "publish"); start.expiresAt = now.addingTimeInterval(60)
        document.enqueue(start, now: now)
        var off = GlobalCampfireCommand(command: "agreement"); off.enabled = false
        document.enqueue(off, now: now.addingTimeInterval(120))
        XCTAssertEqual(document.commands, [off])
    }

    func testLegacyPlanDoesNotAcquirePublicConsentOnDecode() throws {
        let plan = NightWatchPlan(intendedBedtime: now.addingTimeInterval(1800), wakeTime: now.addingTimeInterval(8 * 3600),
            protectedUntil: now.addingTimeInterval(9 * 3600), windDownMinutes: 30, morningQuietMinutes: 60,
            eveningActivity: .read, morningActivity: .openCurtains)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        json.removeValue(forKey: "campfireVisibility"); json.removeValue(forKey: "publicCampfireAgreementID")
        let restored = try JSONDecoder().decode(NightWatchPlan.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(restored.campfireVisibility)
        XCTAssertNil(restored.publicCampfireAgreementID)
    }

    @MainActor func testOwnerIsolationAndRecoveryPreserveOffAndQueuedWithdrawal() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CampfireVisibilityStore(directory: directory)
        let owner = UUID(), other = UUID()
        var document = CampfireVisibilityDocument()
        document.selection = .init(visibility: .off, partyIDs: [], effectiveAt: now)
        var withdrawal = GlobalCampfireCommand(command: "agreement"); withdrawal.enabled = false
        document.enqueue(withdrawal)
        try store.save(document, owner: owner)
        XCTAssertNil(try store.load(owner: other).selection)
        let file = directory.appendingPathComponent(owner.uuidString.lowercased() + ".json")
        try Data("interrupted".utf8).write(to: file)
        XCTAssertEqual(try store.load(owner: owner), document)
        try Data("corrupt".utf8).write(to: file.appendingPathExtension("recovery"))
        XCTAssertThrowsError(try store.load(owner: owner))
    }

    @MainActor func testFutureJournalCannotFallBackToAnOlderSharingChoice() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CampfireVisibilityStore(directory: directory), owner = UUID()
        var document = CampfireVisibilityDocument()
        document.selection = .init(visibility: .global, partyIDs: [], effectiveAt: now)
        try store.save(document, owner: owner)
        document.version = 2; document.selection?.visibility = .off
        try JSONEncoder().encode(document).write(to: directory.appendingPathComponent(owner.uuidString.lowercased() + ".json"))
        XCTAssertThrowsError(try store.load(owner: owner))
    }
}
