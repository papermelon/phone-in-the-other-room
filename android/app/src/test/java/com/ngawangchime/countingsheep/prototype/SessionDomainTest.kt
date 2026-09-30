package com.ngawangchime.countingsheep.prototype

import com.ngawangchime.countingsheep.prototype.data.SessionDocument
import com.ngawangchime.countingsheep.prototype.domain.*
import org.junit.Assert.*
import org.junit.Test
import java.time.Instant
import java.time.ZoneId

class SessionDomainTest {
    private var sample = ClockSample(Instant.parse("2026-09-30T22:30:00Z").toEpochMilli(), 10_000, 1)
    private var stored = PrototypeState(consent = true, selection = setOf("synthetic.app"))
    private var sequence = 1
    private var writes = 0
    private var failAt = -1
    private var failAfter = false
    private fun coordinator() = SessionCoordinator(stored, { next ->
        writes++
        if (writes == failAt && !failAfter) error("before atomic publication")
        stored = SessionDocument.decode(SessionDocument.encode(next))
        if (writes == failAt && failAfter) error("after atomic publication; acknowledgement lost")
    }, { sample }, { "00000000-0000-4000-8000-${(sequence++).toString().padStart(12, '0')}" })
    private fun advance(ms: Long) { sample = sample.copy(wall = sample.wall + ms, elapsed = sample.elapsed + ms) }
    private fun plan() = NightPreferences().makePlan(sample.wall, ZoneId.of("UTC"))
    private fun activeNight() = coordinator().apply { serviceConnected(); assertTrue(startWindDown(plan())) }

    @Test fun ordinaryNightAndMorningHaveFrozenSeparateIdentitiesAndCredit() {
        val c = activeNight(); val run = c.state.session!!; val morning = c.state.mornings.single()
        assertEquals(SearchRules.morningID(run.id), morning.id); assertNotEquals(run.id, morning.id)
        assertEquals(run.plan!!.bedtime, c.nextBoundary())
        advance(run.end - sample.wall + 10_000); c.reconcile()
        assertEquals(run.end, c.state.session!!.endedAt)
        assertEquals(510 * 60_000L, c.state.farm.receipts[run.id]!!.creditedMillis)
        assertEquals(30, c.state.farm.morningReceipts[morning.id]!!.appliedMinutes)
        assertEquals(1, c.state.farm.grantedNights.size)
        assertNull(c.state.session!!.observedAt); assertFalse(c.shouldBlock("synthetic.app"))
        val saved = c.state.farm; c.reconcile(); assertEquals(saved, c.state.farm)
    }
    @Test fun ordinaryExitBeforeWakeSkipsMorningAndPreservesEarlyCredit() {
        val c = activeNight(); advance(338 * 60_000L); c.end("ended")
        assertEquals("skipped", c.state.mornings.single().outcome)
        assertEquals(338 * 60_000L, c.state.farm.receipts[c.state.session!!.id]!!.creditedMillis)
        assertEquals(0L, c.state.session!!.remaining(sample.wall))
        assertEquals(0, c.state.farm.morningPendingMinutes)
    }
    @Test fun exitDuringMorningBoundsItsIndependentElapsed() {
        val c = activeNight(); val wake = c.state.session!!.plan!!.wake
        advance(wake - sample.wall + 20 * 60_000); c.reconcile(); c.end("ended")
        assertEquals(20, c.state.farm.morningReceipts.values.single().appliedMinutes)
        assertEquals(510 * 60_000L, c.state.farm.receipts.values.single().creditedMillis)
    }
    @Test fun earlyWakeChoicesPreserveIndependentIntentAcrossRestart() {
        for (choice in listOf("startNow", "defer", "skip")) {
            stored = PrototypeState(consent = true, selection = setOf("synthetic.app")); sample = sample.copy(wall = Instant.parse("2026-09-30T22:30:00Z").toEpochMilli())
            val c = activeNight(); val original = c.state.mornings.single(); advance(60 * 60_000)
            assertTrue(c.earlyWake(choice)); val newMorning = c.state.mornings.single()
            assertEquals(60 * 60_000L, c.state.farm.receipts.values.single().creditedMillis)
            if (choice == "skip") { assertEquals("skipped", newMorning.outcome); continue }
            if (choice == "defer") { assertEquals(original.id, newMorning.id); assertFalse(c.shouldBlock("synthetic.app")) }
            else { assertNotEquals(original.id, newMorning.id); assertTrue(c.shouldBlock("synthetic.app")) }
            advance(newMorning.end - sample.wall + 60_000)
            val restarted = coordinator(); restarted.serviceConnected()
            assertEquals(30, restarted.state.farm.morningReceipts.values.single().appliedMinutes)
            assertFalse(restarted.shouldBlock("synthetic.app")); assertEquals(1, restarted.state.farm.receipts.size)
        }
    }
    @Test fun morningBriefAccessDoesNotSubtractEligibleElapsedOrGrowWool() {
        val c = coordinator(); c.serviceConnected(); assertTrue(c.startMorning(15))
        val morning = c.state.mornings.single(); val access = c.proposeAccess(morning.id)!!
        assertTrue(c.commitAccess(access)); advance(15 * 60_000); c.reconcile()
        assertEquals(15, c.state.farm.morningPendingMinutes)
        assertTrue(c.state.farm.receipts.isEmpty()); assertEquals(0, c.state.farm.windDownMillis)
    }
    @Test fun morningMinimumAndSkippedOutcomesRemainIndependent() {
        val c = coordinator(); c.serviceConnected(); c.startMorning(30)
        advance(14 * 60_000 + 59_999); c.end("ended")
        assertEquals(0, c.state.farm.morningReceipts.values.single().appliedMinutes)
        assertEquals(14, c.state.farm.morningReceipts.values.single().elapsedMinutes)
    }
    @Test fun interruptedTerminalPublicationAndSettlementReplayOnce() {
        for (boundary in 1..2) for (after in listOf(false, true)) {
            stored = PrototypeState(consent = true, selection = setOf("synthetic.app")); failAt = -1; failAfter = after
            val c = coordinator(); c.serviceConnected(); c.start(200 * 60_000L); advance(100 * 60_000L)
            val before = writes; failAt = before + boundary; c.end("ended")
            assertFalse(c.shouldBlock("synthetic.app")); assertTrue(c.state.repairRequired)
            val persisted = stored
            failAt = -1
            val restarted = coordinator(); restarted.serviceConnected()
            if (boundary == 1 && !after) {
                // Intent never reached disk: recovery can only use persisted active bounds, with unknown coverage.
                assertTrue(persisted.terminalIntents.isEmpty()); restarted.end("emergency")
            }
            assertEquals(1, restarted.state.farm.receipts.size)
            assertEquals(1, restarted.state.farm.outcomes.size)
            assertEquals(1, restarted.state.farm.sheep.size)
            val farm = restarted.state.farm; restarted.replay(); restarted.reconcile(); assertEquals(farm, restarted.state.farm)
            assertNull(restarted.state.session!!.observedAt)
        }
    }
    @Test fun sameProcessRepairReplaysDurablePendingIntent() {
        val c = coordinator(); c.serviceConnected(); c.start(100 * 60_000L); advance(100 * 60_000L)
        failAt = writes + 2; c.end("completed")
        assertEquals(1, stored.terminalIntents.count { !it.settled }); failAt = -1
        c.serviceConnected(); assertTrue(c.repair()); c.reconcile()
        assertEquals(1, c.state.farm.outcomes.size); assertTrue(c.state.terminalIntents.all { it.settled })
    }
    @Test fun runtimeFailureKeepsTimerCreditButNeverCreatesBonusOrObservation() {
        val c = activeNight(); advance(35 * 60_000); c.fail("runtime unavailable")
        assertEquals(35 * 60_000L, c.state.farm.receipts.values.single().creditedMillis)
        assertEquals("unknown", c.state.farm.receipts.values.single().bonus!!.result)
        assertNull(c.state.session!!.observedAt); assertFalse(c.shouldBlock("synthetic.app")); assertTrue(c.state.repairRequired)
    }
    @Test fun runtimeFailureCannotOverwriteEffectsAfterStorageLosesAcknowledgement() {
        for (after in listOf(false, true)) {
            stored = PrototypeState(consent = true, selection = setOf("synthetic.app")); failAt = -1; failAfter = after
            val c = coordinator(); c.serviceConnected(); c.start(200 * 60_000L); advance(100 * 60_000L)
            val before = writes; failAt = before + 2; c.fail("runtime unavailable")
            assertEquals(before + 2, writes)
            assertEquals(if (after) 1 else 0, stored.farm.outcomes.size)
            assertFalse(c.shouldBlock("synthetic.app")); assertTrue(c.state.repairRequired)
            c.select(setOf("replacement.app")); c.serviceConnected()
            assertEquals(before + 2, writes)
            failAt = -1; assertTrue(c.repair()); c.reconcile()
            assertEquals(1, c.state.farm.outcomes.size); assertEquals(1, c.state.farm.receipts.size)
            assertEquals(setOf("synthetic.app"), c.state.selection)
        }
    }
    @Test fun clockJumpFailsOpenWithoutCreditingJumpOrChangingPlan() {
        val c = activeNight(); val plan = c.state.session!!.plan
        sample = sample.copy(wall = sample.wall + 86_400_000); c.reconcile()
        assertEquals(plan, c.state.session!!.plan); assertTrue(c.state.repairRequired)
        assertTrue(c.state.farm.receipts.isEmpty()); assertTrue(c.state.farm.grantedNights.isEmpty())
    }
    @Test fun staleCallbacksCannotEndOrObserveReplacementMorning() {
        val c = activeNight(); val runID = c.state.session!!.id
        advance(60 * 60_000); c.earlyWake("startNow"); val morning = c.state.mornings.single()
        c.end("ended", expectedOccurrence = "stale"); c.end("ended", expectedOccurrence = runID); c.reconcile(runID); c.observed(runID)
        assertEquals(morning, c.state.mornings.single()); assertNull(c.proposeAccess(runID))
        c.end("emergency", expectedOccurrence = morning.id); assertFalse(c.shouldBlock("synthetic.app"))
    }
    @Test fun planAnchorsSurviveMidnightAndTimezoneChange() {
        val c = activeNight(); val plan = c.state.session!!.plan!!
        advance(2 * 60 * 60_000L); c.reconcile()
        assertEquals("overnight", c.state.session!!.phase(sample.wall)); assertEquals(plan, c.state.session!!.plan)
        assertEquals(plan.nightKey, c.state.session!!.plan!!.nightKey)
    }
    @Test fun qualifyingBonusIsOncePerSavedNightAcrossEarlyRestart() {
        val c = activeNight(); val p = c.state.session!!.plan!!
        advance(30 * 60_000); c.end("ended"); assertEquals(FarmSettlement.BONUS, c.state.farm.bonusMillis)
        assertTrue(c.startWindDown(p)); advance(5 * 60_000); c.end("emergency")
        assertEquals("alreadyGranted", c.state.farm.receipts[c.state.session!!.id]!!.bonus!!.result)
        assertEquals(1, c.state.farm.grantedNights.size)
    }
    @Test fun failedLiveWriteRetriesTerminalSnapshotBeforeAllowingAnotherStart() {
        val c = coordinator(); c.serviceConnected(); c.start(200 * 60_000L); advance(60 * 60_000L)
        failAt = writes + 1; assertNull(c.proposeAccess(c.state.session!!.id)); advance(60 * 60_000L)
        failAt = -1; c.serviceConnected(); assertTrue(c.repair())
        assertEquals(60 * 60_000L, c.state.farm.receipts.values.single().creditedMillis)
        assertTrue(c.state.session!!.interruption); assertTrue(c.start(100 * 60_000L))
    }
    @Test fun pendingIntentBeforeCleanupIsDurableAndCreditIsNotPublishedEarly() {
        val c = coordinator(); c.serviceConnected(); c.start(200 * 60_000L); advance(100 * 60_000L)
        failAt = writes + 2; c.end("ended")
        assertEquals("ended", stored.session!!.status); assertEquals(1, stored.terminalIntents.count { !it.settled })
        assertTrue(stored.farm.receipts.isEmpty()); assertTrue(stored.farm.sheep.isEmpty())
        assertFalse(c.shouldBlock("synthetic.app"))
    }
    @Test fun overlapUnionAndMissingAccessDataPreventExtraCredit() {
        val start = sample.wall
        val run = Session("00000000-0000-4000-8000-000000000010", start, start + 3_600_000, setOf("synthetic.app"),
            status = "ended", endedAt = start + 3_600_000, farmCreditVersion = 2, accessUseCount = 3,
            access = listOf(AccessInterval("a", "", start - 60_000, start + 120_000, true),
                AccessInterval("b", "", start + 60_000, start + 180_000, true), AccessInterval("c", "", start + 3_500_000, start + 3_800_000, true)))
        val farm = FarmSettlement.settle(GuestFarm(), run)
        assertEquals(280_000, farm.receipts.values.single().excludedAccessMillis)
        assertEquals(3_320_000, farm.phoneAwayMillis)
        val overlap = run.copy(id = "00000000-0000-4000-8000-000000000011", mode = "windDown", access = emptyList(), accessUseCount = 0)
        assertEquals(0, FarmSettlement.settle(farm, overlap).windDownMillis)
        val missing = FarmSettlement.settle(GuestFarm(), run.copy(accessUseCount = 4))
        assertEquals(0, missing.phoneAwayMillis); assertTrue(missing.receipts.values.single().trackingIncomplete)
    }
    @Test fun deferredMorningAllowsPhoneAwayAndItsOrdinaryExitDoesNotCancelMorning() {
        val c = activeNight(); advance(60 * 60_000); c.earlyWake("defer")
        val morning = c.state.mornings.single()
        c.select(setOf("another.app")); assertTrue(c.start(30 * 60_000L))
        advance(10 * 60_000); c.end("ended")
        assertEquals(morning, c.state.mornings.single()); assertFalse(c.shouldBlock("synthetic.app"))
        advance(morning.start - sample.wall + 15 * 60_000); c.reconcile()
        assertTrue(c.shouldBlock("synthetic.app")); assertFalse(c.shouldBlock("another.app"))
        c.end("ended", expectedOccurrence = morning.id)
        assertEquals(15, c.state.farm.morningPendingMinutes)
    }
    @Test fun overlappingDeferredMorningRetainsItsOwnSelectionAndObservedOccurrence() {
        val c = activeNight(); advance(60 * 60_000); c.earlyWake("defer")
        val morning = c.state.mornings.single(); advance(morning.start - sample.wall - 60_000)
        c.select(setOf("another.app")); assertTrue(c.start(30 * 60_000L)); advance(60_000); c.reconcile()
        assertTrue(c.shouldBlock("synthetic.app")); assertTrue(c.shouldBlock("another.app"))
        assertEquals(morning.id, c.protectionOccurrence("synthetic.app")); c.observed(morning.id)
        assertNotNull(c.state.mornings.single().observedAt); assertNull(c.state.session!!.observedAt)
        advance(15 * 60_000); c.end("ended")
        assertEquals("active", c.state.mornings.single().outcome)
        c.end("emergency"); assertFalse(c.shouldBlock("synthetic.app"))
        assertEquals(15, c.state.farm.morningPendingMinutes)
    }
    @Test fun newStartsKeepReadinessAndRepairFencesForEveryMode() {
        val c = coordinator()
        assertFalse(c.startWindDown(plan())); assertFalse(c.startMorning())
        c.serviceConnected(); c.consent(false)
        assertFalse(c.startWindDown(plan())); assertFalse(c.startMorning())
        c.consent(true); c.select(emptySet()); assertFalse(c.startMorning())
        c.select(setOf("synthetic.app")); c.fail("repair"); c.serviceConnected()
        assertFalse(c.startMorning()); assertTrue(c.repair()); assertTrue(c.startMorning())
    }
}
