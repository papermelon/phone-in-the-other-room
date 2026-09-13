import XCTest

final class FarmSaveDocumentTests: XCTestCase {
    func testCompleteFarmRoundTripPreservesEarnedAndSpentState() throws {
        let welcome = WelcomeRewardEngine.reconcile(farm: .empty, search: .empty, ledger: .empty)
        var farm = welcome.farm
        farm.woolBalance = 27
        farm.ownedShopItemIDs = ["future_cosmetic", "shepherd_moss_coat"]
        farm.sheep[0].status = .sold
        farm.sheep[0].displayName = "Cloud"
        farm.sheep[0].regrowthSecondsRemaining = 142.5
        farm.cumulativeCredit = CumulativeFarmCredit()
        farm.cumulativeCredit?.windDownSeconds = 83.5
        farm.cumulativeCredit?.consumedIntervals = [DateInterval(start: Date(timeIntervalSince1970: 100), duration: 180)]
        let document = FarmSaveDocument(lineageID: UUID(), generation: 19, values: [
            "ollie.farm.state": try JSONEncoder().encode(farm),
            "ollie.sheepSearch.state": try JSONEncoder().encode(welcome.search),
            WelcomeRewardLedger.storageKey: try JSONEncoder().encode(welcome.ledger)
        ])
        let restored = try FarmSaveDocument.decode(document.encoded())
        XCTAssertEqual(restored, document)
        let restoredFarm = try JSONDecoder().decode(FarmState.self, from: XCTUnwrap(restored.values["ollie.farm.state"]))
        XCTAssertEqual(restoredFarm, farm)
        let replay = WelcomeRewardEngine.reconcile(farm: restoredFarm, search: welcome.search, ledger: welcome.ledger)
        XCTAssertEqual(replay.farm, restoredFarm)
    }

    func testRejectsFutureSchemaBeforeLossyDomainDecoding() throws {
        let data = Data("{\"schemaVersion\":999,\"woolBalance\":800}".utf8)
        XCTAssertThrowsError(try FarmSaveDocument.validate(data, key: "ollie.farm.state")) {
            XCTAssertEqual($0 as? FarmSaveError, .unsupportedSchema)
        }
    }

    func testChecksumDetectsChangedPayload() throws {
        let document = FarmSaveDocument(lineageID: UUID(), generation: 1, values: [:])
        var wrapper = try XCTUnwrap(JSONSerialization.jsonObject(with: document.encoded()) as? [String: Any])
        wrapper["payload"] = Data("{}".utf8).base64EncodedString()
        XCTAssertThrowsError(try FarmSaveDocument.decode(JSONSerialization.data(withJSONObject: wrapper)))
    }

    func testInvalidComponentAndUnexpectedKeysDoNotBecomeEmptyState() throws {
        XCTAssertThrowsError(try FarmSaveDocument.validate(Data("broken".utf8), key: "ollie.farm.state"))
        let document = FarmSaveDocument(lineageID: UUID(), generation: 1, values: ["ollie.health.raw": Data()])
        XCTAssertThrowsError(try document.encoded())
    }

    func testFutureMorningLedgerCannotBeNormalizedByOlderDecoder() throws {
        let bytes = Data("{\"schemaVersion\":2,\"sunriseTrail\":{\"schemaVersion\":99}}".utf8)
        XCTAssertThrowsError(try FarmSaveDocument.validate(bytes, key: WindDownMorningSettlementJournal.storageKey)) {
            XCTAssertEqual($0 as? FarmSaveError, .unsupportedSchema)
        }
    }

    func testBackupProjectionExcludesPrivateJournalAndDailyHistory() throws {
        var farm = FarmState.empty
        farm.migrateCumulativeCredit(records: [], searchState: .empty, protectedNightCount: 0)
        let document = FarmSaveDocument(lineageID: UUID(), generation: 1, values: [
            "ollie.farm.state": try JSONEncoder().encode(farm),
            "ollie.progress": try JSONEncoder().encode(UserProgress.empty),
            WindDownMorningSettlementJournal.storageKey: try JSONEncoder().encode(WindDownMorningSettlementJournal())
        ])
        let payload = try FarmBackupPayload(document: document)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), Set([
            "schemaVersion", "economyVersion", "lineageID", "farm", "search", "welcome", "socialRewards",
            "sunrise", "completedWindDownCount", "keepsakes", "deliveredWindDownRunIDs", "deliveredEffectIDs"
        ]))
        let encoded = String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)
        for forbidden in ["dailyFocusRecords", "authorizedTerminalMorningDecisions", "morningOccurrences", "hiddenSearchOutcome"] {
            XCTAssertFalse(encoded.contains(forbidden), forbidden)
        }
        XCTAssertEqual(payload.farm, farm)
    }

    func testBackupRequiresCumulativeMigrationBeforeEligibility() throws {
        let document = FarmSaveDocument(lineageID: UUID(), generation: 1, values: [:])
        XCTAssertThrowsError(try FarmBackupPayload(document: document))
    }

    func testRemoteRoundTripRejectsLossyDecodingAndPreservesWool() throws {
        var farm = WelcomeRewardEngine.reconcile(farm: .empty, search: .empty, ledger: .empty).farm
        farm.migrateCumulativeCredit(records: [], searchState: .empty, protectedNightCount: 0)
        farm.woolBalance = 137
        for _ in 0..<12 {
            farm.cumulativeCredit?.receipts[UUID()] = FarmCreditReceipt(creditedSeconds: 32,
                excludedAccessSeconds: 0, trackingIncomplete: false, migrated: false, outcomeIDs: [])
        }
        let document = FarmSaveDocument(lineageID: UUID(), generation: 2,
            values: ["ollie.farm.state": try JSONEncoder().encode(farm)])
        let payload = try FarmBackupPayload(document: document)
        let data = try JSONEncoder().encode(payload)
        XCTAssertEqual(try FarmBackupPayload.decodeRemote(data), payload)
        XCTAssertEqual(try FarmBackupPayload.decodeRemote(data).fingerprint(), try payload.fingerprint())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var remoteFarm = try XCTUnwrap(object["farm"] as? [String: Any])
        remoteFarm["unrecognizedFutureBalance"] = 999
        object["farm"] = remoteFarm
        XCTAssertThrowsError(try FarmBackupPayload.decodeRemote(JSONSerialization.data(withJSONObject: object)))
        let restored = try payload.restoredValues(preservingLocalProgress: .empty)
        XCTAssertEqual(try JSONDecoder().decode(FarmState.self, from: XCTUnwrap(restored["ollie.farm.state"])), farm)
    }

    func testBackupMetadataSurvivesLocalDocumentRoundTrip() throws {
        let backup = FarmBackupSync(ownerID: UUID(), generation: UUID(),
            pending: FarmBackupCommand(action: "delete", generation: UUID(), operationID: UUID()))
        let document = FarmSaveDocument(lineageID: UUID(), generation: 2, values: [:], backup: backup)
        XCTAssertEqual(try FarmSaveDocument.decode(document.encoded()), document)
    }

    func testRestoreSeparatesFarmContinuityFromLocalNightsAndKeepsReplayMarkers() throws {
        var farm = FarmState.empty
        farm.migrateCumulativeCredit(records: [], searchState: .empty, protectedNightCount: 9)
        var progress = UserProgress.empty
        progress.totalCompletedRuns = 9
        let delivered = UUID()
        let journal = WindDownMorningSettlementJournal(restoredDeliveredWindDownRunIDs: [delivered])
        let document = FarmSaveDocument(lineageID: UUID(), generation: 1, values: [
            "ollie.farm.state": try JSONEncoder().encode(farm),
            "ollie.progress": try JSONEncoder().encode(progress),
            WindDownMorningSettlementJournal.storageKey: try JSONEncoder().encode(journal)
        ])
        let payload = try FarmBackupPayload(document: document)
        let restored = try payload.restoredValues(preservingLocalProgress: .empty)
        let newProgress = try JSONDecoder().decode(UserProgress.self, from: XCTUnwrap(restored["ollie.progress"]))
        XCTAssertEqual(newProgress.totalCompletedRuns, 0)
        XCTAssertEqual(newProgress.farmCompletedRuns, 9)
        XCTAssertTrue(newProgress.dailyFocusRecords.isEmpty)
        let projected = try FarmBackupPayload(document: FarmSaveDocument(lineageID: document.lineageID,
            generation: 2, values: restored))
        XCTAssertEqual(projected.completedWindDownCount, 9)
        XCTAssertEqual(projected.deliveredWindDownRunIDs, [delivered])
    }
}
