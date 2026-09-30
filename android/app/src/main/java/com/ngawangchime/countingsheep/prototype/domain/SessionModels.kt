package com.ngawangchime.countingsheep.prototype.domain

import kotlinx.serialization.Serializable

@Serializable data class ClockSample(val wall: Long, val elapsed: Long, val boot: Int)
@Serializable data class Span(val start: Long, val end: Long) { val duration get() = maxOf(0, end - start) }
@Serializable data class AccessInterval(val nonce: String, val occurrence: String, val start: Long, val end: Long, val committed: Boolean = false)
@Serializable data class Session(
    val id: String, val start: Long, val end: Long, val packages: Set<String>,
    val status: String = "scheduled", val access: List<AccessInterval> = emptyList(),
    val endedAt: Long? = null, val observedAt: Long? = null,
    val alarmRegistered: Boolean = false, val coverage: String = "Unknown; no blocker observed",
    val mode: String = "phoneAway", val plan: NightPlan? = null,
    // Prototype v1 never promised rewards. Migration must not invent historical credit/bonuses.
    val farmCreditVersion: Int = 0, val accessUseCount: Int = 0, val interruption: Boolean = false,
    val requestedProtection: Boolean = true
) {
    val live get() = status in setOf("active", "scheduled")
    fun remaining(at: Long) = if (live) maxOf(0, end - at) else 0L
    fun phase(at: Long) = plan?.phase(at) ?: if (at >= end) "complete" else "phoneAway"
}
@Serializable data class MorningOccurrence(
    val id: String, val linkedRun: String? = null, val start: Long, val end: Long,
    val packages: Set<String>, val actualStart: Long? = null, val endedAt: Long? = null,
    val outcome: String = "scheduled", val access: List<AccessInterval> = emptyList(),
    val observedAt: Long? = null, val coverage: String = "Unknown; no blocker observed"
) {
    val live get() = outcome in setOf("scheduled", "active")
    fun elapsedMinutes(at: Long): Int = actualStart?.let {
        minOf(((end - start) / 60_000).toInt(), (maxOf(0, minOf(endedAt ?: at, end) - it) / 60_000).toInt())
    } ?: 0
    fun finalized(at: Long) = if (at < start) copy(outcome = "skipped", endedAt = at)
        else copy(outcome = "finished", actualStart = actualStart ?: start, endedAt = at.coerceIn(start, end))
}
@Serializable data class TerminalIntent(val run: Session, val settled: Boolean = false)
@Serializable data class PrototypeState(
    val schema: Int = 4, val generation: Long = 0, val consent: Boolean? = null,
    val selection: Set<String> = emptySet(), val session: Session? = null,
    val repairRequired: Boolean = false, val failure: String? = null, val clock: ClockSample? = null,
    val scope: String = "localGuest", val farm: GuestFarm = GuestFarm(),
    val mornings: List<MorningOccurrence> = emptyList(), val terminalIntents: List<TerminalIntent> = emptyList(),
    val nightPreferences: NightPreferences? = null, val acknowledgedReceipts: Set<String> = emptySet()
)

object CreditIntervals {
    fun union(spans: List<Span>): List<Span> {
        val result = mutableListOf<Span>()
        for (span in spans.filter { it.duration > 0 }.sortedBy { it.start }) {
            val last = result.lastOrNull()
            if (last != null && span.start <= last.end) result[result.lastIndex] = Span(last.start, maxOf(last.end, span.end))
            else result += span
        }
        return result
    }
    fun subtract(exclusions: List<Span>, spans: List<Span>): List<Span> {
        var result = union(spans)
        for (excluded in union(exclusions)) result = result.flatMap { span ->
            if (excluded.start >= span.end || excluded.end <= span.start) listOf(span)
            else listOfNotNull(if (excluded.start > span.start) Span(span.start, excluded.start) else null,
                if (excluded.end < span.end) Span(excluded.end, span.end) else null)
        }
        return result
    }
}
