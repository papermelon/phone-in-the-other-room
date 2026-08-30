import XCTest

final class SlumberPartyHomePresentationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testUsesOnlyFreshPartyScopedCompletedActivityForHighlight() {
        let partyID = UUID()
        let memberID = UUID()
        let expected = sharedActivity(
            partyID: partyID,
            memberID: memberID,
            status: .completed,
            kind: .windDown,
            minutes: 30,
            occurredAt: now.addingTimeInterval(-60)
        )
        let foreign = sharedActivity(
            partyID: UUID(),
            memberID: memberID,
            status: .completed,
            kind: .phoneAway,
            minutes: 45,
            occurredAt: now.addingTimeInterval(-5)
        )
        let stale = sharedActivity(
            partyID: partyID,
            memberID: memberID,
            status: .completed,
            kind: .phoneAway,
            minutes: 20,
            occurredAt: now.addingTimeInterval(-SlumberPartyHomePresentation.recentHighlightInterval - 1)
        )
        let detail = party(
            partyID: partyID,
            members: [member(memberID, name: "Moss")],
            sharedActivities: [foreign, stale, expected]
        )

        let highlight = SlumberPartyHomePresentation.highlight(in: detail, preserving: nil, at: now)

        XCTAssertEqual(highlight?.id, .completedActivity(expected.activityID))
        XCTAssertEqual(highlight?.title, "Moss completed Wind Down.")
        XCTAssertEqual(highlight?.detail, "30 quiet min · Recent shared moment")
    }

    func testPartialActivityAndUnsupportedEmptyStreamDoNotCreateCompletionHighlight() {
        let partyID = UUID()
        let memberID = UUID()
        let partial = sharedActivity(
            partyID: partyID,
            memberID: memberID,
            status: .partlyCompleted,
            kind: .phoneAway,
            minutes: 15,
            occurredAt: now
        )
        let membershipParty = party(
            partyID: partyID,
            members: [member(memberID, name: "Clover")],
            sharedActivities: [partial]
        )
        let unsupportedParty = party(
            partyID: partyID,
            members: [member(memberID, name: "Clover")],
            sharingScope: nil,
            sharedActivities: [sharedActivity(
                partyID: partyID,
                memberID: memberID,
                status: .completed,
                kind: .windDown,
                minutes: 30,
                occurredAt: now
            )]
        )

        XCTAssertNil(SlumberPartyHomePresentation.highlight(in: membershipParty, preserving: nil, at: now))
        XCTAssertNil(SlumberPartyHomePresentation.highlight(in: unsupportedParty, preserving: nil, at: now))
    }

    func testActivityAtExactFreshnessBoundaryExpiresAndDoesNotScheduleAnotherInvalidation() {
        let partyID = UUID()
        let memberID = UUID()
        let boundary = sharedActivity(
            partyID: partyID,
            memberID: memberID,
            status: .completed,
            kind: .windDown,
            minutes: 30,
            occurredAt: now.addingTimeInterval(-SlumberPartyHomePresentation.recentHighlightInterval)
        )
        let detail = party(
            partyID: partyID,
            members: [member(memberID, name: "Moss")],
            sharedActivities: [boundary]
        )

        XCTAssertNil(SlumberPartyHomePresentation.highlight(in: detail, preserving: nil, at: now))
        XCTAssertNil(SlumberPartyHomePresentation.nextHighlightInvalidation(in: detail, at: now))
    }

    func testLegacyRoundActivityRemainsAvailableForOldServerFallback() {
        let partyID = UUID()
        let memberID = UUID()
        let legacy = NightFlockV4Activity(
            activityID: UUID(), partyID: partyID, roundID: UUID(), memberID: memberID,
            day: 2, kind: .phoneAway, status: .completed, roundedMinutes: 20,
            occurredAt: now.addingTimeInterval(-10)
        )
        let detail = party(
            partyID: partyID,
            members: [member(memberID, name: "Clover")],
            sharingScope: nil,
            activities: [legacy]
        )

        let highlight = SlumberPartyHomePresentation.highlight(in: detail, preserving: nil, at: now)

        XCTAssertEqual(highlight?.id, .completedActivity(legacy.activityID))
        XCTAssertEqual(highlight?.title, "Clover completed Phone Away.")
    }

    func testReceivedEncouragementRequiresExactOwnedMembershipActivityAndIsPreferred() {
        let partyID = UUID()
        let myMemberID = UUID()
        let sourceID = UUID()
        let owned = sharedActivity(
            partyID: partyID,
            memberID: myMemberID,
            status: .completed,
            kind: .windDown,
            minutes: 30,
            occurredAt: now.addingTimeInterval(-120),
            sourceID: sourceID
        )
        let unscoped = sharedActivity(
            partyID: partyID,
            memberID: myMemberID,
            status: .completed,
            kind: .phoneAway,
            minutes: 20,
            occurredAt: now.addingTimeInterval(-5)
        )
        let detail = party(
            partyID: partyID,
            myMemberID: myMemberID,
            members: [member(myMemberID, name: "Me")],
            sharedActivities: [owned, unscoped],
            sharedCheers: [
                .init(activityID: owned.activityID, cheer: .warmWave, count: 2, sentByMe: false),
                .init(activityID: unscoped.activityID, cheer: .pawPrint, count: 9, sentByMe: false)
            ]
        )

        let highlight = SlumberPartyHomePresentation.highlight(in: detail, preserving: nil, at: now)

        XCTAssertEqual(highlight?.id, .receivedEncouragement(owned.activityID))
        XCTAssertEqual(highlight?.title, "2 warm cheers for your Wind Down.")
    }

    func testStableHighlightRemainsUntilItsSourceIsNoLongerEligible() {
        let partyID = UUID()
        let memberID = UUID()
        let older = sharedActivity(partyID: partyID, memberID: memberID, status: .completed, kind: .windDown, minutes: 20, occurredAt: now.addingTimeInterval(-30))
        let newer = sharedActivity(partyID: partyID, memberID: memberID, status: .completed, kind: .phoneAway, minutes: 30, occurredAt: now.addingTimeInterval(-5))
        let original = party(partyID: partyID, members: [member(memberID, name: "Moss")], sharedActivities: [older, newer])
        let selectedID = SlumberPartyHomeHighlightID.completedActivity(older.activityID)

        XCTAssertEqual(
            SlumberPartyHomePresentation.highlight(in: original, preserving: selectedID, at: now)?.id,
            selectedID
        )

        let refreshed = party(partyID: partyID, members: [member(memberID, name: "Moss")], sharedActivities: [newer])
        XCTAssertEqual(
            SlumberPartyHomePresentation.highlight(in: refreshed, preserving: selectedID, at: now)?.id,
            .completedActivity(newer.activityID)
        )
    }

    func testHighlightSelectedAfterExpiryRemainsStableAcrossLaterDetailRefresh() {
        let partyID = UUID()
        let memberID = UUID()
        let expiring = sharedActivity(
            partyID: partyID,
            memberID: memberID,
            status: .completed,
            kind: .windDown,
            minutes: 20,
            occurredAt: now.addingTimeInterval(-SlumberPartyHomePresentation.recentHighlightInterval + 1)
        )
        let replacement = sharedActivity(
            partyID: partyID,
            memberID: memberID,
            status: .completed,
            kind: .phoneAway,
            minutes: 30,
            occurredAt: now.addingTimeInterval(-10)
        )
        let original = party(
            partyID: partyID,
            members: [member(memberID, name: "Moss")],
            sharedActivities: [expiring, replacement]
        )
        let firstID = SlumberPartyHomeHighlightID.completedActivity(expiring.activityID)
        let afterExpiry = now.addingTimeInterval(2)
        let selectedAfterExpiry = SlumberPartyHomePresentation.highlight(
            in: original,
            preserving: firstID,
            at: afterExpiry
        )
        let arriving = sharedActivity(
            partyID: partyID,
            memberID: memberID,
            status: .completed,
            kind: .windDown,
            minutes: 45,
            occurredAt: afterExpiry
        )
        let refreshed = party(
            partyID: partyID,
            members: [member(memberID, name: "Moss")],
            sharedActivities: [replacement, arriving]
        )

        XCTAssertEqual(selectedAfterExpiry?.id, .completedActivity(replacement.activityID))
        XCTAssertEqual(
            SlumberPartyHomePresentation.highlight(
                in: refreshed,
                preserving: selectedAfterExpiry?.id,
                at: afterExpiry
            )?.id,
            .completedActivity(replacement.activityID)
        )
    }

    func testCompletedRoundUsesOnlyTheFactualLifecycleMilestone() throws {
        let partyID = UUID()
        let roundID = UUID()
        let startsOn = try XCTUnwrap(NightFlockLocalDate(
            date: now.addingTimeInterval(-8 * 24 * 60 * 60),
            timeZoneIdentifier: "UTC"
        ))
        let completedRound = NightFlockV4Round(
            roundID: roundID,
            number: 4,
            timeZoneIdentifier: "UTC",
            startsOn: startsOn,
            status: .completed
        )
        let detail = party(
            partyID: partyID,
            members: [member(UUID(), name: "Moss")],
            round: completedRound
        )

        let highlight = SlumberPartyHomePresentation.highlight(in: detail, preserving: nil, at: now)

        XCTAssertEqual(highlight?.id, .completedRound(roundID))
        XCTAssertEqual(highlight?.title, "This seven-night round is complete.")
        XCTAssertFalse(highlight?.title.contains("everyone") == true)
    }

    func testRemovedMemberCannotKeepSharedOrLegacyHighlightAlive() {
        let partyID = UUID()
        let formerMemberID = UUID()
        let currentMemberID = UUID()
        let shared = sharedActivity(
            partyID: partyID,
            memberID: formerMemberID,
            status: .completed,
            kind: .windDown,
            minutes: 30,
            occurredAt: now
        )
        let legacy = NightFlockV4Activity(
            activityID: UUID(), partyID: partyID, roundID: UUID(), memberID: formerMemberID,
            day: 1, kind: .phoneAway, status: .completed, roundedMinutes: 20, occurredAt: now
        )
        let detail = party(
            partyID: partyID,
            members: [member(currentMemberID, name: "Clover")],
            activities: [legacy],
            sharedActivities: [shared]
        )

        XCTAssertNil(SlumberPartyHomePresentation.highlight(in: detail, preserving: nil, at: now))
    }

    func testCompletedRoundExpiresAfterItsActualSevenNightWindow() throws {
        let partyID = UUID()
        let startsOn = try XCTUnwrap(NightFlockLocalDate(
            date: now.addingTimeInterval(-(7 + 3) * 24 * 60 * 60),
            timeZoneIdentifier: "UTC"
        ))
        let detail = party(
            partyID: partyID,
            members: [member(UUID(), name: "Moss")],
            round: .init(
                roundID: UUID(),
                number: 1,
                timeZoneIdentifier: "UTC",
                startsOn: startsOn,
                status: .completed
            )
        )

        XCTAssertNil(SlumberPartyHomePresentation.highlight(in: detail, preserving: nil, at: now))
    }

    func testMemberPreviewsPutCurrentUserFirstAndNeverRepeatTerminalActivity() {
        let partyID = UUID()
        let me = UUID()
        let other = UUID()
        let completed = sharedActivity(partyID: partyID, memberID: other, status: .completed, kind: .windDown, minutes: 30, occurredAt: now)
        let activeStatus = NightFlockV4SharedLiveStatus(
            statusID: UUID(), partyID: partyID, memberID: me, roundID: nil,
            status: .phoneAwayActive, revision: 1, observedAt: now,
            expiresAt: now.addingTimeInterval(60)
        )
        let detail = party(
            partyID: partyID,
            myMemberID: me,
            members: [member(other, name: "Moss"), member(me, name: "Clover")],
            sharedActivities: [completed],
            sharedLiveStatuses: [activeStatus]
        )

        let previews = SlumberPartyHomePresentation.memberPreviews(in: detail, at: now)

        XCTAssertEqual(previews.map(\.memberID), [me, other])
        XCTAssertEqual(previews[0].statusTitle, "Phone is away")
        XCTAssertEqual(previews[1].statusTitle, "No current status")
    }

    private func party(
        partyID: UUID,
        myMemberID: UUID? = nil,
        members: [NightFlockV4Membership],
        sharingScope: NightFlockV4SharingScope? = .membership,
        round: NightFlockV4Round? = nil,
        activities: [NightFlockV4Activity] = [],
        sharedActivities: [NightFlockV4SharedActivity] = [],
        sharedCheers: [NightFlockV4CheerSummary] = [],
        sharedLiveStatuses: [NightFlockV4SharedLiveStatus] = []
    ) -> NightFlockV4PartyDetail {
        NightFlockV4PartyDetail(
            summary: .init(
                partyID: partyID,
                name: "Moonfield",
                memberCount: members.count,
                myRole: .member,
                currentRound: round,
                revision: 1,
                sharingScope: sharingScope
            ),
            myMemberID: myMemberID,
            memberships: members,
            activities: activities,
            sharedActivities: sharedActivities,
            sharedLiveStatuses: sharedLiveStatuses,
            sharedCheers: sharedCheers
        )
    }

    private func member(_ id: UUID, name: String) -> NightFlockV4Membership {
        .init(memberID: id, profile: .init(displayName: name), role: .member, joinedAt: now)
    }

    private func sharedActivity(
        partyID: UUID,
        memberID: UUID,
        status: NightFlockV4ActivityStatus,
        kind: NightFlockV4ActivityKind,
        minutes: Int,
        occurredAt: Date,
        sourceID: UUID? = nil
    ) -> NightFlockV4SharedActivity {
        .init(
            activityID: UUID(), partyID: partyID, memberID: memberID,
            roundID: nil, day: nil, kind: kind, status: status,
            roundedMinutes: minutes, occurredAt: occurredAt,
            mySourceEventID: sourceID
        )
    }
}
