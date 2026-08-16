import Foundation

enum WelcomeRewardGrantKind: String, Codable, Equatable {
    case starterSheep
    case profileWearable
    case onboardingPracticeSheep
    case starterSkippedExistingFarm
}

struct WelcomeRewardGrant: Codable, Equatable, Identifiable {
    let id: UUID
    let kind: WelcomeRewardGrantKind
    let idempotencyKey: String
    let sheepDefinitionID: String?
    let flockSheepID: UUID?
    let itemID: String?
    let runID: UUID?
    let createdAt: Date
    var claimedAt: Date?

    var isClaimed: Bool { claimedAt != nil }

    init(
        id: UUID = UUID(),
        kind: WelcomeRewardGrantKind,
        idempotencyKey: String,
        sheepDefinitionID: String? = nil,
        flockSheepID: UUID? = nil,
        itemID: String? = nil,
        runID: UUID? = nil,
        createdAt: Date,
        claimedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.idempotencyKey = idempotencyKey
        self.sheepDefinitionID = sheepDefinitionID
        self.flockSheepID = flockSheepID
        self.itemID = itemID
        self.runID = runID
        self.createdAt = createdAt
        self.claimedAt = claimedAt
    }
}

struct WelcomeRewardLedger: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let storageKey = "ollie.welcome.rewards"

    var schemaVersion: Int
    var grants: [WelcomeRewardGrant]
    var preexistingFarm: Bool

    static let empty = WelcomeRewardLedger(
        schemaVersion: currentSchemaVersion,
        grants: [],
        preexistingFarm: false
    )

    init(
        schemaVersion: Int = currentSchemaVersion,
        grants: [WelcomeRewardGrant] = [],
        preexistingFarm: Bool = false
    ) {
        self.schemaVersion = max(schemaVersion, Self.currentSchemaVersion)
        self.grants = grants
        self.preexistingFarm = preexistingFarm
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, grants, preexistingFarm
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion,
            grants: try container.decodeIfPresent([WelcomeRewardGrant].self, forKey: .grants) ?? [],
            preexistingFarm: try container.decodeIfPresent(Bool.self, forKey: .preexistingFarm) ?? false
        )
    }

    func grant(of kind: WelcomeRewardGrantKind) -> WelcomeRewardGrant? {
        grants.last { $0.kind == kind }
    }

    func grant(idempotencyKey: String) -> WelcomeRewardGrant? {
        grants.first { $0.idempotencyKey == idempotencyKey }
    }

    var starterSheepGrant: WelcomeRewardGrant? { grant(of: .starterSheep) }
    var pendingWearableGrant: WelcomeRewardGrant? {
        grants.last { $0.kind == .profileWearable && $0.claimedAt == nil }
    }
    var claimedWearableGrant: WelcomeRewardGrant? {
        grants.last { $0.kind == .profileWearable && $0.claimedAt != nil }
    }
    var practiceSheepGrant: WelcomeRewardGrant? { grant(of: .onboardingPracticeSheep) }

    mutating func upsert(_ grant: WelcomeRewardGrant) {
        if let index = grants.firstIndex(where: { $0.idempotencyKey == grant.idempotencyKey }) {
            grants[index] = grant
        } else {
            grants.append(grant)
        }
    }
}

struct WelcomeRewardReconciliation: Equatable {
    var farm: FarmState
    var search: SheepSearchState
    var ledger: WelcomeRewardLedger
    var outcome: SheepSearchOutcome?
}

enum WelcomeRewardCatalog {
    static let starterSheepID = "mabel"
    static let practiceSheepID = "pippin"
    static let starterIdempotencyKey = "starter:\(starterSheepID)"
    static let practiceGrantKey = "practice-sheep:\(practiceSheepID)"
    static let finishedShepherdWearableIDs = [
        "shepherd_wool_hat",
        "shepherd_moss_coat",
        "shepherd_moon_coat"
    ]

    static var starterDefinition: SheepDefinition? {
        SheepCatalog.definition(for: starterSheepID)
    }

    static var practiceDefinition: SheepDefinition? {
        SheepCatalog.definition(for: practiceSheepID)
    }

    static func isFinishedShepherdWearable(_ itemID: String) -> Bool {
        finishedShepherdWearableIDs.contains(itemID)
            && FarmShopCatalog.item(for: itemID)?.category == .shepherd
    }

    static func wearableGiftKey(itemID: String) -> String {
        "welcome-gift:\(itemID)"
    }

    static func starterOutcomeID() -> UUID {
        stableUUID(from: starterIdempotencyKey)
    }

    static func stableUUID(from value: String) -> UUID {
        let first = hash64(value)
        let second = hash64("welcome:\(value)")
        let bytes: [UInt8] = (0..<8).map { UInt8((first >> UInt64($0 * 8)) & 0xFF) }
            + (0..<8).map { UInt8((second >> UInt64($0 * 8)) & 0xFF) }
        let tuple: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: tuple)
    }

    private static func hash64(_ value: String) -> UInt64 {
        value.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { partial, byte in
            (partial ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}

enum WelcomeRewardEngine {
    static func reconcile(
        farm: FarmState,
        search: SheepSearchState,
        ledger: WelcomeRewardLedger,
        now: Date = Date()
    ) -> WelcomeRewardReconciliation {
        var farm = FarmMigration.migrated(existing: farm, searchState: search, now: now)
        var search = search
        var ledger = ledger

        if looksLikePreexistingFarm(farm: farm, search: search, ledger: ledger) {
            ledger.preexistingFarm = true
            if ledger.grant(of: .starterSkippedExistingFarm) == nil,
               ledger.starterSheepGrant == nil {
                ledger.upsert(WelcomeRewardGrant(
                    kind: .starterSkippedExistingFarm,
                    idempotencyKey: "starter:skipped-existing-farm",
                    createdAt: now
                ))
            }
            return WelcomeRewardReconciliation(farm: farm, search: search, ledger: ledger, outcome: nil)
        }

        if ledger.starterSheepGrant != nil || search.starterOutcome() != nil {
            if let outcome = search.starterOutcome() {
                farm.recordArrival(outcome)
                if ledger.starterSheepGrant == nil {
                    ledger.upsert(WelcomeRewardGrant(
                        id: outcome.id,
                        kind: .starterSheep,
                        idempotencyKey: WelcomeRewardCatalog.starterIdempotencyKey,
                        sheepDefinitionID: outcome.sheepID,
                        flockSheepID: outcome.id,
                        runID: outcome.runID,
                        createdAt: outcome.createdAt
                    ))
                }
            }
            return WelcomeRewardReconciliation(
                farm: farm,
                search: search,
                ledger: ledger,
                outcome: search.starterOutcome()
            )
        }

        let calculation = SheepSearchEngine.calculateStarter(now: now)
        search.append(calculation.outcome)
        farm.recordArrival(calculation.outcome)
        ledger.upsert(WelcomeRewardGrant(
            id: calculation.outcome.id,
            kind: .starterSheep,
            idempotencyKey: WelcomeRewardCatalog.starterIdempotencyKey,
            sheepDefinitionID: WelcomeRewardCatalog.starterSheepID,
            flockSheepID: calculation.outcome.id,
            runID: calculation.outcome.runID,
            createdAt: now
        ))
        return WelcomeRewardReconciliation(
            farm: farm,
            search: search,
            ledger: ledger,
            outcome: calculation.outcome
        )
    }

    static func recordProfileGift(
        recommendation: WindDownProfileRecommendation,
        farm: FarmState,
        search: SheepSearchState,
        ledger: WelcomeRewardLedger,
        now: Date = Date()
    ) throws -> WelcomeRewardReconciliation {
        let itemID = recommendation.wearableItemID
        guard WelcomeRewardCatalog.isFinishedShepherdWearable(itemID) else {
            throw FarmActionError.itemNotFound
        }
        var farm = farm
        var ledger = ledger
        let key = WelcomeRewardCatalog.wearableGiftKey(itemID: itemID)
        if ledger.grant(of: .profileWearable) != nil || ledger.grant(idempotencyKey: key) != nil {
            return WelcomeRewardReconciliation(farm: farm, search: search, ledger: ledger, outcome: nil)
        }
        try farm.grantWelcomeWearable(itemID: itemID, at: now)
        ledger.upsert(WelcomeRewardGrant(
            kind: .profileWearable,
            idempotencyKey: key,
            itemID: itemID,
            createdAt: now
        ))
        return WelcomeRewardReconciliation(farm: farm, search: search, ledger: ledger, outcome: nil)
    }

    static func claimWearable(
        itemID: String? = nil,
        farm: FarmState,
        search: SheepSearchState,
        ledger: WelcomeRewardLedger,
        now: Date = Date()
    ) throws -> WelcomeRewardReconciliation {
        var farm = farm
        var ledger = ledger
        guard var grant = ledger.pendingWearableGrant ?? ledger.grant(of: .profileWearable) else {
            throw FarmActionError.itemNotOwned
        }
        let resolvedID = itemID ?? grant.itemID
        guard let resolvedID, resolvedID == grant.itemID else {
            throw FarmActionError.itemNotFound
        }
        if grant.claimedAt != nil {
            throw FarmActionError.welcomeGiftAlreadyClaimed
        }
        try farm.claimWelcomeWearable(itemID: resolvedID)
        grant.claimedAt = now
        ledger.upsert(grant)
        return WelcomeRewardReconciliation(farm: farm, search: search, ledger: ledger, outcome: nil)
    }

    static func equipWearable(
        itemID: String? = nil,
        farm: FarmState,
        search: SheepSearchState,
        ledger: WelcomeRewardLedger
    ) throws -> WelcomeRewardReconciliation {
        var farm = farm
        guard let grant = ledger.claimedWearableGrant ?? ledger.pendingWearableGrant else {
            throw FarmActionError.itemNotOwned
        }
        let resolvedID = itemID ?? grant.itemID
        guard let resolvedID, resolvedID == grant.itemID else {
            throw FarmActionError.itemNotFound
        }
        guard grant.claimedAt != nil else {
            throw FarmActionError.itemNotOwned
        }
        try farm.equip(itemID: resolvedID)
        return WelcomeRewardReconciliation(farm: farm, search: search, ledger: ledger, outcome: nil)
    }

    static func settlePractice(
        run: FocusRun,
        farm: FarmState,
        search: SheepSearchState,
        ledger: WelcomeRewardLedger,
        now: Date = Date()
    ) -> WelcomeRewardReconciliation {
        var farm = FarmMigration.migrated(existing: farm, searchState: search, now: now)
        var search = search
        var ledger = ledger

        if let existing = search.onboardingPracticeOutcome(for: run.id) {
            farm.recordArrival(existing)
            if ledger.practiceSheepGrant == nil {
                ledger.upsert(WelcomeRewardGrant(
                    id: existing.id,
                    kind: .onboardingPracticeSheep,
                    idempotencyKey: WelcomeRewardCatalog.practiceGrantKey,
                    sheepDefinitionID: existing.sheepID,
                    flockSheepID: existing.id,
                    runID: run.id,
                    createdAt: existing.createdAt
                ))
            }
            return WelcomeRewardReconciliation(farm: farm, search: search, ledger: ledger, outcome: existing)
        }

        guard run.isPractice, run.completedSuccessfully else {
            return WelcomeRewardReconciliation(farm: farm, search: search, ledger: ledger, outcome: nil)
        }
        // Existing farms keep their settled history. A leftover completed-practice
        // lastRun on upgrade must not mint Pippin as an unstated launch gift.
        if looksLikePreexistingFarm(farm: farm, search: search, ledger: ledger) {
            return WelcomeRewardReconciliation(farm: farm, search: search, ledger: ledger, outcome: nil)
        }
        if ledger.practiceSheepGrant != nil {
            return WelcomeRewardReconciliation(farm: farm, search: search, ledger: ledger, outcome: nil)
        }

        let calculation = SheepSearchEngine.calculateOnboardingPractice(
            runID: run.id,
            now: now
        )
        search.append(calculation.outcome)
        farm.recordArrival(calculation.outcome)
        ledger.upsert(WelcomeRewardGrant(
            id: calculation.outcome.id,
            kind: .onboardingPracticeSheep,
            idempotencyKey: WelcomeRewardCatalog.practiceGrantKey,
            sheepDefinitionID: WelcomeRewardCatalog.practiceSheepID,
            flockSheepID: calculation.outcome.id,
            runID: run.id,
            createdAt: now
        ))
        return WelcomeRewardReconciliation(
            farm: farm,
            search: search,
            ledger: ledger,
            outcome: calculation.outcome
        )
    }

    private static func looksLikePreexistingFarm(
        farm: FarmState,
        search: SheepSearchState,
        ledger: WelcomeRewardLedger
    ) -> Bool {
        if ledger.preexistingFarm || ledger.grant(of: .starterSkippedExistingFarm) != nil {
            return true
        }
        if ledger.starterSheepGrant != nil || search.starterOutcome() != nil {
            return false
        }
        if search.outcomes.contains(where: { $0.origin == .windDown || $0.origin == .phoneBreak }) {
            return true
        }
        if !search.foundSheepIDs.isEmpty {
            return true
        }
        if !farm.sheep.isEmpty || !farm.discoveries.isEmpty {
            return true
        }
        return false
    }
}
