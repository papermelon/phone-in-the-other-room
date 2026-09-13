import XCTest

final class NightFlockSharedHabitsFenceTests: XCTestCase {
    func testFenceStopsAllPublicationAndOnlyItsPartyRead() {
        let fencedParty = UUID()
        let otherParty = UUID()
        let fence = NightFlockSharedHabitsPrivacyFence(
            partyID: fencedParty,
            action: .leave
        )

        XCTAssertFalse(NightFlockSharedHabitsFencePolicy.permitsAnyPublication(fences: [fence]))
        XCTAssertFalse(
            NightFlockSharedHabitsFencePolicy.permitsPartyReadOrPublication(
                partyID: fencedParty,
                fences: [fence]
            )
        )
        XCTAssertTrue(
            NightFlockSharedHabitsFencePolicy.permitsPartyReadOrPublication(
                partyID: otherParty,
                fences: [fence]
            )
        )
    }

    func testLatestFenceForPartyReplacesEarlierAction() {
        let partyID = UUID()
        let leave = NightFlockSharedHabitsPrivacyFence(partyID: partyID, action: .leave)
        let withdraw = NightFlockSharedHabitsPrivacyFence(partyID: partyID, action: .withdrawHistory)

        XCTAssertEqual(
            NightFlockSharedHabitsFencePolicy.replacing([leave], with: withdraw),
            [withdraw]
        )
    }

    func testWithdrawalRetryRequiresAnAuthoritativeSnapshot() {
        XCTAssertNil(
            NightFlockSharedHabitsFencePolicy.withdrawalRetryRequiresRemoteDelete(
                canonicalSnapshotLoaded: false,
                partyIsStillPresent: false
            )
        )
        XCTAssertEqual(
            NightFlockSharedHabitsFencePolicy.withdrawalRetryRequiresRemoteDelete(
                canonicalSnapshotLoaded: true,
                partyIsStillPresent: true
            ),
            false
        )
        XCTAssertEqual(
            NightFlockSharedHabitsFencePolicy.withdrawalRetryRequiresRemoteDelete(
                canonicalSnapshotLoaded: true,
                partyIsStillPresent: false
            ),
            true
        )
    }

    func testLegacyPartyExitUsesEstablishedTransportWithoutPausingOtherPublication() {
        XCTAssertEqual(
            NightFlockSharedHabitsFencePolicy.partyExitDisposition(
                supportsSharedHabits: false
            ),
            .sendLegacyCommand
        )
        XCTAssertTrue(
            NightFlockSharedHabitsFencePolicy.permitsAnyPublication(fences: [])
        )
    }

    func testCapabilityLossPreservesAnExistingHistoryDeletionFenceWithoutNewArchiveWork() {
        let pendingDeletion = NightFlockSharedHabitsPrivacyFence(
            partyID: UUID(),
            action: .withdrawHistory
        )

        XCTAssertEqual(
            NightFlockSharedHabitsFencePolicy.archiveDeletionDisposition(
                supportsSharedHabits: false,
                fence: pendingDeletion
            ),
            .preservePendingFence
        )
        XCTAssertFalse(
            NightFlockSharedHabitsFencePolicy.permitsAnyPublication(fences: [pendingDeletion])
        )
        XCTAssertEqual(
            NightFlockSharedHabitsFencePolicy.archiveDeletionDisposition(
                supportsSharedHabits: false,
                fence: nil
            ),
            .unavailable
        )
        XCTAssertEqual(
            NightFlockSharedHabitsFencePolicy.archiveDeletionDisposition(
                supportsSharedHabits: true,
                fence: pendingDeletion
            ),
            .send
        )
    }

    func testJoinIntentCannotResolveForAnotherCommand() {
        let intendedCommand = UUID()
        let intent = NightFlockSharedHabitsJoinAgreementIntent(
            commandID: intendedCommand,
            partyID: nil,
            timeZoneIdentifier: "Asia/Singapore",
            createdAt: Date()
        )
        XCTAssertNil(
            NightFlockSharedHabitsJoinAgreementIntentPolicy.resolving(
                intent,
                commandID: UUID(),
                partyID: UUID()
            )
        )
        let partyID = UUID()
        XCTAssertEqual(
            NightFlockSharedHabitsJoinAgreementIntentPolicy.resolving(
                intent,
                commandID: intendedCommand,
                partyID: partyID
            )?.partyID,
            partyID
        )
        XCTAssertTrue(NightFlockSharedHabitsJoinAgreementIntentPolicy.permitsResume(
            NightFlockSharedHabitsJoinAgreementIntentPolicy.resolving(
                intent, commandID: intendedCommand, partyID: partyID
            ),
            partyID: partyID,
            isCurrentMember: true,
            hasCurrentMemberDetail: true,
            agreementIsMissing: true
        ))
        XCTAssertFalse(NightFlockSharedHabitsJoinAgreementIntentPolicy.permitsResume(
            NightFlockSharedHabitsJoinAgreementIntentPolicy.resolving(
                intent, commandID: intendedCommand, partyID: partyID
            ),
            partyID: UUID(),
            isCurrentMember: true,
            hasCurrentMemberDetail: true,
            agreementIsMissing: true
        ))
    }

    func testSleepDeliveryIsScopedToPartyAgreementAndEpoch() {
        let partyA = UUID()
        let partyB = UUID()
        let agreementA = UUID()
        let epochA = UUID()
        let deliveryA = NightFlockSharedHabitsSleepDelivery(
            partyID: partyA,
            agreementID: agreementA,
            memberEpochID: epochA
        )
        let deliveries = NightFlockSharedHabitsSleepDeliveryPolicy.adding(deliveryA, to: nil)
        XCTAssertTrue(NightFlockSharedHabitsSleepDeliveryPolicy.contains(
            deliveries, partyID: partyA, agreementID: agreementA, memberEpochID: epochA
        ))
        XCTAssertFalse(NightFlockSharedHabitsSleepDeliveryPolicy.contains(
            deliveries, partyID: partyB, agreementID: UUID(), memberEpochID: UUID()
        ))
        let bothDelivered = NightFlockSharedHabitsSleepDeliveryPolicy.adding(
            .init(partyID: partyB, agreementID: UUID(), memberEpochID: UUID()),
            to: deliveries
        )
        XCTAssertEqual(bothDelivered.count, 2)
        XCTAssertFalse(NightFlockSharedHabitsSleepDeliveryPolicy.contains(
            NightFlockSharedHabitsSleepDeliveryPolicy.resettingForNewRevision(),
            partyID: partyA, agreementID: agreementA, memberEpochID: epochA
        ))
    }
}

extension NightFlockSharedHabitsFenceTests {
    func testOutboxIdentitySeparatesKindAndMembershipAuthority() {
        let partyID = UUID()
        let sourceID = UUID()
        let agreementID = UUID()
        let epochID = UUID()
        let windDown = sharedHabitOutboxRecord(
            partyID: partyID, sourceID: sourceID, agreementID: agreementID,
            epochID: epochID, kind: .windDown
        )
        let sleep = sharedHabitOutboxRecord(
            partyID: partyID, sourceID: sourceID, agreementID: agreementID,
            epochID: epochID, kind: .sleep
        )
        let rejoined = sharedHabitOutboxRecord(
            partyID: partyID, sourceID: sourceID, agreementID: UUID(),
            epochID: UUID(), kind: .windDown
        )

        XCTAssertNotEqual(windDown.identity, sleep.identity)
        XCTAssertNotEqual(windDown.identity, rejoined.identity)
    }

    func testOutboxKeepsSameSourceForDifferentPartiesAndEpochs() {
        let sourceID = UUID()
        let partyA = sharedHabitOutboxRecord(partyID: UUID(), sourceID: sourceID, agreementID: UUID(), epochID: UUID(), kind: .sleep)
        let partyB = sharedHabitOutboxRecord(partyID: UUID(), sourceID: sourceID, agreementID: UUID(), epochID: UUID(), kind: .sleep)
        let rejoin = sharedHabitOutboxRecord(partyID: partyA.record.partyID, sourceID: sourceID, agreementID: UUID(), epochID: UUID(), kind: .sleep)

        let afterTwoParties = NightFlockSharedHabitsOutboxRules.merge(partyB, into: [partyA])
        XCTAssertEqual(afterTwoParties?.count, 2)
        let afterRejoin = NightFlockSharedHabitsOutboxRules.merge(rejoin, into: afterTwoParties ?? [])
        XCTAssertEqual(afterRejoin?.count, 3)
    }

    func testOutboxRefusesCapacityInsteadOfEvictingOldPublication() {
        let records = (0..<128).map { index in
            sharedHabitOutboxRecord(
                partyID: UUID(), sourceID: UUID(), agreementID: UUID(), epochID: UUID(),
                kind: index.isMultiple(of: 2) ? .windDown : .phoneAway
            )
        }
        let incoming = sharedHabitOutboxRecord(
            partyID: UUID(), sourceID: UUID(), agreementID: UUID(), epochID: UUID(), kind: .sleep
        )
        XCTAssertNil(NightFlockSharedHabitsOutboxRules.merge(incoming, into: records))
        XCTAssertEqual(records.count, 128)
    }

    private func sharedHabitOutboxRecord(
        partyID: UUID,
        sourceID: UUID,
        agreementID: UUID,
        epochID: UUID,
        kind: NightFlockSharedHabitKind
    ) -> NightFlockSharedHabitsOutboxRecord {
        let record = NightFlockSharedHabitRecord(
            recordID: UUID(), partyID: partyID, memberID: UUID(), sourceID: sourceID,
            revision: 1, kind: kind,
            localDate: NightFlockLocalDate(year: 2026, month: 8, day: 28),
            timeZoneIdentifier: "Asia/Singapore", minutes: 20, outcome: .completed,
            protectionMinutes: nil, evidence: .none,
            profileSnapshot: NightFlockSharedHabitProfileSnapshot(displayName: "Moss", avatarID: nil),
            isFormerMember: false, migratedAt: nil
        )
        return NightFlockSharedHabitsOutboxRecord(
            record: record, agreementID: agreementID, memberEpochID: epochID,
            idempotencyKey: String(repeating: "a", count: 64)
        )
    }
}
