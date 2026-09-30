package com.ngawangchime.countingsheep.prototype.platform

import android.accessibilityservice.AccessibilityService
import android.graphics.Color
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import com.ngawangchime.countingsheep.prototype.PrototypeApplication

class ProtectionService : AccessibilityService() {
    private val app get() = application as PrototypeApplication
    private var foregroundPackage: String? = null // Volatile, never a package-event history.
    private var overlay: View? = null
    private var overlayOccurrence: String? = null
    val overlayVisible get() = overlay?.isShown == true

    override fun onServiceConnected() { app.attach(this) }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (app.coordinator.state.consent != true) { foregroundPackage = null; clearOverlay(); return }
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val packageName = event.packageName?.toString() ?: return
        if (packageName == packageName()) return // Ignore our own overlay's window events.
        foregroundPackage = packageName
        app.reconcile()
    }
    private fun packageName() = applicationContext.packageName
    fun returnToPrototype() { foregroundPackage = null; clearOverlay() }
    fun refresh() {
        try {
            val packageName = foregroundPackage
            val safe = packageName != null && AppSelection.launchable(this).any { it.packageName == packageName }
            if (!safe || !app.coordinator.shouldBlock(packageName!!)) { clearOverlay(); return }
            val occurrence = app.coordinator.protectionOccurrence(packageName) ?: return
            if (overlay != null && overlayOccurrence == occurrence) return
            clearOverlay()
            val column = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(dp(24), dp(32), dp(24), dp(24))
                setBackgroundColor(Color.rgb(23, 31, 38))
            }
            column.addView(TextView(this).apply {
                text = getString(com.ngawangchime.countingsheep.prototype.R.string.overlay_message)
                textSize = 22f; setTextColor(Color.WHITE)
            })
            fun button(label: String, action: () -> Unit) {
                column.addView(Button(this).apply { text = label; minHeight = dp(48); setOnClickListener { action() } })
            }
            button("Five-minute Brief Access") {
                if (app.requestGuestAction(occurrence, "access")) {
                    startActivity(android.content.Intent(this, com.ngawangchime.countingsheep.prototype.ui.MainActivity::class.java)
                        .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP))
                }
            }
            button("Home / essential controls") {
                clearOverlay()
                if (!performGlobalAction(GLOBAL_ACTION_HOME)) {
                    app.coordinator.fail("Home navigation failed; protection is open"); app.synchronize()
                }
            }
            button("Emergency exit — open selected apps") { app.coordinator.end("emergency"); app.synchronize() }
            val view = ScrollView(this).apply { addView(column); setBackgroundColor(Color.rgb(23, 31, 38)) }
            val params = WindowManager.LayoutParams(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT).apply { gravity = Gravity.TOP }
            getSystemService(WindowManager::class.java).addView(view, params)
            overlay = view
            overlayOccurrence = occurrence
            app.coordinator.observed(occurrence)
            if (app.coordinator.state.repairRequired) clearOverlay()
        } catch (_: Exception) {
            clearOverlay()
            app.coordinator.fail("Blocker overlay failed; protection is open")
        }
    }
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    fun clearOverlay() {
        overlay?.let { view ->
            if (runCatching { getSystemService(WindowManager::class.java).removeViewImmediate(view) }.isFailure) {
                app.coordinator.fail("Overlay cleanup failed; disabling prototype service")
                disableSelf()
            }
        }
        overlay = null
        overlayOccurrence = null
    }
    override fun onInterrupt() { clearOverlay(); app.coordinator.fail("Service interrupted; protection is open"); app.synchronize() }
    override fun onUnbind(intent: android.content.Intent?): Boolean {
        clearOverlay(); app.detach(this); return super.onUnbind(intent)
    }
    override fun onDestroy() { clearOverlay(); app.detach(this); super.onDestroy() }
}
