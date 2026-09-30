package com.ngawangchime.countingsheep.prototype

import com.ngawangchime.countingsheep.prototype.data.SessionDocument
import com.ngawangchime.countingsheep.prototype.domain.*
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.security.MessageDigest
import java.time.Instant
import java.time.ZoneId

class GuestJourneyTest {
    private var now = ClockSample(Instant.parse("2026-09-30T22:30:00Z").toEpochMilli(), 10_000, 1)
    private var disk = PrototypeState(consent = true, selection = setOf("fixture.app"))
    private var sequence = 1
    private var unavailable = false
    private fun coordinator() = SessionCoordinator(disk, {
        if (unavailable) error("storage unavailable")
        disk = SessionDocument.decode(SessionDocument.encode(it))
    }, { now }, { "00000000-0000-4000-8000-${(sequence++).toString().padStart(12, '0')}" })
    private fun advance(millis: Long) { now = now.copy(wall = now.wall + millis, elapsed = now.elapsed + millis) }
    private fun envelope(payload: String): ByteArray {
        val digest = MessageDigest.getInstance("SHA-256").digest(payload.toByteArray()).joinToString("") { "%02x".format(it) }
        return buildJsonObject { put("payload", payload); put("sha256", digest) }.toString().toByteArray()
    }
    @Test fun savedPlanDoesNotStartAndEditingDoesNotMoveActiveOccurrence() {
        val c = coordinator()
        val preferences = NightPreferences()
        assertTrue(c.saveNightPreferences(preferences)); assertFalse(c.live()); assertFalse(c.shouldBlock("fixture.app"))
        c.serviceConnected(); assertTrue(c.startWindDown(preferences, ZoneId.of("UTC")))
        val run = c.state.session!!; val morning = c.state.mornings.single()
        assertTrue(c.saveNightPreferences(preferences.copy(bedtimeHour = 1, morningMinutes = 90)))
        assertEquals(run, c.state.session); assertEquals(morning, c.state.mornings.single())
        val restored = coordinator(); restored.serviceConnected()
        assertEquals(1, restored.state.nightPreferences!!.bedtimeHour); assertEquals(run.plan, restored.state.session!!.plan)
    }
    @Test fun manualNightOverlapIsStrictAndRequiresExplicitEarlyApproval() {
        val c = coordinator(); c.serviceConnected(); c.saveNightPreferences(NightPreferences())
        now = now.copy(wall = Instant.parse("2026-09-30T22:00:00Z").toEpochMilli())
        assertFalse(GuestJourney.prefersWindDown(c.state, now.wall, ZoneId.of("UTC")))
        advance(1)
        assertTrue(GuestJourney.prefersWindDown(c.state, now.wall, ZoneId.of("UTC")))
        val plan = c.state.nightPreferences!!.makePlan(now.wall, ZoneId.of("UTC"))
        assertFalse(c.startWindDown(plan)); assertTrue(c.startWindDown(plan, earlyApproved = true))
        assertEquals(plan, c.state.session!!.plan); assertEquals(now.wall, c.state.session!!.start)
        // A deliberate early start does not silently normalize bonus eligibility.
        advance(60 * 60_000L); c.end("ended")
        assertEquals("outsideStartWindow", c.state.farm.receipts.values.single().bonus!!.result)
    }
    @Test fun confirmationsAreFreshSingleUseAndPhaseSensitive() {
        val c = coordinator(); c.serviceConnected(); c.startWindDown(NightPreferences(), ZoneId.of("UTC"))
        val id = c.state.session!!.id
        val request = c.beginGuestAction(id, "access")!!
        assertEquals("Put my phone away", request.phrase)
        assertFalse(c.consumeGuestAction(request, "almost"))
        assertTrue(c.consumeGuestAction(request, "ＰＵＴ my phone away!")); assertFalse(c.consumeGuestAction(request, request.phrase))
        val oldPhase = c.beginGuestAction(id, "end")!!
        advance(30 * 60_000L); assertFalse(c.consumeGuestAction(oldPhase, oldPhase.phrase))
        val sleep = c.beginGuestAction(id, "end")!!; assertEquals("Put my phone away for sleep", sleep.phrase)
        val fresh = c.beginGuestAction(id, "end")!!; assertFalse(c.consumeGuestAction(sleep, sleep.phrase))
        val restored = coordinator(); restored.serviceConnected(); assertFalse(restored.consumeGuestAction(fresh, fresh.phrase))
        advance(120_000); assertFalse(c.consumeGuestAction(fresh, fresh.phrase))
        c.end("emergency"); assertNull(c.beginGuestAction(id, "access"))
    }
    @Test fun earlyWakeHasDedicatedStartAndTypedDeferSkipChoices() {
        val c = coordinator(); c.serviceConnected(); c.startWindDown(NightPreferences(), ZoneId.of("UTC"))
        val id = c.state.session!!.id
        assertNull(c.beginGuestAction(id, "startNow")); advance(31 * 60_000L)
        assertEquals("Start my morning at the usual time", c.beginGuestAction(id, "defer")!!.phrase)
        assertEquals("Skip my morning today", c.beginGuestAction(id, "skip")!!.phrase)
        val request = c.beginGuestAction(id, "startNow")!!
        assertTrue(c.consumeGuestAction(request, "")); assertTrue(c.earlyWake("startNow"))
        assertEquals("active", c.state.mornings.single().outcome)
        assertNull(GuestJourney.pendingReceipt(c.state))
    }
    @Test fun endingAnIndependentMorningDoesNotEndOverlappingPhoneAway() {
        val c = coordinator(); c.serviceConnected()
        val plan = NightPlan(now.wall - 60_000, now.wall + 60_000, now.wall + 16 * 60_000, 1, 15, "UTC", "2026-10-1")
        assertTrue(c.startWindDown(plan)); assertTrue(c.earlyWake("defer"))
        assertTrue(c.start(30 * 60_000L)); val phone = c.state.session!!.id
        advance(16 * 60_000L - 1); c.reconcile()
        val morning = c.state.mornings.single(); assertEquals("active", morning.outcome)
        c.end("ended", expectedOccurrence = morning.id)
        assertEquals(phone, c.state.session!!.id); assertTrue(c.state.session!!.live)
        assertTrue(c.shouldBlock("fixture.app")); assertEquals(0, c.state.farm.morningReceipts[morning.id]!!.appliedMinutes)
        c.end("emergency"); assertFalse(c.live())
    }
    @Test fun receiptsAreDurableSeparateAndAcknowledgementsDoNotChangeRewards() {
        val c = coordinator(); c.serviceConnected(); c.startWindDown(NightPreferences(), ZoneId.of("UTC"))
        val run = c.state.session!!; advance(run.end - now.wall); c.reconcile()
        val records = GuestJourney.receipts(c.state); assertEquals(2, records.size)
        assertTrue(records.all { it.ready }); assertEquals(run.id, GuestJourney.pendingReceipt(c.state)!!.id)
        val farm = c.state.farm; assertTrue(c.acknowledgeReceipts(records.map { it.id }.toSet()))
        assertEquals(farm, c.state.farm); assertNull(GuestJourney.pendingReceipt(coordinator().state))
        assertFalse(c.acknowledgeReceipts(setOf("00000000-0000-4000-8000-000000000999")))
    }
    @Test fun failedAcknowledgementDoesNotDismissReceiptOrDuplicateSettlement() {
        val c = coordinator(); c.serviceConnected(); c.start(30 * 60_000L); advance(15 * 60_000L); c.end("ended")
        val record = GuestJourney.pendingReceipt(c.state)!!; val farm = c.state.farm
        unavailable = true; assertFalse(c.acknowledgeReceipts(setOf(record.id)))
        assertEquals(record.id, GuestJourney.pendingReceipt(c.state)!!.id)
        assertTrue(c.state.repairRequired); unavailable = false
        val restarted = coordinator(); restarted.serviceConnected(); restarted.replay()
        assertEquals(farm, restarted.state.farm); assertEquals(record.id, GuestJourney.pendingReceipt(restarted.state)!!.id)
        assertTrue(restarted.acknowledgeReceipts(setOf(record.id)))
    }
    @Test fun schemaTwoMigrationPreservesLedgersUnknownCatalogAndHistoricalReceipts() {
        val c = coordinator(); c.serviceConnected(); c.start(30 * 60_000L); advance(10 * 60_000L); c.end("ended")
        val prior = c.state.copy(farm = c.state.farm.copy(sheep = listOf(GuestSheep("00000000-0000-4000-8000-000000000999", "future-sheep", "future-rarity", now.wall))))
        val payload = Json.parseToJsonElement(SessionDocument.encode(prior).decodeToString()).jsonObject.getValue("payload").jsonPrimitive.content
        val raw = Json.parseToJsonElement(payload).jsonObject.toMutableMap().apply { put("schema", JsonPrimitive(2)); remove("nightPreferences"); remove("acknowledgedReceipts")
            val oldFarm = getValue("farm").jsonObject.toMutableMap().apply {
                put("schema", JsonPrimitive(1)); remove("welcome"); remove("shears")
                put("sheep", JsonArray(getValue("sheep").jsonArray.map { JsonObject(it.jsonObject - "timesSheared") }))
            }
            put("farm", JsonObject(oldFarm)) }
        val migrated = SessionDocument.decode(envelope(JsonObject(raw).toString()))
        assertEquals(4, migrated.schema); assertEquals(prior.farm, migrated.farm); assertEquals(prior.session, migrated.session)
        assertEquals(prior.terminalIntents, migrated.terminalIntents); assertEquals(prior.consent, migrated.consent)
        assertNull(migrated.nightPreferences); assertNull(GuestJourney.pendingReceipt(migrated))
        assertEquals(GuestJourney.receipts(prior), GuestJourney.receipts(migrated))
        assertThrows(Exception::class.java) { SessionDocument.decode(envelope(JsonObject(raw + ("nightPreferences" to JsonNull)).toString())) }
        assertThrows(Exception::class.java) { SessionDocument.decode(envelope(JsonObject(Json.parseToJsonElement(payload).jsonObject - "acknowledgedReceipts").toString())) }
    }
}
