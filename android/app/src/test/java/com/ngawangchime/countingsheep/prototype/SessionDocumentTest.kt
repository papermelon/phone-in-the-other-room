package com.ngawangchime.countingsheep.prototype

import com.ngawangchime.countingsheep.prototype.data.SessionDocument
import com.ngawangchime.countingsheep.prototype.domain.*
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.security.MessageDigest

class SessionDocumentTest {
    private fun envelope(payload: String): ByteArray {
        val digest = MessageDigest.getInstance("SHA-256").digest(payload.toByteArray()).joinToString("") { "%02x".format(it) }
        return buildJsonObject { put("payload", payload); put("sha256", digest) }.toString().toByteArray()
    }
    @Test fun prototypeMigrationPreservesConsentOccurrenceAndAccessWithoutHistoricalRewards() {
        val payload = """{"schema":1,"generation":7,"consent":true,"selection":["test.app"],"session":{"id":"00000000-0000-4000-8000-000000000001","start":1000,"end":601000,"packages":["test.app"],"status":"active","access":[{"nonce":"00000000-0000-4000-8000-000000000002","occurrence":"00000000-0000-4000-8000-000000000001","start":1000,"end":301000,"committed":true}]}}"""
        val migrated = SessionDocument.decode(envelope(payload))
        assertEquals(4, migrated.schema); assertEquals(7, migrated.generation); assertEquals(true, migrated.consent)
        assertEquals(1, migrated.session!!.accessUseCount); assertEquals(0, migrated.session.farmCreditVersion)
        assertEquals(301000, migrated.session.access.single().end)
        assertEquals(migrated, SessionDocument.decode(SessionDocument.encode(migrated)))
        assertEquals(GuestFarm(), FarmSettlement.settle(migrated.farm, migrated.session.copy(status = "completed", endedAt = 601000)))
    }
    @Test fun rejectsCorruptNewerUnknownFieldsAndInvalidAmountsBeforeNormalization() {
        val valid = SessionDocument.encode(PrototypeState())
        val wrapper = Json.parseToJsonElement(valid.decodeToString()).jsonObject
        val payload = wrapper.getValue("payload").jsonPrimitive.content
        val bad = listOf(valid.copyOf().apply { this[lastIndex - 5] = 42 }, envelope(payload.replace("\"schema\":4", "\"schema\":5")),
            envelope(payload.replace("\"wool\":0", "\"wool\":-1")), envelope(payload.replace("\"schema\":2", "\"schema\":3")),
            envelope(payload.dropLast(1) + ",\"accountOwner\":\"pretend\"}"),
            envelope(payload.replace("\"receipts\":{},", "")),
            envelope(payload.replace("\"windDownMillis\":0", "\"windDownMillis\":20000000").replace("\"bonusMillis\":0", "\"bonusMillis\":10000000")),
            envelope(payload.replace("\"scope\":\"localGuest\"", "\"scope\":\"account\"")),
            envelope(payload.replace("\"generation\":0", "\"generation\":0,\"generation\":1")))
        bad.forEach { assertThrows(IllegalArgumentException::class.java) { try { SessionDocument.decode(it) } catch (e: Exception) { throw IllegalArgumentException(e) } } }
    }
    @Test fun unknownCatalogIDsRoundTripWithoutInventingAccountOwnership() {
        val farm = GuestFarm(sheep = listOf(GuestSheep("00000000-0000-4000-8000-000000000001", "future-sheep", "future-rarity", 1000)), trackedSheepID = "future-tracked")
        val state = PrototypeState(farm = farm)
        assertEquals(state, SessionDocument.decode(SessionDocument.encode(state)))
        assertEquals("localGuest", state.scope)
    }
}
