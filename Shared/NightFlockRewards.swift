import Foundation

/// Bounded Slumber Party Farm rewards. Values stay modest beside shearing (1–7 wool)
/// and the cheapest Shop items (3 wool). Opening the app, inviting, joining,
/// reacting, or changing settings never creates a grant.
enum NightFlockRewardRules {
    static let qualifyingNightWool = 1
    static let threeNightWoolFallback = 3
    static let groupCompletionWool = 2
    static let threeNightQualifyingCount = 3
    static let sevenNightSearchThreshold = 4
    static let groupCompletionMinimumMembers = 2
    static let threeNightItemIDs = [
        "collectible_trail_pin",
        "farm_lanterns",
        "ollie_moss_bandana"
    ]

    static func isQualifyingStatus(_ status: NightFlockMemberNightStatus) -> Bool {
        NightFlockProgressRules.isQualifying(status)
    }

    static func qualifyingNightCount(
        in progress: [NightFlockMemberNightProgress],
        memberID: UUID
    ) -> Int {
        Set(
            progress
                .filter { $0.memberID == memberID && isQualifyingStatus($0.status) }
                .map(\.day)
        ).count
    }

    static func membersMeetingSevenNightThreshold(
        in progress: [NightFlockMemberNightProgress]
    ) -> Set<UUID> {
        Dictionary(grouping: progress.filter { isQualifyingStatus($0.status) }, by: \.memberID)
            .compactMap { memberID, nights in
                Set(nights.map(\.day)).count >= sevenNightSearchThreshold ? memberID : nil
            }
            .reduce(into: Set<UUID>()) { $0.insert($1) }
    }

    static func firstUnownedThreeNightItem(in farm: FarmState) -> String? {
        threeNightItemIDs.first { itemID in
            FarmShopCatalog.item(for: itemID) != nil && !farm.ownedShopItemIDs.contains(itemID)
        }
    }
}

enum NightFlockRewardMilestone: Hashable, Codable, Sendable {
    case qualifyingNight(day: Int)
    case threeNightParticipation
    case sevenNightCompletion
    case groupCompletion

    var rawValue: String {
        switch self {
        case let .qualifyingNight(day): return "qualifyingNight:\(day)"
        case .threeNightParticipation: return "threeNightParticipation"
        case .sevenNightCompletion: return "sevenNightCompletion"
        case .groupCompletion: return "groupCompletion"
        }
    }

    init?(rawValue: String) {
        if rawValue.hasPrefix("qualifyingNight:") {
            let day = Int(rawValue.dropFirst("qualifyingNight:".count)) ?? 0
            guard (1...NightFlockChallengeDayRules.dayCount).contains(day) else { return nil }
            self = .qualifyingNight(day: day)
            return
        }
        switch rawValue {
        case "threeNightParticipation": self = .threeNightParticipation
        case "sevenNightCompletion": self = .sevenNightCompletion
        case "groupCompletion": self = .groupCompletion
        default: return nil
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown milestone")
            )
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var title: String {
        switch self {
        case let .qualifyingNight(day):
            return "Night \(day) together"
        case .threeNightParticipation:
            return "Three shared nights"
        case .sevenNightCompletion:
            return "Seven-night homecoming"
        case .groupCompletion:
            return "The flock finished together"
        }
    }
}

enum NightFlockRewardKind: String, Codable, Equatable, Sendable {
    case wool
    case itemOrWool
    case sheepSearch
}

struct NightFlockRewardGrant: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var challengeID: UUID
    var memberID: UUID
    var milestone: NightFlockRewardMilestone
    var rewardKind: NightFlockRewardKind
    var woolAmount: Int
    var itemID: String?
    var sheepSearchEntitlement: Bool
    var createdAt: Date
    var claimedAt: Date?

    var isClaimed: Bool { claimedAt != nil }

    init(
        id: UUID,
        challengeID: UUID,
        memberID: UUID,
        milestone: NightFlockRewardMilestone,
        rewardKind: NightFlockRewardKind,
        woolAmount: Int = 0,
        itemID: String? = nil,
        sheepSearchEntitlement: Bool = false,
        createdAt: Date,
        claimedAt: Date? = nil
    ) {
        self.id = id
        self.challengeID = challengeID
        self.memberID = memberID
        self.milestone = milestone
        self.rewardKind = rewardKind
        self.woolAmount = max(0, woolAmount)
        self.itemID = itemID
        self.sheepSearchEntitlement = sheepSearchEntitlement
        self.createdAt = createdAt
        self.claimedAt = claimedAt
    }
}

struct NightFlockRewardLedger: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let storageKey = "ollie.nightFlock.rewards"

    var schemaVersion: Int
    var appliedGrantIDs: [UUID]
    var grants: [NightFlockRewardGrant]

    static let empty = NightFlockRewardLedger(
        schemaVersion: currentSchemaVersion,
        appliedGrantIDs: [],
        grants: []
    )

    init(
        schemaVersion: Int = currentSchemaVersion,
        appliedGrantIDs: [UUID] = [],
        grants: [NightFlockRewardGrant] = []
    ) {
        self.schemaVersion = max(schemaVersion, Self.currentSchemaVersion)
        self.appliedGrantIDs = appliedGrantIDs
        self.grants = grants
    }

    func hasApplied(_ grantID: UUID) -> Bool {
        appliedGrantIDs.contains(grantID) || grants.contains { $0.id == grantID && $0.claimedAt != nil }
    }

    mutating func recordApplied(_ grant: NightFlockRewardGrant, at date: Date) {
        var stored = grant
        stored.claimedAt = stored.claimedAt ?? date
        if let index = grants.firstIndex(where: { $0.id == grant.id }) {
            grants[index] = stored
        } else {
            grants.append(stored)
        }
        if !appliedGrantIDs.contains(grant.id) {
            appliedGrantIDs.append(grant.id)
        }
    }
}

struct NightFlockRewardApplication: Equatable {
    var farm: FarmState
    var search: SheepSearchState
    var ledger: NightFlockRewardLedger
    var applied: [NightFlockRewardGrant]
    var outcome: SheepSearchOutcome?
}

enum NightFlockRewardEngine {
    static func apply(
        grants: [NightFlockRewardGrant],
        farm: FarmState,
        search: SheepSearchState,
        ledger: NightFlockRewardLedger,
        protectedNightCount: Int = 1,
        now: Date = Date()
    ) -> NightFlockRewardApplication {
        var farm = FarmMigration.migrated(existing: farm, searchState: search, now: now)
        var search = search
        var ledger = ledger
        var applied: [NightFlockRewardGrant] = []
        var latestOutcome: SheepSearchOutcome?

        for grant in grants.sorted(by: { $0.createdAt < $1.createdAt }) {
            guard !ledger.hasApplied(grant.id) else { continue }
            switch grant.rewardKind {
            case .wool:
                farm.applySlumberPartyWool(grant: grant, at: now)
            case .itemOrWool:
                farm.applySlumberPartyItemOrWool(grant: grant, at: now)
            case .sheepSearch:
                let calculation = SheepSearchEngine.calculateSlumberParty(
                    grantID: grant.id,
                    protectedNightNumber: max(1, protectedNightCount),
                    state: search,
                    now: now
                )
                search.append(calculation.outcome)
                farm.recordArrival(calculation.outcome)
                latestOutcome = calculation.outcome
            }
            ledger.recordApplied(grant, at: now)
            applied.append(grant)
        }

        return NightFlockRewardApplication(
            farm: farm,
            search: search,
            ledger: ledger,
            applied: applied,
            outcome: latestOutcome
        )
    }
}

extension FarmState {
    mutating func applySlumberPartyWool(grant: NightFlockRewardGrant, at date: Date) {
        let key = "slumber-party:\(grant.id.uuidString.lowercased())"
        guard !transactions.contains(where: { $0.idempotencyKey == key }) else { return }
        let amount = max(0, grant.woolAmount)
        woolBalance += amount
        appendTransaction(FarmTransaction(
            id: grant.id,
            idempotencyKey: key,
            kind: .slumberPartyGrant,
            sheepID: nil,
            itemID: nil,
            woolDelta: amount,
            createdAt: date
        ))
    }

    mutating func applySlumberPartyItemOrWool(grant: NightFlockRewardGrant, at date: Date) {
        let key = "slumber-party:\(grant.id.uuidString.lowercased())"
        guard !transactions.contains(where: { $0.idempotencyKey == key }) else { return }
        if let itemID = NightFlockRewardRules.firstUnownedThreeNightItem(in: self)
            ?? grant.itemID,
           let item = FarmShopCatalog.item(for: itemID),
           !ownedShopItemIDs.contains(item.id) {
            ownedShopItemIDs.append(item.id)
            ownedShopItemIDs.sort()
            appendTransaction(FarmTransaction(
                id: grant.id,
                idempotencyKey: key,
                kind: .slumberPartyGrant,
                sheepID: nil,
                itemID: item.id,
                woolDelta: 0,
                createdAt: date
            ))
            return
        }
        let amount = max(grant.woolAmount, NightFlockRewardRules.threeNightWoolFallback)
        woolBalance += amount
        appendTransaction(FarmTransaction(
            id: grant.id,
            idempotencyKey: key,
            kind: .slumberPartyGrant,
            sheepID: nil,
            itemID: nil,
            woolDelta: amount,
            createdAt: date
        ))
    }
}
