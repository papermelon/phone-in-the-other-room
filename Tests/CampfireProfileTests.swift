import XCTest

final class CampfireProfileTests: XCTestCase {
    func testChannelsDecodeAlongsideOlderStateAndKeepTheirCapacity() throws {
        let legacy = Data(#"{"version":1,"available":true,"observedAt":0,"participants":[],"approximateCount":0}"#.utf8)
        let state = try JSONDecoder().decode(GlobalCampfireState.self, from: legacy)
        XCTAssertNil(state.channels)
        var current = state
        current.channels = [.init(id: 1, count: 8), .init(id: 2, count: 0)]
        current.channelID = 1
        let restored = try JSONDecoder().decode(GlobalCampfireState.self, from: JSONEncoder().encode(current))
        XCTAssertEqual(restored.channelID, 1)
        XCTAssertTrue(try XCTUnwrap(restored.channels?.first).isFull)
        XCTAssertFalse(try XCTUnwrap(restored.channels?.last).isFull)
    }

    func testProfileOwnerRequiresAKnownMatchingAccount() {
        let owner = UUID()
        XCTAssertFalse(CampfireRules.permitsOwner(captured: nil, current: nil))
        XCTAssertFalse(CampfireRules.permitsOwner(captured: owner, current: UUID()))
        XCTAssertTrue(CampfireRules.permitsOwner(captured: owner, current: owner))
    }

    func testDisplaySnapshotRoundTripsWithoutPrivateFarmLedger() throws {
        let snapshot = CampfireProfileSnapshot(session: ["Phone Away · Active"], tasks: ["Read one chapter"],
            routines: ["Evening · Read"], intention: "Rest", history: ["Wind Down · Completed"],
            partyNames: ["Family"], inventory: ["shepherd_moss_coat"], sheep: [],
            appearance: .init(), decorations: ["leftMeadow": "flower_patch"], collectibles: [:],
            ollieAccessory: "ollie_moss_bandana", barnCapacityLevel: 1)
        let data = try JSONEncoder().encode(snapshot)
        XCTAssertEqual(try JSONDecoder().decode(CampfireProfileSnapshot.self, from: data), snapshot)
        XCTAssertEqual(snapshot.thought, "Read one chapter")
        XCTAssertEqual(snapshot.farm.ownedShopItemIDs, ["shepherd_moss_coat"])
        XCTAssertTrue(snapshot.farm.transactions.isEmpty)
        XCTAssertEqual(snapshot.farm.equipment.decorationPlacements[.leftMeadow], "flower_patch")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(json["transactions"])
        XCTAssertNil(json["health"])
        XCTAssertNil(json["ownerID"])
    }

    func testLegacyAliasJournalCannotAcquireBroaderAgreement() throws {
        var document = CampfireVisibilityDocument()
        document.publicName = "Fern"
        let commandID = UUID().uuidString
        document.selection = .init(visibility: .global, partyIDs: [], effectiveAt: Date(), publicAgreementCommandID: commandID)
        document.bindPublicAgreement(commandID: commandID,
            agreement: .init(id: UUID(), version: 1, revision: 1, enabled: true, acceptedAt: Date()))
        XCTAssertNil(document.selection?.publicAgreementID)
        let restored = try JSONDecoder().decode(CampfireVisibilityDocument.self, from: JSONEncoder().encode(document))
        XCTAssertEqual(restored.publicName, "Fern")
        var profile = GlobalCampfireCommand(command: "profile"); profile.agreementID = UUID()
        document.enqueue(profile)
        var off = GlobalCampfireCommand(command: "agreement"); off.enabled = false
        document.enqueue(off)
        XCTAssertEqual(document.commands, [off])
    }
}
