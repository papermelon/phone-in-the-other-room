package com.ngawangchime.countingsheep.prototype.domain

import kotlinx.serialization.Serializable
import java.time.*

/** Saved instants and local attribution never change when the device travels or preferences change. */
@Serializable data class NightPlan(
    val bedtime: Long, val wake: Long, val protectedUntil: Long,
    val windDownMinutes: Int, val morningMinutes: Int,
    val zone: String? = null, val nightKey: String? = null
) {
    val plannedStart get() = bedtime - windDownMinutes * 60_000L
    fun phase(at: Long) = when {
        at >= protectedUntil -> "complete"
        at >= wake -> "morningQuiet"
        at >= bedtime -> "overnight"
        else -> "windDown"
    }
    fun nextTransition(at: Long) = listOf(bedtime, wake, protectedUntil).firstOrNull { it > at }
    fun beforeBedMinutes(start: Long, end: Long) = (maxOf(0, minOf(end, bedtime) - maxOf(start, plannedStart)) / 60_000).toInt()
}
@Serializable data class NightPreferences(
    val bedtimeHour: Int = 23, val bedtimeMinute: Int = 0,
    val wakeHour: Int = 7, val wakeMinute: Int = 0,
    val windDownMinutes: Int = 30, val morningMinutes: Int = 30
) {
    init {
        require(bedtimeHour in 0..23 && wakeHour in 0..23 && bedtimeMinute in 0..59 && wakeMinute in 0..59)
        require(windDownMinutes in 15..180 && morningMinutes in 15..180)
    }
    fun makePlan(at: Long, zone: ZoneId): NightPlan {
        val day = Instant.ofEpochMilli(at).atZone(zone).toLocalDate()
        val candidates = (-1L..1L).map { localTime(day.plusDays(it), bedtimeHour, bedtimeMinute, zone) }
        fun plan(bed: Long): NightPlan {
            val bedDay = Instant.ofEpochMilli(bed).atZone(zone).toLocalDate()
            var wake = localTime(bedDay, wakeHour, wakeMinute, zone)
            if (wake <= bed) wake = localTime(bedDay.plusDays(1), wakeHour, wakeMinute, zone)
            val night = Instant.ofEpochMilli(wake).atZone(zone).toLocalDate()
            return NightPlan(bed, wake, wake + morningMinutes * 60_000L, windDownMinutes, morningMinutes,
                zone.id, "${night.year}-${night.monthValue}-${night.dayOfMonth}")
        }
        return candidates.map(::plan).firstOrNull { at >= it.plannedStart && at < it.protectedUntil }
            ?: plan(candidates.firstOrNull { it >= at } ?: localTime(day.plusDays(2), bedtimeHour, bedtimeMinute, zone))
    }
}

/** Foundation Calendar .nextTime/.first: nonexistent clock times move to the gap's end; overlaps use first. */
fun localTime(day: LocalDate, hour: Int, minute: Int, zone: ZoneId): Long {
    val local = day.atTime(hour, minute)
    val offsets = zone.rules.getValidOffsets(local)
    val resolved = if (offsets.isEmpty()) zone.rules.getTransition(local).dateTimeAfter.atZone(zone)
        else ZonedDateTime.ofLocal(local, zone, offsets.first())
    return resolved.toInstant().toEpochMilli()
}
