import Foundation

extension FocusRunViewModel {
    var personalisationIsActive: Bool { isRunning || activeScreenFreeMorning != nil }

    func reloadPersonalisation() {
        personalisationMessage = nil
        personalisation = RitualPersonalisation()
        personalisationLoadFailed = false
        guard habitLocalIdentity != nil else { return }
        do {
            personalisation = try persistence.loadPersonalisation()
            try finishPersonalisationProjection()
            refreshPersonalisation()
        } catch {
            personalisationLoadFailed = true
            personalisationMessage = "Your personalisation could not be loaded. Its saved copy is being kept. Reopen the app to try again."
        }
    }

    func personalisationToken() -> RitualPersonalisationEditToken? {
        guard !personalisationLoadFailed, !habitPlanLoadFailed, !habitReflectionsLoadFailed,
              habitLocalIdentity == (try? persistence.windDownHabitIdentity()) else { return nil }
        guard let token = try? persistence.personalisationEditToken() else { return nil }
        if token.storedData != nil, (try? persistence.loadPersonalisation()) != personalisation { return nil }
        return token
    }

    func refreshPersonalisation() {
        guard !personalisationLoadFailed, let token = personalisationToken() else { return }
        var next = personalisation
        next.reconcile(preferences: nightWatchPreferences, support: windDownHabitPlan, now: nowProvider())
        RitualPersonalisationRules.refresh(&next, history: windDownHabitReflections, now: nowProvider())
        if next != personalisation { _ = commitPersonalisation(next, token: token) }
    }

    @discardableResult
    func saveRitualGoal(mode: WindDownRoutinePhase, kind: RitualGoalKind?, wording: String,
                        token: RitualPersonalisationEditToken) -> Bool {
        guard !personalisationIsActive else { return false }
        var next = personalisation
        let goal = kind.map { RitualGoal(mode: mode, kind: $0, wording: $0 == .personal ? wording : $0.title, now: nowProvider()) }
        guard goal == nil || (goal!.kind.supports(mode) && !goal!.wording.isEmpty) else { return false }
        next.setGoal(goal, preferences: nightWatchPreferences, support: windDownHabitPlan, now: nowProvider())
        return commitPersonalisation(next, token: token)
    }

    @discardableResult
    func savePersonalisationReflection(_ reflection: WindDownHabitReflection,
                                       token: RitualPersonalisationEditToken) -> Bool {
        guard !personalisationIsActive else { return false }
        var reflection = reflection
        if let planID = reflection.experience?.planID {
            guard let plan = personalisation.plans.first(where: { $0.id == planID }),
                  plan.goal.mode == reflection.mode else { return false }
        }
        if let text = reflection.experience?.context {
            let bounded = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240))
            reflection.experience?.context = bounded.isEmpty ? nil : bounded
        }
        var history = windDownHabitReflections
        history.upsert(reflection)
        var next = personalisation
        next.postponeInvitation(now: nowProvider(), worked: reflection.experience?.answer == .yes)
        RitualPersonalisationRules.refresh(&next, history: history, now: nowProvider())
        return commitPersonalisation(next, token: token, reflections: history)
    }

    @discardableResult
    func respondToRitualSuggestion(_ id: UUID, status: RitualSuggestion.Status,
                                   token: RitualPersonalisationEditToken) -> Bool {
        var next = personalisation
        guard RitualPersonalisationRules.respond(&next, suggestionID: id, status: status, now: nowProvider()) else { return false }
        return commitPersonalisation(next, token: token)
    }

    /// Save the reviewed intention first. Preferences are an idempotent device projection;
    /// recovery only applies it while both owner and previous values still match.
    @discardableResult
    func reviewRitualPlan(activities: [WindDownRoutineStep], cue: String, preparation: String,
                         suggestionID: UUID?, token: RitualPersonalisationEditToken) -> Bool {
        guard !personalisationIsActive, let old = personalisation.currentPlan,
              old.preferences == nightWatchPreferences, old.support == windDownHabitPlan else { return false }
        if let suggestionID {
            guard RitualPersonalisationRules.visibleSuggestion(personalisation, now: nowProvider())?.id == suggestionID else { return false }
        }
        var preferences = old.preferences
        let steps = WindDownRoutineStep.normalized(activities, for: old.goal.mode)
        guard !steps.isEmpty else { return false }
        if old.goal.mode == .morning { preferences.morningRoutine = steps }
        else { preferences.eveningRoutine = steps }
        preferences.syncLegacyFieldsFromRoutine()
        var support = old.support
        if old.goal.mode == .morning { support.morningCue = cue }
        else { support.cue = cue; support.preparation = preparation }
        support = support.normalized()
        guard preferences != old.preferences || support != old.support else {
            personalisationMessage = "Your plan is unchanged. You can keep it as it is."
            return false
        }
        let plan = RitualPlanRevision(goal: old.goal, preferences: preferences, support: support, now: nowProvider())
        var next = personalisation
        next.supersedeSuggestions()
        if let suggestionID, let index = next.suggestions.firstIndex(where: { $0.id == suggestionID }) {
            next.suggestions[index].status = .accepted
        }
        next.plans.append(plan)
        next.adjustments.append(RitualReviewedAdjustment(suggestionID: suggestionID, oldPlan: old, newPlan: plan, reviewedAt: nowProvider()))
        guard commitPersonalisation(next, token: token, support: support) else { return false }
        do {
            try finishPersonalisationProjection()
            return true
        } catch {
            personalisationMessage = "Your choice is saved, but the plan update needs another try. Reopen this page before editing again."
            return false
        }
    }

    private func finishPersonalisationProjection() throws {
        guard let index = personalisation.adjustments.lastIndex(where: { $0.applicationPending }) else { return }
        let adjustment = personalisation.adjustments[index]
        guard let token = try? persistence.personalisationEditToken(), token.identity == habitLocalIdentity else { throw FarmSaveError.unavailable }
        var next = personalisation
        if token.preferences == adjustment.oldPlan.preferences || token.preferences == adjustment.newPlan.preferences {
            persistence.nightWatchPreferences = adjustment.newPlan.preferences
            nightWatchPreferences = adjustment.newPlan.preferences
            // Reuse the existing routine/schedule projection; no coordinator transition.
            let existing = windDownRoutines.first { $0.role == .primarySleepBookend }
            let primary = WindDownRoutine.primary(from: nightWatchPreferences, id: existing?.id ?? UUID())
            windDownRoutines = [primary] + windDownRoutines.filter { $0.role != .primarySleepBookend }
            saveWindDownRoutines()
            next.adjustments[index].wasApplied = true
        } else {
            next.adjustments[index].wasApplied = false
            personalisationMessage = "Your routine changed after this choice. Your newer plan has been kept."
        }
        next.adjustments[index].applicationPending = false
        let currentToken = try persistence.personalisationEditToken()
        next.revision = UUID()
        try persistence.savePersonalisation(next, token: currentToken)
        personalisation = next
    }

    @discardableResult
    func updatePersonalisationPrivacy(invitations: Bool? = nil, clearSuggestions: Bool = false,
                                      clearAll: Bool = false, token: RitualPersonalisationEditToken) -> Bool {
        var next = personalisation
        if clearAll {
            next = RitualPersonalisation()
            next.invitationsEnabled = false
            return commitPersonalisation(next, token: token, reflections: WindDownHabitReflectionHistory())
        }
        if let invitations { next.invitationsEnabled = invitations }
        if clearSuggestions {
            next.rejectedActions = RitualAdjustmentAction.allCases
            next.suggestions = []
            next.adjustments = []
        }
        return commitPersonalisation(next, token: token)
    }

    func dismissPersonalisationInvitation() {
        guard let token = personalisationToken() else { return }
        var next = personalisation
        next.postponeInvitation(now: nowProvider())
        _ = commitPersonalisation(next, token: token)
    }

    @discardableResult
    private func commitPersonalisation(_ proposed: RitualPersonalisation, token: RitualPersonalisationEditToken,
                                       reflections: WindDownHabitReflectionHistory? = nil,
                                       support: WindDownHabitPlan? = nil) -> Bool {
        guard !personalisationLoadFailed else { return false }
        var next = proposed
        next.prune(now: nowProvider())
        next.revision = UUID()
        do {
            try persistence.savePersonalisation(next, token: token, reflections: reflections, support: support)
            personalisation = next
            if let reflections { windDownHabitReflections = reflections }
            if let support { windDownHabitPlan = support }
            personalisationMessage = nil
            return true
        } catch {
            personalisationMessage = "This page is out of date or the save is unavailable. Reopen it before trying again. Your saved choices have been kept."
            return false
        }
    }
}
