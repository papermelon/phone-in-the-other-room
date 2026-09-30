package com.ngawangchime.countingsheep.prototype.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.*
import androidx.compose.ui.tooling.preview.Preview
import com.ngawangchime.countingsheep.prototype.domain.*
import com.ngawangchime.countingsheep.prototype.platform.SelectableApp
import java.time.*
import java.time.format.DateTimeFormatter

class GuestActions(
    val savePlan: (NightPreferences) -> Boolean = { false }, val startNight: (Boolean) -> Boolean = { false },
    val startPhone: (Int) -> Boolean = { false }, val startMorning: () -> Boolean = { false },
    val request: (String, String) -> Boolean = { _, _ -> false }, val confirm: (GuestChallenge, String) -> Boolean = { _, _ -> false },
    val cancel: () -> Unit = {}, val acknowledge: (Set<String>) -> Boolean = { false },
    val welcome: () -> Boolean = { false }, val acknowledgeWelcome: () -> Boolean = { false },
    val shear: (String, Int) -> Boolean = { _, _ -> false },
    val consent: (Boolean) -> Unit = {}, val settings: () -> Unit = {}, val select: (Set<String>) -> Unit = {},
    val emergency: () -> Unit = {}, val repair: () -> Unit = {}, val refresh: () -> Unit = {},
    val debugStart: (Long, Long) -> Unit = { _, _ -> }, val debugDomain: (Boolean) -> Unit = {},
    val debugEnd: (String) -> Unit = {}, val debugWake: (String) -> Unit = {}, val debugAccess: () -> Unit = {}
)
fun clockText(at: Long, zone: String? = null): String = Instant.ofEpochMilli(at).atZone(zone?.let(ZoneId::of) ?: ZoneId.systemDefault())
    .format(DateTimeFormatter.ofPattern("EEE HH:mm"))
fun durationText(millis: Long): String { val seconds = (maxOf(0, millis) + 999) / 1000; return "%d:%02d:%02d".format(seconds / 3600, seconds / 60 % 60, seconds % 60) }
fun minutesText(millis: Long) = "${maxOf(0, millis) / 60_000} min ${maxOf(0, millis) / 1000 % 60} sec"

@Composable fun GuestScreen(state: PrototypeState, apps: List<SelectableApp>, now: Long, connected: Boolean = false,
                            challenge: GuestChallenge? = null, actions: GuestActions = GuestActions()) {
    var tab by rememberSaveable { mutableStateOf("Home") }
    var editor by rememberSaveable { mutableStateOf(false) }
    var debug by rememberSaveable { mutableStateOf(false) }
    var selectedReceipt by rememberSaveable { mutableStateOf<String?>(null) }
    var startDialog by remember { mutableStateOf<String?>(null) }
    var phoneMinutes by rememberSaveable { mutableIntStateOf(30) }
    var message by remember { mutableStateOf<String?>(null) }
    val live = state.session?.live == true || state.mornings.any { it.live }
    val active = state.session?.live == true || state.mornings.any { it.outcome == "active" }
    val ready = connected && state.consent == true && state.selection.isNotEmpty() && !state.repairRequired && !active && state.terminalIntents.all { it.settled }
    val receipts = GuestJourney.receipts(state)
    val receipt = selectedReceipt?.let { id -> receipts.firstOrNull { it.id == id } } ?: GuestJourney.pendingReceipt(state)
    fun closeReceipt(destination: String): Boolean {
        val current = receipt ?: return false
        val ids = setOf(current.id) + if (current.run != null) receipts.filter { it.morning?.linkedRun == current.id && it.ready }.map { it.id } else emptyList()
        if (!actions.acknowledge(ids)) { message = "This receipt could not be saved. Check local storage and repair."; return false }
        selectedReceipt = null; tab = destination; return true
    }
    BackHandler(editor || debug || receipt != null) {
        when { editor -> editor = false; debug -> debug = false; else -> closeReceipt("Nights") }
    }
    GuestTheme {
        Surface(Modifier.fillMaxSize()) {
            Column(Modifier.safeDrawingPadding()) {
                Row(Modifier.fillMaxWidth().padding(horizontal = GuestSpace.page), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Counting Sheep", Modifier.padding(vertical = GuestSpace.gap), style = MaterialTheme.typography.titleLarge)
                    Text("Local guest", Modifier.padding(vertical = GuestSpace.gap), style = MaterialTheme.typography.labelLarge)
                }
                if (live) TextButton(onClick = actions.emergency, modifier = Modifier.fillMaxWidth().heightIn(min = GuestSpace.touch)) {
                    Text("Emergency exit — open apps now", color = MaterialTheme.colorScheme.error)
                }
                if (debug) {
                    TextButton(onClick = { debug = false }) { Text("Back to Settings") }
                    Box(Modifier.weight(1f)) {
                        PrototypeScreen(state, apps, now, connected, actions.consent, actions.settings, actions.select,
                            actions.debugStart, actions.debugAccess, actions.debugEnd, actions.repair, actions.refresh, actions.debugDomain, actions.debugWake)
                    }
                } else {
                    val scroll = rememberScrollState()
                    LaunchedEffect(tab, editor, receipt?.id, state.farm.welcome) { scroll.scrollTo(0) }
                    Column(Modifier.weight(1f).verticalScroll(scroll).padding(GuestSpace.page), verticalArrangement = Arrangement.spacedBy(GuestSpace.gap)) {
                        message?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                        if (state.repairRequired) {
                            GuestCard("Protection needs repair") {
                                Text(state.failure ?: "Protection is open. Check the service and local storage before starting again.")
                                Button(onClick = actions.repair) { Text("Check service and repair") }
                                TextButton(onClick = { tab = "Settings"; editor = false }) { Text("Protection settings") }
                            }
                        }
                        when {
                            editor -> PlanEditor(state.nightPreferences ?: NightPreferences(), save = {
                                if (actions.savePlan(it)) { editor = false; tab = "Home"; message = null }
                                else message = "Your plan was not saved. Check local storage and repair."
                            }, cancel = { editor = false })
                            receipt != null -> ReceiptContent(receipt, state, close = { closeReceipt("Farm") }, back = { closeReceipt("Nights") })
                            !active && state.farm.welcome.introductionCompleted && !state.farm.welcome.acknowledged -> WelcomeContent(state.farm) {
                                if (actions.acknowledgeWelcome()) { tab = "Farm"; message = null }
                                else message = "Your welcome could not be saved. Check local storage and repair."
                            }
                            !active && tab in setOf("Home", "Farm") && !state.farm.welcome.introductionCompleted -> GuestIntroduction {
                                if (!actions.welcome()) message = "Your local Farm could not be saved. Check local storage and repair."
                                else message = null
                            }
                            tab == "Home" -> {
                                Text("Home", style = MaterialTheme.typography.headlineMedium)
                                if (!active) {
                                    state.nightPreferences?.let { preferences ->
                                        val plan = preferences.makePlan(now, ZoneId.systemDefault())
                                        GuestCard("Your usual night") {
                                            Text("Wind Down ${clockText(plan.plannedStart)}\nBedtime ${clockText(plan.bedtime)}\nWake ${clockText(plan.wake)}\nMorning ends ${clockText(plan.protectedUntil)}")
                                            Text("${plan.zone} • starts when you choose")
                                            TextButton(onClick = { editor = true }) { Text("Edit usual plan") }
                                        }
                                    } ?: GuestCard("Choose your usual night") {
                                        Text("Set your bedtime, wake time and quiet windows. Saving a plan keeps it ready for you to start.")
                                        Button(onClick = { editor = true }) { Text("Set up usual plan") }
                                    }
                                }
                                state.session?.takeIf { it.live }?.let { run ->
                                    LiveContent(run.id, if (run.phase(now) == "morningQuiet") "Screen-Free Morning" else if (run.mode == "windDown") "Wind Down" else "Phone Away",
                                        run.remaining(now), run.end, run.access, run.coverage, run.observedAt, now, actions)
                                    run.plan?.let { Text("Saved bedtime ${clockText(it.bedtime, it.zone)} • Morning starts ${clockText(it.wake, it.zone)} (${it.zone ?: ZoneId.systemDefault().id})") }
                                    if (run.mode == "windDown" && run.phase(now) == "overnight") GuestCard("Up before your usual wake time?") {
                                        Button(onClick = { actions.request(run.id, "startNow") }) { Text("Start Morning now") }
                                        OutlinedButton(onClick = { actions.request(run.id, "defer") }) { Text("Morning at usual time") }
                                        OutlinedButton(onClick = { actions.request(run.id, "skip") }) { Text("Skip Morning today") }
                                    }
                                }
                                state.mornings.filter { it.live && !(state.session?.live == true && it.linkedRun == state.session.id) }.forEach { morning ->
                                    if (morning.outcome == "active") LiveContent(morning.id, "Screen-Free Morning", maxOf(0, morning.end - now), morning.end,
                                        morning.access, morning.coverage, morning.observedAt, now, actions)
                                    else Text("Screen-Free Morning is saved for ${clockText(morning.start)}. Keep the service available.")
                                }
                                if (!active) {
                                    if (!ready) GuestCard("Get protection ready") {
                                        Text(when { state.consent != true -> "Review package-only protection and choose whether to consent."
                                            !connected -> "Enable the protection service in Android Settings."
                                            state.selection.isEmpty() -> "Choose at least one app to protect."
                                            else -> "Repair protection before starting." })
                                        Button(onClick = { tab = "Settings" }) { Text("Review protection setup") }
                                    }
                                    val nightFirst = GuestJourney.prefersWindDown(state, now, ZoneId.systemDefault())
                                    Button(onClick = { startDialog = if (nightFirst) "night" else "phone" }, enabled = ready, modifier = Modifier.fillMaxWidth()) {
                                        Text(if (nightFirst) "Start Wind Down" else "Start Phone Away")
                                    }
                                    if (!nightFirst && state.nightPreferences != null) Text("Wind Down becomes available near your saved start time.")
                                    OutlinedButton(onClick = { startDialog = "morning" }, enabled = ready, modifier = Modifier.fillMaxWidth()) { Text("Start Screen-Free Morning") }
                                    if (nightFirst) TextButton(onClick = { startDialog = "phone" }, enabled = ready) { Text("Choose Phone Away instead") }
                                }
                                Text("Timer progress records elapsed time. It does not verify sleep, physical placement or continuous protection.", style = MaterialTheme.typography.bodySmall)
                            }
                            tab == "Nights" -> {
                                Text("Nights", style = MaterialTheme.typography.headlineMedium)
                                Text("Your local overnight, Phone Away and Morning records.")
                                if (receipts.isEmpty()) Text("Your first receipt will appear here after an occurrence ends.")
                                receipts.forEach { record ->
                                    OutlinedButton(onClick = { selectedReceipt = record.id }, modifier = Modifier.fillMaxWidth()) {
                                        Text("${record.title} • ${clockText(record.at)}${if (!record.ready) " • progress pending" else ""}")
                                    }
                                }
                            }
                            tab == "Farm" -> FarmContent(state.farm, enabled = !state.repairRequired) { sheep, ordinal ->
                                message = if (actions.shear(sheep, ordinal)) null else "That shear was not saved. Check the sheep's wool and local storage."
                            }
                            else -> SettingsContent(state, apps, live, connected, actions, edit = { editor = true }, debug = { debug = true })
                        }
                    }
                }
                NavigationBar {
                    listOf("Home", "Nights", "Farm", "Settings").forEach { name ->
                        NavigationBarItem(selected = name == tab, onClick = { tab = name; editor = false; debug = false; selectedReceipt = null },
                            icon = { Text(name.take(1), Modifier.clearAndSetSemantics {}) }, label = { Text(name) }, alwaysShowLabel = true)
                    }
                }
            }
        }
        startDialog?.let { mode ->
            val early = mode == "night" && (state.nightPreferences?.makePlan(now, ZoneId.systemDefault())?.plannedStart ?: now) > now
            AlertDialog(onDismissRequest = { startDialog = null }, title = { Text(when (mode) { "night" -> if (early) "Start Wind Down early?" else "Start Wind Down?"; "morning" -> "Start Screen-Free Morning?"; else -> "Start Phone Away?" }) },
                text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(GuestSpace.gap)) {
                    Text(if (mode == "night") "Your saved bedtime and morning boundaries stay anchored. This requests selected-app protection through Morning. You can always use emergency exit."
                        else if (mode == "morning") "${state.nightPreferences?.morningMinutes ?: 30} minutes from now. Morning rewards settle separately from overnight credit."
                        else "Choose a quiet window. Eligible timer credit stays with your guest Farm, including an early ending.")
                    if (mode == "phone") ChoiceMenu("Duration", phoneMinutes, GuestJourney.phoneAwayMinutes) { phoneMinutes = it }
                } }, confirmButton = { TextButton(onClick = {
                    val ok = when (mode) { "night" -> actions.startNight(early); "morning" -> actions.startMorning(); else -> actions.startPhone(phoneMinutes) }
                    startDialog = null; if (!ok) message = "The start was not accepted. Review protection setup and repair." else message = null
                }, enabled = ready) { Text("Start now") } }, dismissButton = { TextButton(onClick = { startDialog = null }) { Text("Cancel") } })
        }
        challenge?.let { request ->
            var entry by remember(request.id) { mutableStateOf("") }
            val expired = now !in request.createdAt until request.createdAt + 120_000 || GuestJourney.phrase(state, request.occurrence, request.action, now) != request.phrase
            AlertDialog(onDismissRequest = actions.cancel, title = { Text(when (request.action) { "access" -> "Brief Access"; "startNow" -> "Start Screen-Free Morning"; "defer" -> "Morning at usual time"; "skip" -> "Skip Morning today"; else -> "End this occurrence" }) },
                text = { Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(GuestSpace.gap)) {
                    Text(if (request.action == "access") "Selected apps open for up to five minutes, bounded by this occurrence. Overnight and Phone Away credit exclude this time."
                        else "Eligible progress stays saved locally. Morning and overnight settle separately.")
                    if (request.action != "startNow") { Text("Type: ${request.phrase}"); OutlinedTextField(entry, { entry = it }, label = { Text("Confirmation phrase") }, singleLine = true) }
                    if (expired) Text("This confirmation expired. Open a fresh one from the live controls.")
                    TextButton(onClick = actions.emergency) { Text("Emergency exit — open apps now") }
                } }, confirmButton = { TextButton(onClick = {
                    if (!actions.confirm(request, entry)) message = "That confirmation is no longer current. Review the live controls."
                }, enabled = !expired && (request.action == "startNow" || GuestJourney.matches(entry, request.phrase))) {
                    Text(if (request.action == "access") "Open apps for five minutes" else if (request.action == "startNow") "Start Morning" else "Confirm")
                } }, dismissButton = { TextButton(onClick = actions.cancel) { Text("Keep going") } })
        }
    }
}
@Composable fun GuestCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(Modifier.fillMaxWidth()) { Column(Modifier.padding(GuestSpace.card), verticalArrangement = Arrangement.spacedBy(GuestSpace.gap)) {
        Text(title, Modifier.semantics { heading() }, style = MaterialTheme.typography.titleLarge); content()
    } }
}
@Composable private fun LiveContent(id: String, title: String, remaining: Long, end: Long, access: List<AccessInterval>, coverage: String,
                                   observed: Long?, now: Long, actions: GuestActions) {
    GuestCard("$title is running") {
        Text(durationText(remaining), Modifier.semantics { contentDescription = "$title, ${minutesText(remaining)} remaining" }, style = MaterialTheme.typography.headlineLarge)
        Text("Ends ${clockText(end)}")
        val grant = access.firstOrNull { it.committed && now >= it.start && now < it.end }
        if (grant != null) Text("Brief Access • ${durationText(grant.end - now)} left")
        Button(onClick = { actions.request(id, "access") }, enabled = grant == null) { Text("Five-minute Brief Access") }
        OutlinedButton(onClick = { actions.request(id, "end") }) { Text("End $title") }
        var evidence by remember(id) { mutableStateOf(false) }
        TextButton(onClick = { evidence = !evidence }) { Text("Protection observations") }
        if (evidence) { Text(coverage); Text("Last blocker event: ${observed?.let { clockText(it) } ?: "none observed"}. Continuous coverage is unknown.") }
    }
}
@Preview(fontScale = 1.5f) @Composable private fun GuestFreshPreview() { GuestScreen(PrototypeState(), emptyList(), 0) }
@Preview @Composable private fun GuestReadyPreview() { GuestScreen(PrototypeState(consent = true, selection = setOf("fixture.app"), nightPreferences = NightPreferences()), emptyList(), 1_790_000_000_000, true) }
@Preview @Composable private fun GuestFailurePreview() { GuestScreen(PrototypeState(repairRequired = true, failure = "Local storage is unavailable; protection is open"), emptyList(), 0) }

@Preview @Composable private fun GuestLivePreview() {
    val at = 1_790_000_000_000L
    GuestScreen(PrototypeState(consent = true, selection = setOf("fixture.app"),
        session = Session("00000000-0000-4000-8000-000000000001", at, at + 1_800_000, setOf("fixture.app"), status = "active")), emptyList(), at, true)
}
