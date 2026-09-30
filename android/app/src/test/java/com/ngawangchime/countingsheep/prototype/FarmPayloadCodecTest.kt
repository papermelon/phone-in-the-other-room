package com.ngawangchime.countingsheep.prototype

import com.ngawangchime.countingsheep.prototype.data.FarmPayloadCodec
import com.ngawangchime.countingsheep.prototype.data.FarmWireSchema
import kotlinx.serialization.json.*
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.util.UUID

class FarmPayloadCodecTest {
    private val fixtures = File(requireNotNull(System.getProperty("fixtureDir")))
    private val exchange = File(requireNotNull(System.getProperty("exchangeDir"))).apply { mkdirs() }
    private fun edit(root: JsonObject, key: String, value: JsonElement): JsonObject = JsonObject(root + (key to value))
    private fun editFarm(root: JsonObject, key: String, value: JsonElement): JsonObject = edit(root, "farm", edit(root.getValue("farm").jsonObject, key, value))
    private fun id(n: Int) = "00000000-0000-4000-8000-${n.toString().padStart(12, '0')}"

    @Test fun swiftCorpusRoundTripsLosslesslyAndExportsKotlinOrigin() {
        val inputs = fixtures.listFiles()!!.filter { it.name.startsWith("farm-") }.sortedBy { it.name }
        assertEquals(8, inputs.size)
        inputs.forEach { source ->
            val payload = FarmPayloadCodec.decode(source.readText())
            val roundTrip = FarmPayloadCodec.decode(payload.encode())
            assertEquals(payload.value, roundTrip.value)
            File(exchange, source.name).writeText(roundTrip.encode())
            val farm = payload.value.getValue("farm").jsonObject
            assertEquals(137, farm.getValue("woolBalance").jsonPrimitive.int)
            assertEquals("future_sheep_catalog_id", farm.getValue("sheep").jsonArray[0].jsonObject.getValue("definitionID").jsonPrimitive.content)
            assertEquals(123.25, farm.getValue("cumulativeCredit").jsonObject.getValue("consumedIntervals").jsonArray[0].jsonObject.getValue("duration").jsonPrimitive.double, 0.0)
            assertEquals(810_892_923.456, FarmWireSchema.referenceSeconds(farm.getValue("sheep").jsonArray[0].jsonObject.getValue("arrivedAt")), 0.001)
        }
        val original = FarmPayloadCodec.decode(File(fixtures, "farm-v4-rich-numeric.json").readText()).value
        var kotlin = edit(editFarm(original, "woolBalance", JsonPrimitive(201)), "lineageID", JsonPrimitive(id(700)))
        val farm = kotlin.getValue("farm").jsonObject
        val sheep = farm.getValue("sheep").jsonArray.map { edit(edit(it.jsonObject, "id", JsonPrimitive(id(701))), "arrivedAt", JsonPrimitive(810000123.125)) }
        kotlin = editFarm(kotlin, "sheep", JsonArray(sheep))
        kotlin = editFarm(kotlin, "fetchPracticeBest", JsonPrimitive(15))
        kotlin = editFarm(kotlin, "equipment", edit(farm.getValue("equipment").jsonObject, "fetchBallItemID", JsonPrimitive("kotlin_unknown_ball")))
        File(exchange, "kotlin-origin.json").writeText(FarmPayloadCodec.decode(kotlin.toString()).encode())
        val manifest = Json.parseToJsonElement(File(fixtures, "manifest.json").readText()).jsonObject
        UUID.fromString(manifest.getValue("ownerID").jsonPrimitive.content)
        File(exchange, "kotlin-owner.json").writeText(JsonObject(mapOf("ownerID" to manifest.getValue("ownerID"))).toString())
        if (System.getProperty("verifySwift") == "true") {
            val returned = FarmPayloadCodec.decode(File(exchange, "swift-return.json").readText())
            assertSemantic(kotlin, returned.value)
        }
    }
    private fun assertSemantic(expected: JsonElement, actual: JsonElement, path: String = "root") {
        when (expected) {
            is JsonObject -> {
                assertEquals(path, expected.keys, actual.jsonObject.keys)
                expected.forEach { (key, value) -> assertSemantic(value, actual.jsonObject.getValue(key), "$path/$key") }
            }
            is JsonArray -> {
                val right = actual.jsonArray
                assertEquals(path, expected.size, right.size)
                if (path.endsWith("/receipts") || path.endsWith("/decorationPlacements") || path.endsWith("/collectiblePlacements")) {
                    fun pairs(array: JsonArray) = array.chunked(2).associate { it[0].jsonPrimitive.content to it[1] }
                    val leftPairs = pairs(expected); val rightPairs = pairs(right)
                    assertEquals(leftPairs.keys, rightPairs.keys)
                    leftPairs.forEach { (key, value) -> assertSemantic(value, rightPairs.getValue(key), "$path/$key") }
                } else expected.indices.forEach { assertSemantic(expected[it], right[it], "$path/$it") }
            }
            is JsonPrimitive -> {
                if (!expected.isString && expected.content.toBigDecimalOrNull() != null) {
                    assertEquals(path, 0, expected.content.toBigDecimal().compareTo(actual.jsonPrimitive.content.toBigDecimal()))
                } else assertEquals(path, expected, actual)
            }
        }
    }
    @Test fun incompatiblePayloadsCannotProduceAnEncodedUploadCandidate() {
        val root = FarmPayloadCodec.decode(File(fixtures, "farm-v4-rich-numeric.json").readText()).value
        val farm = root.getValue("farm").jsonObject
        val bad = linkedMapOf<String, JsonObject>()
        bad["wire-version"] = edit(root, "schemaVersion", JsonPrimitive(2))
        bad["economy-version"] = edit(root, "economyVersion", JsonPrimitive(2))
        bad["farm-version"] = editFarm(root, "schemaVersion", JsonPrimitive(5))
        for (key in listOf("search", "welcome", "socialRewards", "sunrise")) {
            bad["$key-version"] = edit(root, key, edit(root.getValue(key).jsonObject, "schemaVersion", JsonPrimitive(99)))
        }
        bad["legacy-farm"] = editFarm(root, "schemaVersion", JsonPrimitive(2))
        bad["unknown-root"] = edit(root, "localValues", JsonObject(emptyMap()))
        bad["unknown-nested"] = editFarm(root, "futureBalance", JsonPrimitive(999))
        bad["missing-ledger"] = JsonObject(root - "socialRewards")
        bad["missing-balance"] = edit(root, "farm", JsonObject(farm - "woolBalance"))
        bad["negative-balance"] = editFarm(root, "woolBalance", JsonPrimitive(-1))
        bad["overflow-balance"] = editFarm(root, "woolBalance", Json.parseToJsonElement("9223372036854775808"))
        bad["fractional-balance"] = editFarm(root, "woolBalance", JsonPrimitive(1.5))
        bad["quoted-balance"] = editFarm(root, "woolBalance", JsonPrimitive("1"))
        bad["invalid-fetch"] = editFarm(root, "fetchPracticeBest", JsonPrimitive(16))
        bad["null-optional"] = editFarm(root, "fetchPracticeBest", JsonNull)
        bad["duplicate-inventory"] = editFarm(root, "ownedShopItemIDs", JsonArray(listOf(JsonPrimitive("x"), JsonPrimitive("x"))))
        bad["bad-uuid"] = edit(root, "lineageID", JsonPrimitive("not-owner"))
        for (date in listOf("2026-02-30T08:02:03.456", "2026-09-12T08:02:03.456garbage", "2026-09-12T08:02:03+08:00")) {
            val sheep = farm.getValue("sheep").jsonArray.map { edit(it.jsonObject, "arrivedAt", JsonPrimitive(date)) }
            bad["bad-date-${bad.size}"] = editFarm(root, "sheep", JsonArray(sheep))
        }
        bad.forEach { (name, payload) ->
            try { FarmPayloadCodec.decode(payload.toString()).encode(); fail("Accepted $name") } catch (_: IllegalArgumentException) { }
            File(exchange, "rejected-$name.json").writeText(payload.toString())
        }
        val duplicate = root.toString().replaceFirst("\"schemaVersion\":1", "\"schemaVersion\":1,\"schemaVersion\":1")
        assertThrows(IllegalArgumentException::class.java) { FarmPayloadCodec.decode(duplicate) }
        assertThrows(IllegalArgumentException::class.java) { FarmPayloadCodec.decode("{broken") }
        assertThrows(IllegalArgumentException::class.java) { FarmPayloadCodec.decode("[".repeat(65) + "0" + "]".repeat(65)) }
        val scientific = farm.getValue("sheep").jsonArray[0].jsonObject.getValue("arrivedAt")
        assertTrue(FarmWireSchema.referenceSeconds(scientific).isFinite())
    }
}
