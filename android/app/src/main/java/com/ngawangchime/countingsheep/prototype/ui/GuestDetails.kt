package com.ngawangchime.countingsheep.prototype.ui

import android.app.TimePickerDialog
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.tooling.preview.Preview
import com.ngawangchime.countingsheep.prototype.domain.*
import com.ngawangchime.countingsheep.prototype.platform.SelectableApp
import java.util.Locale

@Composable fun ChoiceMenu(label: String, value: Int, options: List<Int>, change: (Int) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        OutlinedButton(onClick = { expanded = true }, modifier = Modifier.heightIn(min = GuestSpace.touch)) { Text("$label: $value minutes") }
        DropdownMenu(expanded, { expanded = false }) { options.forEach { option ->
            DropdownMenuItem(text = { Text("$option minutes") }, onClick = { change(option); expanded = false })
        } }
    }
}
@Composable fun PlanEditor(saved: NightPreferences, save: (NightPreferences) -> Unit, cancel: () -> Unit) {
    var bedHour by rememberSaveable { mutableIntStateOf(saved.bedtimeHour) }
    var bedMinute by rememberSaveable { mutableIntStateOf(saved.bedtimeMinute) }
    var wakeHour by rememberSaveable { mutableIntStateOf(saved.wakeHour) }
    var wakeMinute by rememberSaveable { mutableIntStateOf(saved.wakeMinute) }
    var windDown by rememberSaveable { mutableIntStateOf(saved.windDownMinutes) }
    var morning by rememberSaveable { mutableIntStateOf(saved.morningMinutes) }
    val context = LocalContext.current
    Text("Your usual plan", style = MaterialTheme.typography.headlineMedium)
    Text("Choose local clock times. Saving prepares your plan; it does not start protection or enable a recurring schedule.")
    OutlinedButton(onClick = { TimePickerDialog(context, { _, hour, minute -> bedHour = hour; bedMinute = minute }, bedHour, bedMinute, true).show() }) {
        Text("Bedtime: %02d:%02d".format(bedHour, bedMinute))
    }
    OutlinedButton(onClick = { TimePickerDialog(context, { _, hour, minute -> wakeHour = hour; wakeMinute = minute }, wakeHour, wakeMinute, true).show() }) {
        Text("Wake time: %02d:%02d".format(wakeHour, wakeMinute))
    }
    ChoiceMenu("Wind Down before bed", windDown, (15..180 step 15).toList()) { windDown = it }
    ChoiceMenu("Screen-Free Morning", morning, (15..180 step 15).toList()) { morning = it }
    Text("A running occurrence keeps its original times, even if you edit this plan or travel.")
    Button(onClick = { save(NightPreferences(bedHour, bedMinute, wakeHour, wakeMinute, windDown, morning)) }, modifier = Modifier.fillMaxWidth()) { Text("Save usual plan") }
    TextButton(onClick = cancel) { Text("Cancel changes") }
}
@Composable fun SettingsContent(state: PrototypeState, apps: List<SelectableApp>, live: Boolean, connected: Boolean, actions: GuestActions,
                               edit: () -> Unit, debug: () -> Unit) {
    Text("Settings", style = MaterialTheme.typography.headlineMedium)
    Text("Local guest on this phone. No account, upload or synchronization.")
    OutlinedButton(onClick = edit) { Text("Edit usual plan") }
    GuestCard("Package-only protection") {
        Text("This Android preview uses Accessibility to receive package names when windows change and cover selected apps. Selections and blocker timestamps stay on this phone. It does not read screen text, window content, screenshots or notification content. Nothing is uploaded. System apps and launchers are excluded. You can refuse, disable the service or uninstall at any time.")
        if (state.consent != true) {
            if (state.consent == false) Text("You declined. Protection stays off until you choose to consent.")
            Button(onClick = { actions.consent(true) }) { Text("I consent to package-only protection") }
            TextButton(onClick = { actions.consent(false) }) { Text("Refuse — keep protection off") }
        } else {
            Text("Service ${if (connected) "connected" else "unavailable"}. A connection alone is not blocker evidence.")
            OutlinedButton(onClick = actions.settings) { Text("Open Android protection settings") }
            TextButton(onClick = { actions.consent(false) }) { Text("Withdraw consent") }
            Text("Choose apps to cover during your quiet window.")
            if (apps.isEmpty()) Text("No eligible apps found. Install a non-system test app, then refresh.")
            if (live) Text("End the current occurrence before changing the selected apps.")
            apps.forEach { item ->
                Row(Modifier.fillMaxWidth().heightIn(min = GuestSpace.touch).toggleable(item.packageName in state.selection,
                    enabled = !live, role = Role.Checkbox) { checked -> actions.select(if (checked) state.selection + item.packageName else state.selection - item.packageName) }) {
                    Checkbox(item.packageName in state.selection, onCheckedChange = null)
                    Text(item.label, Modifier.weight(1f).padding(GuestSpace.gap))
                }
            }
            TextButton(onClick = actions.refresh) { Text("Refresh apps and check protection") }
        }
    }
    Text("Protection is experimental. Physical overnight, battery and manufacturer checks are pending.", style = MaterialTheme.typography.bodySmall)
    OutlinedButton(onClick = debug) { Text("Internal scenario controls") }
}
@Composable fun GuestIntroduction(begin: () -> Unit) {
    Text("Welcome to Counting Sheep", style = MaterialTheme.typography.headlineMedium)
    GuestCard("I'm Ollie. You're the shepherd.") {
        Text("Put your phone away for a quiet stretch. Wind Down is your usual night; Phone Away is a shorter break. Screen-Free Morning keeps its own record.")
        Text("Eligible timer time helps Ollie search and grows your sheep's wool, even when you end early. Brief Access pauses that timer credit.")
    }
    GuestCard("Your local guest Farm") {
        Text("A fresh Farm starts with Mabel. Existing sheep and progress stay yours on this phone, without an extra starter grant.")
        Text("Guest progress is saved only here. It has no account or cloud backup and can be lost if app data is cleared or the app is uninstalled.")
        Text("App protection has a separate consent and setup step. Timer records do not verify sleep or where your phone was placed.")
        Button(onClick = begin, modifier = Modifier.fillMaxWidth().heightIn(min = GuestSpace.touch)) { Text("Begin as a local guest") }
    }
}
@Composable fun WelcomeContent(farm: GuestFarm, continueToFarm: () -> Unit) {
    val starter = farm.welcome.grant?.kind == "starterSheep"
    Text(if (starter) "Mabel is here" else "Welcome back to your Farm", style = MaterialTheme.typography.headlineMedium)
    GuestCard(if (starter) "Your first sheep" else "Your saved progress") {
        Text(if (starter) "Mabel has joined your pasture with wool ready to shear. Your starter gift is saved once; it adds no quiet minutes or search credit."
            else "Your existing Farm is still here. No extra starter sheep or historical quiet credit was added.")
        Text("Shearing keeps the sheep in your pasture and adds wool. Eligible Wind Down and Phone Away timer credit regrows it. Bedtime bonuses and Morning rewards stay separate.")
        Button(onClick = continueToFarm, modifier = Modifier.fillMaxWidth().heightIn(min = GuestSpace.touch)) { Text("Open my Farm") }
    }
}
@Composable fun FarmContent(farm: GuestFarm, enabled: Boolean = true, shear: (String, Int) -> Unit = { _, _ -> }) {
    Text("Farm", style = MaterialTheme.typography.headlineMedium)
    Text("Genuine guest progress, saved only on this phone.")
    GuestCard("Ollie's search trails") {
        Meter("Wind Down", farm.windDownMillis + farm.bonusMillis, FarmSettlement.WIND_DOWN)
        Text("Timer: ${minutesText(farm.windDownMillis)}\nBedtime bonus remaining: ${farm.bonusMillis * 100 / FarmSettlement.WIND_DOWN}% of a trail")
        Text("The bedtime bonus advances the trail separately; it adds no timer minutes or wool growth.")
        Meter("Phone Away", farm.phoneAwayMillis, FarmSettlement.PHONE_AWAY)
        Meter("Screen-Free Morning", farm.morningPendingMinutes.toLong(), 100)
        Text("Morning: ${farm.morningPendingMinutes} / 100 minutes. Completed fills earn wool and a separate search.")
    }
    GuestCard("Your pasture") {
        Text("Wool: ${farm.wool}")
        Text("${farm.sheep.count { it.status == "active" }} sheep in the pasture • ${farm.sheep.count { it.status == "pending" }} waiting in the Barn")
        if (farm.sheep.none { it.status != "sold" }) Text("Your saved sheep will appear here as Ollie's searches bring them home.")
        farm.sheep.filter { it.status != "sold" }.forEach { sheep ->
            Text("${sheepLabel(sheep.definitionID)} • ${if (sheep.status == "pending") "waiting in the Barn" else when (GuestFarmActions.woolState(sheep)) { "wool_ready" -> "wool ready"; "shorn" -> "freshly shorn"; else -> "wool regrowing" }}")
            if (sheep.status == "active") {
                val yield = GuestFarmActions.woolYield(sheep.rarity)
                if (sheep.regrowthRemaining > 0) Text("${(sheep.regrowthRemaining + 59_999) / 60_000} more eligible timer minutes to regrow")
                if (yield == null) Text("A catalog update is needed before this sheep can be sheared.")
                else OutlinedButton(onClick = { shear(sheep.id, sheep.timesSheared + 1) },
                    enabled = enabled && sheep.regrowthRemaining == 0L && sheep.timesSheared < Int.MAX_VALUE,
                    modifier = Modifier.heightIn(min = GuestSpace.touch)) { Text("Shear ${sheepLabel(sheep.definitionID)} • $yield wool") }
            }
        }
        Text("Wool regrows from eligible timer credit. Brief Access and bedtime bonuses add no wool growth.")
        farm.shears.values.maxByOrNull { it.createdAt }?.let { receipt -> Text("Last saved shear: ${receipt.woolDelta} wool • ${clockText(receipt.createdAt)}") }
    }
    farm.outcomes.lastOrNull()?.let { outcome -> GuestCard("Ollie's latest search") {
        Text(if (outcome.sheepID != null) "Ollie found ${sheepLabel(outcome.sheepID)}." else "Ollie brought back a clue. Your search history is saved.")
        Text(when (outcome.origin) { "starter" -> "Starter gift • no search credit"; "sunrise" -> "From Screen-Free Morning"; "phoneBreak" -> "From Phone Away"; else -> "From Wind Down" })
    } }
}
@Composable private fun Meter(label: String, value: Long, total: Long) {
    val percent = (value.toDouble() / total).coerceIn(0.0, 1.0)
    Text("$label • ${(percent * 100).toInt()}%", style = MaterialTheme.typography.titleMedium)
    LinearProgressIndicator(progress = { percent.toFloat() }, modifier = Modifier.fillMaxWidth())
}
fun sheepLabel(id: String): String = if (SearchRules.catalog.any { it.id == id }) id.replaceFirstChar { it.titlecase(Locale.ROOT) } else "Saved sheep (catalog update needed)"
@Composable fun ReceiptContent(receipt: GuestReceipt, state: PrototypeState, close: () -> Unit, back: () -> Unit) {
    Text("${receipt.title} receipt", style = MaterialTheme.typography.headlineMedium)
    Text(clockText(receipt.at))
    if (!receipt.ready) Text("Settlement is waiting for local storage. Repair before trusting new progress.")
    receipt.run?.let { run ->
        GuestCard(if (run.mode == "windDown") "Overnight record" else "Phone Away record") {
            Text(when (run.status) { "completed" -> "Reached the planned end"; "emergency" -> "Ended through emergency exit"; "failed" -> "Interrupted • protection failed open"; "refused" -> "Ended after consent was withdrawn"; else -> "Ended early" })
            Text("Started ${clockText(run.start, run.plan?.zone)}\nEnded ${clockText(run.endedAt ?: run.end, run.plan?.zone)}")
            run.plan?.let { plan -> Text("Saved time zone: ${plan.zone ?: "unknown"}"); Text("Before bedtime: ${plan.beforeBedMinutes(run.start, run.endedAt ?: run.end)} minutes\nPlanned wake: ${clockText(plan.wake, plan.zone)}") }
            val credit = state.farm.receipts[run.id]
            if (receipt.ready && credit != null) {
                Text("Saved eligible timer credit: ${minutesText(credit.creditedMillis)}\nBrief Access excluded: ${minutesText(credit.excludedAccessMillis)}")
                if (credit.trackingIncomplete) Text("Access tracking was incomplete. No unverified timer credit was added.")
                credit.bonus?.let { Text(if (it.result == "granted") "Bedtime bonus: +20 percentage points to the Wind Down trail, saved once for this anchored night."
                    else if (it.result == "alreadyGranted") "This night's bedtime bonus was already saved." else "No bedtime bonus was added.") }
                if (credit.outcomeIDs.isEmpty()) Text(if (credit.creditedMillis > 0 || (credit.bonus?.grantedMillis ?: 0) > 0)
                    "Your credit carries toward Ollie's next search." else "No new search progress was added.")
                credit.outcomeIDs.forEach { id -> state.farm.outcomes.firstOrNull { it.id == id }?.let { Text(if (it.sheepID != null) "Ollie found ${sheepLabel(it.sheepID)}." else "Ollie brought back a clue.") } }
            } else if (receipt.ready) Text(if (run.farmCreditVersion == 0) "Historical prototype record. No Farm reward was promised or invented." else "No eligible timer credit was added.")
            Text("Requested app protection: ${if (run.requestedProtection) "yes" else "no"}\n${run.coverage}")
        }
        state.mornings.filter { it.linkedRun == run.id }.forEach { morning -> MorningReceiptContent(morning, state.farm) }
    }
    receipt.morning?.let { MorningReceiptContent(it, state.farm) }
    Text("Timer records do not verify sleep, phone placement or continuous protection.", style = MaterialTheme.typography.bodySmall)
    Button(onClick = close, enabled = receipt.ready, modifier = Modifier.fillMaxWidth()) { Text("See Farm progress") }
    TextButton(onClick = back, enabled = receipt.ready) { Text("Back to Nights") }
}
@Composable private fun MorningReceiptContent(morning: MorningOccurrence, farm: GuestFarm) {
    GuestCard("Screen-Free Morning • separate record") {
        Text(when (morning.outcome) { "scheduled" -> "Saved for ${clockText(morning.start)}"; "active" -> "Still running until ${clockText(morning.end)}"; "skipped" -> "Skipped today • no Morning reward"; else -> "Ended ${clockText(morning.endedAt ?: morning.end)}" })
        farm.morningReceipts[morning.id]?.let { reward ->
            Text("Elapsed Morning: ${reward.elapsedMinutes} minutes\nSaved Morning credit: ${reward.appliedMinutes} minutes")
            if (reward.appliedMinutes == 0) Text("Morning credit starts at 15 elapsed minutes.")
            Text("${reward.fillIDs.size} completed Morning fills • ${reward.fillIDs.size} wool earned")
        }
        Text("Morning is accounted separately. Its elapsed-time rule includes Brief Access.")
    }
}
@Preview(fontScale = 1.5f) @Composable private fun PlanPreview() { GuestTheme { Column { PlanEditor(NightPreferences(), {}, {}) } } }
@Preview @Composable private fun FarmPreview() { GuestTheme { Column { FarmContent(GuestFarm(phoneAwayMillis = 2_700_000, wool = 1)) } } }
@Preview(fontScale = 1.5f) @Composable private fun IntroductionPreview() { GuestTheme { Column { GuestIntroduction {} } } }
@Preview @Composable private fun WelcomePreview() { GuestTheme { Column { WelcomeContent(GuestFarmActions.welcome(GuestFarm(), 1_790_000_000_000, GuestFarmActions.starterID)) {} } } }
@Preview @Composable private fun ReceiptPreview() {
    val run = Session("00000000-0000-4000-8000-000000000001", 1_790_000_000_000, 1_790_001_800_000, setOf("fixture.app"), status = "ended", endedAt = 1_790_000_900_000)
    GuestTheme { Column { ReceiptContent(GuestReceipt(run.id, run = run, ready = true), PrototypeState(), {}, {}) } }
}
