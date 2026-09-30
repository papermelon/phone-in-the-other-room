package com.ngawangchime.countingsheep.prototype

import com.ngawangchime.countingsheep.prototype.domain.*
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.time.ZoneId

class DomainParityTest {
    private val reference get() = Json.parseToJsonElement(File(System.getProperty("fixtureDir"), "domain-reference.json").readText()).jsonObject
    private inline fun <reified T> decode(value: JsonElement) = Json.decodeFromJsonElement<T>(value)
    @Test fun currentSwiftAnchoredTimingPhasesAndIdentitiesMatch() {
        for (entry in reference.getValue("timing").jsonArray) {
            val row = entry.jsonObject; val at = row.getValue("at").jsonPrimitive.long
            val plan = decode<NightPreferences>(row.getValue("preferences")).makePlan(at, ZoneId.of(row.getValue("zone").jsonPrimitive.content))
            val expected = decode<NightPlan>(row.getValue("expected"))
            // Foundation spells UTC as GMT. Compare zone semantics without rewriting saved attribution.
            assertEquals(ZoneId.of(expected.zone).rules, ZoneId.of(plan.zone).rules)
            assertEquals(row.getValue("name").toString(), expected, plan.copy(zone = expected.zone))
            for (sample in row.getValue("samples").jsonArray) {
                val point = sample.jsonObject; val time = point.getValue("at").jsonPrimitive.long
                assertEquals(point.getValue("phase").jsonPrimitive.content, plan.phase(time))
                assertEquals(point.getValue("next").jsonPrimitive.longOrNull, plan.nextTransition(time))
            }
        }
        for (entry in reference.getValue("identities").jsonArray) {
            val row = entry.jsonObject
            assertEquals(row.getValue("morning").jsonPrimitive.content, SearchRules.morningID(row.getValue("run").jsonPrimitive.content))
        }
    }
    @Test fun currentSwiftCreditBonusGrowthAndDeterministicSearchSemanticsMatch() {
        for (entry in reference.getValue("credit").jsonArray) {
            val row = entry.jsonObject; var farm = decode<GuestFarm>(row.getValue("initial"))
            row.getValue("runs").jsonArray.forEachIndexed { index, raw ->
                val run = decode<Session>(raw)
                farm = FarmSettlement.settle(farm, run)
                assertEquals("${row.getValue("name")} step $index", decode<GuestFarm>(row.getValue("expected").jsonArray[index]), farm)
                assertEquals(farm, FarmSettlement.settle(farm, run))
                farm = Json.decodeFromString( kotlinx.serialization.json.Json.encodeToString(GuestFarm.serializer(), farm))
            }
        }
    }
    @Test fun currentSwiftMorningMinutesWoolFillsAndSearchSemanticsMatch() {
        for (entry in reference.getValue("morning").jsonArray) {
            val row = entry.jsonObject; var farm = decode<GuestFarm>(row.getValue("initial"))
            row.getValue("occurrences").jsonArray.forEachIndexed { index, raw ->
                val occurrence = decode<MorningOccurrence>(raw)
                farm = FarmSettlement.morning(farm, occurrence)
                assertEquals("${row.getValue("name")} step $index", decode<GuestFarm>(row.getValue("expected").jsonArray[index]), farm)
                assertEquals(farm, FarmSettlement.morning(farm, occurrence))
            }
        }
    }
    @Test fun currentSwiftGuestRoutingDurationsAndFreshPhraseSemanticsMatch() {
        val journey = reference.getValue("journey").jsonObject
        val preferences = NightPreferences()
        val state = PrototypeState(nightPreferences = preferences)
        for (raw in journey.getValue("routing").jsonArray) {
            val row = raw.jsonObject
            assertEquals(row.getValue("expected").jsonPrimitive.boolean,
                GuestJourney.prefersWindDown(state, row.getValue("at").jsonPrimitive.long, ZoneId.of("UTC")))
        }
        assertEquals(journey.getValue("phoneAwayMinutes").jsonArray.map { it.jsonPrimitive.int }, GuestJourney.phoneAwayMinutes)
        val start = journey.getValue("phases").jsonArray.first().jsonObject.getValue("at").jsonPrimitive.long
        val plan = preferences.makePlan(start, ZoneId.of("UTC"))
        val run = Session("00000000-0000-4000-8000-000000000601", start, plan.protectedUntil, setOf("fixture.app"), status = "active", mode = "windDown", plan = plan)
        for (raw in journey.getValue("phases").jsonArray) {
            val row = raw.jsonObject
            assertEquals(row.getValue("phrase").jsonPrimitive.content,
                GuestJourney.phrase(state.copy(session = run), run.id, "access", row.getValue("at").jsonPrimitive.long))
        }
        for (raw in journey.getValue("normalization").jsonArray) {
            val row = raw.jsonObject; val entry = row.getValue("entry").jsonPrimitive.content
            assertEquals(row.getValue("normalized").jsonPrimitive.content, GuestJourney.normalized(entry))
            assertEquals(row.getValue("matches").jsonPrimitive.boolean, GuestJourney.matches(entry, "Put my phone away"))
        }
        for (raw in journey.getValue("confirmations").jsonArray) {
            val row = raw.jsonObject; val action = row.getValue("action").jsonPrimitive.content
            assertEquals(row.getValue("phrase").jsonPrimitive.content, GuestJourney.phrase(state.copy(session = run), run.id, action, start + 3_600_000))
            assertEquals(row.getValue("typed").jsonPrimitive.boolean, action != "startNow")
        }
    }

    @Test fun currentSwiftStarterSkipShearingYieldsAndCreditRegrowthMatch() {
        for (raw in reference.getValue("welcome").jsonArray) {
            val row = raw.jsonObject; val initial = decode<GuestFarm>(row.getValue("initial"))
            val farm = GuestFarmActions.welcome(initial, row.getValue("at").jsonPrimitive.long, row.getValue("skipID").jsonPrimitive.content)
            assertEquals(row.getValue("name").toString(), decode<GuestFarm>(row.getValue("expected")), farm)
            assertEquals(farm, GuestFarmActions.welcome(farm, row.getValue("at").jsonPrimitive.long + 60_000, GuestFarmActions.starterID))
        }
        for (raw in reference.getValue("shearing").jsonArray) {
            val row = raw.jsonObject; var farm = decode<GuestFarm>(row.getValue("initial"))
            row.getValue("actions").jsonArray.forEachIndexed { index, value ->
                val action = value.jsonObject
                if (action.getValue("kind").jsonPrimitive.content == "shear") {
                    val next = GuestFarmActions.shear(farm, action.getValue("sheepID").jsonPrimitive.content,
                        action.getValue("ordinal").jsonPrimitive.int, action.getValue("at").jsonPrimitive.long)
                    assertEquals(action.getValue("accepted").jsonPrimitive.boolean, next != null)
                    farm = next ?: farm
                } else farm = FarmSettlement.settle(farm, decode<Session>(action.getValue("run")))
                assertEquals("${row.getValue("rarity")} step $index", decode<GuestFarm>(row.getValue("expected").jsonArray[index]), farm)
                assertEquals(row.getValue("woolStates").jsonArray[index].jsonArray.map { it.jsonPrimitive.content }, farm.sheep.map(GuestFarmActions::woolState))
                farm = Json.decodeFromString(Json.encodeToString(GuestFarm.serializer(), farm))
            }
        }
    }

}
