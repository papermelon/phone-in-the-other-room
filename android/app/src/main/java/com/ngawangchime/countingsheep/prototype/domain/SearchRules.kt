package com.ngawangchime.countingsheep.prototype.domain

import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable data class SearchOutcome(
    val id: String, val runID: String, val origin: String, val number: Int, val sheepID: String?,
    val rarity: String?, val habitat: String?, val score: Int, val odds: Double,
    val distance: Double, val drought: Int, val createdAt: Long
)
data class CatalogSheep(val id: String, val rarity: String, val habitat: String, val arrival: Int) {
    val rank get() = listOf("common", "uncommon", "rare", "legendary").indexOf(rarity)
}
object SearchRules {
    val catalog = listOf(
        CatalogSheep("mabel", "common", "starterPasture", 1), CatalogSheep("pippin", "common", "starterPasture", 1),
        CatalogSheep("bramble", "common", "starterPasture", 1), CatalogSheep("clementine", "common", "sunriseHill", 1),
        CatalogSheep("oat", "common", "storybookBarn", 1), CatalogSheep("midnight", "uncommon", "moonMeadow", 6),
        CatalogSheep("juniper", "uncommon", "fenceLine", 4), CatalogSheep("hazel", "uncommon", "sunflowerField", 7),
        CatalogSheep("ramsey", "uncommon", "farField", 8), CatalogSheep("luna", "rare", "moonMeadow", 10),
        CatalogSheep("marigold", "rare", "sunriseHill", 14), CatalogSheep("wisp", "legendary", "highMoor", 25))
    fun seed(id: String, number: Int): Long = id.uppercase().fold(number * 1_000_003L) { value, c -> value * 31 + c.code }
    fun fnv(value: String, seed: Long = 0xcbf29ce484222325UL.toLong()) = value.toByteArray().fold(seed) { hash, byte ->
        (hash xor (byte.toLong() and 255)) * 0x100000001b3L
    }
    private fun uuid(bytes: List<Int>): String {
        val hex = bytes.joinToString("") { "%02x".format(it) }
        return "${hex.take(8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}".uppercase()
    }
    fun creditID(run: String, ordinal: Int): String {
        val text = "legacy:cumulative:${run.uppercase()}:$ordinal"
        val high = fnv(text); val low = fnv("farm:$text")
        return uuid((0..7).map { ((high ushr (it * 8)) and 255).toInt() } + (0..7).map { ((low ushr (it * 8)) and 255).toInt() })
    }
    fun morningID(run: String): String {
        for (counter in 0..3) {
            val text = "ollie.morning-occurrence.v1.$counter:${run.lowercase()}"
            val hex = "%016x%016x".format(fnv(text), fnv(text, 0x9e3779b97f4a7c15UL.toLong())).toCharArray()
            hex[12] = '4'; hex[16] = "89ab"[hex[16].digitToInt(16) and 3]
            val result = uuid(String(hex).chunked(2).map { it.toInt(16) })
            if (!result.equals(run, true)) return result
        }
        val source = UUID.fromString(run)
        return UUID(source.mostSignificantBits xor (1L shl 56), source.leastSignificantBits).toString().uppercase()
    }
    fun sunriseID(run: String, index: Int): String {
        var seed = seed(run, index) xor 0x53554E5249534554L
        val bytes = (0..15).map { seed = seed * 6_364_136_223_846_793_005L + 1; (seed ushr 56).toInt() }.toMutableList()
        bytes[6] = (bytes[6] and 15) or 64; bytes[8] = (bytes[8] and 63) or 128
        return uuid(bytes)
    }
    fun outcome(id: String, run: String, origin: String, number: Int, count: Int, drought: Int,
                found: Set<String>, at: Long, tracked: String? = null): SearchOutcome {
        val guaranteed = count < 3 || drought >= 4
        val odds = if (guaranteed) 1.0 else if (origin == "windDown") minOf(0.92, 0.20 + minOf(drought, 4) * 0.08)
            else listOf(0.20, 0.30, 0.40, 0.50)[drought.coerceIn(0, 3)]
        var seed = seed(if (origin == "sunrise") run else id, if (origin == "sunrise") count + 1 else number)
        seed = seed xor when (origin) { "phoneBreak" -> 0x50484F4E4542524BL; "sunrise" -> 0x53554E5249534554L; else -> 0 }
        if (seed == 0L) seed = 0xA5A5A5A5A5A5A5A5UL.toLong()
        fun random(): Double { seed = seed * 6_364_136_223_846_793_005L + 1; return (seed ushr 11).toDouble() / (1L shl 53).toDouble() }
        val shouldFind = guaranteed || random() < odds
        val all = catalog.filter { it.arrival <= maxOf(1, number) }
        val candidates = all.filter { it.id !in found }.ifEmpty { all }
        val score = if (origin == "windDown") 0 else 50
        val weights = candidates.map { maxOf(0.08, 1 - it.rank * 0.28 + score / 100.0 * it.rank * 0.32) * if (it.id == tracked) 3 else 1 }
        val sheep = if (shouldFind && candidates.isNotEmpty()) {
            var cursor = random() * weights.sum()
            candidates.indices.firstOrNull { cursor -= weights[it]; cursor <= 0 }?.let { candidates[it] } ?: candidates.last()
        } else null
        return SearchOutcome(id, run, origin, number, sheep?.id, sheep?.rarity, sheep?.habitat, score, odds,
            if (origin == "windDown") 0.1 else 1.0, drought, at)
    }
}
