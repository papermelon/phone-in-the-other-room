package com.ngawangchime.countingsheep.prototype

import android.content.ComponentName
import android.content.Intent
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ProtectionInstrumentationTest {
    @Test fun observedOverlayInterceptsTargetAndBriefAccessAndExitOpenIt() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val app = instrumentation.targetContext.applicationContext as PrototypeApplication
        androidx.test.uiautomator.Configurator.getInstance().setUiAutomationFlags(android.app.UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
        val device = UiDevice.getInstance(instrumentation)
        check(InstrumentationRegistry.getArguments().getString("isolatedPrototype") == "true" &&
            android.os.Build.MODEL.contains("sdk_gphone")) { "Explicit disposable emulator opt-in required before permission changes" }
        // Run only on the explicitly selected disposable emulator (see README). No founder app/data.
        device.executeShellCommand("settings put secure enabled_accessibility_services ${app.packageName}/com.ngawangchime.countingsheep.prototype.platform.ProtectionService")
        device.executeShellCommand("settings put secure accessibility_enabled 1")
        device.executeShellCommand("am start -n ${app.packageName}/com.ngawangchime.countingsheep.prototype.ui.MainActivity")
        val deadline = System.currentTimeMillis() + 30_000
        while (app.service == null && System.currentTimeMillis() < deadline) Thread.sleep(100)
        assertNotNull("Service must actually connect", app.service)
        val targetPackage = instrumentation.context.packageName
        instrumentation.runOnMainSync {
            app.coordinator.end("ended")
            app.coordinator.consent(true)
            app.coordinator.serviceConnected()
            app.coordinator.repair()
            app.coordinator.select(setOf(targetPackage))
            assertTrue(app.coordinator.start(600_000))
            app.synchronize()
        }
        fun launch() {
            instrumentation.context.startActivity(Intent().setComponent(ComponentName(targetPackage, TestTargetActivity::class.java.name)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
        launch()
        assertTrue(device.wait(Until.hasObject(By.text("Five-minute Brief Access")), 10_000))
        instrumentation.runOnMainSync {
            assertTrue(app.service!!.overlayVisible)
            assertNotNull(app.coordinator.state.session!!.observedAt)
        }
        // Touch near the bottom, outside overlay controls; the full-screen target button must not receive it.
        device.click(device.displayWidth / 2, device.displayHeight * 4 / 5)
        assertFalse(device.hasObject(By.text("TARGET WAS TAPPED")))
        device.findObject(By.text("Five-minute Brief Access")).click()
        assertTrue(device.wait(Until.hasObject(By.text("Confirmation phrase")), 10_000))
        device.findObject(By.clazz("android.widget.EditText")).text = "Put my phone away"
        device.findObject(By.text("Open apps for five minutes")).click()
        launch()
        assertTrue(device.wait(Until.hasObject(By.text("Isolated target interaction")), 5_000))
        device.findObject(By.text("Isolated target interaction")).click()
        assertTrue(device.wait(Until.hasObject(By.text("TARGET WAS TAPPED")), 5_000))
        instrumentation.runOnMainSync {
            assertTrue(app.coordinator.state.session!!.access.single().committed)
            app.coordinator.end("ended"); app.synchronize()
            assertFalse(app.service!!.overlayVisible)
            // Already observed target remains open: exercise real Handler automatic start and normal expiry.
            assertTrue(app.coordinator.start(4_000, 1_000)); app.synchronize()
        }
        assertTrue(device.wait(Until.hasObject(By.text("Five-minute Brief Access")), 5_000))
        assertTrue(device.wait(Until.gone(By.text("Five-minute Brief Access")), 8_000))
        instrumentation.runOnMainSync {
            assertEquals("completed", app.coordinator.state.session!!.status)
            assertNotNull(app.coordinator.state.session!!.observedAt)
            assertTrue(app.coordinator.start(600_000)); app.synchronize()
        }
        assertTrue(device.wait(Until.hasObject(By.text("Emergency exit — open selected apps")), 5_000))
        device.findObject(By.text("Emergency exit — open selected apps")).click()
        assertTrue(device.wait(Until.gone(By.text("Five-minute Brief Access")), 5_000))
        instrumentation.runOnMainSync {
            assertEquals("emergency", app.coordinator.state.session!!.status)
            assertFalse(app.service!!.overlayVisible)
            assertFalse(app.coordinator.shouldBlock(targetPackage))
        }
        device.executeShellCommand("settings put secure enabled_accessibility_services ''")
        device.executeShellCommand("settings put secure accessibility_enabled 0")
    }
}
