package com.ngawangchime.countingsheep.prototype.domain

import java.text.Normalizer
import java.time.ZoneId
import java.util.Locale

/** Read-only projections of the coordinator's durable state, not another session machine. */
data class GuestReceipt(val id: String, val run: Session? = null, val morning: MorningOccurrence? = null, val ready: Boolean) {
    val at get() = run?.endedAt ?: morning?.endedAt ?: 0
    val title get() = if (morning != null) "Screen-Free Morning" else if (run?.mode == "windDown") "Wind Down" else "Phone Away"
}
data class GuestChallenge(val id: String, val occurrence: String, val action: String, val phrase: String, val createdAt: Long)

object GuestJourney {
    val phoneAwayMinutes = listOf(5, 10, 15, 20, 25, 30)
    fun receipts(state: PrototypeState): List<GuestReceipt> =
        (state.terminalIntents.map { GuestReceipt(it.run.id, run = it.run, ready = it.settled) } +
            state.mornings.filterNot { it.live }.map { GuestReceipt(it.id, morning = it,
                ready = it.outcome == "skipped" || it.id in state.farm.morningReceipts) }).sortedByDescending { it.at }
    fun pendingReceipt(state: PrototypeState): GuestReceipt? = if (state.session?.live == true || state.mornings.any { it.outcome == "active" }) null
        else receipts(state).filter { it.ready && it.id !in state.acknowledgedReceipts }
            .minWithOrNull(compareBy<GuestReceipt> { it.at }.thenBy { if (it.run != null) 0 else 1 })
    fun prefersWindDown(state: PrototypeState, at: Long, zone: ZoneId): Boolean = state.nightPreferences?.makePlan(at, zone)?.let {
        at >= it.plannedStart || it.plannedStart < at + 1_800_000
    } ?: false
    fun phrase(state: PrototypeState, occurrence: String, action: String, at: Long): String? {
        val run = state.session?.takeIf { it.id == occurrence && it.live }
        val morning = state.mornings.firstOrNull { it.id == occurrence && it.outcome == "active" }
        if (run == null && morning == null) return null
        if (action in setOf("startNow", "defer", "skip")) {
            if (run?.mode != "windDown" || run.phase(at) != "overnight") return null
            return when (action) { "startNow" -> "Start my morning"; "defer" -> "Start my morning at the usual time"; else -> "Skip my morning today" }
        }
        if (action !in setOf("access", "end")) return null
        return if (run?.phase(at) == "overnight") "Put my phone away for sleep" else "Put my phone away"
    }
    fun normalized(text: String): String = Normalizer.normalize(text, Normalizer.Form.NFKC).lowercase(Locale.ROOT)
        .replace(Regex("\\p{P}"), "").replace(Regex("[\\p{Z}\\s\\u0085]+"), " ").trim()
    fun matches(entry: String, phrase: String) = normalized(phrase).isNotEmpty() && normalized(entry) == normalized(phrase)
}
