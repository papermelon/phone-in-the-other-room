package com.ngawangchime.countingsheep.prototype.data

import kotlinx.serialization.json.*

/** Lossless wire tree; no permissive Farm-domain decoder, migration or upload transport. */
class FarmPayloadCodec private constructor(val value: JsonObject) {
    fun encode(): String = value.toString()
    companion object {
        fun decode(raw: String): FarmPayloadCodec = try {
            require(raw.toByteArray().size <= 5_000_000) { "Fixture size limit" }
            rejectDuplicateKeys(raw)
            val value = Json.parseToJsonElement(raw)
            FarmWireSchema.payload(value)
            val farm = value.jsonObject.getValue("farm").jsonObject
            val owned = farm.getValue("ownedShopItemIDs").jsonArray.map { it.jsonPrimitive.content }
            require(owned == owned.distinct().sorted()) { "Swift would normalize inventory" }
            require(farm.getValue("transactions").jsonArray.size <= 256) { "Swift would prune transactions" }
            require(value.jsonObject.getValue("search").jsonObject.getValue("trailMap").jsonObject
                .getValue("creditedAdHocRunIDs").jsonArray.size <= 128) { "Swift would prune run IDs" }
            FarmPayloadCodec(value.jsonObject)
        } catch (error: Exception) {
            throw IllegalArgumentException("Incompatible Farm wire payload; retain original bytes", error)
        }
        internal fun rejectDuplicateKeys(raw: String) {
            val stack = mutableListOf<MutableSet<String>?>()
            var i = 0
            while (i < raw.length) {
                when (raw[i]) {
                    '{' -> { require(stack.size < 64); stack.add(mutableSetOf()) }
                    '[' -> { require(stack.size < 64); stack.add(null) }
                    '}', ']' -> stack.removeAt(stack.lastIndex)
                    '"' -> {
                        val start = i++
                        while (raw[i] != '"') { if (raw[i] == '\\') i++; i++ }
                        val end = i + 1
                        var next = end
                        while (next < raw.length && raw[next].isWhitespace()) next++
                        if (next < raw.length && raw[next] == ':') {
                            val key = Json.decodeFromString<String>(raw.substring(start, end))
                            require(stack.last()!!.add(key)) { "Duplicate JSON key" }
                        }
                    }
                }
                i++
            }
        }
    }
}
