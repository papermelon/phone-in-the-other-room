import Foundation

func uuid(_ n: Int) -> UUID { UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", n))! }
let date = Date(timeIntervalSince1970: 1_789_200_123.456)
let owner = uuid(900)
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
let args = CommandLine.arguments
let directory = URL(fileURLWithPath: args[2], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

func synthetic(_ version: Int, rich: Bool) throws -> FarmBackupPayload {
    var farm = FarmState.empty
    farm.schemaVersion = version
    farm.woolBalance = 137
    farm.cumulativeCredit = CumulativeFarmCredit(migrationCompleted: true,
        consumedIntervals: [DateInterval(start: date, duration: 123.25)], windDownSeconds: 61.125,
        phoneAwaySeconds: 33.75, receipts: [uuid(10): FarmCreditReceipt(creditedSeconds: 123.25,
            excludedAccessSeconds: 300, trackingIncomplete: false, migrated: false, outcomeIDs: [uuid(3)])])
    farm.cumulativeCredit?.receipts[uuid(12)] = FarmCreditReceipt(creditedSeconds: 32.125,
        excludedAccessSeconds: 0, trackingIncomplete: false, migrated: true, outcomeIDs: [])
    let sheep = FlockSheep(id: uuid(1), definitionID: "future_sheep_catalog_id", displayName: "Synthetic Sheep",
        sourceOutcomeID: uuid(3), sourceRunID: uuid(2), arrivedAt: date, protectedNightNumber: 4,
        rarity: .common, isFavorite: true, lastShearedProtectedNight: 3, timesSheared: 2,
        equippedCosmeticIDs: ["unknown_sheep_hat"])
    farm.sheep = [sheep]
    farm.sheep[0].regrowthSecondsRemaining = 42.125
    farm.discoveries = [SheepDiscoveryRecord(definitionID: sheep.definitionID, firstDiscoveredAt: date,
        encounterCount: 1, outcomeIDs: [uuid(3)], highestRarity: .common)]
    farm.ownedShopItemIDs = ["unknown_ball", "unknown_coat", "unknown_shirt"]
    farm.transactions = [FarmTransaction(id: uuid(4), idempotencyKey: "synthetic:reward:4", kind: .welcomeGift,
        sheepID: uuid(1), itemID: "unknown_shirt", woolDelta: 7, legacyCashDelta: -2, createdAt: date)]
    let outcome = SheepSearchOutcome(id: uuid(3), runID: uuid(2), origin: .windDown, protectedNightNumber: 4,
        result: .found, sheepID: sheep.definitionID, rarity: .common, habitat: .starterPasture,
        trailStrength: 23, encounterOdds: 0.25, trailDistance: 10.125, consecutiveNoFinds: 0,
        bonusPoints: 20, trailMapBonusPercentagePoints: 0, createdAt: date)
    var search = SheepSearchState.empty
    search.outcomes = [outcome]; search.foundSheepIDs = [sheep.definitionID]; search.totalTrailDistance = 10.125
    search.phoneAwaySettlements = [PhoneAwaySearchSettlementRecord(runID: uuid(2), eligible: true, reason: .eligible,
        completedSuccessfully: true, isPractice: false, creditedMinutes: 16, appliedCreditDelta: 16,
        meterBefore: 4, meterAfter: 20, outcomeID: uuid(3), protectedWindDownCount: 4, createdAt: date)]
    let welcome = WelcomeRewardLedger(grants: [WelcomeRewardGrant(id: uuid(5), kind: .profileWearable,
        idempotencyKey: "synthetic:welcome:5", sheepDefinitionID: sheep.definitionID, flockSheepID: uuid(1),
        itemID: "unknown_shirt", runID: uuid(2), createdAt: date, claimedAt: date)])
    let social = NightFlockRewardLedger(appliedGrantIDs: [uuid(6)], grants: [NightFlockRewardGrant(id: uuid(6),
        challengeID: uuid(7), memberID: owner, milestone: .qualifyingNight(day: 1), rewardKind: .wool,
        woolAmount: 1, itemID: "unknown_gift", createdAt: date, claimedAt: date)])
    let sunrise = SunriseTrailState(pendingMinutes: 10, completedSearchCount: 1,
        occurrenceSettlements: [SunriseTrailOccurrenceSettlement(occurrenceID: uuid(8), eligibleMinutes: 30,
            appliedMinutes: 30, createdAt: date)],
        fills: [SunriseTrailFill(id: uuid(9), occurrenceID: uuid(8), fillIndex: 0, woolGranted: 1, outcome: outcome, settledAt: date)])
    var journal = WindDownMorningSettlementJournal(sunriseTrail: sunrise, deliveredEffectIDs: ["synthetic:effect:2"],
        restoredDeliveredWindDownRunIDs: [uuid(2)])
    journal.sunriseTrail = sunrise
    var progress = UserProgress.empty; progress.restoredFarmCompletedRuns = 4
    let reward = RewardItem(id: uuid(11), type: .ribbon, rarity: .common, title: "Synthetic ribbon", description: "",
        earnedAt: date, runDurationMinutes: 0, isDemoReward: false)
    if rich {
        farm.fetchPracticeBest = 12
        farm.equipment.fetchBallItemID = "unknown_ball"; farm.equipment.ollieCoatID = "unknown_coat"
        farm.equipment.ollieAccessoryItemID = "unknown_ornament"
        farm.equipment.decorationPlacements = [.leftMeadow: "unknown_tree"]
        farm.equipment.collectiblePlacements = [.left: "unknown_collectible"]
        farm.shepherd.shirtItemID = "unknown_shirt"; farm.shepherd.outfitItemID = "unknown_outfit"
        farm.shepherd.accessoryItemID = "unknown_accessory"; farm.shepherd.headShapeID = "unknown_shape"
        farm.trackedSheepDefinitionID = sheep.definitionID
        if version == 4 {
            farm.cumulativeCredit?.bedtimeBonus = BedtimeSearchBonus(remainingSearchSeconds: 5040,
                grantedNights: ["2026-9-12": uuid(2)])
            farm.cumulativeCredit?.receipts[uuid(10)] = FarmCreditReceipt(creditedSeconds: 123.25,
                excludedAccessSeconds: 300, trackingIncomplete: false, migrated: false, outcomeIDs: [uuid(3)],
                bedtimeBonus: BedtimeBonusReceipt(result: .granted, nightKey: "2026-9-12", grantedSearchSeconds: 5040))
        }
    }
    let document = FarmSaveDocument(lineageID: uuid(100), generation: 2, values: [
        "ollie.farm.state": try encoder.encode(farm), "ollie.sheepSearch.state": try encoder.encode(search),
        WelcomeRewardLedger.storageKey: try encoder.encode(welcome), NightFlockRewardLedger.storageKey: try encoder.encode(social),
        WindDownMorningSettlementJournal.storageKey: try encoder.encode(journal), "ollie.progress": try encoder.encode(progress),
        "ollie.rewards": try encoder.encode([reward])], backup: FarmBackupSync(ownerID: owner, generation: uuid(101)))
    return try FarmBackupPayload(document: document,
        pasture: rich ? PastureSceneSnapshot(positions: [PastureSceneStoredPosition(entityID: .sheep(uuid(1), pastureIndex: 0),
            point: PastureScenePoint(x: 0.25, y: 0.75))]) : nil,
        appearance: rich ? .defaultValue : nil)
}
func read(_ url: URL) throws -> FarmBackupPayload { try FarmBackupPayload.decodeRemote(Data(contentsOf: url)) }
if args[1] == "generate" {
    try generateDomainReference(in: directory)
    for version in [3, 4] {
        for rich in [false, true] {
            let payload = try synthetic(version, rich: rich)
            for iso in [false, true] {
                let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys, .prettyPrinted]
                if iso { enc.dateEncodingStrategy = .custom { date, encoder in
                    var container = encoder.singleValueContainer()
                    try container.encode(date.formatted(Date.ISO8601FormatStyle.iso8601.year().month().day()
                        .dateTimeSeparator(.standard).time(includingFractionalSeconds: true)))
                } }
                let name = "farm-v\(version)-\(rich ? "rich" : "optional-absent")-\(iso ? "iso" : "numeric").json"
                let bytes = try enc.encode(payload)
                _ = try FarmBackupPayload.decodeRemote(bytes)
                try bytes.write(to: directory.appendingPathComponent(name))
            }
        }
    }
    try encoder.encode(["ownerID": owner.uuidString, "lineageID": uuid(100).uuidString,
        "source": "Synthetic only; generated through current FarmBackupPayload(document:) and decodeRemote"])
        .write(to: directory.appendingPathComponent("manifest.json"))
    print("Swift exported 8 sanitized codec fixtures; owner metadata is not a Farm payload field")
} else if args[1] == "compare" {
    let baseline = URL(fileURLWithPath: args[3], isDirectory: true)
    for source in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        where source.lastPathComponent.hasPrefix("farm-") {
        let current = try read(source)
        let original = try read(baseline.appendingPathComponent(source.lastPathComponent))
        guard current == original, try current.fingerprint() == original.fingerprint() else { fatalError("Current Swift differs from preserved fixture") }
    }
    print("PASS: current Swift wire fixtures semantically match all 8 preserved AND-006 fixture bytes")
} else {
    let exchange = URL(fileURLWithPath: args[3], isDirectory: true)
    for source in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        where source.lastPathComponent.hasPrefix("farm-") {
        let expected = try read(source)
        let output = exchange.appendingPathComponent(source.lastPathComponent)
        let actual = try read(output)
        guard expected == actual, try expected.fingerprint() == actual.fingerprint() else { fatalError("Swift semantic mismatch: \(source.lastPathComponent)") }
    }
    for invalid in try FileManager.default.contentsOfDirectory(at: exchange, includingPropertiesForKeys: nil)
        where invalid.lastPathComponent.hasPrefix("rejected-") {
        do { _ = try read(invalid); fatalError("Swift accepted invalid fixture: \(invalid.lastPathComponent)") } catch { }
    }
    let reverse = try read(exchange.appendingPathComponent("kotlin-origin.json"))
    guard reverse.farm.woolBalance == 201, reverse.farm.sheep[0].id == uuid(701),
          reverse.farm.sheep[0].arrivedAt == Date(timeIntervalSinceReferenceDate: 810000123.125),
          reverse.lineageID == uuid(700), reverse.socialRewards.grants[0].memberID == uuid(900),
          reverse.farm.equipment.fetchBallItemID == "kotlin_unknown_ball", reverse.farm.fetchPracticeBest == 15 else { fatalError("Kotlin-origin values changed") }
    try encoder.encode(reverse).write(to: exchange.appendingPathComponent("swift-return.json"))
    let owned = try JSONSerialization.jsonObject(with: Data(contentsOf: exchange.appendingPathComponent("kotlin-owner.json"))) as! [String: String]
    guard owned["ownerID"] == owner.uuidString else { fatalError("owner changed") }
    print("PASS: 8 Swift → Kotlin → Swift semantic/fingerprint comparisons and Kotlin → Swift return; UUID owner preserved outside payload")
}
