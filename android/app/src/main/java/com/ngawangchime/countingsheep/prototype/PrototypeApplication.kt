package com.ngawangchime.countingsheep.prototype

import android.app.AlarmManager
import android.app.Application
import android.app.PendingIntent
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import com.ngawangchime.countingsheep.prototype.data.SessionStore
import com.ngawangchime.countingsheep.prototype.domain.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import com.ngawangchime.countingsheep.prototype.domain.ClockSample
import com.ngawangchime.countingsheep.prototype.domain.SessionCoordinator
import com.ngawangchime.countingsheep.prototype.platform.AppSelection
import com.ngawangchime.countingsheep.prototype.platform.BoundaryReceiver
import com.ngawangchime.countingsheep.prototype.platform.ProtectionService

/** Process composition root: UI and service always share the same store/coordinator. */
class PrototypeApplication : Application() {
    lateinit var coordinator: SessionCoordinator
        private set
    var service: ProtectionService? = null
        private set
    private val mutableChallenge = MutableStateFlow<GuestChallenge?>(null)
    val challenges = mutableChallenge.asStateFlow()
    private val handler = Handler(Looper.getMainLooper())
    private val boundary = Runnable { reconcile() }
    private var alarm: PendingIntent? = null

    override fun onCreate() {
        super.onCreate()
        val store = SessionStore(filesDir)
        coordinator = SessionCoordinator(store.load(), store::save, ::sample)
    }
    private fun sample() = ClockSample(System.currentTimeMillis(), SystemClock.elapsedRealtime(),
        Settings.Global.getInt(contentResolver, Settings.Global.BOOT_COUNT, -1))
    fun attach(protection: ProtectionService) {
        service = protection
        coordinator.serviceConnected()
        synchronize()
    }
    fun detach(protection: ProtectionService) {
        if (service === protection) {
            service = null
            coordinator.fail("Service disconnected; protection is open. Enable service and repair before another start.")
            synchronize()
        }
    }
    fun reconcile(expectedOccurrence: String? = null) {
        coordinator.reconcile(expectedOccurrence)
        synchronize()
    }
    fun synchronize() {
        check(Looper.myLooper() == Looper.getMainLooper())
        service?.refresh()
        handler.removeCallbacks(boundary)
        try { alarm?.let { getSystemService(AlarmManager::class.java).cancel(it); it.cancel() } }
        catch (_: Exception) { coordinator.fail("Boundary cleanup failed; protection is open"); service?.clearOverlay() }
        alarm = null
        val next = coordinator.nextBoundary() ?: return
        val occurrence = coordinator.boundaryOccurrence() ?: return
        try {
            val intent = Intent(this, BoundaryReceiver::class.java).setAction("$packageName.BOUNDARY").putExtra("occurrence", occurrence)
                .setData(android.net.Uri.parse("countingsheep-prototype://boundary/$occurrence/$next"))
            val pending = PendingIntent.getBroadcast(this, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            // Inexact spike only: supported events always reconcile absolute bounds, even if delivery is late.
            getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pending)
            alarm = pending
            handler.postDelayed(boundary, (next - System.currentTimeMillis()).coerceAtLeast(1))
            coordinator.markAlarm(occurrence, true)
        } catch (_: Exception) {
            coordinator.fail("Boundary registration failed; protection is open")
            service?.clearOverlay()
        }
    }
    fun availableApps() = try { AppSelection.launchable(this) } catch (_: Exception) {
        coordinator.fail("App selection unavailable; protection is open"); synchronize(); emptyList()
    }
    fun start(duration: Long, delay: Long): Boolean {
        val eligible = availableApps().map { it.packageName }.toSet()
        coordinator.select(coordinator.state.selection.intersect(eligible))
        val accepted = coordinator.start(duration, delay)
        synchronize()
        return accepted
    }
    private fun refreshSelection() {
        coordinator.select(coordinator.state.selection.intersect(availableApps().map { it.packageName }.toSet()))
    }
    fun startSavedWindDown(earlyApproved: Boolean = false): Boolean {
        refreshSelection()
        val preferences = coordinator.state.nightPreferences ?: return false
        val accepted = coordinator.startWindDown(preferences.makePlan(System.currentTimeMillis(), java.time.ZoneId.systemDefault()), earlyApproved)
        synchronize()
        return accepted
    }
    fun startSavedMorning(): Boolean {
        refreshSelection()
        val accepted = coordinator.startMorning(coordinator.state.nightPreferences?.morningMinutes ?: 30)
        synchronize()
        return accepted
    }
    fun requestGuestAction(occurrence: String, action: String): Boolean {
        mutableChallenge.value = coordinator.beginGuestAction(occurrence, action)
        return mutableChallenge.value != null
    }
    fun cancelGuestAction() { coordinator.cancelGuestAction(); mutableChallenge.value = null }
    fun confirmGuestAction(request: GuestChallenge, entry: String): Boolean {
        if (!coordinator.consumeGuestAction(request, entry)) { cancelGuestAction(); return false }
        mutableChallenge.value = null
        val result = when (request.action) {
            "access" -> briefAccess(request.occurrence)
            "end" -> { coordinator.end("ended", expectedOccurrence = request.occurrence); !coordinator.state.repairRequired }
            else -> coordinator.earlyWake(request.action)
        }
        synchronize()
        return result
    }
    fun startDomainScenario(morning: Boolean): Boolean {
        val eligible = availableApps().map { it.packageName }.toSet()
        coordinator.select(coordinator.state.selection.intersect(eligible))
        val now = System.currentTimeMillis()
        val zone = java.time.ZoneId.systemDefault()
        val night = java.time.Instant.ofEpochMilli(now + 120_000).atZone(zone).toLocalDate()
        val accepted = if (morning) coordinator.startMorning(15) else coordinator.startWindDown(
            NightPlan(now + 60_000, now + 120_000, now + 1_020_000, 1, 15, zone.id,
                "${night.year}-${night.monthValue}-${night.dayOfMonth}"))
        synchronize()
        return accepted
    }
    fun briefAccess(occurrence: String): Boolean {
        val interval = coordinator.proposeAccess(occurrence) ?: return false
        // Write intent first, register boundary second, commit grant third, remove overlay last.
        try {
            val pending = PendingIntent.getBroadcast(this, 1,
                Intent(this, BoundaryReceiver::class.java).setAction("$packageName.BOUNDARY").putExtra("occurrence", occurrence)
                    .setData(android.net.Uri.parse("countingsheep-prototype://access/${interval.nonce}")), PendingIntent.FLAG_IMMUTABLE)
            getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, interval.end, pending)
        } catch (_: Exception) { coordinator.fail("Brief Access scheduling failed; protection is open"); synchronize(); return false }
        val result = coordinator.commitAccess(interval)
        if (!result) coordinator.fail("Brief Access commit failed; protection is open")
        synchronize()
        return result
    }
}
