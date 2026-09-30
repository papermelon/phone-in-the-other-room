import XCTest

final class SocialInboxTests: XCTestCase {
    func testSupportVocabularyDoesNotRewriteLegacyHistory() {
        XCTAssertEqual(SupportMessage.allCases.count, 9)
        XCTAssertEqual(SupportMessage.title(for: "warmWave"), "Warm wave")
        XCTAssertEqual(SupportMessage.title(for: "future-message"), "A little encouragement")
        XCTAssertNil(NightFlockV4Cheer(rawValue: "restWell"))
    }

    func testInvitationLinkAcceptsOnlyOwnedHostsAndCompleteCodes() {
        let code = "ABCDEFGHJKLM"
        XCTAssertEqual(SlumberPartyLink.code(in: SlumberPartyLink.url(code: code)!), code)
        XCTAssertEqual(SlumberPartyLink.code(in: URL(string: "countingsheep://invite/\(code)")!), code)
        for raw in ["http://countingsheepproject.com/invite/\(code)", "https://countingsheepproject.com.evil.test/invite/\(code)",
                    "https://countingsheepproject.com/invite/\(code)?next=other", "https://countingsheepproject.com/invite/SHORT",
                    "https://user@countingsheepproject.com/invite/\(code)", "https://countingsheepproject.com/invite/ABCDEFGHIJKL"] {
            XCTAssertNil(SlumberPartyLink.code(in: URL(string: raw)!), raw)
        }
    }

    func testQueueRoundTripPreservesCommandIdentityAndOriginalSource() throws {
        let owner = UUID(), source = SocialSource(kind: "activity", id: UUID(), partyID: UUID())
        let command = PendingSupportMessage(source: source, messageID: "niceWork")
        var document = CampfireVisibilityDocument()
        document.supportCommands = [command]
        let restored = try JSONDecoder().decode(CampfireVisibilityDocument.self, from: JSONEncoder().encode(document))
        XCTAssertEqual(restored.supportCommands?.first?.request(owner: owner), command.request(owner: owner))
        let legacy = try JSONEncoder().encode(CampfireVisibilityDocument())
        XCTAssertNil(try JSONDecoder().decode(CampfireVisibilityDocument.self, from: legacy).supportCommands)
    }

    func testAcquisitionRoundTripReusesCommandAfterUncertainCreation() throws {
        let intent = SlumberPartyAcquisition.Intent.create(name: "Night Owls", timeZone: "UTC")
        var acquisition = SlumberPartyAcquisition()
        let id = acquisition.begin(intent)
        var restored = try JSONDecoder().decode(SlumberPartyAcquisition.self, from: JSONEncoder().encode(acquisition))
        restored.finish()
        XCTAssertEqual(restored.begin(intent), id)
        restored.finish(partyID: UUID())
        XCTAssertNil(restored.commandID)
    }

    func testNotificationRouteRequiresAccountAndKnownEventKind() {
        let owner = UUID()
        XCTAssertEqual(SocialNotificationRoute.parse(["socialOwnerID": owner.uuidString, "socialEventID": "support:\(UUID())"])?.ownerID, owner)
        XCTAssertNil(SocialNotificationRoute.parse(["socialEventID": "support:\(UUID())"]))
        XCTAssertNil(SocialNotificationRoute.parse(["socialOwnerID": owner.uuidString, "socialEventID": "https://example.com"]))
    }

    func testConfirmedRejectionReleasesAcquisitionButUncertainFailureDoesNot() {
        var acquisition = SlumberPartyAcquisition()
        let first = acquisition.begin(.join(code: "ABCDEFGHJKLM"))
        acquisition.finish()
        XCTAssertEqual(acquisition.commandID, first)
        acquisition.finish(rejected: true)
        XCTAssertNil(acquisition.intent)
        XCTAssertNil(acquisition.commandID)
        XCTAssertNotEqual(acquisition.begin(.join(code: "BCDEFGHJKLMN")), first)
    }

    @MainActor func testQueueStorageIsSeparatedByAccount() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = CampfireVisibilityStore(directory: directory), owner = UUID()
        var document = CampfireVisibilityDocument()
        document.supportCommands = [.init(source: .init(kind: "global", id: UUID()), messageID: "restWell")]
        try store.save(document, owner: owner)
        XCTAssertEqual(try store.load(owner: owner).supportCommands, document.supportCommands)
        XCTAssertNil(try store.load(owner: UUID()).supportCommands)
    }
}
