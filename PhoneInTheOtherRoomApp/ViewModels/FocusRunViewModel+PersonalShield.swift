import Foundation

extension FocusRunViewModel {
    func preparePersonalShield(id: UUID, plan: NightWatchPlan, startedAt: Date, tasks: [String] = []) throws {
        let owner = try persistence.personalShieldOwner()
        let existing = try persistence.personalShieldSessions().first(where: { $0.id == id })
        // Future automatic plans can still be edited. Admission freezes the words.
        if let existing, existing.interval.start <= nowProvider() || personalisationLoadFailed { return }
        let isPhoneAway = plan.role == .additionalQuiet
        let goal = personalisation.goal
        let session = PersonalShieldSession(
            id: id, owner: owner, interval: DateInterval(start: startedAt, end: plan.protectedUntil),
            role: isPhoneAway ? .additionalQuiet : .primaryWindDown,
            bedtime: isPhoneAway ? nil : plan.intendedBedtime, morningStart: isPhoneAway ? nil : plan.wakeTime,
            steps: isPhoneAway ? PersonalShieldSession.taskTitles(tasks).map { PersonalShieldStep(id: UUID(), title: $0) }
                : plan.eveningRoutine.map { PersonalShieldStep(id: $0.id, title: $0.title) },
            morningSteps: isPhoneAway ? [] : plan.morningRoutine.map { PersonalShieldStep(id: $0.id, title: $0.title) },
            goal: !isPhoneAway && goal?.mode == .evening ? goal?.wording : nil,
            morningGoal: !isPhoneAway && goal?.mode == .morning ? goal?.wording : nil
        )
        if existing != session { try persistence.savePersonalShieldSession(session, at: nowProvider()) }
    }

    /// Run recovery happens first. The local plan is authoritative; the extension
    /// receives only its bounded display projection, never the account profile.
    func refreshPersonalShield() {
        guard let defaults = purposeCueDefaults else { return }
        let now = nowProvider()
        do {
            let owner = try persistence.personalShieldOwner()
            if let old = PersonalShieldStorage.projection(from: defaults), old.session.owner != owner {
                PersonalShieldStorage.clear(from: defaults)
                dismissPersonalShield()
                nextPhoneAwayTasks = ["", "", ""]
            }
            let sessionID: UUID
            if let run = activeRun, isRunning {
                sessionID = run.id
                if let plan = run.nightWatchPlan {
                    try preparePersonalShield(id: run.id, plan: plan, startedAt: run.startedAt)
                } else if let fallback = personalShieldFallback(owner: owner) {
                    try persistence.savePersonalShieldSession(fallback, at: now)
                }
            } else if let morning = activeScreenFreeMorning {
                sessionID = morning.id
                if try !persistence.personalShieldSessions().contains(where: { $0.id == morning.id }) {
                    let records = try persistence.personalShieldSessions()
                    let parent = records.first { $0.id == morning.linkedWindDownRunID }
                    let plan = nightWatchRecords.first { $0.id == morning.linkedWindDownRunID }?.plan
                    let steps = parent?.morningSteps ?? plan?.morningRoutine.map { PersonalShieldStep(id: $0.id, title: $0.title) } ?? []
                    let session = PersonalShieldSession(id: morning.id, owner: owner,
                        interval: DateInterval(start: morning.scheduledStart, end: morning.scheduledEnd),
                        role: .screenFreeMorning, bedtime: nil, morningStart: nil, steps: steps, morningSteps: [],
                        goal: parent?.morningGoal ?? (personalisation.goal?.mode == .morning ? personalisation.goal?.wording : nil), morningGoal: nil)
                    try persistence.savePersonalShieldSession(session, at: now)
                }
            } else if let schedule = persistence.automaticWindDownSchedule, schedule.plan.protectedUntil > now {
                sessionID = schedule.id
                try preparePersonalShield(id: schedule.id, plan: schedule.plan, startedAt: schedule.startedAt)
            } else {
                personalShieldSession = nil
                PersonalShieldStorage.clear(from: defaults)
                dismissPersonalShield()
                return
            }
            guard let session = try persistence.personalShieldSessions().first(where: { $0.id == sessionID }) else { throw FarmSaveError.unavailable }
            personalShieldSession = session
            if let snapshot = QuietTimeShieldPresentationSnapshot.load(from: defaults), snapshot.runID == session.id {
                PersonalShieldStorage.save(PersonalShieldProjection(session: session, scheduleID: snapshot.runID,
                    revision: snapshot.registryRevision, epoch: snapshot.registryEpoch), to: defaults)
            } else {
                PersonalShieldStorage.clear(from: defaults)
            }
            if let sheet = personalShieldSheet,
               sheet.sessionID != session.id || sheet.owner != owner || now >= session.interval.end || homeReceiptRoute.replacesTabShell {
                dismissPersonalShield()
            }
        } catch {
            // An unreadable optional checklist must never trap somebody in a run.
            // Keep its saved copy intact and offer the plain default exit phrase.
            personalShieldSession = personalShieldFallback(owner: (try? persistence.personalShieldOwner()) ?? "unavailable")
            PersonalShieldStorage.clear(from: defaults)
            if personalShieldSession == nil { dismissPersonalShield() }
            personalShieldError = "Your saved list couldn’t be loaded. You can still end this session."
        }
    }

    private func personalShieldFallback(owner: String) -> PersonalShieldSession? {
        if let run = activeRun, isRunning {
            let plan = run.nightWatchPlan
            return PersonalShieldSession(id: run.id, owner: owner,
                interval: DateInterval(start: run.startedAt, end: run.plannedEndAt),
                role: plan?.role == .primarySleepBookend ? .primaryWindDown : .additionalQuiet,
                bedtime: plan?.intendedBedtime, morningStart: plan?.wakeTime,
                steps: [], morningSteps: [], goal: nil, morningGoal: nil)
        }
        if let morning = activeScreenFreeMorning {
            return PersonalShieldSession(id: morning.id, owner: owner,
                interval: DateInterval(start: morning.scheduledStart, end: morning.scheduledEnd),
                role: .screenFreeMorning, bedtime: nil, morningStart: nil,
                steps: [], morningSteps: [], goal: nil, morningGoal: nil)
        }
        return nil
    }

    func consumePersonalShieldRoute() {
        refreshPersonalShield()
        // Automatic admission can await its existing sharing-decision transaction.
        // Leave the bounded route pending until Home observes the restored run.
        if !isRunning, activeScreenFreeMorning == nil,
           let schedule = persistence.automaticWindDownSchedule,
           schedule.startedAt <= nowProvider(), nowProvider() < schedule.plan.protectedUntil { return }
        guard let defaults = purposeCueDefaults,
              let route = PersonalShieldStorage.consumeRoute(from: defaults),
              let projection = PersonalShieldStorage.projection(from: defaults),
              route.matches(projection, at: nowProvider()),
              !homeReceiptRoute.replacesTabShell else { return }
        openPersonalShield(route.action)
    }

    func openPersonalShield(_ action: PersonalShieldAction, earlyMorningIntent: MorningQuietIntent? = nil) {
        refreshPersonalShield()
        guard let session = personalShieldSession, session.interval.start <= nowProvider(),
              nowProvider() < session.interval.end, isRunning || activeScreenFreeMorning != nil,
              !homeReceiptRoute.replacesTabShell else { return }
        coordinator.cancelEmergencyExitChallenge()
        let phrase = session.phrase(at: nowProvider())
        if action == .endSession {
            guard coordinator.beginPersonalExitChallenge(phrase: phrase, occurrenceID: session.id, earlyMorningIntent: earlyMorningIntent) else { return }
        }
        personalShieldError = nil
        personalShieldSheet = PersonalShieldSheet(sessionID: session.id, owner: session.owner, action: action,
            phrase: phrase, mode: session.mode(at: nowProvider()))
        switch earlyMorningIntent {
        case .startNow: personalShieldSheet?.endDetail = "Ends Wind Down and starts Screen-Free Morning now. Selected apps stay blocked."
        case .deferToUsualTime: personalShieldSheet?.endDetail = "Ends Wind Down and unblocks selected apps until your usual morning time."
        case .skipToday: personalShieldSheet?.endDetail = "Ends Wind Down and unblocks selected apps. Screen-Free Morning is skipped today."
        case .keepWindDownRunning, .none: break
        }
    }

    func dismissPersonalShield() {
        personalShieldSheet = nil
        coordinator.cancelEmergencyExitChallenge()
    }

    func togglePersonalShieldStep(_ id: UUID) {
        guard var session = personalShieldSession, session.toggle(id, at: nowProvider()) else { return }
        do {
            try persistence.savePersonalShieldSession(session, at: nowProvider())
            personalShieldError = nil
            refreshPersonalShield()
        } catch {
            personalShieldError = "That check wasn’t saved. Please try again."
        }
    }

    @discardableResult
    func confirmPersonalShield(_ sheet: PersonalShieldSheet, entry: String) -> Bool {
        refreshPersonalShield()
        guard personalShieldSheet?.id == sheet.id, let session = personalShieldSession,
              session.id == sheet.sessionID, session.owner == sheet.owner,
              session.mode(at: nowProvider()) == sheet.mode,
              session.phrase(at: nowProvider()) == sheet.phrase,
              PersonalShieldPhrase.matches(entry, phrase: sheet.phrase) else {
            personalShieldError = "This session has changed. Close this sheet and try again."
            return false
        }
        switch sheet.action {
        case .checklist: return false
        case .briefAccess:
            guard let defaults = purposeCueDefaults, let projection = PersonalShieldStorage.projection(from: defaults),
                  quietTimeShielding.grantBriefAccess(for: projection, at: nowProvider()) else {
                personalShieldError = "Access couldn’t start. Please try again."
                return false
            }
        case .endSession:
            guard coordinator.submitEmergencyExitConfirmation(entry), coordinator.confirmEmergencyExit() else {
                personalShieldError = "The session could not end. Please try again."
                return false
            }
        }
        dismissPersonalShield()
        return true
    }
}
