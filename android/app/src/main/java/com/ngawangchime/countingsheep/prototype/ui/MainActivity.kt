package com.ngawangchime.countingsheep.prototype.ui

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.*
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.ngawangchime.countingsheep.prototype.PrototypeApplication
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    private val app get() = application as PrototypeApplication
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val state by app.coordinator.states.collectAsStateWithLifecycle()
            val challenge by app.challenges.collectAsStateWithLifecycle()
            var apps by remember { mutableStateOf(app.availableApps()) }
            var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
            LaunchedEffect(Unit) { while (true) { now = System.currentTimeMillis(); delay(1_000) } }
            // A newly admitted window must not render against the preceding one-second UI sample.
            GuestScreen(state, apps, maxOf(now, state.clock?.wall ?: now), app.coordinator.operational, challenge, GuestActions(
                savePlan = app.coordinator::saveNightPreferences,
                startNight = app::startSavedWindDown, startMorning = app::startSavedMorning,
                startPhone = { app.start(it * 60_000L, 0) },
                request = app::requestGuestAction, confirm = app::confirmGuestAction, cancel = app::cancelGuestAction,
                acknowledge = app.coordinator::acknowledgeReceipts,
                welcome = { app.coordinator.welcomeGuest().also { app.synchronize() } },
                acknowledgeWelcome = { app.coordinator.acknowledgeWelcome().also { app.synchronize() } },
                shear = { sheep, ordinal -> app.coordinator.shear(sheep, ordinal).also { app.synchronize() } },
                consent = { app.coordinator.consent(it); app.synchronize() },
                settings = { startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }, select = app.coordinator::select,
                emergency = { app.cancelGuestAction(); app.coordinator.end("emergency"); app.synchronize() },
                repair = { app.service?.let { app.coordinator.serviceConnected() }; app.coordinator.repair(); app.synchronize() },
                refresh = { apps = app.availableApps(); app.reconcile() },
                debugStart = { duration, delay -> app.start(duration, delay) },
                debugDomain = app::startDomainScenario,
                debugEnd = { app.coordinator.end(it); app.synchronize() },
                debugWake = { app.coordinator.earlyWake(it); app.synchronize() },
                debugAccess = { app.coordinator.protectionOccurrence()?.let { app.briefAccess(it) } }
            ))
        }
    }
    override fun onResume() { super.onResume(); app.service?.returnToPrototype(); app.reconcile() }
    override fun onPause() { app.cancelGuestAction(); super.onPause() }
}
