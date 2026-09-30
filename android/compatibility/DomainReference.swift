import Foundation

// Only sanitized reference data; calculations and round trips use the current production Swift types.
func generateDomainReference(in directory: URL) throws {
    let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
    let dec = JSONDecoder()
    func ms(_ date: Date) -> Int64 { Int64((date.timeIntervalSince1970 * 1000).rounded()) }
    func millis(_ value: Double) -> Int64 { Int64((value * 1000).rounded()) }
    func optional(_ value: Any?) -> Any { value ?? NSNull() }
    func date(_ raw: String) -> Date { ISO8601DateFormatter().date(from: raw)! }
    func calendar(_ zone: String) -> Calendar {
        var result = Calendar(identifier: .gregorian); result.timeZone = TimeZone(identifier: zone)!; return result
    }
    func planValue(_ plan: NightWatchPlan) -> [String: Any] {
        let anchor = plan.localDateAnchor
        let night = anchor?.nightEndingDate
        return ["bedtime": ms(plan.intendedBedtime), "wake": ms(plan.wakeTime), "protectedUntil": ms(plan.protectedUntil),
            "windDownMinutes": plan.windDownMinutes, "morningMinutes": plan.morningQuietMinutes,
            "zone": optional(anchor?.timeZoneIdentifier), "nightKey": optional(night.map { "\($0.year)-\($0.month)-\($0.day)" })]
    }
    func outcomeValue(_ o: SheepSearchOutcome) -> [String: Any] {
        ["id": o.id.uuidString, "runID": o.runID.uuidString, "origin": o.origin.rawValue,
            "number": o.protectedNightNumber, "sheepID": optional(o.sheepID), "rarity": optional(o.rarity?.rawValue),
            "habitat": optional(o.habitat?.rawValue), "score": o.trailStrength, "odds": o.encounterOdds,
            "distance": o.trailDistance, "drought": o.consecutiveNoFinds, "createdAt": ms(o.createdAt)]
    }
    func farmValue(_ farm: FarmState, sunrise: SunriseTrailState = .empty, completed: [String] = [], welcome: WelcomeRewardLedger? = nil) -> [String: Any] {
        let ledger = farm.cumulativeCredit ?? CumulativeFarmCredit(migrationCompleted: true)
        var receipts: [String: Any] = [:]
        for (id, r) in ledger.receipts {
            let bonus = r.bedtimeBonus.map { b -> [String: Any] in
                ["result": b.result.rawValue, "nightKey": optional(b.nightKey), "grantedMillis": millis(b.grantedSearchSeconds), "policyVersion": b.policyVersion]
            }
            receipts[id.uuidString] = ["creditedMillis": millis(r.creditedSeconds), "excludedAccessMillis": millis(r.excludedAccessSeconds),
                "trackingIncomplete": r.trackingIncomplete, "outcomeIDs": r.outcomeIDs.map(\.uuidString), "bonus": optional(bonus)]
        }
        var mornings: [String: Any] = [:]
        for r in sunrise.occurrenceSettlements {
            mornings[r.occurrenceID.uuidString] = ["elapsedMinutes": r.eligibleMinutes, "appliedMinutes": r.appliedMinutes,
                "fillIDs": sunrise.fills.filter { $0.occurrenceID == r.occurrenceID }.map { $0.id.uuidString }]
        }
        var shearValues: [String: Any] = [:]
        for t in farm.transactions where t.kind == .shearing {
            let ordinal = Int(t.idempotencyKey.split(separator: ":").last!)!
            shearValues[t.idempotencyKey] = ["sheepID": t.sheepID!.uuidString, "ordinal": ordinal, "woolDelta": t.woolDelta, "createdAt": ms(t.createdAt)]
        }
        var welcomeValue: [String: Any] = ["introductionCompleted": false, "acknowledged": false, "grant": NSNull()]
        var starterValues: [[String: Any]] = []
        if let ledger = welcome, let grant = ledger.starterSheepGrant ?? ledger.grant(of: .starterSkippedExistingFarm) {
            welcomeValue = ["introductionCompleted": true, "acknowledged": false,
                "grant": ["id": grant.id.uuidString, "kind": grant.kind.rawValue, "key": grant.idempotencyKey, "createdAt": ms(grant.createdAt)]]
            if grant.kind == .starterSheep { starterValues = [outcomeValue(SheepSearchEngine.calculateStarter(now: grant.createdAt).outcome)] }
        }
        return ["schema": 2, "welcome": welcomeValue, "shears": shearValues, "consumed": ledger.consumedIntervals.map { ["start": ms($0.start), "end": ms($0.end)] },
            "windDownMillis": millis(ledger.windDownSeconds), "phoneAwayMillis": millis(ledger.phoneAwaySeconds),
            "bonusMillis": millis(ledger.bedtimeBonus?.remainingSearchSeconds ?? 0),
            "grantedNights": (ledger.bedtimeBonus?.grantedNights ?? [:]).mapValues(\.uuidString), "receipts": receipts,
            "outcomes": starterValues + (ledger.outcomes + sunrise.fills.map(\.outcome)).map(outcomeValue),
            "sheep": farm.sheep.map { s -> [String: Any] in
                let shear = farm.transactions.filter { $0.kind == .shearing && $0.sheepID == s.id }.map(\.createdAt).max()
                return ["id": s.id.uuidString, "definitionID": s.definitionID, "rarity": s.rarity.rawValue,
                    "arrivedAt": ms(s.arrivedAt), "status": s.status.rawValue, "regrowthRemaining": millis(s.regrowthSecondsRemaining ?? 0),
                    "lastShearedAt": optional(shear.map(ms)), "timesSheared": s.timesSheared]
            }, "wool": farm.woolBalance, "morningPendingMinutes": sunrise.pendingMinutes, "morningReceipts": mornings,
            "completedWindDowns": completed, "trackedSheepID": optional(farm.trackedSheepDefinitionID)]
    }
    func runValue(_ r: FocusRun) -> [String: Any] {
        let phone = r.nightWatchPlan?.role == .additionalQuiet
        return ["id": r.id.uuidString, "start": ms(r.startedAt), "end": ms(r.plannedEndAt), "packages": ["synthetic.app"],
            "status": r.endedEarlyReason == .appInterrupted ? "failed" : r.state == .completed ? "completed" : "ended",
            "access": r.briefAccessIntervals.enumerated().map { i, span in
                ["nonce": uuid(1000 + i).uuidString, "occurrence": r.id.uuidString, "start": ms(span.start), "end": ms(span.end), "committed": true] as [String: Any]
            }, "endedAt": optional(r.endedAt.map(ms)), "observedAt": NSNull(), "alarmRegistered": false,
            "coverage": "Unknown; no blocker observed", "mode": phone ? "phoneAway" : "windDown",
            "plan": phone ? NSNull() : optional(r.nightWatchPlan.map(planValue)), "farmCreditVersion": r.farmCreditVersion,
            "accessUseCount": r.briefAccessUseCount, "interruption": r.endedEarlyReason == .appInterrupted, "requestedProtection": true]
    }
    var timing: [[String: Any]] = []
    for (name, raw, zone, bedHour, bedMinute, wakeHour, wakeMinute) in [
        ("evening", "2026-09-30T14:30:00Z", "Asia/Singapore", 23, 0, 7, 0),
        ("after-midnight", "2026-09-30T18:30:00Z", "Asia/Singapore", 23, 0, 7, 0),
        ("last-morning-millisecond", "2026-10-01T07:29:59Z", "UTC", 23, 0, 7, 0),
        ("at-protected-end", "2026-10-01T07:30:00Z", "UTC", 23, 0, 7, 0),
        ("spring-wake-gap", "2026-03-08T03:30:00Z", "America/New_York", 23, 0, 2, 30),
        ("fall-wake-overlap", "2026-11-01T02:30:00Z", "America/New_York", 23, 0, 1, 30),
        ("midnight-bedtime", "2026-09-30T23:45:00Z", "UTC", 0, 10, 7, 0),
        ("bedtime-gap", "2026-03-08T06:40:00Z", "America/New_York", 2, 30, 7, 0)
    ] {
        let at = date(raw), cal = calendar(zone)
        let prefs = NightWatchPreferences(bedtimeHour: bedHour, bedtimeMinute: bedMinute, wakeHour: wakeHour, wakeMinute: wakeMinute,
            windDownMinutes: 30, morningQuietMinutes: 30, eveningActivity: .read, morningActivity: .openCurtains,
            eveningRoutine: [], morningRoutine: [], guardKind: .honorTimer, isConfigured: true)
        let plan = try dec.decode(NightWatchPlan.self, from: enc.encode(prefs.makePlan(startedAt: at, calendar: cal)))
        let sampleDates = [at, plan.intendedBedtime, plan.wakeTime, plan.protectedUntil]
        timing.append(["name": name, "at": ms(at), "zone": zone,
            "preferences": ["bedtimeHour": bedHour, "bedtimeMinute": bedMinute, "wakeHour": wakeHour, "wakeMinute": wakeMinute, "windDownMinutes": 30, "morningMinutes": 30],
            "expected": planValue(plan), "samples": sampleDates.map { sample in
                ["at": ms(sample), "phase": plan.phase(at: sample).rawValue, "next": optional(plan.nextTransition(after: sample).map(ms))] as [String: Any]
            }, "sourceCodecPlan": try JSONSerialization.jsonObject(with: enc.encode(plan))])
    }
    let start = date("2026-09-30T22:30:00Z")
    func makeRun(_ n: Int, minutes: Double, day: Int = 0, phone: Bool = false, offset: Double = 0) -> FocusRun {
        let base = start.addingTimeInterval(Double(day) * 86400)
        let began = base.addingTimeInterval(offset)
        let plan = phone ? NightWatchPlan(intendedBedtime: began, wakeTime: began.addingTimeInterval(12 * 3600), protectedUntil: began.addingTimeInterval(12 * 3600),
                windDownMinutes: 720, morningQuietMinutes: 0, eveningActivity: .read, morningActivity: .openCurtains,
                eveningRoutine: [], morningRoutine: [], role: .additionalQuiet, calendar: calendar("UTC"))
            : NightWatchPlan(intendedBedtime: base.addingTimeInterval(1800), wakeTime: base.addingTimeInterval(9 * 3600),
                protectedUntil: base.addingTimeInterval(9 * 3600 + 1800), windDownMinutes: 30, morningQuietMinutes: 30,
                eveningActivity: .read, morningActivity: .openCurtains, eveningRoutine: [], morningRoutine: [], calendar: calendar("UTC"))
        var run = FocusRun(id: uuid(n), plannedDurationSeconds: plan.protectedUntil.timeIntervalSince(began), startedAt: began,
            state: .endedEarly, nightWatchPlan: plan)
        run.endedAt = began.addingTimeInterval(minutes * 60)
        if !phone && FocusRunRules.protectedSpanMinutes(for: run) >= 420 { run.state = .completed; run.completedSuccessfully = true }
        return run
    }
    func emptyFarm() -> FarmState { var f = FarmState.empty; f.migrateCumulativeCredit(records: [], searchState: .empty, protectedNightCount: 0); return f }
    var credit: [[String: Any]] = []
    func creditCase(_ name: String, _ runs: [FocusRun], initial: FarmState? = nil, initialSearch: SheepSearchState = .empty, welcome: WelcomeRewardLedger? = nil) throws {
        var farm = initial ?? emptyFarm(); var search = initialSearch; var completed: [String] = []
        let initialValue = farmValue(farm, welcome: welcome)
        var inputs: [[String: Any]] = [], expected: [[String: Any]] = [], originals: [Any] = []
        for value in runs {
            let r = try dec.decode(FocusRun.self, from: enc.encode(value))
            inputs.append(runValue(r)); originals.append(try JSONSerialization.jsonObject(with: enc.encode(r)))
            farm.settleCumulativeCredit(run: r, searchState: search)
            for outcome in farm.cumulativeCredit?.outcomes ?? [] { search.append(outcome) }
            if r.completedSuccessfully && r.isProgressionEligibleNightWatch && r.endedEarlyReason != .appInterrupted { completed.append(r.id.uuidString) }
            farm = try dec.decode(FarmState.self, from: enc.encode(farm))
            expected.append(farmValue(farm, completed: completed, welcome: welcome))
        }
        credit.append(["name": name, "initial": initialValue, "runs": inputs, "expected": expected, "sourceCodecRuns": originals])
    }
    try creditCase("early-ended-338", [makeRun(201, minutes: 338)])
    try creditCase("bonus-replay-same-night-next-night", [makeRun(202, minutes: 30), makeRun(202, minutes: 30), makeRun(203, minutes: 60, offset: 60), makeRun(204, minutes: 30, day: 1)])
    for (index, offset, minutes) in [(0, -901.0, 60.0), (1, -900.0, 45.0), (2, 900.0, 15.0), (3, 901.0, 30.0), (4, 0.0, 29.99), (5, 1800.0, 30.0)] {
        try creditCase("bonus-boundary-\(index)", [makeRun(210 + index, minutes: minutes, offset: offset)])
    }
    var overlap = makeRun(220, minutes: 60, phone: true)
    overlap.briefAccessUseCount = 3
    overlap.briefAccessIntervals = [DateInterval(start: start.addingTimeInterval(-60), end: start.addingTimeInterval(120)),
        DateInterval(start: start.addingTimeInterval(60), end: start.addingTimeInterval(180)),
        DateInterval(start: start.addingTimeInterval(3500), end: start.addingTimeInterval(3800))]
    try creditCase("overlapping-clipped-access", [overlap])
    overlap.briefAccessUseCount = 4
    try creditCase("missing-access-timestamps", [overlap])
    try creditCase("cross-mode-consumed-union", [makeRun(222, minutes: 60), makeRun(223, minutes: 60, phone: true, offset: 1800)])
    var version1 = makeRun(224, minutes: 30); version1.farmCreditVersion = 1
    var legacy = makeRun(225, minutes: 60, day: 1); legacy.farmCreditVersion = 0
    var interrupted = makeRun(226, minutes: 60, day: 2); interrupted.endedEarlyReason = .appInterrupted
    var unknown = makeRun(227, minutes: 60, day: 3); unknown.nightWatchPlan?.localDateAnchor = nil
    try creditCase("versions-interruption-unknown-anchor", [version1, legacy, interrupted, unknown])
    var growth = emptyFarm(); var sheep = FlockSheep(id: uuid(230), definitionID: "future-sheep", displayName: "Synthetic", sourceOutcomeID: uuid(231),
        sourceRunID: uuid(232), arrivedAt: start.addingTimeInterval(-60), protectedNightNumber: 1, rarity: .common)
    sheep.regrowthSecondsRemaining = 3000; growth.sheep = [sheep]
    growth.cumulativeCredit?.windDownSeconds = 320 * 60
    try creditCase("time-first-bonus-and-wool-growth", [makeRun(233, minutes: 30)], initial: growth)
    try creditCase("phone-fraction-and-multiple-searches", [makeRun(234, minutes: 250.125, phone: true)])
    try creditCase("independent-search-guarantees-and-drought", (0..<16).map { makeRun(250 + $0, minutes: 500, day: $0, phone: $0.isMultiple(of: 2)) })

    var morningCases: [[String: Any]] = []
    for (name, durations, pending) in [("minimum-and-fills", [14.99, 15, 30, 180], 85), ("sunrise-guarantees-drought", Array(repeating: 100.0, count: 12), 0)] {
        var farm = emptyFarm(); var sunrise = SunriseTrailState(pendingMinutes: pending)
        let initial = farmValue(farm, sunrise: sunrise)
        var inputs: [[String: Any]] = [], expected: [[String: Any]] = [], originals: [Any] = []
        for (index, minutes) in durations.enumerated() {
            let began = start.addingTimeInterval(Double(index) * 86400)
            let id = uuid(400 + index)
            let occurrence = try dec.decode(MorningQuietOccurrence.self, from: enc.encode(MorningQuietOccurrence(id: id, scheduleOccurrenceID: id,
                scheduledStart: began, scheduledEnd: began.addingTimeInterval(180 * 60), actualStart: began,
                endedAt: began.addingTimeInterval(minutes * 60), outcome: .finished)))
            inputs.append(["id": id.uuidString, "linkedRun": NSNull(), "start": ms(occurrence.scheduledStart), "end": ms(occurrence.scheduledEnd),
                "packages": ["synthetic.app"], "actualStart": ms(began), "endedAt": ms(occurrence.endedAt!), "outcome": "finished", "access": [],
                "observedAt": NSNull(), "coverage": "Unknown; no blocker observed"])
            originals.append(try JSONSerialization.jsonObject(with: enc.encode(occurrence)))
            let result = SunriseTrailSettlementEngine.settle(occurrence: occurrence, at: occurrence.endedAt!, state: sunrise, protectedWindDownCount: 0)
            sunrise = result.state; for fill in result.fills { farm.applySunriseTrailFill(fill) }
            expected.append(farmValue(farm, sunrise: sunrise))
        }
        morningCases.append(["name": name, "initial": initial, "occurrences": inputs, "expected": expected, "sourceCodecOccurrences": originals])
    }
    let identities = (0..<16).map { index -> [String: Any] in
        let id = UUID(uuidString: "\(String(index, radix: 16))0000000-0000-4000-8000-000000000001")!
        return ["run": id.uuidString, "morning": MorningQuietOccurrenceIdentity.ordinary(for: id).uuidString]
    }
    // Current guest routing and phrase rules, including Unicode normalization through Swift itself.
    let routeStart = date("2026-09-30T22:30:00Z")
    let routine = WindDownRoutine(id: uuid(600), title: "Wind Down", role: .primarySleepBookend,
        start: .init(hour: 22, minute: 30), end: .init(hour: 7, minute: 0))
    let routing = [1801.0, 1800.0, 1799.0, 60.0, 0.0, -60.0].map { lead -> [String: Any] in
        let at = routeStart.addingTimeInterval(-lead)
        return ["at": ms(at), "expected": HomeStartRoutingPolicy.windDownPeriod(in: .init(routines: [routine]), at: at, calendar: calendar("UTC")) != nil]
    }
    let personal = try dec.decode(PersonalShieldSession.self, from: enc.encode(PersonalShieldSession(id: uuid(601), owner: "guest:synthetic",
        interval: DateInterval(start: routeStart, duration: 10 * 3600), role: .primaryWindDown,
        bedtime: routeStart.addingTimeInterval(1800), morningStart: routeStart.addingTimeInterval(8.5 * 3600),
        steps: [], morningSteps: [], goal: nil, morningGoal: nil)))
    let phases = ["windDown": 0.0, "overnight": 3600.0, "morningQuiet": 9 * 3600.0].map { phase, seconds -> [String: Any] in
        let at = routeStart.addingTimeInterval(seconds)
        return ["phase": phase, "at": ms(at), "phrase": personal.phrase(at: at)]
    }.sorted { ($0["at"] as! Int64) < ($1["at"] as! Int64) }
    let normalization = ["ＰＵＴ my phone away!", "  Put\nmy\tphone away  ", "Put, my phone away", "Put my phone away for sleep", "Put\u{0085}my phone away", "Put\u{00a0}my phone away"].map { entry -> [String: Any] in
        ["entry": entry, "normalized": PersonalShieldPhrase.normalized(entry), "matches": PersonalShieldPhrase.matches(entry, phrase: "Put my phone away")]
    }
    let intents: [(String, MorningQuietIntent)] = [("startNow", .startNow), ("defer", .deferToUsualTime), ("skip", .skipToday)]
    let confirmations = intents.map { action, intent -> [String: Any] in
        let phrase = personal.confirmationPhrase(at: routeStart.addingTimeInterval(3600), morningIntent: intent)
        let sheet = PersonalShieldSheet(sessionID: personal.id, owner: personal.owner, action: .endSession, phrase: phrase, mode: .primaryWindDown, morningIntent: intent)
        return ["action": action, "phrase": phrase, "typed": sheet.requiresTypedPhrase]
    }
    let journey: [String: Any] = ["routing": routing, "phases": phases, "normalization": normalization, "confirmations": confirmations,
        "phoneAwayMinutes": PhoneAwayDurationPolicy.options]
    var welcomeCases: [[String: Any]] = []
    for existing in [false, true] {
        var farm = emptyFarm()
        if existing { farm.sheep = [FlockSheep(id: uuid(701), definitionID: "future-sheep", displayName: "Synthetic", arrivedAt: start, protectedNightNumber: 0, rarity: .common)] }
        let initial = farmValue(farm)
        var result = WelcomeRewardEngine.reconcile(farm: farm, search: .empty, ledger: .empty, now: start)
        if existing { result.ledger.grants[0] = WelcomeRewardGrant(id: uuid(702), kind: .starterSkippedExistingFarm, idempotencyKey: "starter:skipped-existing-farm", createdAt: start) }
        result.farm = try dec.decode(FarmState.self, from: enc.encode(result.farm))
        result.ledger = try dec.decode(WelcomeRewardLedger.self, from: enc.encode(result.ledger))
        let expected = farmValue(result.farm, welcome: result.ledger)
        let replay = WelcomeRewardEngine.reconcile(farm: result.farm, search: result.search, ledger: result.ledger, now: start.addingTimeInterval(60))
        precondition(expected as NSDictionary == farmValue(replay.farm, welcome: replay.ledger) as NSDictionary)
        welcomeCases.append(["name": existing ? "existing-no-extra-starter" : "fresh-starter-once", "initial": initial, "at": ms(start), "skipID": uuid(702).uuidString, "expected": expected])
    }
    let starter = WelcomeRewardEngine.reconcile(farm: emptyFarm(), search: .empty, ledger: .empty, now: start.addingTimeInterval(-60))
    try creditCase("starter-does-not-consume-search-ordinal", [makeRun(705, minutes: 250, phone: true), makeRun(706, minutes: 338, day: 1)], initial: starter.farm, initialSearch: starter.search, welcome: starter.ledger)
    var shearCases: [[String: Any]] = []
    for (index, rarity) in SheepRarity.allCases.enumerated() {
        var farm = emptyFarm(); var search = SheepSearchState.empty
        let sheepID = uuid(710 + index)
        var sheep = FlockSheep(id: sheepID, definitionID: "future-sheep", displayName: "Synthetic", arrivedAt: start.addingTimeInterval(-60), protectedNightNumber: 0, rarity: rarity)
        sheep.regrowthSecondsRemaining = 0; farm.sheep = [sheep]
        let initial = farmValue(farm)
        var actions: [[String: Any]] = [], expected: [[String: Any]] = [], woolStates: [[String]] = []
        func shear(at: Date, ordinal: Int) throws {
            let accepted: Bool
            do { try farm.shear(sheepID: sheepID, protectedNightCount: 0, at: at); accepted = true }
            catch FarmActionError.woolRegrowing { accepted = false }
            farm = try dec.decode(FarmState.self, from: enc.encode(farm))
            actions.append(["kind": "shear", "sheepID": sheepID.uuidString, "ordinal": ordinal, "at": ms(at), "accepted": accepted])
            expected.append(farmValue(farm)); woolStates.append(farm.sheep.map { FarmEconomyRules.woolVisualState(for: $0, protectedNightCount: 0).rawValue })
        }
        func settle(_ run: FocusRun) throws {
            farm.settleCumulativeCredit(run: run, searchState: search)
            for outcome in farm.cumulativeCredit?.outcomes ?? [] { search.append(outcome) }
            farm = try dec.decode(FarmState.self, from: enc.encode(farm))
            actions.append(["kind": "credit", "run": runValue(run)]); expected.append(farmValue(farm)); woolStates.append(farm.sheep.map { FarmEconomyRules.woolVisualState(for: $0, protectedNightCount: 0).rawValue })
        }
        try shear(at: start, ordinal: 1)
        try shear(at: start.addingTimeInterval(1), ordinal: 2)
        var access = makeRun(730 + index, minutes: 60, phone: true)
        access.briefAccessUseCount = 2
        access.briefAccessIntervals = [DateInterval(start: start, duration: 240), DateInterval(start: start.addingTimeInterval(120), duration: 180)]
        try settle(access)
        try settle(makeRun(740 + index, minutes: 30, day: 1))
        for day in 2...5 { try settle(makeRun(750 + index * 10 + day, minutes: 600, day: day, phone: true)) }
        try shear(at: start.addingTimeInterval(6 * 86400), ordinal: 2)
        shearCases.append(["rarity": rarity.rawValue, "initial": initial, "actions": actions, "expected": expected, "woolStates": woolStates])
    }
    let output: [String: Any] = ["schema": 1, "source": "Current Swift Codable round trips and pure domain rules; synthetic only", "timing": timing,
        "credit": credit, "morning": morningCases, "identities": identities, "journey": journey, "welcome": welcomeCases, "shearing": shearCases]
    try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys, .prettyPrinted]).write(to: directory.appendingPathComponent("domain-reference.json"))
    print("Swift exported \(timing.count) anchored timing cases, \(credit.count) credit sequences, \(morningCases.count) morning sequences and 16 identities")
}
