package com.ngawangchime.countingsheep.prototype

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.ngawangchime.countingsheep.prototype.data.*
import com.ngawangchime.countingsheep.prototype.domain.*
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.security.MessageDigest

@RunWith(AndroidJUnit4::class)
class DomainStoreInstrumentationTest {
    private fun isolated(body: (File) -> Unit) {
        check(InstrumentationRegistry.getArguments().getString("isolatedPrototype") == "true" && android.os.Build.MODEL.contains("sdk_gphone"))
        val directory = File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir, "and007-isolated-domain")
        directory.deleteRecursively(); directory.mkdirs()
        try { body(directory) } finally { directory.deleteRecursively() }
    }
    private fun envelope(payload: String): ByteArray {
        val digest = MessageDigest.getInstance("SHA-256").digest(payload.toByteArray()).joinToString("") { "%02x".format(it) }
        return buildJsonObject { put("payload", payload); put("sha256", digest) }.toString().toByteArray()
    }
    @Test fun migrationPreservesPrototypeBytesAsRecoveryAndDoesNotInventRewards() = isolated { directory ->
        val original = envelope("""{"schema":1,"generation":7,"consent":true,"selection":["synthetic.app"],"session":{"id":"00000000-0000-4000-8000-000000000001","start":1000,"end":601000,"packages":["synthetic.app"],"status":"active","access":[{"nonce":"00000000-0000-4000-8000-000000000002","occurrence":"00000000-0000-4000-8000-000000000001","start":1000,"end":301000,"committed":true}]}}""")
        File(directory, "session.json").writeBytes(original)
        val store = SessionStore(directory); val migrated = store.load()
        store.save(migrated.copy(generation = 8))
        assertArrayEquals(original, File(directory, "session.recovery.json").readBytes())
        val c = SessionCoordinator(SessionStore(directory).load(), store::save, { ClockSample(601000, 601000, 1) })
        c.serviceConnected()
        assertEquals("completed", c.state.session!!.status); assertEquals(0, c.state.session!!.farmCreditVersion)
        assertEquals(1, c.state.session!!.access.size); assertTrue(c.state.farm.receipts.isEmpty())
        assertEquals("localGuest", c.state.scope)
    }
    @Test fun interruptedIntentEffectsAndLostAcknowledgementsReplayExactlyOnceOnRealAtomicFiles() = isolated { directory ->
        for (checkpoint in listOf("before-primary", "primary-before-finish", "after-primary")) {
            directory.listFiles()!!.forEach { it.delete() }
            var fault = false
            var now = ClockSample(1_790_000_000_000, 10_000, 1)
            var writes = 0
            val store = SessionStore(directory) { name -> if (fault && writes == 2 && name == checkpoint) error("simulated interruption") }
            val c = SessionCoordinator(PrototypeState(consent = true, selection = setOf("synthetic.app")), { writes++; store.save(it) }, { now },
                { "00000000-0000-4000-8000-000000000001" })
            c.serviceConnected(); assertTrue(c.start(200 * 60_000L))
            now = now.copy(wall = now.wall + 100 * 60_000, elapsed = now.elapsed + 100 * 60_000)
            writes = 0; fault = true; c.end("ended")
            assertTrue(c.state.repairRequired); assertFalse(c.shouldBlock("synthetic.app"))
            fault = false
            val reopened = SessionStore(directory)
            val restarted = SessionCoordinator(reopened.load(), reopened::save, { now })
            restarted.serviceConnected(); restarted.replay()
            assertEquals(1, restarted.state.farm.receipts.size); assertEquals(1, restarted.state.farm.outcomes.size)
            assertEquals(1, restarted.state.farm.sheep.size); assertTrue(restarted.state.terminalIntents.all { it.settled })
            val committed = restarted.state.farm
            val again = SessionCoordinator(SessionStore(directory).load(), reopened::save, { now }); again.serviceConnected()
            assertEquals(committed, again.state.farm); assertNull(again.state.session!!.observedAt)
        }
    }
    @Test fun corruptNewerAndUnknownDocumentsStayBytePreservedAndWriteFenced() = isolated { directory ->
        val store = SessionStore(directory); val initial = PrototypeState(generation = 1, consent = true, selection = setOf("synthetic.app"))
        store.save(initial); store.save(initial.copy(generation = 2))
        val payload = Json.parseToJsonElement(SessionDocument.encode(initial).decodeToString()).jsonObject.getValue("payload").jsonPrimitive.content
        for (bad in listOf("corrupt".toByteArray(), envelope(payload.replace("\"schema\":4", "\"schema\":99")),
            envelope(payload.dropLast(1) + ",\"futureField\":true}"))) {
            val primary = File(directory, "session.json"); primary.writeBytes(bad)
            val reopened = SessionStore(directory); val recovered = reopened.load()
            assertTrue(recovered.repairRequired); assertEquals(initial.farm, recovered.farm)
            assertThrows(IllegalStateException::class.java) { reopened.save(initial.copy(generation = 3)) }
            assertArrayEquals(bad, primary.readBytes())
        }
    }
    @Test fun morningSettlementCrashCannotDuplicateWoolOrArrival() = isolated { directory ->
        var now = ClockSample(1_790_000_000_000, 10_000, 1)
        val store = SessionStore(directory)
        val c = SessionCoordinator(PrototypeState(consent = true, selection = setOf("synthetic.app"), farm = GuestFarm(morningPendingMinutes = 85)), store::save, { now })
        c.serviceConnected(); c.startMorning(15)
        now = now.copy(wall = now.wall + 15 * 60_000, elapsed = now.elapsed + 15 * 60_000)
        // First persist the terminal occurrence, then interrupt the atomic inventory/effect publication.
        var writes = 0
        val retryStore = SessionStore(directory) { if (writes == 2 && it == "before-primary") error("interrupt effect") }
        val restored = SessionCoordinator(store.load(), { writes++; retryStore.save(it) }, { now })
        restored.reconcile()
        assertTrue(restored.state.repairRequired)
        assertEquals("finished", SessionStore(directory).load().mornings.single().outcome)
        assertEquals(0, SessionStore(directory).load().farm.wool)
        val reopened = SessionStore(directory)
        val recovered = SessionCoordinator(reopened.load(), reopened::save, { now }); recovered.serviceConnected(); recovered.reconcile()
        assertEquals(1, recovered.state.farm.wool); assertEquals(1, recovered.state.farm.sheep.size)
        assertEquals(1, recovered.state.farm.morningReceipts.size)
        val farm = recovered.state.farm; recovered.replay(); assertEquals(farm, recovered.state.farm)
    }
    @Test fun guestJourneyUpdatePreservesV2OccurrenceFarmAndOriginalRecoveryBytes() = isolated { directory ->
        val id = "00000000-0000-4000-8000-000000000001"
        val prior = PrototypeState(generation = 7, consent = true, selection = setOf("synthetic.app"),
            session = Session(id, 1000, 601000, setOf("synthetic.app"), status = "active", farmCreditVersion = 2,
                access = listOf(AccessInterval("00000000-0000-4000-8000-000000000002", id, 1000, 301000, true)), accessUseCount = 1),
            farm = GuestFarm(phoneAwayMillis = 90 * 60_000L, morningPendingMinutes = 85,
                sheep = listOf(GuestSheep("00000000-0000-4000-8000-000000000003", "future-sheep", "future-rarity", 1000))))
        val payload = Json.parseToJsonElement(SessionDocument.encode(prior).decodeToString()).jsonObject.getValue("payload").jsonPrimitive.content
        val objectValue = Json.parseToJsonElement(payload).jsonObject.toMutableMap().apply {
            put("schema", JsonPrimitive(2)); remove("nightPreferences"); remove("acknowledgedReceipts")
            val oldFarm = getValue("farm").jsonObject.toMutableMap().apply {
                put("schema", JsonPrimitive(1)); remove("welcome"); remove("shears")
                put("sheep", JsonArray(getValue("sheep").jsonArray.map { JsonObject(it.jsonObject - "timesSheared") }))
            }
            put("farm", JsonObject(oldFarm))
        }
        val original = envelope(JsonObject(objectValue).toString())
        File(directory, "session.json").writeBytes(original)
        val store = SessionStore(directory); val migrated = store.load()
        assertEquals(4, migrated.schema); assertEquals(prior.farm, migrated.farm); assertEquals(prior.session, migrated.session)
        assertEquals(prior.consent, migrated.consent); assertEquals(prior.selection, migrated.selection)
        store.save(migrated.copy(generation = 8, nightPreferences = NightPreferences()))
        assertArrayEquals(original, File(directory, "session.recovery.json").readBytes())
        val reopened = SessionStore(directory).load()
        assertEquals(NightPreferences(), reopened.nightPreferences); assertEquals(prior.farm, reopened.farm)
        assertEquals(prior.session, reopened.session)
    }

    @Test fun starterAndShearingAtomicFaultsPreserveIdentityAcrossRepairAndRestart() = isolated { directory ->
        for (checkpoint in listOf("recovery-before-finish", "before-primary", "primary-before-finish", "after-primary")) {
            directory.listFiles()!!.forEach { it.delete() }
            var fault = false
            val store = SessionStore(directory) { if (fault && it == checkpoint) error("interrupted economic action") }
            val initial = PrototypeState(generation = 1)
            store.save(initial)
            val c = SessionCoordinator(initial, store::save, { ClockSample(1_790_000_000_000, 1000, 1) },
                { "00000000-0000-4000-8000-000000000001" })
            fault = true; assertFalse(c.welcomeGuest()); assertTrue(c.state.farm.sheep.isEmpty())
            assertFalse(c.shouldBlock("synthetic.app"))
            val interrupted = SessionStore(directory).load()
            assertEquals(if (checkpoint == "after-primary") 1 else 0, interrupted.farm.sheep.size)
            fault = false; c.serviceConnected(); assertTrue(c.repair()); assertTrue(c.welcomeGuest())
            assertEquals(1, c.state.farm.sheep.size)
            fault = true; assertFalse(c.shear(GuestFarmActions.starterID, 1)); assertEquals(0, c.state.farm.wool)
            val interruptedShear = SessionStore(directory).load()
            assertEquals(if (checkpoint == "after-primary") 1 else 0, interruptedShear.farm.wool)
            fault = false; c.serviceConnected(); assertTrue(c.repair())
            val reopened = SessionStore(directory)
            val restarted = SessionCoordinator(reopened.load(), reopened::save, { ClockSample(1_790_000_000_000, 1000, 1) })
            assertTrue(restarted.welcomeGuest()); assertTrue(restarted.shear(GuestFarmActions.starterID, 1))
            assertEquals(1, restarted.state.farm.wool); assertEquals(1, restarted.state.farm.shears.size)
            assertEquals(1, restarted.state.farm.sheep.size); assertNull(restarted.state.session)
        }
    }

}
