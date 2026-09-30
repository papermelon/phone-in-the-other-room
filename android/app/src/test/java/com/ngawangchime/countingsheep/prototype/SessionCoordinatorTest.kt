package com.ngawangchime.countingsheep.prototype

import com.ngawangchime.countingsheep.prototype.domain.*
import org.junit.Assert.*
import org.junit.Test

class SessionCoordinatorTest {
    private var now = ClockSample(1_790_000_000_000, 10_000, 1)
    private var saved = PrototypeState(consent = true, selection = setOf("test.app"))
    private var writeFails = false
    private var sequence = 1
    private fun coordinator() = SessionCoordinator(saved, { if (writeFails) error("disk full"); saved = it }, { now },
        { "00000000-0000-4000-8000-${(sequence++).toString().padStart(12, '0')}" })
    private fun advance(ms: Long) { now = now.copy(wall = now.wall + ms, elapsed = now.elapsed + ms) }
    private fun active(duration: Long = 900_000) = coordinator().apply { serviceConnected(); assertTrue(start(duration)) }

    @Test fun admissionRequiresConsentSelectionAndConnectedService() {
        val c = coordinator()
        assertFalse(c.start(900_000))
        c.serviceConnected(); c.consent(false); assertFalse(c.start(900_000))
        c.consent(true); c.select(emptySet()); assertFalse(c.start(900_000))
    }
    @Test fun fiveMinutesIsPersistedBeforeClearAndClippedToEnd() {
        val c = active(180_000)
        val interval = c.proposeAccess(c.state.session!!.id)!!
        assertEquals(180_000, interval.end - interval.start)
        assertFalse(saved.session!!.access.single().committed)
        assertTrue(c.shouldBlock("test.app"))
        assertTrue(c.commitAccess(interval))
        assertTrue(saved.session!!.access.single().committed)
        assertFalse(c.shouldBlock("test.app"))
        advance(180_000); c.reconcile()
        assertEquals("completed", c.state.session!!.status)
        assertFalse(c.shouldBlock("test.app"))
    }
    @Test fun accessExpiresAtFiveMinutesAndRestoresOnEvent() {
        val c = active()
        val grant = c.proposeAccess(c.state.session!!.id)!!
        assertEquals(300_000, grant.end - grant.start)
        assertTrue(c.commitAccess(grant)); advance(299_999)
        assertFalse(c.shouldBlock("test.app")); advance(1)
        assertTrue(c.shouldBlock("test.app"))
        assertEquals(1, c.state.session!!.access.size)
    }
    @Test fun pendingGrantDoesNotAuthorizeAfterRestart() {
        val c = active()
        c.proposeAccess(c.state.session!!.id)
        val restarted = coordinator(); restarted.serviceConnected()
        assertTrue(restarted.state.session!!.access.isEmpty())
        assertTrue(restarted.shouldBlock("test.app"))
    }
    @Test fun committedGrantSurvivesRestartUntilBoundary() {
        val c = active(); c.commitAccess(c.proposeAccess(c.state.session!!.id)!!)
        advance(60_000)
        val restarted = coordinator(); restarted.serviceConnected()
        assertFalse(restarted.shouldBlock("test.app")); advance(240_000)
        assertTrue(restarted.shouldBlock("test.app"))
        assertTrue(restarted.state.session!!.coverage.startsWith("Unknown"))
    }
    @Test fun staleOccurrenceAndGrantCannotAffectReplacement() {
        val c = active(); val old = c.state.session!!.id; val grant = c.proposeAccess(old)!!
        c.end("emergency"); assertTrue(c.start(900_000)); val replacement = c.state.session
        c.reconcile(old); c.end("ended", expectedOccurrence = old); assertEquals(replacement, c.state.session)
        assertFalse(c.commitAccess(grant)); assertNull(c.proposeAccess(old))
        assertTrue(c.shouldBlock("test.app"))
    }
    @Test fun restartPastEndRecordsPlannedEndWithoutInventingCoverage() {
        val c = active(); val end = c.state.session!!.end
        advance(1_800_000)
        val restarted = coordinator(); restarted.serviceConnected()
        assertEquals("completed", restarted.state.session!!.status)
        assertEquals(end, restarted.state.session!!.endedAt)
        assertNull(restarted.state.session!!.observedAt)
    }
    @Test fun failureFailsOpenAndRequiresExplicitRepair() {
        val c = active(); c.fail("overlay failed")
        assertFalse(c.shouldBlock("test.app")); assertFalse(c.start(900_000))
        c.serviceConnected(); assertFalse(c.start(900_000))
        assertTrue(c.repair()); assertTrue(c.start(900_000))
    }
    @Test fun storageFailureDoesNotLiftIntoAnUnrecordedGrant() {
        val c = active(); writeFails = true
        assertNull(c.proposeAccess(c.state.session!!.id))
        assertFalse(c.shouldBlock("test.app")); assertTrue(c.state.repairRequired)
        writeFails = false; c.serviceConnected(); assertTrue(c.repair()); assertTrue(c.start(900_000))
    }
    @Test fun normalAndEmergencyExitLeaveAppsOpen() {
        for (reason in listOf("ended", "emergency")) {
            val c = active(); c.commitAccess(c.proposeAccess(c.state.session!!.id)!!); advance(60_000); c.end(reason)
            assertEquals(60_000, c.state.session!!.access.single().end - c.state.session!!.access.single().start)
            assertFalse(c.shouldBlock("test.app")); assertNull(c.nextBoundary())
            assertEquals(reason, saved.session!!.status)
        }
    }
    @Test fun clockJumpAndRebootFailOpen() {
        val c = active(); now = now.copy(wall = now.wall - 3_600_000)
        c.reconcile(); assertTrue(c.state.repairRequired); assertFalse(c.shouldBlock("test.app"))
        c.serviceConnected(); c.repair(); c.start(900_000)
        now = now.copy(boot = 2, elapsed = 0)
        c.reconcile(); assertTrue(c.state.repairRequired)
    }
    @Test fun scheduledStartUsesAbsoluteBoundaryAndNoEarlyBlock() {
        val c = coordinator(); c.serviceConnected(); assertTrue(c.start(600_000, 120_000))
        assertFalse(c.shouldBlock("test.app")); advance(120_000)
        assertTrue(c.shouldBlock("test.app")); assertEquals("active", c.state.session!!.status)
        assertFalse(c.shouldBlock("other.app"))
    }
    @Test fun refuseAndSubTwoSecondAccessStaySafe() {
        val c = active(2_001); advance(2)
        assertNull(c.proposeAccess(c.state.session!!.id))
        c.consent(false); assertFalse(c.shouldBlock("test.app")); assertEquals("refused", c.state.session!!.status)
    }
    @Test fun staleAlarmDoesNotCreateObservedEvidence() {
        val c = active(); c.markAlarm("stale", true); c.observed("stale")
        assertFalse(c.state.session!!.alarmRegistered); assertNull(c.state.session!!.observedAt)
        c.markAlarm(c.state.session!!.id, true)
        assertNull(c.state.session!!.observedAt)
    }
}
