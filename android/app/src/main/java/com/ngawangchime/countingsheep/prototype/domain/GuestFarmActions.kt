package com.ngawangchime.countingsheep.prototype.domain

import kotlinx.serialization.Serializable

@Serializable data class StarterGrant(val id: String, val kind: String, val key: String, val createdAt: Long)
@Serializable data class GuestWelcome(val introductionCompleted: Boolean = false, val acknowledged: Boolean = false,
                                     val grant: StarterGrant? = null)
@Serializable data class ShearReceipt(val sheepID: String, val ordinal: Int, val woolDelta: Int, val createdAt: Long)

/** Current Swift starter and cumulative-credit shearing rules, inside the existing guest transaction. */
object GuestFarmActions {
    val starterID: String = run {
        val key = "starter:mabel"
        val bytes = listOf(SearchRules.fnv(key), SearchRules.fnv("welcome:$key")).flatMap { hash ->
            (0..7).map { "%02x".format((hash ushr (it * 8)) and 255) }
        }.joinToString("")
        "${bytes.take(8)}-${bytes.substring(8, 12)}-${bytes.substring(12, 16)}-${bytes.substring(16, 20)}-${bytes.substring(20)}".uppercase()
    }
    fun welcome(farm: GuestFarm, at: Long, skippedID: String): GuestFarm {
        if (farm.welcome.introductionCompleted) return farm
        val starter = farm.outcomes.firstOrNull { it.origin == "starter" }
        val existing = starter == null && (farm.sheep.isNotEmpty() || farm.outcomes.any { it.origin in setOf("windDown", "phoneBreak") || it.sheepID != null })
        val grant = if (existing) StarterGrant(skippedID, "starterSkippedExistingFarm", "starter:skipped-existing-farm", at)
            else StarterGrant(starter?.id ?: starterID, "starterSheep", "starter:mabel", starter?.createdAt ?: at)
        if (existing) return farm.copy(welcome = GuestWelcome(true, grant = grant))
        val outcome = starter ?: SearchOutcome(starterID, starterID, "starter", 0, "mabel", "common", "starterPasture", 0, 1.0, 0.0, 0, at)
        return farm.copy(welcome = GuestWelcome(true, grant = grant),
            outcomes = if (starter == null) farm.outcomes + outcome else farm.outcomes,
            sheep = if (farm.sheep.any { it.id == outcome.id }) farm.sheep else farm.sheep + GuestSheep(outcome.id, "mabel", "common", outcome.createdAt))
    }
    fun woolYield(rarity: String): Int? = when (rarity) { "common" -> 1; "uncommon" -> 2; "rare" -> 4; "legendary" -> 7; else -> null }
    fun regrowth(rarity: String): Long? = when (rarity) { "common" -> 2; "uncommon" -> 3; "rare" -> 4; "legendary" -> 5; else -> null }?.times(FarmSettlement.WIND_DOWN)
    fun woolState(sheep: GuestSheep) = if (sheep.regrowthRemaining == 0L) "wool_ready"
        else if (sheep.regrowthRemaining == regrowth(sheep.rarity)) "shorn" else "regrowing"
    fun shearKey(sheepID: String, ordinal: Int) = "shear:${sheepID.uppercase()}:$ordinal"
    fun shear(farm: GuestFarm, sheepID: String, ordinal: Int, at: Long): GuestFarm? {
        val key = shearKey(sheepID, ordinal)
        if (key in farm.shears) return farm
        val sheep = farm.sheep.firstOrNull { it.id == sheepID } ?: return null
        val yield = woolYield(sheep.rarity) ?: return null
        val growth = regrowth(sheep.rarity) ?: return null
        if (sheep.status != "active" || sheep.regrowthRemaining != 0L || sheep.timesSheared == Int.MAX_VALUE ||
            ordinal != sheep.timesSheared + 1 || at < maxOf(sheep.arrivedAt, sheep.lastShearedAt ?: sheep.arrivedAt) || farm.wool > Int.MAX_VALUE - yield) return null
        return farm.copy(wool = farm.wool + yield,
            sheep = farm.sheep.map { if (it.id == sheepID) it.copy(regrowthRemaining = growth, lastShearedAt = at, timesSheared = ordinal) else it },
            shears = farm.shears + (key to ShearReceipt(sheepID, ordinal, yield, at)))
    }
}
