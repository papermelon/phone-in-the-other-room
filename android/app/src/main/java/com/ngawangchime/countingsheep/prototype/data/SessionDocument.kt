package com.ngawangchime.countingsheep.prototype.data

import com.ngawangchime.countingsheep.prototype.domain.*
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*
import java.security.MessageDigest
import java.time.ZoneId
import java.util.UUID

@Serializable private data class Envelope(val payload: String, val sha256: String)

/** Strict device-only codec. Unsupported input is preserved by SessionStore, never replaced with an empty write. */
object SessionDocument {
    private val json = Json { encodeDefaults = true }
    private fun digest(value: String) = MessageDigest.getInstance("SHA-256").digest(value.toByteArray()).joinToString("") { "%02x".format(it) }
    fun encode(state: PrototypeState): ByteArray {
        require(state.schema == 4 && state.farm.schema == 2)
        validate(state)
        val payload = json.encodeToString(state)
        return json.encodeToString(Envelope(payload, digest(payload))).toByteArray()
    }
    fun decode(bytes: ByteArray): PrototypeState {
        require(bytes.size <= 5_000_000)
        val raw = bytes.decodeToString()
        FarmPayloadCodec.rejectDuplicateKeys(raw)
        val envelope = json.decodeFromString<Envelope>(raw)
        require(digest(envelope.payload) == envelope.sha256)
        FarmPayloadCodec.rejectDuplicateKeys(envelope.payload)
        val objectValue = Json.parseToJsonElement(envelope.payload).jsonObject
        val schema = objectValue.getValue("schema").jsonPrimitive.int
        require(schema in 1..4)
        if (schema == 1) {
            require(objectValue.keys.all { it in setOf("schema", "generation", "consent", "selection", "session", "repairRequired", "failure", "clock") })
            objectValue["session"]?.takeUnless { it is JsonNull }?.jsonObject?.let { session ->
                require(session.keys.all { it in setOf("id", "start", "end", "packages", "status", "access", "endedAt", "observedAt", "alarmRegistered", "coverage") })
            }
        }
        else {
            if (schema == 2) require(objectValue.keys.all { it in setOf("schema", "generation", "consent", "selection", "session",
                "repairRequired", "failure", "clock", "scope", "farm", "mornings", "terminalIntents") })
            if (schema >= 3) require(objectValue.keys.containsAll(setOf("nightPreferences", "acknowledgedReceipts")))
            require(objectValue.keys.containsAll(setOf("scope", "farm", "mornings", "terminalIntents")))
            require(objectValue.getValue("farm").jsonObject.keys.containsAll(setOf("schema", "consumed", "windDownMillis",
                "phoneAwayMillis", "bonusMillis", "grantedNights", "receipts", "outcomes", "sheep", "wool",
                "morningPendingMinutes", "morningReceipts", "completedWindDowns")))
            val farm = objectValue.getValue("farm").jsonObject
            if (schema < 4) {
                require(farm.getValue("schema").jsonPrimitive.int == 1)
                require("welcome" !in farm && "shears" !in farm)
                require(farm.getValue("sheep").jsonArray.all { "timesSheared" !in it.jsonObject })
            } else {
                require(farm.getValue("schema").jsonPrimitive.int == 2 && farm.keys.containsAll(setOf("welcome", "shears")))
                require(farm.getValue("sheep").jsonArray.all { "timesSheared" in it.jsonObject })
                val welcome = farm.getValue("welcome").jsonObject
                require(welcome.keys.containsAll(setOf("introductionCompleted", "acknowledged", "grant")))
                welcome["grant"]?.takeUnless { it is JsonNull }?.let { require(it.jsonObject.keys.containsAll(setOf("id", "kind", "key", "createdAt"))) }
                require(farm.getValue("shears").jsonObject.values.all { it.jsonObject.keys.containsAll(setOf("sheepID", "ordinal", "woolDelta", "createdAt")) })
            }
        }
        val decoded = json.decodeFromString<PrototypeState>(envelope.payload)
        validate(decoded)
        return if (schema < 4) decoded.copy(schema = 4, farm = decoded.farm.copy(schema = 2),
            session = if (schema == 1) decoded.session?.copy(farmCreditVersion = 0,
                accessUseCount = decoded.session.access.count { it.committed }) else decoded.session,
            // Historical records remain in Nights without reopening every old receipt after an update.
            acknowledgedReceipts = if (schema < 3) GuestJourney.receipts(decoded).map { it.id }.toSet() else decoded.acknowledgedReceipts) else decoded
    }
    fun validate(state: PrototypeState) {
        require(state.schema in 1..4 && state.generation >= 0 && state.scope == "localGuest")
        fun uuid(id: String) { require(UUID.fromString(id).toString().equals(id, true)) }
        fun access(grants: List<AccessInterval>, occurrence: String, start: Long, end: Long) {
            require(grants.map { it.nonce }.distinct().size == grants.size)
            grants.forEach { uuid(it.nonce); require(it.occurrence == occurrence && it.start >= start && it.start <= it.end &&
                it.end <= end && it.end - it.start <= 300_000) }
        }
        fun run(session: Session) {
            uuid(session.id)
            require(session.start < session.end && session.end - session.start in 1..if (session.mode == "windDown") 172_800_000L else 43_200_000L)
            require(session.status in setOf("scheduled", "active", "failed", "completed", "ended", "emergency", "refused"))
            require(session.mode in setOf("windDown", "phoneAway") && session.packages.isNotEmpty() && session.farmCreditVersion in 0..2)
            require(session.endedAt == null || session.endedAt in session.start..session.end)
            require(session.accessUseCount >= 0)
            access(session.access, session.id, session.start, session.end)
            session.plan?.let { p ->
                require(session.mode == "windDown" && p.bedtime <= p.wake && p.wake <= p.protectedUntil && p.protectedUntil == session.end)
                require(p.windDownMinutes in 0..180 && p.morningMinutes in 0..180)
                p.zone?.let { ZoneId.of(it) }
                p.nightKey?.let { key -> val parts = key.split('-').map(String::toInt); require(parts.size == 3); java.time.LocalDate.of(parts[0], parts[1], parts[2]) }
            }
            require(session.mode != "windDown" || session.plan != null)
        }
        state.session?.let(::run)
        require(state.mornings.map { it.id }.distinct().size == state.mornings.size)
        state.mornings.forEach { m ->
            uuid(m.id); m.linkedRun?.let(::uuid)
            require(m.end - m.start in 60_000..10_800_000 && m.packages.isNotEmpty() && m.outcome in setOf("scheduled", "active", "finished", "skipped"))
            require(m.actualStart == null || m.actualStart in m.start..m.end)
            require(m.endedAt == null || m.endedAt <= m.end)
            access(m.access, m.id, m.start, m.end)
        }
        require(state.terminalIntents.map { it.run.id }.distinct().size == state.terminalIntents.size)
        state.terminalIntents.forEach { run(it.run); require(!it.run.live && it.run.endedAt != null) }
        require(state.acknowledgedReceipts.all { id -> GuestJourney.receipts(state).any { it.id == id } })
        val farm = state.farm
        require(farm.schema in 1..2 && (state.schema < 4 || farm.schema == 2) && farm.windDownMillis in 0 until FarmSettlement.WIND_DOWN &&
            farm.phoneAwayMillis in 0 until FarmSettlement.PHONE_AWAY && farm.bonusMillis in 0 until FarmSettlement.WIND_DOWN)
        require(farm.windDownMillis + farm.bonusMillis < FarmSettlement.WIND_DOWN)
        require(farm.wool >= 0 && farm.morningPendingMinutes in 0..99)
        require(farm.consumed.all { it.start < it.end } && CreditIntervals.union(farm.consumed) == farm.consumed)
        farm.grantedNights.values.forEach(::uuid)
        farm.receipts.forEach { (id, r) ->
            uuid(id); require(r.creditedMillis >= 0 && r.excludedAccessMillis >= 0); r.outcomeIDs.forEach(::uuid)
            r.bonus?.let { require(it.policyVersion == 2 && it.result in setOf("granted", "alreadyGranted", "outsideStartWindow", "endedBeforeBedtime", "notEligible", "unknown"))
                require(it.grantedMillis == if (it.result == "granted") FarmSettlement.BONUS else 0L) }
        }
        require(farm.sheep.map { it.id }.distinct().size == farm.sheep.size && farm.outcomes.map { it.id }.distinct().size == farm.outcomes.size)
        farm.sheep.forEach { uuid(it.id); require(it.definitionID.isNotBlank() && it.regrowthRemaining >= 0 && it.timesSheared >= 0 && it.status in setOf("active", "pending", "sold")) }
        farm.outcomes.forEach { o -> uuid(o.id); uuid(o.runID); require(o.origin in setOf("windDown", "phoneBreak", "sunrise", "starter") &&
            o.number >= 0 && o.drought >= 0 && o.score in 0..100 && o.odds.isFinite() && o.odds in 0.0..1.0 && o.distance.isFinite() && o.distance >= 0) }
        farm.completedWindDowns.forEach(::uuid)
        farm.morningReceipts.forEach { (id, r) -> uuid(id); require(r.elapsedMinutes >= 0 && r.appliedMinutes in 0..r.elapsedMinutes); r.fillIDs.forEach(::uuid) }
        val welcome = farm.welcome
        require(welcome.introductionCompleted == (welcome.grant != null) && (!welcome.acknowledged || welcome.introductionCompleted))
        welcome.grant?.let { grant ->
            uuid(grant.id)
            when (grant.kind) {
                "starterSheep" -> {
                    require(grant.id == GuestFarmActions.starterID && grant.key == "starter:mabel")
                    require(farm.sheep.any { it.id == grant.id && it.definitionID == "mabel" } &&
                        farm.outcomes.any { it.id == grant.id && it.origin == "starter" && it.sheepID == "mabel" && it.createdAt == grant.createdAt })
                }
                "starterSkippedExistingFarm" -> require(grant.key == "starter:skipped-existing-farm" && farm.outcomes.none { it.origin == "starter" })
                else -> error("Unsupported welcome grant")
            }
        }
        farm.shears.forEach { (key, r) ->
            uuid(r.sheepID)
            val sheep = farm.sheep.single { it.id == r.sheepID }
            require(r.ordinal > 0 && r.ordinal <= sheep.timesSheared && key == GuestFarmActions.shearKey(r.sheepID, r.ordinal) &&
                r.woolDelta == GuestFarmActions.woolYield(sheep.rarity) && r.createdAt >= sheep.arrivedAt)
        }
        farm.sheep.forEach { sheep ->
            val records = farm.shears.values.filter { it.sheepID == sheep.id }
            require(records.size == sheep.timesSheared)
            if (records.isNotEmpty()) require(records.maxOf { it.createdAt } == sheep.lastShearedAt &&
                sheep.regrowthRemaining <= GuestFarmActions.regrowth(sheep.rarity)!!)
        }
    }
}
