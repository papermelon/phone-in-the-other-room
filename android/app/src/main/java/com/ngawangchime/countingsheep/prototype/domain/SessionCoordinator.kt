package com.ngawangchime.countingsheep.prototype.domain

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.time.ZoneId
import java.util.UUID
import kotlin.math.abs

/** One authority for UI, service, alarms, morning handoff and settlement. Main-thread callers serialize intents. */
class SessionCoordinator(
    initial: PrototypeState,
    private val save: (PrototypeState) -> Unit,
    private val clock: () -> ClockSample,
    private val id: () -> String = { UUID.randomUUID().toString().uppercase() }
) {
    private val mutable = MutableStateFlow(initial)
    val states = mutable.asStateFlow()
    val state get() = mutable.value
    private var durable = initial
    var operational = false
        private set
    private var volatileFailure = false
    private var pending: PrototypeState? = null
    private var challenge: GuestChallenge? = null

    private fun commit(next: PrototypeState): Boolean = if (volatileFailure) false else try {
        check(state.generation < Long.MAX_VALUE)
        val committed = next.copy(schema = 4, generation = state.generation + 1, clock = clock())
        save(committed)
        pending = null
        durable = committed
        mutable.value = committed
        true
    } catch (_: Exception) {
        volatileFailure = true; operational = false
        // Keep the failed transaction for explicit retry. A failed live write closes its timer at failure,
        // preserving only recorded access; no later repair can credit the open interruption gap.
        val failedRun = next.session?.takeIf { it.live }?.let { run ->
            val end = clock().wall.coerceIn(run.start, run.end)
            run.copy(status = "failed", endedAt = end, interruption = true, alarmRegistered = false,
                access = run.access.map { it.copy(end = maxOf(it.start, minOf(it.end, end))) })
        }
        pending = next.copy(session = failedRun ?: next.session,
            mornings = next.mornings.map { if (it.live) it.finalized(clock().wall) else it },
            terminalIntents = next.terminalIntents + if (failedRun != null) listOf(TerminalIntent(failedRun)) else emptyList(),
            repairRequired = true, failure = "Local storage failed; protection is open")
        mutable.value = state.copy(repairRequired = true, failure = "Local storage failed; protection is open",
            session = state.session?.takeUnless { !it.live }?.copy(status = "failed", coverage = "Failed; storage unavailable") ?: state.session,
            mornings = state.mornings.map { if (it.live) it.finalized(clock().wall).copy(coverage = "Failed; storage unavailable") else it })
        false
    }

    fun consent(accepted: Boolean) {
        if (!accepted && live()) end("refused")
        if (volatileFailure) { pending = pending?.copy(consent = accepted); mutable.value = state.copy(consent = accepted) }
        else commit(state.copy(consent = accepted))
    }
    fun select(packages: Set<String>) { if (!volatileFailure && state.session?.live != true && state.mornings.none { it.outcome == "active" }) commit(state.copy(selection = packages)) }
    fun live() = state.session?.live == true || state.mornings.any { it.live }
    private fun admitted() = operational && !volatileFailure && !state.repairRequired && state.consent == true &&
        state.selection.isNotEmpty() && state.session?.live != true && state.mornings.none { it.outcome == "active" } && state.terminalIntents.none { !it.settled }

    fun serviceConnected() {
        operational = true
        replay()
        reconcile()
        if (!volatileFailure) commit(state.copy(
            session = state.session?.let { if (it.live) it.copy(coverage = "Unknown coverage before service connection", access = it.access.filter { grant -> grant.committed }) else it },
            mornings = state.mornings.map { if (it.live) it.copy(coverage = "Unknown coverage before service connection", access = it.access.filter { grant -> grant.committed }) else it }))
    }
    fun fail(reason: String, at: Long = clock().wall) {
        operational = false
        if (volatileFailure) return
        if (!terminate("failed", at, interruption = true)) return
        commit(state.copy(repairRequired = true, failure = reason,
            session = state.session?.copy(coverage = "Failed; protection is open", alarmRegistered = false),
            mornings = state.mornings.map { if (it.live) it.finalized(at).copy(coverage = "Failed; protection is open") else it }))
        replay()
    }
    fun repair(): Boolean {
        // Local transaction retry needs no Accessibility consent. Protected starts still require
        // a connected service, consent, selection and successful repair through admitted().
        if (live() || (!operational && pending == null)) return false
        // Retry the exact pending transaction before opening another start. Acknowledgement loss can
        // publish the same effects again as a generation, but permanent reward identities stay identical.
        val retry = pending ?: durable.copy(repairRequired = true)
        volatileFailure = false
        if (pending != null && !commit(retry)) return false
        if (!replay()) return false
        val ok = commit(state.copy(repairRequired = false, failure = null))
        if (ok) volatileFailure = false
        return ok
    }
    /** Retained short boundary experiment; real Phone Away uses the same integrated settlement path. */
    fun start(durationMillis: Long, delayMillis: Long = 0): Boolean {
        reconcile()
        if (!admitted() || durationMillis !in 2_000..43_200_000 || delayMillis !in 0..3_600_000) return false
        val start = clock().wall + delayMillis
        return commit(state.copy(session = Session(id(), start, start + durationMillis, state.selection,
            status = if (delayMillis == 0L) "active" else "scheduled", farmCreditVersion = 2)))
    }
    fun startWindDown(preferences: NightPreferences = NightPreferences(), zone: ZoneId = ZoneId.systemDefault()): Boolean =
        startWindDown(preferences.makePlan(clock().wall, zone))
    fun startWindDown(plan: NightPlan, earlyApproved: Boolean = false): Boolean {
        reconcile()
        val now = clock().wall
        if (!admitted() || (now < plan.plannedStart && !(earlyApproved && plan.plannedStart - now < 1_800_000)) || plan.protectedUntil - now < 60_000 ||
            plan.wake < plan.bedtime || plan.protectedUntil < plan.wake || plan.protectedUntil - now > 172_800_000) return false
        val run = Session(id(), now, plan.protectedUntil, state.selection, status = "active", mode = "windDown", plan = plan, farmCreditVersion = 2)
        val morningID = SearchRules.morningID(run.id)
        val morning = MorningOccurrence(morningID, run.id, plan.wake, maxOf(plan.wake + 60_000, plan.protectedUntil), state.selection)
        return commit(state.copy(session = run, mornings = state.mornings + if (plan.morningMinutes > 0) listOf(morning) else emptyList()))
    }
    fun startMorning(minutes: Int = 30): Boolean {
        reconcile()
        if (!admitted() || minutes !in 15..180) return false
        val now = clock().wall
        return commit(state.copy(mornings = state.mornings + MorningOccurrence(id(), start = now, end = now + minutes * 60_000L,
            packages = state.selection, actualStart = now, outcome = "active")))
    }
    /** Explicit early wake preserves/replaces the independent Morning in the same terminal-intent write. */
    fun earlyWake(choice: String): Boolean {
        reconcile()
        val run = state.session ?: return false
        val plan = run.plan ?: return false
        val now = clock().wall
        if (!run.live || run.mode != "windDown" || plan.phase(now) != "overnight" || choice !in setOf("startNow", "defer", "skip")) return false
        if (choice != "skip" && (!operational || state.repairRequired || state.consent != true || run.packages.isEmpty())) return false
        val ordinary = state.mornings.firstOrNull { it.linkedRun == run.id && it.live } ?: return false
        val replacement = when (choice) {
            "startNow" -> MorningOccurrence(id(), run.id, now, now + plan.morningMinutes * 60_000L, run.packages, actualStart = now, outcome = "active")
            "defer" -> ordinary
            else -> ordinary.copy(outcome = "skipped", endedAt = now)
        }
        val mornings = state.mornings.filterNot { it.id == ordinary.id } + replacement
        return terminate("ended", now, mornings = mornings, preserveMorning = true)
    }
    fun reconcile(expectedOccurrence: String? = null) {
        if (expectedOccurrence != null && expectedOccurrence != state.session?.takeIf { it.live }?.id && state.mornings.none { it.id == expectedOccurrence && it.live }) return
        replay()
        if (!live() || volatileFailure) return
        val now = clock(); val prior = state.clock
        if (prior != null && (prior.boot != now.boot || now.elapsed < prior.elapsed ||
                abs((now.wall - prior.wall) - (now.elapsed - prior.elapsed)) > 2_000)) {
            fail("Clock or reboot changed; inspect frozen boundaries and repair", minOf(now.wall, prior.wall)); return
        }
        if (state.consent != true) { end("refused"); return }
        val run = state.session
        if (run?.live == true && now.wall >= run.end) { end("completed", run.end); reconcile(); return }
        val activeMorning = state.mornings.any { it.live && now.wall >= it.start && now.wall < it.end }
        if (((run?.live == true && now.wall >= run.start) || activeMorning) && !operational) {
            fail("Protection service unavailable; repair required"); return
        }
        val mornings = state.mornings.map { occurrence ->
            when {
                !occurrence.live || now.wall < occurrence.start -> occurrence
                now.wall >= occurrence.end -> occurrence.finalized(occurrence.end)
                else -> occurrence.copy(actualStart = occurrence.actualStart ?: occurrence.start, outcome = "active")
            }
        }
        val nextRun = run?.let { if (it.live) it.copy(status = if (now.wall >= it.start) "active" else "scheduled") else it }
        if (nextRun != run || mornings != state.mornings) commit(state.copy(session = nextRun, mornings = mornings))
        replay()
    }
    /** Effects and replay markers publish in one durable generation. */
    fun replay(): Boolean {
        if (volatileFailure) return false
        var farm = state.farm
        val intents = state.terminalIntents.map { intent ->
            if (intent.settled) intent else { farm = FarmSettlement.settle(farm, intent.run); intent.copy(settled = true) }
        }
        state.mornings.forEach { farm = FarmSettlement.morning(farm, it) }
        if (farm == state.farm && intents == state.terminalIntents) return true
        return commit(state.copy(farm = farm, terminalIntents = intents))
    }
    private fun currentProtection(occurrence: String): Boolean {
        val now = clock().wall; val run = state.session
        if (run?.id == occurrence) return run.live && now >= run.start && now < run.end
        return state.mornings.any { it.id == occurrence && it.outcome == "active" && now >= it.start && now < it.end &&
            !(run?.live == true && it.linkedRun == run.id) }
    }
    fun protectionOccurrence(packageName: String? = null): String? {
        val now = clock().wall
        fun eligible(id: String, packages: Set<String>, access: List<AccessInterval>) = currentProtection(id) &&
            (packageName == null || packageName in packages && access.none { it.committed && now >= it.start && now < it.end })
        return state.session?.takeIf { eligible(it.id, it.packages, it.access) }?.id
            ?: state.mornings.firstOrNull { eligible(it.id, it.packages, it.access) }?.id
    }
    private fun accessFor(occurrence: String) = if (state.session?.id == occurrence) state.session!!.access
        else state.mornings.firstOrNull { it.id == occurrence }?.access ?: emptyList()
    private fun updateAccess(occurrence: String, access: List<AccessInterval>): PrototypeState = if (state.session?.id == occurrence)
        state.copy(session = state.session!!.copy(access = access, accessUseCount = access.count { it.committed }))
        else state.copy(mornings = state.mornings.map { if (it.id == occurrence) it.copy(access = access) else it })
    fun proposeAccess(occurrence: String): AccessInterval? {
        reconcile(occurrence)
        if (!currentProtection(occurrence) || !operational || state.repairRequired || volatileFailure) return null
        val now = clock().wall
        val end = state.session?.takeIf { it.id == occurrence }?.end ?: state.mornings.first { it.id == occurrence }.end
        if (accessFor(occurrence).any { now < it.end } || end - now < 2_000) return null
        val grant = AccessInterval(id(), occurrence, now, minOf(now + 300_000, end))
        return if (commit(updateAccess(occurrence, accessFor(occurrence) + grant))) grant else null
    }
    fun commitAccess(interval: AccessInterval): Boolean {
        val access = accessFor(interval.occurrence)
        if (!currentProtection(interval.occurrence) || !operational || state.repairRequired || volatileFailure ||
            clock().wall >= interval.end || access.lastOrNull() != interval || interval.committed) return false
        return commit(updateAccess(interval.occurrence, access.dropLast(1) + interval.copy(committed = true)))
    }
    fun markAlarm(occurrence: String, registered: Boolean) {
        val session = state.session ?: return
        if (session.id == occurrence && session.live && session.alarmRegistered != registered)
            commit(state.copy(session = session.copy(alarmRegistered = registered)))
    }
    fun shouldBlock(packageName: String): Boolean {
        reconcile()
        if (!operational || volatileFailure || state.repairRequired || state.consent != true) return false
        val now = clock().wall
        fun eligible(packages: Set<String>, access: List<AccessInterval>) = packageName in packages &&
            access.none { it.committed && now >= it.start && now < it.end }
        val run = state.session
        val parentBlocks = run?.live == true && now >= run.start && now < run.end && eligible(run.packages, run.access)
        val morningBlocks = state.mornings.any { morning ->
            morning.outcome == "active" && now >= morning.start && now < morning.end &&
                // Ordinary Morning is the parent's continuous protected interval and shares its access grant.
                !(run?.live == true && morning.linkedRun == run.id) && eligible(morning.packages, morning.access)
        }
        return parentBlocks || morningBlocks
    }
    fun observed(occurrence: String) {
        if (!currentProtection(occurrence) || !operational || state.repairRequired || volatileFailure) return
        val coverage = "Overlay shown at observed event; continuous coverage unknown"
        commit(if (state.session?.id == occurrence) state.copy(session = state.session!!.copy(observedAt = clock().wall, coverage = coverage))
            else state.copy(mornings = state.mornings.map { if (it.id == occurrence) it.copy(observedAt = clock().wall, coverage = coverage) else it }))
    }
    fun end(reason: String, at: Long = clock().wall, expectedOccurrence: String? = null) {
        require(reason in setOf("completed", "ended", "emergency", "refused"))
        if (expectedOccurrence != null && expectedOccurrence != state.session?.takeIf { it.live }?.id && state.mornings.none { it.id == expectedOccurrence && it.live }) return
        if (expectedOccurrence != null && expectedOccurrence != state.session?.takeIf { it.live }?.id &&
            reason !in setOf("emergency", "refused")) {
            val mornings = state.mornings.map { if (it.id == expectedOccurrence && it.live) it.finalized(at) else it }
            if (commit(state.copy(mornings = mornings))) replay()
        } else terminate(reason, at)
    }
    fun saveNightPreferences(preferences: NightPreferences): Boolean = commit(state.copy(nightPreferences = preferences))
    fun welcomeGuest(): Boolean {
        if (state.repairRequired || volatileFailure) return false
        val farm = GuestFarmActions.welcome(state.farm, clock().wall, id())
        return farm == state.farm || commit(state.copy(farm = farm))
    }
    fun acknowledgeWelcome(): Boolean {
        if (!state.farm.welcome.introductionCompleted || state.repairRequired || volatileFailure) return false
        return state.farm.welcome.acknowledged || commit(state.copy(farm = state.farm.copy(welcome = state.farm.welcome.copy(acknowledged = true))))
    }
    fun shear(sheepID: String, ordinal: Int): Boolean {
        reconcile()
        if (state.repairRequired || volatileFailure) return false
        val farm = GuestFarmActions.shear(state.farm, sheepID, ordinal, clock().wall) ?: return false
        return farm == state.farm || commit(state.copy(farm = farm))
    }
    fun acknowledgeReceipts(ids: Set<String>): Boolean {
        val ready = GuestJourney.receipts(state).filter { it.ready }.map { it.id }.toSet()
        if (!ready.containsAll(ids)) return false
        return commit(state.copy(acknowledgedReceipts = state.acknowledgedReceipts + ids))
    }
    fun beginGuestAction(occurrence: String, action: String): GuestChallenge? {
        reconcile(occurrence)
        if (!currentProtection(occurrence) || volatileFailure || state.repairRequired) return null
        val phrase = GuestJourney.phrase(state, occurrence, action, clock().wall) ?: return null
        return GuestChallenge(id(), occurrence, action, phrase, clock().wall).also { challenge = it }
    }
    fun cancelGuestAction() { challenge = null }
    fun consumeGuestAction(request: GuestChallenge, entry: String): Boolean {
        reconcile(request.occurrence)
        if (challenge != request || !currentProtection(request.occurrence) || volatileFailure || state.repairRequired ||
            clock().wall !in request.createdAt until request.createdAt + 120_000 ||
            GuestJourney.phrase(state, request.occurrence, request.action, clock().wall) != request.phrase ||
            (request.action != "startNow" && !GuestJourney.matches(entry, request.phrase))) return false
        challenge = null
        return true
    }
    private fun terminate(reason: String, at: Long, interruption: Boolean = false,
                          mornings: List<MorningOccurrence> = state.mornings, preserveMorning: Boolean = false): Boolean {
        val run = state.session?.takeIf { it.live }
        val terminal = run?.let { it.copy(status = reason, endedAt = at.coerceIn(it.start, it.end), alarmRegistered = false,
            interruption = interruption, access = it.access.map { grant -> grant.copy(end = maxOf(grant.start, minOf(grant.end, at))) }) }
        val globalExit = reason in setOf("emergency", "refused", "failed")
        val activeMorningID = mornings.firstOrNull { it.outcome == "active" }?.id
        val finalized = if (preserveMorning) mornings else mornings.map {
            val owned = if (run != null) it.linkedRun == run.id else it.id == activeMorningID
            if (it.live && (globalExit || owned)) it.finalized(at) else it
        }
        if (terminal == null && finalized == state.mornings) return true
        val ok = commit(state.copy(session = terminal ?: state.session, mornings = finalized,
            terminalIntents = state.terminalIntents + if (terminal != null) listOf(TerminalIntent(terminal)) else emptyList()))
        if (ok && !volatileFailure) replay()
        return ok
    }
    fun boundaryOccurrence(): String? = state.session?.takeIf { it.live }?.id ?: state.mornings.firstOrNull { it.live }?.id
    fun nextBoundary(): Long? {
        val now = clock().wall
        val run = state.session?.takeIf { it.live }
        return (listOfNotNull(run?.start, run?.end, run?.plan?.nextTransition(now)) +
            state.mornings.filter { it.live }.flatMap { listOf(it.start, it.end) } +
            (run?.access.orEmpty() + state.mornings.filter { it.live }.flatMap { it.access }).filter { it.committed }.map { it.end })
            .filter { it > now }.minOrNull()
    }
}
