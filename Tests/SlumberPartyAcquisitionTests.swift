import XCTest

final class SlumberPartyAcquisitionTests: XCTestCase {
    func testRepeatedTapAndUncertainRetryUseOneCommandUntilAccepted() throws {
        var state = SlumberPartyAcquisition()
        let intent = SlumberPartyAcquisition.Intent.create(name: "Night Owls", timeZone: "Asia/Singapore")
        let command = try XCTUnwrap(state.begin(intent))
        XCTAssertNil(state.begin(intent))
        state.finish()
        XCTAssertEqual(state.begin(intent), command)
        let party = UUID()
        state.finish(partyID: party)
        XCTAssertEqual(state.acceptedPartyID, party)
        XCTAssertFalse(state.isBusy)
        state.dismissAcknowledgement()
        XCTAssertNil(state.acceptedPartyID)
        XCTAssertNotEqual(state.begin(intent), command)
        XCTAssertNil(state.acceptedPartyID)
    }

    func testDifferentInvitationNeverReusesAnotherPartysConsentIntent() throws {
        var state = SlumberPartyAcquisition()
        let first = try XCTUnwrap(state.begin(.invitation(UUID())))
        state.finish()
        XCTAssertNotEqual(state.begin(.invitation(UUID())), first)
    }

    func testExactSearchAndOlderServerCompatibility() throws {
        XCTAssertEqual(SlumberPartyInvitationSearch.normalized(" @Night_Owl "), "night_owl")
        let id = UUID()
        XCTAssertEqual(SlumberPartyInvitationSearch.normalized(id.uuidString), id.uuidString.lowercased())
        for value in ["", "%", "ab", "fern%", "friend@example.com", "hello there"] {
            XCTAssertNil(SlumberPartyInvitationSearch.normalized(value))
        }
        let old = try JSONDecoder().decode(NightFlockV4ListStateResponse.self, from: Data(#"{"parties":[]}"#.utf8))
        XCTAssertNil(old.directInvitationsVersion)
        let current = try JSONDecoder().decode(NightFlockV4ListStateResponse.self, from: Data(#"{"parties":[],"directInvitationsVersion":1}"#.utf8))
        XCTAssertEqual(current.directInvitationsVersion, 1)
        let request = SlumberPartyConnectionsRequest(action: "search", partyID: id, query: "night_owl")
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        XCTAssertEqual(Set(encoded.keys), ["action", "partyID", "query"])
    }
}
