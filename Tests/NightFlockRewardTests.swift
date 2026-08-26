import XCTest

final class NightFlockRewardTests: XCTestCase {
    func testEconomyStaysModestBesideShearingAndShop() {
        XCTAssertEqual(NightFlockRewardRules.qualifyingNightWool, 1)
        XCTAssertEqual(NightFlockRewardRules.threeNightWoolFallback, 3)
        XCTAssertEqual(NightFlockRewardRules.groupCompletionWool, 2)
        XCTAssertEqual(NightFlockRewardRules.sevenNightSearchThreshold, 4)
        XCTAssertLessThanOrEqual(NightFlockRewardRules.qualifyingNightWool, FarmEconomyRules.woolYield(for: .common))
        XCTAssertEqual(FarmShopCatalog.item(for: "collectible_trail_pin")?.woolCost, 3)
        XCTAssertLessThan(
            NightFlockRewardRules.threeNightWoolFallback,
            FarmEconomyRules.capacityUpgradeWoolCosts[0]
        )
    }

    func testReplayDoesNotDuplicateWoolOrSearch() {
        let grantID = UUID()
        let grant = NightFlockRewardGrant(
            id: grantID,
            challengeID: UUID(),
            memberID: UUID(),
            milestone: .qualifyingNight(day: 1),
            rewardKind: .wool,
            woolAmount: 1,
            createdAt: Date()
        )
        let first = NightFlockRewardEngine.apply(
            grants: [grant],
            farm: .empty,
            search: .empty,
            ledger: .empty
        )
        XCTAssertEqual(first.farm.woolBalance, 1)
        XCTAssertEqual(first.applied.count, 1)
        let second = NightFlockRewardEngine.apply(
            grants: [grant, grant],
            farm: first.farm,
            search: first.search,
            ledger: first.ledger
        )
        XCTAssertEqual(second.farm.woolBalance, 1)
        XCTAssertTrue(second.applied.isEmpty)
        XCTAssertEqual(
            second.farm.transactions.filter { $0.kind == .slumberPartyGrant }.count,
            1
        )
    }

    func testReactionsHaveNoRewardMilestone() {
        XCTAssertNil(NightFlockRewardMilestone(rawValue: "reaction"))
        XCTAssertNil(NightFlockRewardMilestone(rawValue: "invite"))
        XCTAssertNil(NightFlockRewardMilestone(rawValue: "join"))
        XCTAssertEqual(NightFlockReactionKind.allCases.count, 3)
    }

    func testThreeNightItemFallsBackToWoolWhenOwned() {
        var farm = FarmState.empty
        farm.ownedShopItemIDs = NightFlockRewardRules.threeNightItemIDs
        let grant = NightFlockRewardGrant(
            id: UUID(),
            challengeID: UUID(),
            memberID: UUID(),
            milestone: .threeNightParticipation,
            rewardKind: .itemOrWool,
            woolAmount: 3,
            createdAt: Date()
        )
        let result = NightFlockRewardEngine.apply(
            grants: [grant],
            farm: farm,
            search: .empty,
            ledger: .empty
        )
        XCTAssertEqual(result.farm.woolBalance, 3)
        XCTAssertNil(result.farm.transactions.last?.itemID)
    }

    func testSevenNightSearchDoesNotConsumeGuarantees() {
        let grant = NightFlockRewardGrant(
            id: UUID(),
            challengeID: UUID(),
            memberID: UUID(),
            milestone: .sevenNightCompletion,
            rewardKind: .sheepSearch,
            sheepSearchEntitlement: true,
            createdAt: Date()
        )
        let result = NightFlockRewardEngine.apply(
            grants: [grant],
            farm: .empty,
            search: .empty,
            ledger: .empty
        )
        XCTAssertEqual(result.search.completedWindDownSearchCount, 0)
        XCTAssertEqual(result.search.completedPhoneAwaySearchCount, 0)
        XCTAssertEqual(result.search.outcomes.first?.origin, .slumberParty)
        XCTAssertEqual(result.search.outcomes.first?.encounterOdds, 1)
        XCTAssertEqual(result.outcome?.origin, .slumberParty)
        XCTAssertTrue(result.ledger.hasApplied(grant.id))
    }

    func testFinalSearchRequiresFourQualifyingNights() {
        let member = UUID()
        let progress = (1...3).map {
            NightFlockMemberNightProgress(
                memberID: member,
                day: $0,
                status: .morningQuietCompleted,
                shieldingEvidence: .notRequested
            )
        }
        XCTAssertEqual(NightFlockRewardRules.qualifyingNightCount(in: progress, memberID: member), 3)
        XCTAssertTrue(NightFlockRewardRules.membersMeetingSevenNightThreshold(in: progress).isEmpty)
        let withFourth = progress + [
            NightFlockMemberNightProgress(
                memberID: member,
                day: 4,
                status: .sharedGoalCompleted,
                shieldingEvidence: .observed
            )
        ]
        XCTAssertEqual(
            NightFlockRewardRules.membersMeetingSevenNightThreshold(in: withFourth),
            [member]
        )
    }

    func testOpeningInvitingAndSettingsNeverCreateGrants() {
        let empty = NightFlockRewardEngine.apply(
            grants: [],
            farm: .empty,
            search: .empty,
            ledger: .empty
        )
        XCTAssertTrue(empty.applied.isEmpty)
        XCTAssertEqual(empty.farm.woolBalance, 0)
        XCTAssertTrue(empty.search.outcomes.isEmpty)
    }
}
