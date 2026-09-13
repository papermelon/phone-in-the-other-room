import XCTest

final class SharedMeadowTests: XCTestCase {
    private let partyID = UUID(uuidString: "91000000-0000-4000-8000-000000000001")!
    private let me = UUID(uuidString: "91000000-0000-4000-8000-000000000002")!
    private let friend = UUID(uuidString: "91000000-0000-4000-8000-000000000003")!
    private let now = Date(timeIntervalSince1970: 1_788_912_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        calendar.locale = Locale(identifier: "en_SG")
        return calendar
    }

    // MARK: Visits

    func testVisitStaysSevenNightsAndCountsDownTruthfully() {
        let visit = SharedFarmVisit(partyID: partyID, memberID: me, sheepDefinitionID: "bramble",
                                    sheepDisplayName: "Bramble", sentAt: now)
        XCTAssertTrue(visit.isCurrent(at: now))
        XCTAssertEqual(visit.nightsRemaining(at: now), 7)
        XCTAssertEqual(visit.nightsRemaining(at: now.addingTimeInterval(6.5 * 86_400)), 1)
        XCTAssertFalse(visit.isCurrent(at: now.addingTimeInterval(7 * 86_400)))
        XCTAssertEqual(visit.nightsRemaining(at: now.addingTimeInterval(8 * 86_400)), 0)
    }

    func testVisitCopyDistinguishesOwnerAndNeverClaimsMoreThanNameAndLook() {
        XCTAssertEqual(
            SharedFarmSocialCopy.visitLine(sheepName: "Bramble", ownerName: "Moss", isMe: false, nightsRemaining: 3),
            "Moss’s Bramble is visiting · 3 nights left"
        )
        XCTAssertEqual(
            SharedFarmSocialCopy.visitLine(sheepName: "Bramble", ownerName: "Clover", isMe: true, nightsRemaining: 1),
            "Your Bramble is visiting · last night"
        )
        let preview = SharedFarmSocialCopy.visitSenderPreview(sheepName: "Bramble")
        XCTAssertTrue(preview.contains("7 nights"))
        XCTAssertTrue(preview.contains("nothing else from your Farm is shared"))
    }

    // MARK: Greetings

    func testGreetingIdentityCollapsesRepeatedTapsButNotDifferentCheers() {
        let base = SharedFarmGreeting(id: UUID(), partyID: partyID, senderMemberID: me, recipientMemberID: friend,
                                      cheer: .pawPrint, context: .meadow, sentAt: now, delivery: .pending)
        var repeat_ = base
        repeat_.id = UUID()
        repeat_.sentAt = now.addingTimeInterval(5)
        XCTAssertEqual(base.identity, repeat_.identity)
        var other = base
        other.cheer = .moonGlow
        XCTAssertNotEqual(base.identity, other.identity)
        var bound = base
        bound.context = .update(activityID: UUID())
        XCTAssertNotEqual(base.identity, bound.identity)
    }

    func testDeliveryTitlesNeverClaimAttention() {
        for state in [SharedFarmGreetingDelivery.pending, .accepted, .receivedByApp, .failed] {
            XCTAssertFalse(state.title.lowercased().contains("seen"))
            XCTAssertFalse(state.title.lowercased().contains("read"))
        }
        XCTAssertTrue(SharedFarmGreetingDelivery.receivedByApp.isSettled)
        XCTAssertFalse(SharedFarmGreetingDelivery.failed.isSettled)
    }

    func testSenderPreviewAndRecipientLineNameBothPeopleAndContext() {
        XCTAssertEqual(
            SharedFarmSocialCopy.senderPreview(cheer: .warmWave, recipientName: "Moss", contextTitle: "last night"),
            "Moss’s app will show a warm wave from you beside last night."
        )
        XCTAssertEqual(
            SharedFarmSocialCopy.recipientLine(cheer: .pawPrint, senderName: "Clover", contextTitle: nil),
            "Clover left a paw print on the shared Farm."
        )
    }

    func testGreetingCodableRoundTripKeepsContext() throws {
        let greeting = SharedFarmGreeting(id: UUID(), partyID: partyID, senderMemberID: me, recipientMemberID: friend,
                                          cheer: .moonGlow, context: .visit(visitID: UUID()), sentAt: now, delivery: .accepted)
        let data = try JSONEncoder().encode(greeting)
        XCTAssertEqual(try JSONDecoder().decode(SharedFarmGreeting.self, from: data), greeting)
    }

    // MARK: Update line ("0 min · Completed")

    func testCompletedWindDownWithZeroBeforeBedMinutesIsExplainedNotZeroed() {
        let line = SharedFarmSocialCopy.updateLine(kind: .windDown, status: .completed, roundedMinutes: 0,
                                                   occurredAt: now.addingTimeInterval(-86_400), now: now, calendar: calendar)
        XCTAssertEqual(line, "Completed Wind Down · 0 before-bed min recorded · last night")
        XCTAssertFalse(line.contains("0 min"))
    }

    func testUpdateLineVariants() {
        XCTAssertEqual(
            SharedFarmSocialCopy.updateLine(kind: .windDown, status: .completed, roundedMinutes: 45, occurredAt: now, now: now, calendar: calendar),
            "Wound down 45 min before bed · today"
        )
        XCTAssertEqual(
            SharedFarmSocialCopy.updateLine(kind: .phoneAway, status: .partlyCompleted, roundedMinutes: 15, occurredAt: now, now: now, calendar: calendar),
            "Phone Away ended early after 15 min · today"
        )
        XCTAssertEqual(
            SharedFarmSocialCopy.updateLine(kind: .phoneAway, status: .partlyCompleted, roundedMinutes: 0, occurredAt: now, now: now, calendar: calendar),
            "Phone Away ended early · today"
        )
    }

    func testRelativeNightUsesWeekdayWithinAWeekAndDateBeyond() {
        let threeDaysAgo = now.addingTimeInterval(-3 * 86_400)
        let name = SharedFarmSocialCopy.relativeNight(threeDaysAgo, now: now, calendar: calendar)
        XCTAssertTrue(name.hasSuffix(" night"))
        XCTAssertFalse(name.hasPrefix("last"))
        let old = SharedFarmSocialCopy.relativeNight(now.addingTimeInterval(-20 * 86_400), now: now, calendar: calendar)
        XCTAssertFalse(old.contains("night"))
    }

    func testSharedActivityPresentationExplainsZeroMinutesInsteadOfPrintingThem() {
        let completed = NightFlockV4SharedActivity(activityID: UUID(), partyID: partyID, memberID: me, kind: .windDown,
                                                    status: .completed, roundedMinutes: 0, occurredAt: now)
        let presentation = NightFlockV4Presentation.activityPresentation(for: completed)
        XCTAssertEqual(presentation.cardSummary, "Wind Down · 0 before-bed min recorded · rounded")
        XCTAssertEqual(presentation.cardState, "Recent shared moment · Completed")
        XCTAssertFalse(presentation.latestMemberLine.contains("0 min"))
        XCTAssertEqual(NightFlockV4Presentation.minutesTitle(kind: .phoneAway, status: .completed, roundedMinutes: 30), "30 min · rounded")
        XCTAssertEqual(NightFlockV4Presentation.minutesTitle(kind: .phoneAway, status: .partlyCompleted, roundedMinutes: 0), "Under a minute")
    }

    // MARK: Layout

    func testSeededPositionsAreDeterministicInsideBoundsAndSeparateVisitorsFromMembers() {
        let member = SharedMeadowOccupant.member(me)
        let visitor = SharedMeadowOccupant.visitor(UUID(uuidString: "94000000-0000-4000-8000-000000000001")!)
        let a = SharedMeadowLayout.seededPosition(for: member, memberIndex: 0, memberCount: 2, seed: 7)
        let b = SharedMeadowLayout.seededPosition(for: member, memberIndex: 0, memberCount: 2, seed: 7)
        XCTAssertEqual(a, b)
        let v = SharedMeadowLayout.seededPosition(for: visitor, memberIndex: 0, memberCount: 2, seed: 7)
        XCTAssertNotEqual(a, v)
        for point in [a, v] {
            XCTAssertGreaterThanOrEqual(point.x, PastureSceneLayout.groundMinimum.x)
            XCTAssertLessThanOrEqual(point.x, PastureSceneLayout.groundMaximum.x)
            XCTAssertGreaterThanOrEqual(point.y, PastureSceneLayout.groundMinimum.y)
            XCTAssertLessThanOrEqual(point.y, PastureSceneLayout.groundMaximum.y)
        }
    }

    func testEightMembersUseDistinctPlacesWithoutLeavingGround() {
        let points = (0..<8).map {
            SharedMeadowLayout.seededPosition(for: .member(UUID()), memberIndex: $0, memberCount: 8, seed: 3)
        }
        XCTAssertTrue(points.allSatisfy(SharedPastureRules.isWalkable))
        XCTAssertLessThan(points[4].y, points[0].y, "second row stands further back")
    }

    func testFourMembersKeepDistinctGroundAnchorsAsThirdAndFourthArrive() {
        let four = (0..<4).map { SharedMeadowLayout.seededPosition(for: .member(UUID()), memberIndex: $0, memberCount: 4, seed: 3) }
        let three = (0..<3).map { SharedMeadowLayout.seededPosition(for: .member(UUID()), memberIndex: $0, memberCount: 3, seed: 3) }
        XCTAssertEqual(Array(four.prefix(3)), three, "An arrival does not reshuffle existing people")
        XCTAssertTrue(four.allSatisfy(SharedPastureRules.isWalkable))
        for i in four.indices {
            for j in four.indices where j > i { XCTAssertGreaterThan(four[i].distance(to: four[j]), 0.15) }
        }
    }

    func testGreetingCandidateRequiresMyOwnCharacterNearAFriend() {
        let friendPoint = PastureScenePoint(x: 0.5, y: 0.7)
        let positions: [SharedMeadowOccupant: PastureScenePoint] = [.member(friend): friendPoint, .member(me): PastureScenePoint(x: 0.2, y: 0.7)]
        XCTAssertEqual(
            SharedMeadowLayout.greetingCandidate(droppedIsMine: true, at: PastureScenePoint(x: 0.53, y: 0.72), positions: positions, me: me),
            friend
        )
        XCTAssertNil(SharedMeadowLayout.greetingCandidate(droppedIsMine: false, at: PastureScenePoint(x: 0.53, y: 0.72), positions: positions, me: me))
        XCTAssertNil(SharedMeadowLayout.greetingCandidate(droppedIsMine: true, at: PastureScenePoint(x: 0.9, y: 0.9), positions: positions, me: me))
    }

    func testArrangementDecodingRejectsUnknownSchema() throws {
        var arrangement = SharedMeadowArrangement()
        arrangement.positions["member-x"] = PastureScenePoint(x: 0.4, y: 0.7)
        let data = try JSONEncoder().encode(arrangement)
        XCTAssertEqual(SharedMeadowArrangement.decodeSafely(data), arrangement)
        let future = Data(#"{"schemaVersion":99,"positions":{}}"#.utf8)
        XCTAssertNil(SharedMeadowArrangement.decodeSafely(future))
        XCTAssertNil(SharedMeadowArrangement.decodeSafely(nil))
    }

    // MARK: Nudge (shared rule for both Farms)

    func testNudgeDisplacesOnlyOverlappedNeighboursAndKeepsSpacing() {
        let landing = PastureScenePoint(x: 0.5, y: 0.7)
        let neighbours = [
            PastureSceneNeighbour(key: "near", point: PastureScenePoint(x: 0.52, y: 0.71), footprint: .sheep),
            PastureSceneNeighbour(key: "far", point: PastureScenePoint(x: 0.85, y: 0.85), footprint: .sheep)
        ]
        let plan = PastureSceneLayout.nudgePlan(dropped: "me", footprint: .sheep, at: landing, among: neighbours, seed: 11)
        XCTAssertEqual(plan.landing, landing)
        XCTAssertEqual(plan.displaced.map(\.key), ["near"])
        let minimum = PastureSceneLayout.minimumSpacing(.sheep, .sheep)
        XCTAssertGreaterThanOrEqual(plan.displaced[0].target.distance(to: landing), minimum - 0.0001)
        XCTAssertGreaterThanOrEqual(plan.displaced[0].target.distance(to: neighbours[1].point), minimum - 0.0001)
    }

    func testNudgeIsDeterministicForTheSameSeed() {
        let neighbours = [PastureSceneNeighbour(key: "n", point: PastureScenePoint(x: 0.5, y: 0.7), footprint: .ollie)]
        let a = PastureSceneLayout.nudgePlan(dropped: "d", footprint: .sheep, at: PastureScenePoint(x: 0.5, y: 0.7), among: neighbours, seed: 4)
        let b = PastureSceneLayout.nudgePlan(dropped: "d", footprint: .sheep, at: PastureScenePoint(x: 0.5, y: 0.7), among: neighbours, seed: 4)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.displaced.count, 1)
    }

    func testGenericSettleMatchesEntitySettleForPersonalPasture() {
        let sheepA = PastureSceneEntityID.sheep(me, pastureIndex: 0)
        let sheepB = PastureSceneEntityID.sheep(friend, pastureIndex: 0)
        let point = PastureScenePoint(x: 0.5, y: 0.7)
        let viaEntity = PastureSceneLayout.settledPosition(proposed: point, for: sheepB, among: [sheepA: point])
        let viaGeneric = PastureSceneLayout.settledPosition(
            proposed: point, footprint: .sheep, entityKey: sheepB.id,
            among: [PastureSceneNeighbour(key: sheepA.id, point: point, footprint: .sheep)]
        )
        XCTAssertEqual(viaEntity, viaGeneric)
    }
}
