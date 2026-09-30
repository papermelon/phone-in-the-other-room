package com.ngawangchime.countingsheep.prototype

import com.ngawangchime.countingsheep.prototype.data.SessionDocument
import com.ngawangchime.countingsheep.prototype.domain.*
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.security.MessageDigest

class GuestFarmActionsTest {
    private val id = "00000000-0000-4000-8000-000000000001"
    private val at = 1_790_000_000_000L
    private fun envelope(payload: String): ByteArray {
        val digest = MessageDigest.getInstance("SHA-256").digest(payload.toByteArray()).joinToString("") { "%02x".format(it) }
        return buildJsonObject { put("payload", payload); put("sha256", digest) }.toString().toByteArray()
    }
    @Test fun freshIntroductionStarterWelcomeAndShearStayLocalAcrossRestart() {
        var disk = PrototypeState(); val clock = { ClockSample(at, 1000, 1) }
        val c = SessionCoordinator(disk, { disk = SessionDocument.decode(SessionDocument.encode(it)) }, clock, { id })
        assertFalse(c.operational); assertTrue(c.welcomeGuest()); assertFalse(c.live()); assertNull(c.state.consent)
        val first = c.state.farm; assertEquals(1, first.sheep.size); assertEquals("mabel", first.sheep.single().definitionID)
        assertEquals(0, first.wool); assertEquals(0, first.phoneAwayMillis); assertTrue(first.receipts.isEmpty())
        assertTrue(c.welcomeGuest()); assertEquals(first, c.state.farm)
        assertTrue(c.acknowledgeWelcome()); assertTrue(c.shear(GuestFarmActions.starterID, 1))
        assertTrue(c.shear(GuestFarmActions.starterID, 1)); assertFalse(c.shear(GuestFarmActions.starterID, 2))
        val restored = SessionCoordinator(disk, {}, clock)
        assertEquals(c.state.farm, restored.state.farm); assertTrue(restored.state.farm.welcome.acknowledged)
        assertEquals(1, restored.state.farm.wool); assertEquals(1, restored.state.farm.shears.size)
        assertEquals(2 * FarmSettlement.WIND_DOWN, restored.state.farm.sheep.single().regrowthRemaining)
        assertEquals("localGuest", restored.state.scope)
    }
    @Test fun establishedFarmSkipsStarterAndPreservesUnknownCatalogAndLedgers() {
        val farm = GuestFarm(phoneAwayMillis = 90_000, sheep = listOf(GuestSheep(id, "future-sheep", "future-rarity", at)))
        val next = GuestFarmActions.welcome(farm, at, id)
        assertEquals(farm.sheep, next.sheep); assertEquals(farm.phoneAwayMillis, next.phoneAwayMillis)
        assertEquals("starterSkippedExistingFarm", next.welcome.grant!!.kind)
        assertTrue(next.outcomes.isEmpty()); assertNull(GuestFarmActions.shear(next, id, 1, at))
        assertEquals(next, SessionDocument.decode(SessionDocument.encode(PrototypeState(farm = next))).farm)
    }
    @Test fun partialCreditAccessUnionAndBonusesHaveDistinctRegrowthEffects() {
        var farm = GuestFarmActions.welcome(GuestFarm(), at - 60_000, id)
        farm = GuestFarmActions.shear(farm, GuestFarmActions.starterID, 1, at)!!
        val plan = NightPlan(at + 30 * 60_000, at + 9 * 3_600_000, at + 9 * 3_600_000 + 30 * 60_000, 30, 30, "UTC", "2026-10-1")
        val run = Session(id, at, plan.protectedUntil, setOf("fixture.app"), status = "ended", endedAt = plan.bedtime,
            mode = "windDown", plan = plan, farmCreditVersion = 2, accessUseCount = 2,
            access = listOf(AccessInterval("00000000-0000-4000-8000-000000000002", id, at, at + 240_000, true),
                AccessInterval("00000000-0000-4000-8000-000000000003", id, at + 120_000, at + 300_000, true)))
        val next = FarmSettlement.settle(farm, run)
        assertEquals(25 * 60_000L, next.receipts[id]!!.creditedMillis)
        assertEquals(FarmSettlement.BONUS, next.bonusMillis)
        assertEquals(2 * FarmSettlement.WIND_DOWN - 25 * 60_000, next.sheep.single().regrowthRemaining)
        assertEquals(next, FarmSettlement.settle(next, run))
        val morning = MorningOccurrence("00000000-0000-4000-8000-000000000004", start = at, end = at + 100 * 60_000,
            packages = setOf("fixture.app"), actualStart = at, endedAt = at + 100 * 60_000, outcome = "finished")
        val afterMorning = FarmSettlement.morning(next, morning)
        assertEquals(next.sheep.single().regrowthRemaining, afterMorning.sheep.first().regrowthRemaining)
        assertEquals(2, afterMorning.wool)
    }
    @Test fun sheepCannotShearBeforeArrivalWhilePendingOrWithStaleHarvestIdentity() {
        val sheep = GuestSheep(id, "mabel", "common", at)
        val farm = GuestFarm(sheep = listOf(sheep))
        assertNull(GuestFarmActions.shear(farm, id, 1, at - 1))
        assertNull(GuestFarmActions.shear(farm.copy(sheep = listOf(sheep.copy(status = "pending"))), id, 1, at))
        assertNull(GuestFarmActions.shear(farm, id, 2, at))
        val first = GuestFarmActions.shear(farm, id, 1, at)!!
        val regrown = first.copy(sheep = first.sheep.map { it.copy(regrowthRemaining = 0) })
        assertEquals(regrown, GuestFarmActions.shear(regrown, id, 1, at + 1))
        val second = GuestFarmActions.shear(regrown, id, 2, at + 1)!!
        assertEquals(2, second.wool); assertEquals(2, second.shears.size)
        assertEquals(second, SessionDocument.decode(SessionDocument.encode(PrototypeState(farm = second))).farm)
    }
    @Test fun versionThreeMigrationPreservesPreferencesReceiptsOccurrenceAndUnknownSheep() {
        val prior = PrototypeState(consent = true, selection = setOf("fixture.app"), nightPreferences = NightPreferences(),
            session = Session(id, at, at + 600_000, setOf("fixture.app"), status = "active", farmCreditVersion = 2),
            farm = GuestFarm(sheep = listOf(GuestSheep(id, "future-sheep", "future-rarity", at))))
        val wrapper = Json.parseToJsonElement(SessionDocument.encode(prior).decodeToString()).jsonObject
        val raw = Json.parseToJsonElement(wrapper.getValue("payload").jsonPrimitive.content).jsonObject.toMutableMap()
        raw["schema"] = JsonPrimitive(3)
        val oldFarm = raw.getValue("farm").jsonObject.toMutableMap().apply {
            put("schema", JsonPrimitive(1)); remove("welcome"); remove("shears")
            put("sheep", JsonArray(getValue("sheep").jsonArray.map { JsonObject(it.jsonObject - "timesSheared") }))
        }
        raw["farm"] = JsonObject(oldFarm)
        val migrated = SessionDocument.decode(envelope(JsonObject(raw).toString()))
        assertEquals(prior, migrated); assertFalse(migrated.farm.welcome.introductionCompleted)
        assertEquals(prior.farm.sheep, GuestFarmActions.welcome(migrated.farm, at, id).sheep)
        raw["farm"] = wrapper.let { Json.parseToJsonElement(it.getValue("payload").jsonPrimitive.content).jsonObject.getValue("farm") }
        assertThrows(Exception::class.java) { SessionDocument.decode(envelope(JsonObject(raw).toString())) }
    }
    @Test fun failedWelcomeAndShearWritesRetryExactIdentitiesWithoutOptimisticRewards() {
        for (lostAcknowledgement in listOf(false, true)) {
            var disk = PrototypeState(); var fail = true
            val c = SessionCoordinator(disk, {
                if (!fail || lostAcknowledgement) disk = SessionDocument.decode(SessionDocument.encode(it))
                if (fail) error("interrupted transaction")
            }, { ClockSample(at, 1000, 1) }, { id })
            assertFalse(c.welcomeGuest()); assertTrue(c.state.farm.sheep.isEmpty()); assertTrue(c.state.repairRequired)
            fail = false; assertTrue(c.repair()); assertFalse(c.operational); assertTrue(c.welcomeGuest())
            assertEquals(1, disk.farm.sheep.size)
            fail = true; assertFalse(c.shear(GuestFarmActions.starterID, 1)); assertEquals(0, c.state.farm.wool)
            fail = false; assertTrue(c.repair()); assertFalse(c.operational); assertTrue(c.shear(GuestFarmActions.starterID, 1))
            val reopened = SessionCoordinator(disk, { disk = it }, { ClockSample(at, 1000, 1) })
            assertTrue(reopened.shear(GuestFarmActions.starterID, 1)); assertEquals(1, disk.farm.wool)
            assertEquals(1, disk.farm.shears.size); assertEquals(1, disk.farm.sheep.size)
        }
    }
    @Test fun malformedWelcomeAndShearStateCannotOverwriteThroughDefaults() {
        val farm = GuestFarmActions.shear(GuestFarmActions.welcome(GuestFarm(), at, id), GuestFarmActions.starterID, 1, at)!!
        val wrapper = Json.parseToJsonElement(SessionDocument.encode(PrototypeState(farm = farm)).decodeToString()).jsonObject
        val payload = wrapper.getValue("payload").jsonPrimitive.content
        val invalid = listOf(payload.replace("\"ordinal\":1", "\"ordinal\":2"),
            payload.replace("\"woolDelta\":1", "\"woolDelta\":7"),
            payload.replace("\"timesSheared\":1", "\"timesSheared\":0"),
            payload.replace("\"kind\":\"starterSheep\"", "\"kind\":\"futureGrant\""),
            payload.replace("\"introductionCompleted\":true", "\"introductionCompleted\":false"),
            payload.replace(",\"timesSheared\":1", ""),
            payload.replace("\"acknowledged\":false,", ""),
            payload.replace("\"shears\":", "\"futureShears\":"))
        invalid.forEach { assertThrows(Exception::class.java) { SessionDocument.decode(envelope(it)) } }
    }

}
