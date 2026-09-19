import Foundation

extension FocusRunViewModel {
    func reloadWindDownHabitState() {
        isReloadingWindDownHabit = true
        defer { isReloadingWindDownHabit = false }
        let identity = try? persistence.windDownHabitIdentity()
        if habitLocalIdentity != identity {
            if habitLocalIdentity != nil || identity == nil, let defaults = purposeCueDefaults { PersonalShieldStorage.clear(from: defaults) }
            personalShieldSession = nil
            dismissPersonalShield()
            nextPhoneAwayTasks = ["", "", ""]
            habitEditingIdentity = UUID()
            pendingHabitSupport = nil
            pendingHabitIdentity = nil
        }
        habitLocalIdentity = identity
        morningCheckIns = persistence.morningCheckIns
        habitPlanLoadFailed = false
        habitReflectionsLoadFailed = false
        habitSaveMessage = nil
        windDownHabitPlan = WindDownHabitPlan()
        windDownHabitReflections = WindDownHabitReflectionHistory()
        if identity != nil {
            do { windDownHabitPlan = try persistence.loadWindDownHabitPlan() }
            catch { habitPlanLoadFailed = true }
            do { windDownHabitReflections = try persistence.loadWindDownHabitReflections() }
            catch { habitReflectionsLoadFailed = true }
            if habitPlanLoadFailed || habitReflectionsLoadFailed {
                habitSaveMessage = "Some routine details could not be loaded. Their saved copy is being kept. Please try reopening the app."
            }
        }
        useSmallerWindDownNextTime = windDownHabitPlan.useSmallerVersionNextTime
        consumeSmallerWindDownChoice(after: persistence.lastRun?.nightWatchPlan)
        reloadPersonalisation()
    }

    @discardableResult
    func saveWindDownHabitPlan(_ proposed: WindDownHabitPlan) -> Bool {
        guard !habitPlanLoadFailed else {
            habitSaveMessage = "Your saved routine support could not be read. It has been kept without changes."
            return false
        }
        guard let identity = currentHabitIdentityForSave() else { return false }
        let plan = proposed.normalized()
        do {
            try persistence.saveWindDownHabitPlan(plan, identity: identity)
            publishWindDownHabitPlan(plan)
            habitSaveMessage = nil
            scheduleAutomaticWindDownIfNeeded()
            return true
        } catch {
            habitSaveMessage = "Your routine support wasn’t saved. Your previous choices are still in place. Please try again."
            return false
        }
    }

    func windDownHabitReflection(for day: Date) -> WindDownHabitReflection {
        windDownHabitReflections.entry(for: day)
            ?? WindDownHabitReflection(day: Calendar.current.startOfDay(for: day))
    }

    @discardableResult
    func saveWindDownHabitReflection(_ reflection: WindDownHabitReflection) -> Bool {
        guard !habitReflectionsLoadFailed else {
            habitSaveMessage = "Your saved reflections could not be read. They have been kept without changes."
            return false
        }
        guard let identity = currentHabitIdentityForSave() else { return false }
        var history = windDownHabitReflections
        history.upsert(reflection)
        do {
            try persistence.saveWindDownHabitReflections(history, identity: identity)
            windDownHabitReflections = history
            habitSaveMessage = nil
            return true
        } catch {
            habitSaveMessage = "Your reflection wasn’t saved. Please try again."
            return false
        }
    }

    func persistSmallerWindDownChoiceIfNeeded() {
        guard !isReloadingWindDownHabit,
              useSmallerWindDownNextTime != windDownHabitPlan.useSmallerVersionNextTime else { return }
        var plan = windDownHabitPlan
        plan.useSmallerVersionNextTime = useSmallerWindDownNextTime
        if !saveWindDownHabitPlan(plan) {
            publishWindDownHabitPlan(windDownHabitPlan)
        }
    }

    /// Match the choice captured in the admitted run, so replay cannot consume
    /// a different choice made later. Failed admission never reaches this path.
    func consumeSmallerWindDownChoice(after plan: NightWatchPlan?) {
        guard let plan, plan.role == .primarySleepBookend, plan.usesSmallerRoutine,
              let selectionID = plan.smallerRoutineSelectionID,
              windDownHabitPlan.useSmallerVersionNextTime,
              selectionID == windDownHabitPlan.smallerVersionSelectionID,
              let identity = habitLocalIdentity else { return }
        var next = windDownHabitPlan
        next.useSmallerVersionNextTime = false
        next = next.normalized()
        do {
            try persistence.saveWindDownHabitPlan(next, identity: identity)
            publishWindDownHabitPlan(next)
        } catch {
            habitSaveMessage = "Your smaller version started, but its next-time choice could not be cleared. Check it before your next Wind Down."
        }
    }

    var pendingWindDownHabitPlan: WindDownHabitPlan { pendingHabitSupport ?? windDownHabitPlan }

    private func publishWindDownHabitPlan(_ plan: WindDownHabitPlan) {
        let wasReloading = isReloadingWindDownHabit
        isReloadingWindDownHabit = true
        windDownHabitPlan = plan
        useSmallerWindDownNextTime = plan.useSmallerVersionNextTime
        isReloadingWindDownHabit = wasReloading
    }

    private func currentHabitIdentityForSave() -> WindDownHabitLocalIdentity? {
        guard let identity = habitLocalIdentity,
              identity == (try? persistence.windDownHabitIdentity()) else {
            reloadWindDownHabitState()
            habitSaveMessage = "Your account changed. Reopen your routine before making changes."
            return nil
        }
        return identity
    }
}
