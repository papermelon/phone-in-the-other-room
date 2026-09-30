package com.ngawangchime.countingsheep.prototype.ui

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.ngawangchime.countingsheep.prototype.PrototypeApplication
import com.ngawangchime.countingsheep.prototype.domain.PrototypeState
import com.ngawangchime.countingsheep.prototype.platform.SelectableApp
import kotlinx.coroutines.delay

@Composable fun PrototypeScreen(
    state: PrototypeState, apps: List<SelectableApp>, now: Long, connected: Boolean = false,
    consent: (Boolean) -> Unit = {}, settings: () -> Unit = {}, select: (Set<String>) -> Unit = {},
    start: (Long, Long) -> Unit = { _, _ -> }, access: () -> Unit = {}, end: (String) -> Unit = {},
    repair: () -> Unit = {}, refresh: () -> Unit = {}, domainStart: (Boolean) -> Unit = {}, earlyWake: (String) -> Unit = {}
) {
    var confirmEnd by remember { mutableStateOf(false) }
    val scroll = rememberScrollState()
    val session = state.session
    val live = session?.live == true || state.mornings.any { it.live }
    LaunchedEffect(live, session?.id) { scroll.scrollTo(0) }
    MaterialTheme(colorScheme = darkColorScheme()) {
        Surface(Modifier.fillMaxSize()) {
            Column(Modifier.safeDrawingPadding().verticalScroll(scroll).padding(24.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Counting Sheep", style = MaterialTheme.typography.headlineMedium)
                Text("Internal protection prototype • offline", style = MaterialTheme.typography.titleMedium)
                Text("Selected app packages only. Guest timer progress stays on this phone; continuous coverage is unknown.")
                Text("Service connected: $connected. This alone is not blocking evidence.")
                if (live) Button(onClick = { end("emergency") }) { Text("Emergency exit — open apps now") }
                if (state.consent != true) {
                    if (state.consent == false) Text("Protection stays off. You can return here if you choose to try it.")
                    Text("Accessibility disclosure", style = MaterialTheme.typography.titleLarge)
                    Text("This experiment uses Android Accessibility to receive package names when windows change and cover selected apps. Package selections and the last blocker timestamp stay on this phone. It does not read screen text, window content, screenshots or notification content. Nothing is uploaded. System apps are excluded. You can refuse, disable the service or uninstall at any time.")
                    Button(onClick = { consent(true) }) { Text("I consent to package-only protection") }
                    OutlinedButton(onClick = { consent(false) }) { Text("Refuse — keep protection off") }
                } else {
                    OutlinedButton(onClick = settings) { Text("Enable / disable service in Android Settings") }
                    OutlinedButton(onClick = { consent(false) }) { Text("Withdraw consent") }
                    Text("Select launchable apps. System apps and launchers stay reachable.")
                    if (apps.isEmpty()) Text("No eligible apps found. Install a non-system test app, then refresh.")
                    apps.forEach { item ->
                        Row(Modifier.fillMaxWidth().heightIn(min = 48.dp)
                            .toggleable(value = item.packageName in state.selection, enabled = !live, role = Role.Checkbox) { checked ->
                                select(if (checked) state.selection + item.packageName else state.selection - item.packageName) }) {
                            Checkbox(checked = item.packageName in state.selection, onCheckedChange = null)
                            Text(item.label, Modifier.padding(top = 12.dp))
                        }
                    }
                    OutlinedButton(onClick = refresh) { Text("Refresh apps and reconcile") }
                    state.failure?.let { Text(it) }
                    if (state.repairRequired) Button(onClick = repair) { Text("Check service and repair") }
                    if (!live) {
                        Button(onClick = { start(1_800_000, 0) }, enabled = connected && state.selection.isNotEmpty() && !state.repairRequired) { Text("Start 30-minute protection") }
                        OutlinedButton(onClick = { start(120_000, 0) }, enabled = connected && state.selection.isNotEmpty() && !state.repairRequired) { Text("Start two-minute boundary test") }
                        OutlinedButton(onClick = { start(600_000, 120_000) }, enabled = connected && state.selection.isNotEmpty() && !state.repairRequired) { Text("Schedule in two minutes • inexact experiment") }
                        OutlinedButton(onClick = { domainStart(false) }, enabled = connected && state.selection.isNotEmpty() && !state.repairRequired) { Text("Wind Down scenario • 1 + 1 + 15 minutes") }
                        OutlinedButton(onClick = { domainStart(true) }, enabled = connected && state.selection.isNotEmpty() && !state.repairRequired) { Text("Screen-Free Morning • 15 minutes") }
                        Text("Internal short plan: bedtime in one minute, wake in two; real domain settlement. Guest setup is available on Home.")
                        Text("Starts require a connected service. Android may delay alarms; re-entry and window events reconcile timestamps. Force-stop stops this prototype.")
                    }
                }
                Text("Local guest • no verified account or sync")
                Text("Wind Down timer: ${state.farm.windDownMillis / 1000}s • bedtime bonus: ${state.farm.bonusMillis / 1000}s search units")
                Text("Phone Away: ${state.farm.phoneAwayMillis / 1000}s / 6000s • Morning: ${state.farm.morningPendingMinutes} / 100 min")
                Text("Sheep: ${state.farm.sheep.size} • wool: ${state.farm.wool} • pending replay: ${state.terminalIntents.count { !it.settled }}")
                session?.let {
                    Text("Occurrence: ${it.id}")
                    Text("${it.mode} / ${it.phase(now)} • requested: ${it.status} • remaining ${(it.remaining(now) + 999) / 1000}s")
                    Text("Boundary work registered: ${it.alarmRegistered} (inexact)")
                    Text("Evidence: ${it.coverage}")
                    Text("Last blocker: ${it.observedAt?.let { time -> java.time.Instant.ofEpochMilli(time).toString() } ?: "none"}")
                    Text("Brief Access grants: ${it.access.count { grant -> grant.committed }}")
                    if (it.live) {
                        Button(onClick = access, enabled = it.status == "active") { Text("Five-minute Brief Access") }
                        OutlinedButton(onClick = { confirmEnd = true }) { Text("End session") }
                    }
                }
                if (session?.live == true && session.mode == "windDown" && session.phase(now) == "overnight") {
                    OutlinedButton(onClick = { earlyWake("startNow") }) { Text("Early wake • start Morning now") }
                    OutlinedButton(onClick = { earlyWake("defer") }) { Text("Early wake • Morning at saved time") }
                    OutlinedButton(onClick = { earlyWake("skip") }) { Text("Early wake • skip Morning") }
                }
                state.mornings.takeLast(3).forEach { morning ->
                    Text("Morning ${morning.id}: ${morning.outcome} • elapsed ${morning.elapsedMinutes(now)} min • ${morning.coverage}")
                    if (morning.outcome == "active" && session?.live != true) {
                        Button(onClick = access) { Text("Five-minute Brief Access") }
                        OutlinedButton(onClick = { confirmEnd = true }) { Text("End Morning") }
                    }
                }
                session?.let { state.farm.receipts[it.id] }?.let { receipt ->
                    Text("Saved Farm credit: ${receipt.creditedMillis / 1000}s • excluded access: ${receipt.excludedAccessMillis / 1000}s • bonus: ${receipt.bonus?.result ?: "none"}")
                }
                Text("Overlay coverage is experimental. Split screen, picture-in-picture, already-open windows and OEM overnight behavior require device acceptance.")
            }
        }
        if (confirmEnd) AlertDialog(onDismissRequest = { confirmEnd = false }, title = { Text("End this occurrence?") },
            text = { Text("Selected apps will open. Eligible timer credit stays saved locally; Brief Access is excluded from overnight and Phone Away credit.") },
            confirmButton = { TextButton(onClick = { confirmEnd = false; end("ended") }) { Text("End session") } },
            dismissButton = { TextButton(onClick = { confirmEnd = false }) { Text("Keep going") } })
    }
}
@Preview(fontScale = 1.5f) @Composable private fun DisclosurePreview() { PrototypeScreen(PrototypeState(), emptyList(), 0) }
@Preview @Composable private fun FailedPreview() { PrototypeScreen(PrototypeState(consent = true, repairRequired = true, failure = "Service unavailable; protection is open"), emptyList(), 0) }
