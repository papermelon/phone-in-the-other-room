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

    func testRemoteBackupWithSupabaseDateEncodingPreservesFarmAndRejectsLossyFields() throws {
        let format = Date.ISO8601FormatStyle.iso8601.year().month().day()
            .dateTimeSeparator(.standard).time(includingFractionalSeconds: true)
        let date = Date(timeIntervalSince1970: 1_789_200_123.456)
        var welcome = WelcomeRewardEngine.reconcile(farm: .empty, search: .empty, ledger: .empty, now: date)
        welcome.farm.schemaVersion = 3
        welcome.farm.migrateCumulativeCredit(records: [], searchState: .empty, protectedNightCount: 0)
        welcome.farm.cumulativeCredit?.consumedIntervals = [DateInterval(start: date, duration: 123.25)]
        welcome.farm.woolBalance = 137
        let document = FarmSaveDocument(lineageID: UUID(), generation: 2, values: [
            "ollie.farm.state": try JSONEncoder().encode(welcome.farm),
            WelcomeRewardLedger.storageKey: try JSONEncoder().encode(welcome.ledger)
        ])
        let payload = try FarmBackupPayload(document: document)
        // Match the installed Supabase SDK's default RPC Date codec.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(format))
        }
        let bytes = try encoder.encode(payload)
        let restored = try FarmBackupPayload.decodeRemote(bytes)
        XCTAssertEqual(restored.farm.schemaVersion, 3)
        XCTAssertEqual(restored.farm.woolBalance, 137)
        XCTAssertEqual(restored.farm.sheep.map(\.id), payload.farm.sheep.map(\.id))
        XCTAssertEqual(restored.farm.sheep[0].arrivedAt, try Date("2026-09-12T08:02:03.456", strategy: format))
        XCTAssertEqual(restored.farm.cumulativeCredit?.consumedIntervals.first?.duration, 123.25)
        XCTAssertEqual(try FarmBackupPayload.decodeRemote(JSONEncoder().encode(restored)), restored)
        XCTAssertEqual(try FarmBackupPayload.decodeRemote(bytes).fingerprint(), try restored.fingerprint())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        var farm = try XCTUnwrap(object["farm"] as? [String: Any])
        farm["unrecognizedFutureBalance"] = 999
        object["farm"] = farm
        XCTAssertThrowsError(try FarmBackupPayload.decodeRemote(JSONSerialization.data(withJSONObject: object)))
        farm.removeValue(forKey: "unrecognizedFutureBalance")
        farm.removeValue(forKey: "woolBalance")
        object["farm"] = farm
        XCTAssertThrowsError(try FarmBackupPayload.decodeRemote(JSONSerialization.data(withJSONObject: object)))
        farm["woolBalance"] = 137
        var sheep = try XCTUnwrap(farm["sheep"] as? [[String: Any]])
        for invalidDate in ["2026-02-30T08:02:03.456", "2026-09-12T08:02:03.456garbage", "bad"] {
            sheep[0]["arrivedAt"] = invalidDate
            farm["sheep"] = sheep
            object["farm"] = farm
            XCTAssertThrowsError(try FarmBackupPayload.decodeRemote(JSONSerialization.data(withJSONObject: object)))
        }
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
