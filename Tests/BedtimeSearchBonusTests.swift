import XCTest

final class BedtimeSearchBonusTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_790_002_800)

    private func makeRun(minutes: Double = 30, day: Int = 0, startOffset: Double = 0) -> FocusRun {
        let plannedStart = start.addingTimeInterval(Double(day) * 86400)
        let bedtime = plannedStart.addingTimeInterval(1800)
        let wake = plannedStart.addingTimeInterval(9 * 3600)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let plan = NightWatchPlan(intendedBedtime: bedtime, wakeTime: wake, protectedUntil: wake,
            windDownMinutes: 30, morningQuietMinutes: 0, eveningActivity: .read,
            morningActivity: .openCurtains, calendar: calendar)
        let began = plannedStart.addingTimeInterval(startOffset)
        var result = FocusRun(id: FarmMigration.stableLegacyID(for: "bonus-test:\(day):\(startOffset):\(minutes)"),
                             plannedDurationSeconds: wake.timeIntervalSince(began),
                             startedAt: began, state: .endedEarly, nightWatchPlan: plan)
        result.endedAt = began.addingTimeInterval(minutes * 60)
        return result
    }

    private func farm() -> FarmState {
        var result = FarmState.empty
        result.migrateCumulativeCredit(records: [], searchState: .empty, protectedNightCount: 0)
        return result
    }

    func testStartWindowAndBedtimeBoundaries() {
        for (offset, minutes, expected) in [
            (-901.0, 60.0, BedtimeBonusReceipt.Result.outsideStartWindow),
            (-900, 45, .granted), (900, 15, .granted), (901, 30, .outsideStartWindow),
            (0, 29.99, .endedBeforeBedtime), (0, 30, .granted), (0, 31, .granted),
            (1800, 30, .outsideStartWindow)
        ] {
            var state = farm()
            let attempt = makeRun(minutes: minutes, startOffset: offset)
            state.settleCumulativeCredit(run: attempt, searchState: .empty)
            XCTAssertEqual(state.cumulativeCredit?.receipts[attempt.id]?.bedtimeBonus?.result,
                           expected, "offset \(offset), minutes \(minutes)")
        }
    }

    func testThresholdCarryConsumesTimeBeforeBonusAndDoesNotGrowWool() throws {
        var state = farm()
        state.recordArrival(SheepSearchEngine.calculate(runID: UUID(), protectedNightNumber: 1,
            evidence: .empty, state: .empty, now: start.addingTimeInterval(-60)).outcome)
        let id = try XCTUnwrap(state.sheep.first?.id)
        _ = try state.shear(sheepID: id, protectedNightCount: 0, at: start.addingTimeInterval(-30))
        let beforeGrowth = try XCTUnwrap(state.sheep.first?.regrowthSecondsRemaining)
        state.cumulativeCredit?.windDownSeconds = 320 * 60
        let attempt = makeRun(minutes: 30)
        state.settleCumulativeCredit(run: attempt, searchState: .empty)
        let ledger = try XCTUnwrap(state.cumulativeCredit)
        XCTAssertEqual(ledger.windDownSeconds, 0)
        XCTAssertEqual(ledger.bedtimeBonus?.remainingSearchSeconds, 14 * 60)
        XCTAssertEqual(ledger.outcomes.count, 1)
        XCTAssertEqual(ledger.receipts[attempt.id]?.creditedSeconds, 1800)
        XCTAssertEqual(ledger.receipts[attempt.id]?.bedtimeBonus?.grantedSearchSeconds, 5040)
        XCTAssertEqual(state.sheep.first?.regrowthSecondsRemaining, beforeGrowth - 1800)
        XCTAssertEqual(state.woolBalance, 1)
        XCTAssertTrue(try XCTUnwrap(ledger.receipts[attempt.id]).detail.contains("+20%"))
    }

    func testMultipleCrossingsAndFractionalRemainder() {
        var state = farm()
        state.cumulativeCredit?.windDownSeconds = 419 * 60 + 0.5
        state.settleCumulativeCredit(run: makeRun(minutes: 500), searchState: .empty)
        XCTAssertEqual(state.cumulativeCredit?.outcomes.count, 2)
        XCTAssertEqual(state.cumulativeCredit?.windDownSeconds, 79 * 60 + 0.5)
        XCTAssertEqual(state.cumulativeCredit?.bedtimeBonus?.remainingSearchSeconds, 5040)
    }

    func testReplayRestartAndSavedNightAttribution() throws {
        var state = farm()
        let first = makeRun()
        state.settleCumulativeCredit(run: first, searchState: .empty)
        state = try JSONDecoder().decode(FarmState.self, from: JSONEncoder().encode(state))
        let saved = state
        state.settleCumulativeCredit(run: first, searchState: .empty)
        XCTAssertEqual(state, saved)
        var restarted = makeRun(minutes: 60, startOffset: 60)
        // A later schedule edit must not change the already captured night identity.
        restarted.nightWatchPlan?.intendedBedtime = first.nightWatchPlan!.intendedBedtime.addingTimeInterval(60)
        state.settleCumulativeCredit(run: restarted, searchState: .empty)
        XCTAssertEqual(state.cumulativeCredit?.receipts[restarted.id]?.bedtimeBonus?.result, .alreadyGranted)
        XCTAssertEqual(state.cumulativeCredit?.bedtimeBonus?.grantedNights.count, 1)
        state.settleCumulativeCredit(run: makeRun(day: 1), searchState: .empty)
        XCTAssertEqual(state.cumulativeCredit?.bedtimeBonus?.grantedNights.count, 2)
    }

    func testAccessAndUnknownTrackingRemainSeparateFromBonus() {
        var state = farm()
        var attempt = makeRun()
        attempt.briefAccessUseCount = 1
        attempt.briefAccessIntervals = [DateInterval(start: attempt.startedAt, duration: 300)]
        state.settleCumulativeCredit(run: attempt, searchState: .empty)
        XCTAssertEqual(state.cumulativeCredit?.receipts[attempt.id]?.creditedSeconds, 1500)
        XCTAssertEqual(state.cumulativeCredit?.receipts[attempt.id]?.bedtimeBonus?.result, .granted)
        var unknown = makeRun(day: 1)
        unknown.briefAccessUseCount = 1
        state.settleCumulativeCredit(run: unknown, searchState: .empty)
        XCTAssertEqual(state.cumulativeCredit?.receipts[unknown.id]?.bedtimeBonus?.result, .unknown)
        XCTAssertEqual(state.cumulativeCredit?.bedtimeBonus?.grantedNights.count, 1)
    }

    func testLegacyMigrationPracticeOtherModesAndInterruptedRunsNeverGrantBonus() {
        for scenario in 0..<8 {
            var state = farm()
            var attempt = makeRun(minutes: 60)
            switch scenario {
            case 0: attempt.farmCreditVersion = 1
            case 1: attempt.isPractice = true
            case 2: attempt.nightWatchPlan?.role = .additionalQuiet
            case 3: attempt.nightWatchPlan?.localDateAnchor = nil
            case 4: attempt.endedEarlyReason = .appInterrupted
            case 5: attempt.nightWatchPlan?.windDownMinutes = 0
            case 6: attempt.plannedEndAt = attempt.startedAt.addingTimeInterval(60)
            default: break
            }
            state.settleCumulativeCredit(run: attempt, searchState: .empty, migrated: scenario == 7)
            XCTAssertNil(state.cumulativeCredit?.bedtimeBonus, "scenario \(scenario)")
        }
    }

    func testOldQueuedPayloadIsLosslessAndNewBonusRequiresNewFarmSchema() throws {
        var state = farm()
        state.schemaVersion = 3
        let document = FarmSaveDocument(lineageID: UUID(), generation: 1,
            values: ["ollie.farm.state": try JSONEncoder().encode(state)])
        let oldPayload = try FarmBackupPayload(document: document)
        let oldBytes = try JSONEncoder().encode(oldPayload)
        let restored = try FarmBackupPayload.decodeRemote(oldBytes)
        XCTAssertEqual(restored.farm.schemaVersion, 3)
        XCTAssertEqual(try restored.fingerprint(), try oldPayload.fingerprint())
        state = restored.farm
        state.settleCumulativeCredit(run: makeRun(), searchState: .empty)
        XCTAssertEqual(state.schemaVersion, 4)
        let newDocument = FarmSaveDocument(lineageID: document.lineageID, generation: 2,
            values: ["ollie.farm.state": try JSONEncoder().encode(state)])
        let newPayload = try FarmBackupPayload(document: newDocument)
        let decoded = try FarmBackupPayload.decodeRemote(JSONEncoder().encode(newPayload))
        XCTAssertEqual(decoded.farm, state)
        let values = try decoded.restoredValues(preservingLocalProgress: .empty)
        var replay = try JSONDecoder().decode(FarmState.self, from: XCTUnwrap(values["ollie.farm.state"]))
        replay.settleCumulativeCredit(run: makeRun(), searchState: .empty)
        XCTAssertEqual(replay.cumulativeCredit?.bedtimeBonus?.grantedNights.count, 1)
        // The released v3 local/wire gate rejects this before its forgiving decoder.
        XCTAssertGreaterThan(decoded.farm.schemaVersion, 3)
        XCTAssertNil(restored.farm.cumulativeCredit?.bedtimeBonus)
    }

    func testSameNightKeySurvivesTimezoneChangesAndDifferentAccountIsIndependent() throws {
        var state = farm()
        let first = makeRun()
        state.settleCumulativeCredit(run: first, searchState: .empty)
        var shifted = makeRun(minutes: 60)
        let anchor = try XCTUnwrap(shifted.nightWatchPlan?.localDateAnchor)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(anchor)) as? [String: Any])
        object["timeZoneIdentifier"] = "America/New_York"
        shifted.nightWatchPlan?.localDateAnchor = try JSONDecoder().decode(NightWatchLocalDateAnchor.self,
            from: JSONSerialization.data(withJSONObject: object))
        state.settleCumulativeCredit(run: shifted, searchState: .empty)
        XCTAssertEqual(state.cumulativeCredit?.bedtimeBonus?.grantedNights.count, 1)
        var otherAccount = farm()
        otherAccount.settleCumulativeCredit(run: shifted, searchState: .empty)
        XCTAssertEqual(otherAccount.cumulativeCredit?.bedtimeBonus?.grantedNights.count, 1)
    }

    func testPresentationShowsUnspentContributionsAndCannotPrematurelySayFull() {
        let credit = CumulativeFarmCredit(windDownSeconds: 256 * 60, phoneAwaySeconds: 300,
            bedtimeBonus: BedtimeSearchBonus(remainingSearchSeconds: 5040))
        let display = SearchTrailPresentation(credit: credit)
        XCTAssertEqual(display.percentage, 81)
        XCTAssertEqual(display.time, "4h 16m")
        XCTAssertEqual(display.phoneAway, "5 / 100 min")
        XCTAssertNotNil(display.bonusShare)
        XCTAssertNil(SearchTrailPresentation(credit: CumulativeFarmCredit()).bonusShare)
        XCTAssertEqual(SearchTrailPresentation(credit: CumulativeFarmCredit(windDownSeconds: 25199)).percentage, 99)
    }

    func testInvalidBonusAmountsCannotEnterThroughRestore() throws {
        for invalid in [-1.0, CumulativeFarmCredit.windDownSearchSeconds] {
            let bytes = try JSONEncoder().encode(BedtimeSearchBonus(remainingSearchSeconds: invalid))
            XCTAssertThrowsError(try JSONDecoder().decode(BedtimeSearchBonus.self, from: bytes))
        }
    }

    func testDSTAndMidnightUseFrozenAbsolutePlanBoundaries() throws {
        for bedtimeString in ["2026-03-08T07:15:00Z", "2026-11-01T06:15:00Z", "2026-09-21T00:10:00Z"] {
            let bedtime = try XCTUnwrap(ISO8601DateFormatter().date(from: bedtimeString))
            let began = bedtime.addingTimeInterval(-1800)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
            let plan = NightWatchPlan(intendedBedtime: bedtime, wakeTime: bedtime.addingTimeInterval(8 * 3600),
                protectedUntil: bedtime.addingTimeInterval(8 * 3600), windDownMinutes: 30,
                morningQuietMinutes: 0, eveningActivity: .read, morningActivity: .openCurtains, calendar: calendar)
            var attempt = FocusRun(plannedDurationSeconds: 8.5 * 3600, startedAt: began,
                                   state: .endedEarly, nightWatchPlan: plan)
            attempt.endedAt = bedtime
            var state = farm()
            state.settleCumulativeCredit(run: attempt, searchState: .empty)
            XCTAssertEqual(state.cumulativeCredit?.receipts[attempt.id]?.bedtimeBonus?.result, .granted)
        }
    }

    func testThirtyDayEconomyComparison() throws {
        for (label, duration, phoneMinutes, regular) in [
            ("bedtime-only", 420.0, 0.0, true), ("mixed", 420, 100, true),
            ("heavy-phone-away", 420, 500, true), ("short", 30, 0, true),
            ("irregular", 240, 100, false)
        ] {
            var old = farm(), new = farm()
            for day in 0..<30 {
                var attempt = makeRun(minutes: duration, day: day, startOffset: regular || day.isMultiple(of: 3) ? 0 : 1200)
                new.settleCumulativeCredit(run: attempt, searchState: .empty)
                attempt.farmCreditVersion = 1
                old.settleCumulativeCredit(run: attempt, searchState: .empty)
                if phoneMinutes > 0 {
                    var phone = makeRun(minutes: phoneMinutes, day: day, startOffset: 10 * 3600)
                    phone.nightWatchPlan?.role = .additionalQuiet
                    phone.plannedEndAt = phone.startedAt.addingTimeInterval(phoneMinutes * 60)
                    phone.nightWatchPlan?.protectedUntil = phone.plannedEndAt
                    new.settleCumulativeCredit(run: phone, searchState: .empty)
                    old.settleCumulativeCredit(run: phone, searchState: .empty)
                }
                for id in old.activeSheep.filter({ FarmEconomyRules.isWoolReady(for: $0, protectedNightCount: 0) }).map(\.id) {
                    _ = try old.shear(sheepID: id, protectedNightCount: 0, at: attempt.endedAt!)
                }
                for id in new.activeSheep.filter({ FarmEconomyRules.isWoolReady(for: $0, protectedNightCount: 0) }).map(\.id) {
                    _ = try new.shear(sheepID: id, protectedNightCount: 0, at: attempt.endedAt!)
                }
            }
            XCTAssertGreaterThanOrEqual(new.cumulativeCredit!.outcomes.count, old.cumulativeCredit!.outcomes.count)
            XCTAssertEqual(new.cumulativeCredit!.receipts.values.reduce(0) { $0 + $1.creditedSeconds },
                           old.cumulativeCredit!.receipts.values.reduce(0) { $0 + $1.creditedSeconds })
            print("SEARCH_BALANCE \(label): searches \(old.cumulativeCredit!.outcomes.count)->\(new.cumulativeCredit!.outcomes.count), sheep \(old.sheep.count)->\(new.sheep.count), pending \(old.pendingSheep.count)->\(new.pendingSheep.count), wool \(old.woolBalance)->\(new.woolBalance)")
        }
    }
}
