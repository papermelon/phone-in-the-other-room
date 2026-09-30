package com.ngawangchime.countingsheep.prototype.data

import kotlinx.serialization.json.*
import java.time.LocalDateTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.UUID

private typealias Rule = (JsonElement) -> Unit

/** Snapshot of current Swift wire shapes, not Farm economy or local migration code. */
internal object FarmWireSchema {
    private val text: Rule = { require(it is JsonPrimitive && it.isString) }
    private val uuid: Rule = { text(it); require(Regex("[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}").matches(it.jsonPrimitive.content)); UUID.fromString(it.jsonPrimitive.content) }
    private val bool: Rule = { require(it is JsonPrimitive && !it.isString && it.booleanOrNull != null) }
    private val number: Rule = { require(it is JsonPrimitive && !it.isString && it.doubleOrNull?.isFinite() == true) }
    private fun integer(min: Long = Long.MIN_VALUE, max: Long = Long.MAX_VALUE): Rule = {
        require(it is JsonPrimitive && !it.isString && it.longOrNull?.let { n -> n in min..max } == true)
    }
    private val nonnegative = integer(0)
    private fun choice(vararg choices: String): Rule = { text(it); require(it.jsonPrimitive.content in choices) }
    private fun array(rule: Rule): Rule = { require(it is JsonArray); it.forEach(rule) }
    private fun record(required: Map<String, Rule>, optional: Map<String, Rule> = emptyMap()): Rule = {
        require(it is JsonObject)
        require(it.keys.containsAll(required.keys) && (it.keys - required.keys - optional.keys).isEmpty())
        it.forEach { (key, value) -> (required[key] ?: optional.getValue(key))(value) }
    }
    private fun dictionary(value: Rule): Rule = { require(it is JsonObject); it.values.forEach(value) }
    private val date: Rule = { referenceSeconds(it) }
    fun referenceSeconds(value: JsonElement): Double {
        val primitive = value.jsonPrimitive
        if (!primitive.isString) {
            val seconds = primitive.doubleOrNull ?: error("Invalid numeric Date")
            require(seconds.isFinite() && seconds >= -63_113_904_000 && seconds <= 252_423_993_599)
            return seconds
        }
        val raw = primitive.content
        require(Regex("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]{3})?Z?").matches(raw))
        val local = LocalDateTime.parse(raw.removeSuffix("Z"), DateTimeFormatter.ISO_LOCAL_DATE_TIME)
        return local.toEpochSecond(ZoneOffset.UTC) - 978_307_200.0 + local.nano / 1_000_000_000.0
    }
    private val rarity = choice("common", "uncommon", "rare", "legendary")
    private val outcome = record(mapOf("id" to uuid, "runID" to uuid,
        "origin" to choice("windDown", "phoneBreak", "sunrise", "starter", "onboardingPractice", "slumberParty", "unspecified"),
        "protectedNightNumber" to nonnegative, "result" to choice("found", "trailOnly"),
        "trailStrength" to integer(), "encounterOdds" to number, "trailDistance" to number,
        "consecutiveNoFinds" to integer(), "bonusPoints" to integer(), "trailMapBonusPercentagePoints" to nonnegative,
        "createdAt" to date), mapOf("sheepID" to text, "rarity" to rarity,
        "habitat" to choice("starterPasture", "fenceLine", "farField", "moonMeadow", "sunriseHill", "storybookBarn", "sunflowerField", "highMoor")))
    private val bonusReceipt = record(mapOf("result" to choice("granted", "alreadyGranted", "outsideStartWindow", "endedBeforeBedtime", "notEligible", "unknown"),
        "grantedSearchSeconds" to number, "policyVersion" to integer(2, 2)), mapOf("nightKey" to text))
    private val creditReceipt = record(mapOf("creditedSeconds" to number, "excludedAccessSeconds" to number,
        "trackingIncomplete" to bool, "migrated" to bool, "outcomeIDs" to array(uuid)), mapOf("bedtimeBonus" to bonusReceipt))
    private val receipts: Rule = {
        require(it is JsonArray && it.size % 2 == 0)
        val keys = mutableSetOf<String>()
        it.chunked(2).forEach { pair -> uuid(pair[0]); require(keys.add(pair[0].jsonPrimitive.content.uppercase())); creditReceipt(pair[1]) }
    }
    private val credit = record(mapOf("migrationCompleted" to { require(it == JsonPrimitive(true)) },
        "consumedIntervals" to array(record(mapOf("start" to date, "duration" to number))),
        "windDownSeconds" to number, "phoneAwaySeconds" to number, "receipts" to receipts, "outcomes" to array(outcome)),
        mapOf("bedtimeBonus" to record(mapOf("remainingSearchSeconds" to { number(it); require(it.jsonPrimitive.double in 0.0..<25_200.0) },
            "grantedNights" to dictionary(uuid)))))
    private val sheep = record(mapOf("id" to uuid, "definitionID" to text, "displayName" to text, "arrivedAt" to date,
        "protectedNightNumber" to nonnegative, "rarity" to rarity, "isFavorite" to bool, "timesSheared" to nonnegative,
        "status" to choice("active", "pending", "sold"), "equippedCosmeticIDs" to array(text)),
        mapOf("sourceOutcomeID" to uuid, "sourceRunID" to uuid, "lastShearedProtectedNight" to integer(), "regrowthSecondsRemaining" to number))
    private val transaction = record(mapOf("id" to uuid, "idempotencyKey" to text,
        "kind" to choice("arrival", "shearing", "sale", "purchase", "capacityUpgrade", "currencyConsolidation", "starterGrant", "welcomeGift", "onboardingPracticeArrival", "slumberPartyGrant", "sunriseTrail"),
        "woolDelta" to integer(), "createdAt" to date), mapOf("sheepID" to uuid, "itemID" to text, "legacyCashDelta" to integer()))
    // Swift enum-keyed dictionaries are alternating arrays, not JSON maps.
    private fun enumPairs(keys: Set<String>): Rule = {
        require(it is JsonArray && it.size % 2 == 0)
        val seen = mutableSetOf<String>()
        it.chunked(2).forEach { pair -> text(pair[0]); require(pair[0].jsonPrimitive.content in keys && seen.add(pair[0].jsonPrimitive.content)); text(pair[1]) }
    }
    private val equipment = record(mapOf(
        "decorationPlacements" to enumPairs(setOf("leftMeadow", "rightMeadow", "centerHorizon", "leftFence", "waterEdge", "barnCorner")),
        "collectiblePlacements" to enumPairs(setOf("left", "centerLeft", "centerRight", "right"))),
        mapOf("ollieAccessoryItemID" to text, "ollieCoatID" to text, "fetchBallItemID" to text))
    private val shepherd = record(mapOf("skinTone" to choice("porcelain", "warm", "olive", "brown", "deep"),
        "hairStyle" to choice("cropped", "waves", "curls", "coils", "long")),
        mapOf("outfitItemID" to text, "shirtItemID" to text, "accessoryItemID" to text, "headShapeID" to text))
    private val farm = record(mapOf("schemaVersion" to integer(3, 4), "sheep" to array(sheep),
        "discoveries" to array(record(mapOf("definitionID" to text, "firstDiscoveredAt" to date,
            "encounterCount" to integer(), "outcomeIDs" to array(uuid), "highestRarity" to rarity))),
        "barnCapacityLevel" to integer(0, 4), "woolBalance" to nonnegative, "unlockedShopTier" to integer(0, 3),
        "ownedShopItemIDs" to array(text), "equipment" to equipment, "shepherd" to shepherd,
        "transactions" to array(transaction), "cumulativeCredit" to credit),
        mapOf("fetchPracticeBest" to integer(0, 15), "trackedSheepDefinitionID" to text))
    private val phoneSettlement = record(mapOf("runID" to uuid, "eligible" to bool,
        "reason" to choice("eligible", "notPhoneAway", "practice", "endedEarly", "tooShort"), "completedSuccessfully" to bool,
        "isPractice" to bool, "creditedMinutes" to nonnegative, "appliedCreditDelta" to nonnegative,
        "meterBefore" to nonnegative, "meterAfter" to nonnegative, "protectedWindDownCount" to nonnegative, "createdAt" to date), mapOf("outcomeID" to uuid))
    private val search = record(mapOf("schemaVersion" to integer(4, 4), "outcomes" to array(outcome),
        "foundSheepIDs" to array(text), "consecutiveNoFinds" to integer(), "phoneBreakConsecutiveNoFinds" to integer(),
        "totalTrailDistance" to number, "showExactOdds" to bool,
        "trailMap" to record(mapOf("schemaVersion" to integer(3, 3), "pendingMappedMinutes" to integer(0, 200), "creditedAdHocRunIDs" to array(uuid))),
        "phoneAwaySettlements" to array(phoneSettlement)))
    private val welcome = record(mapOf("schemaVersion" to integer(1, 1), "preexistingFarm" to bool,
        "grants" to array(record(mapOf("id" to uuid, "kind" to choice("starterSheep", "profileWearable", "onboardingPracticeSheep", "starterSkippedExistingFarm"),
            "idempotencyKey" to text, "createdAt" to date), mapOf("sheepDefinitionID" to text, "flockSheepID" to uuid,
            "itemID" to text, "runID" to uuid, "claimedAt" to date)))))
    private val social = record(mapOf("schemaVersion" to integer(1, 1), "appliedGrantIDs" to array(uuid),
        "grants" to array(record(mapOf("id" to uuid, "challengeID" to uuid, "memberID" to uuid,
            "milestone" to choice("qualifyingNight:1", "qualifyingNight:2", "qualifyingNight:3", "qualifyingNight:4", "qualifyingNight:5", "qualifyingNight:6", "qualifyingNight:7", "threeNightParticipation", "sevenNightCompletion", "groupCompletion"),
            "rewardKind" to choice("wool", "itemOrWool", "sheepSearch"), "woolAmount" to nonnegative,
            "sheepSearchEntitlement" to bool, "createdAt" to date), mapOf("itemID" to text, "claimedAt" to date)))))
    private val sunrise = record(mapOf("schemaVersion" to integer(1, 1), "pendingMinutes" to nonnegative,
        "completedSearchCount" to nonnegative, "consecutiveNoFinds" to nonnegative,
        "occurrenceSettlements" to array(record(mapOf("occurrenceID" to uuid, "eligibleMinutes" to integer(), "appliedMinutes" to integer(), "createdAt" to date))),
        "fills" to array(record(mapOf("id" to uuid, "occurrenceID" to uuid, "fillIndex" to integer(), "woolGranted" to integer(), "outcome" to outcome, "settledAt" to date)))))
    private val keepsake = record(mapOf("id" to uuid, "type" to choice("ollieMail", "letter", "ribbon", "trophy", "tennisBall", "stick", "postcard", "sheepBadge", "fieldMap", "muddyPaw"),
        "rarity" to choice("common", "uncommon", "rare", "legendary", "consolation", "demo"), "title" to text, "earnedAt" to date, "isDemoReward" to bool))
    private val pasture = record(mapOf("schemaVersion" to integer(1, 1), "positions" to array(record(mapOf(
        "entityID" to record(mapOf("kind" to choice("sheep", "ollie", "shepherd"), "pastureIndex" to integer()), mapOf("sheepID" to uuid)),
        "point" to record(mapOf("x" to number, "y" to number)))))))
    private val appearance = record(listOf("skinToneID", "hairStyleID", "shepherdOutfitID", "shepherdAccessoryID", "ollieOrnamentID",
        "featuredSheepDefinitionID", "pastureThemeID", "avatarID").associateWith { text },
        listOf("headShapeID", "shepherdShirtID", "shepherdOuterwearID", "ollieCoatID").associateWith { text })
    val payload: (JsonElement) -> Unit = record(mapOf("schemaVersion" to integer(1, 1), "economyVersion" to integer(1, 1),
        "lineageID" to uuid, "farm" to farm, "search" to search, "welcome" to welcome, "socialRewards" to social,
        "sunrise" to sunrise, "completedWindDownCount" to nonnegative, "keepsakes" to array(keepsake),
        "deliveredWindDownRunIDs" to array(uuid), "deliveredEffectIDs" to array(text)), mapOf("pasture" to pasture, "appearance" to appearance))
}
