package com.ngawangchime.countingsheep.prototype.domain

import kotlinx.serialization.Serializable
import kotlin.math.abs

@Serializable data class BonusReceipt(val result: String, val nightKey: String? = null, val grantedMillis: Long = 0, val policyVersion: Int = 2)
@Serializable data class CreditReceipt(val creditedMillis: Long, val excludedAccessMillis: Long, val trackingIncomplete: Boolean,
                                     val outcomeIDs: List<String> = emptyList(), val bonus: BonusReceipt? = null)
@Serializable data class GuestSheep(val id: String, val definitionID: String, val rarity: String, val arrivedAt: Long,
                                  val status: String = "active", val regrowthRemaining: Long = 0, val lastShearedAt: Long? = null,
                                  val timesSheared: Int = 0)
@Serializable data class MorningReceipt(val elapsedMinutes: Int, val appliedMinutes: Int, val fillIDs: List<String>)
/** Minimum local inventory and permanent economic identities. No account identity or cloud encoder. */
@Serializable data class GuestFarm(
    val schema: Int = 2, val consumed: List<Span> = emptyList(),
    val windDownMillis: Long = 0, val phoneAwayMillis: Long = 0, val bonusMillis: Long = 0,
    val grantedNights: Map<String, String> = emptyMap(), val receipts: Map<String, CreditReceipt> = emptyMap(),
    val outcomes: List<SearchOutcome> = emptyList(), val sheep: List<GuestSheep> = emptyList(),
    val wool: Int = 0, val morningPendingMinutes: Int = 0, val morningReceipts: Map<String, MorningReceipt> = emptyMap(),
    val completedWindDowns: Set<String> = emptySet(), val trackedSheepID: String? = null,
    val welcome: GuestWelcome = GuestWelcome(), val shears: Map<String, ShearReceipt> = emptyMap()
)
object FarmSettlement {
    const val WIND_DOWN = 420 * 60_000L
    const val PHONE_AWAY = 100 * 60_000L
    const val BONUS = WIND_DOWN / 5
    fun settle(farm: GuestFarm, run: Session): GuestFarm {
        if (run.id in farm.receipts || run.live || run.farmCreditVersion == 0 || run.mode == "morning") return farm
        val plannedEnd = if (run.mode == "windDown" && (run.plan?.morningMinutes ?: 0) > 0) minOf(run.end, run.plan!!.wake) else run.end
        val terminal = minOf(run.endedAt ?: return farm, plannedEnd)
        if (terminal <= run.start) return farm
        val interval = Span(run.start, terminal)
        val access = run.access.filter { it.committed }.map { Span(it.start, it.end) }
        val incomplete = run.accessUseCount > access.size
        val eligible = CreditIntervals.subtract(access, listOf(interval))
        val fresh = if (incomplete) emptyList() else CreditIntervals.subtract(farm.consumed, eligible)
        val credited = fresh.sumOf { it.duration }
        val excluded = interval.duration - eligible.sumOf { it.duration }
        val bonus = if (run.mode == "windDown" && run.farmCreditVersion == 2) bonus(run, interval, incomplete, credited > 0, farm) else null
        var next = farm.copy(consumed = CreditIntervals.union(farm.consumed + interval), sheep = farm.sheep.map { sheep ->
            val growthStart = maxOf(sheep.arrivedAt, sheep.lastShearedAt ?: sheep.arrivedAt)
            val growth = fresh.sumOf { maxOf(0, it.end - maxOf(it.start, growthStart)) }
            if (sheep.status == "active") sheep.copy(regrowthRemaining = maxOf(0, sheep.regrowthRemaining - growth)) else sheep
        }, windDownMillis = farm.windDownMillis + if (run.mode == "windDown") credited else 0,
            phoneAwayMillis = farm.phoneAwayMillis + if (run.mode == "phoneAway") credited else 0,
            bonusMillis = farm.bonusMillis + (bonus?.grantedMillis ?: 0),
            grantedNights = if (bonus?.result == "granted") farm.grantedNights + (bonus.nightKey!! to run.id) else farm.grantedNights)
        val ids = mutableListOf<String>()
        val phone = run.mode == "phoneAway"
        while ((if (phone) next.phoneAwayMillis else next.windDownMillis + next.bonusMillis) >= if (phone) PHONE_AWAY else WIND_DOWN) {
            val cumulative = next.outcomes.count { it.origin in setOf("windDown", "phoneBreak") }
            val id = SearchRules.creditID(run.id, cumulative)
            val origin = if (phone) "phoneBreak" else "windDown"
            val history = next.outcomes.filter { it.origin == origin }
            val drought = history.takeLastWhile { it.sheepID == null }.size
            val number = next.outcomes.count { it.origin == "windDown" } + 1
            val outcome = SearchRules.outcome(id, id, origin, number, history.size, drought,
                next.outcomes.mapNotNull { it.sheepID }.toSet(), terminal, next.trackedSheepID)
            next = arrival(next.copy(outcomes = next.outcomes + outcome), outcome)
            ids += id
            if (phone) next = next.copy(phoneAwayMillis = next.phoneAwayMillis - PHONE_AWAY)
            else { val time = minOf(next.windDownMillis, WIND_DOWN)
                next = next.copy(windDownMillis = next.windDownMillis - time, bonusMillis = next.bonusMillis - (WIND_DOWN - time)) }
        }
        val spanStart = maxOf(run.start, run.plan?.plannedStart ?: run.start)
        val completed = run.mode == "windDown" && !run.interruption &&
            (run.endedAt!! - spanStart) / 60_000 >= 420 && run.status in setOf("completed", "ended", "emergency")
        return next.copy(receipts = next.receipts + (run.id to CreditReceipt(credited, excluded, incomplete, ids, bonus)),
            completedWindDowns = if (completed) next.completedWindDowns + run.id else next.completedWindDowns)
    }
    private fun bonus(run: Session, span: Span, incomplete: Boolean, fresh: Boolean, farm: GuestFarm): BonusReceipt {
        val plan = run.plan ?: return BonusReceipt("notEligible")
        if (plan.windDownMinutes <= 0) return BonusReceipt("notEligible")
        if (plan.nightKey == null || plan.zone == null || runCatching { java.time.ZoneId.of(plan.zone) }.isFailure || run.interruption || incomplete) return BonusReceipt("unknown")
        if (plan.nightKey in farm.grantedNights) return BonusReceipt("alreadyGranted", plan.nightKey)
        if (run.start >= plan.bedtime || abs(run.start - plan.plannedStart) > 900_000) return BonusReceipt("outsideStartWindow", plan.nightKey)
        if (span.end < plan.bedtime) return BonusReceipt("endedBeforeBedtime", plan.nightKey)
        if (!fresh) return BonusReceipt("unknown", plan.nightKey)
        return BonusReceipt("granted", plan.nightKey, BONUS)
    }
    fun morning(farm: GuestFarm, occurrence: MorningOccurrence): GuestFarm {
        if (occurrence.id in farm.morningReceipts || occurrence.live || occurrence.outcome == "skipped") return farm
        val elapsed = occurrence.elapsedMinutes(occurrence.endedAt ?: occurrence.end)
        val applied = if (elapsed >= 15) elapsed else 0
        var next = farm.copy(morningPendingMinutes = farm.morningPendingMinutes + applied)
        val ids = mutableListOf<String>()
        while (next.morningPendingMinutes >= 100) {
            val history = next.outcomes.filter { it.origin == "sunrise" }
            val id = SearchRules.sunriseID(occurrence.id, history.size + 1)
            val outcome = SearchRules.outcome(id, occurrence.id, "sunrise", next.completedWindDowns.size,
                history.size, history.takeLastWhile { it.sheepID == null }.size, history.mapNotNull { it.sheepID }.toSet(),
                occurrence.endedAt ?: occurrence.end, next.trackedSheepID)
            next = arrival(next.copy(morningPendingMinutes = next.morningPendingMinutes - 100, wool = next.wool + 1,
                outcomes = next.outcomes + outcome), outcome)
            ids += id
        }
        return next.copy(morningReceipts = next.morningReceipts + (occurrence.id to MorningReceipt(elapsed, applied, ids)))
    }
    private fun arrival(farm: GuestFarm, outcome: SearchOutcome): GuestFarm {
        val definition = SearchRules.catalog.firstOrNull { it.id == outcome.sheepID } ?: return farm
        if (farm.sheep.any { it.id == outcome.id }) return farm
        return farm.copy(sheep = farm.sheep + GuestSheep(outcome.id, definition.id, definition.rarity, outcome.createdAt,
            status = if (farm.sheep.count { it.status == "active" } < 12) "active" else "pending"),
            trackedSheepID = farm.trackedSheepID.takeUnless { it == definition.id })
    }
}
