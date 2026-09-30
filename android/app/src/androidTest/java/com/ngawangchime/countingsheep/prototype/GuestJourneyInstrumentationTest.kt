package com.ngawangchime.countingsheep.prototype

import android.app.UiAutomation
import android.os.Build
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.*
import com.ngawangchime.countingsheep.prototype.domain.*
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class GuestJourneyInstrumentationTest {
    @Test fun realGuestPlanStartPhraseEarlyWakeReceiptsAndFarm() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        check(InstrumentationRegistry.getArguments().getString("isolatedPrototype") == "true" && Build.MODEL.contains("sdk_gphone"))
        Configurator.getInstance().setUiAutomationFlags(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
        assertTrue(GuestJourney.matches("ＰＵＴ\u0085my phone away!", "Put my phone away"))
        val device = UiDevice.getInstance(instrumentation)
        val app = instrumentation.targetContext.applicationContext as PrototypeApplication
        fun shell(command: String) = device.executeShellCommand(command)
        fun main(body: () -> Unit) = instrumentation.runOnMainSync(body)
        fun click(text: String) {
            var found = device.wait(Until.findObject(By.text(text).enabled(true)), 1_000)
            repeat(7) {
                if (found == null) {
                    device.swipe(device.displayWidth / 2, device.displayHeight * 3 / 5, device.displayWidth / 2, device.displayHeight / 3, 20)
                    found = device.wait(Until.findObject(By.text(text).enabled(true)), 500)
                }
            }
            assertNotNull("Reachable control: $text", found)
            if (text == "Save usual plan" && device.displayWidth > device.displayHeight)
                shell("screencap -p /sdcard/guest-welcome-guest-plan-landscape-save.png")
            repeat(3) {
                try { device.wait(Until.findObject(By.text(text).enabled(true)), 3_000)!!.click(); return }
                catch (_: StaleObjectException) { device.waitForIdle() }
            }
            error("Control changed repeatedly during configuration update: $text")
        }
        fun screenshot(name: String) { device.waitForIdle(); Thread.sleep(500); shell("screencap -p /sdcard/guest-welcome-$name.png") }
        shell("settings delete secure enabled_accessibility_services"); shell("settings put secure accessibility_enabled 0")
        try {
            shell("settings put secure enabled_accessibility_services ${app.packageName}/com.ngawangchime.countingsheep.prototype.platform.ProtectionService")
            shell("settings put secure accessibility_enabled 1")
            shell("am start -n ${app.packageName}/com.ngawangchime.countingsheep.prototype.ui.MainActivity")
            val deadline = System.currentTimeMillis() + 30_000
            while (app.service == null && System.currentTimeMillis() < deadline) Thread.sleep(100)
            assertNotNull(app.service)
            main {
                app.coordinator.end("emergency"); app.coordinator.consent(false); app.coordinator.serviceConnected(); app.coordinator.repair()
                app.coordinator.acknowledgeReceipts(GuestJourney.receipts(app.coordinator.state).filter { it.ready }.map { it.id }.toSet())
                app.synchronize()
            }
            if (!app.coordinator.state.farm.welcome.introductionCompleted) {
                assertTrue(device.wait(Until.hasObject(By.text("Welcome to Counting Sheep")), 10_000))
                screenshot("introduction")
                click("Begin as a local guest")
            }
            if (!app.coordinator.state.farm.welcome.acknowledged) {
                screenshot("welcome")
                click("Open my Farm")
            }
            main {
                assertEquals("starterSheep", app.coordinator.state.farm.welcome.grant!!.kind)
                assertEquals(1, app.coordinator.state.farm.sheep.count { it.id == GuestFarmActions.starterID })
            }
            click("Farm")
            val beforeWool = app.coordinator.state.farm.wool
            click("Shear Mabel • 1 wool")
            main {
                assertEquals(beforeWool + 1, app.coordinator.state.farm.wool)
                assertEquals(1, app.coordinator.state.farm.shears.size)
                assertTrue(app.coordinator.shear(GuestFarmActions.starterID, 1))
                assertEquals(beforeWool + 1, app.coordinator.state.farm.wool)
                assertFalse(app.coordinator.shear(GuestFarmActions.starterID, 2))
                assertEquals(app.coordinator.state.farm, com.ngawangchime.countingsheep.prototype.data.SessionStore(app.filesDir).load().farm)
            }
            screenshot("sheared-farm")
            shell("settings put system font_scale 1.5")
            device.setOrientationLeft()
            var regrowing = device.wait(Until.findObject(By.text("Shear Mabel • 1 wool")), 1_000)
            repeat(7) {
                if (regrowing == null) {
                    device.swipe(device.displayWidth / 2, device.displayHeight * 3 / 5, device.displayWidth / 2, device.displayHeight / 3, 20)
                    regrowing = device.wait(Until.findObject(By.text("Shear Mabel • 1 wool")), 500)
                }
            }
            assertNotNull("Regrowing sheep remains reachable with large text in landscape", regrowing)
            // Move the whole button clear of the bottom navigation before inspecting and tapping it.
            device.swipe(device.displayWidth / 2, device.displayHeight * 3 / 5, device.displayWidth / 2, device.displayHeight / 3, 20)
            regrowing = device.wait(Until.findObject(By.text("Shear Mabel • 1 wool")), 3_000)
            assertNotNull(regrowing)
            // Compose exposes the label as an enabled child of the disabled button.
            val ancestry = generateSequence(regrowing!!) { it.parent }.take(6).toList()
            assertTrue("Disabled shear button ancestry: ${ancestry.map { "${it.className}:${it.isEnabled}" }}", ancestry.any { !it.isEnabled })
            regrowing!!.click()
            main { assertEquals(beforeWool + 1, app.coordinator.state.farm.wool); assertEquals(1, app.coordinator.state.farm.shears.size) }
            screenshot("sheared-farm-large-landscape")
            shell("settings put system font_scale 1.0"); device.setOrientationNatural(); device.unfreezeRotation()
            click("Home")
            click(if (app.coordinator.state.nightPreferences == null) "Set up usual plan" else "Edit usual plan")
            click("Save usual plan")
            main { assertNotNull(app.coordinator.state.nightPreferences); assertFalse(app.coordinator.live()) }
            screenshot("guest-plan-home")
            click("Settings"); click("I consent to package-only protection")
            click("Isolated blocker target")
            main { assertTrue(app.coordinator.state.selection.contains(instrumentation.context.packageName)) }
            click("Home")
            click(if (device.hasObject(By.text("Start Phone Away"))) "Start Phone Away" else "Choose Phone Away instead")
            click("Start now")
            assertTrue(device.wait(Until.hasObject(By.text("Phone Away is running")), 5_000))
            click("Five-minute Brief Access")
            assertTrue(device.wait(Until.hasObject(By.text("Confirmation phrase")), 5_000))
            device.wait(Until.findObject(By.clazz("android.widget.EditText")), 5_000)!!.text = "wrong"
            device.findObject(By.text("Open apps for five minutes")).click()
            main { assertTrue(app.coordinator.state.session!!.access.isEmpty()) }
            device.wait(Until.findObject(By.clazz("android.widget.EditText")), 5_000)!!.text = "Put my phone away"
            click("Open apps for five minutes")
            main { assertTrue(app.coordinator.state.session!!.access.single().committed) }
            screenshot("guest-live-access")
            click("End Phone Away")
            device.wait(Until.findObject(By.clazz("android.widget.EditText")), 5_000)!!.text = "Put my phone away"
            click("Confirm")
            assertTrue(device.wait(Until.hasObject(By.text("Phone Away receipt")), 5_000))
            screenshot("guest-phone-receipt")
            click("See Farm progress"); assertTrue(device.wait(Until.hasObject(By.text("Ollie's search trails")), 5_000))
            screenshot("guest-farm")
            // Synthetic timestamps exercise the actual coordinator and UI without overnight waiting or OS clock changes.
            main {
                val now = System.currentTimeMillis()
                assertTrue(app.coordinator.startWindDown(NightPlan(now - 60_000, now + 60_000, now + 31 * 60_000, 1, 30, "UTC", "2026-10-1")))
                app.synchronize()
            }
            click("Home"); click("Start Morning now"); click("Start Morning")
            assertTrue(device.wait(Until.hasObject(By.text("Screen-Free Morning is running")), 5_000))
            main { assertEquals("ended", app.coordinator.state.session!!.status); assertEquals("active", app.coordinator.state.mornings.last().outcome) }
            val countdown = device.wait(Until.findObject(By.text(java.util.regex.Pattern.compile("\\d+:\\d{2}:\\d{2}"))), 5_000)!!.text.split(':').map(String::toInt)
            assertTrue("New Morning countdown stays within its window", countdown[0] * 3600 + countdown[1] * 60 + countdown[2] <= 1800)
            screenshot("guest-early-morning")
            main {
                val morning = app.coordinator.state.mornings.last()
                app.coordinator.end("completed", at = morning.end, expectedOccurrence = morning.id); app.synchronize()
            }
            assertTrue(device.wait(Until.hasObject(By.text("Wind Down receipt")), 5_000))
            screenshot("guest-night-morning-receipt")
            click("See Farm progress"); click("Nights")
            click("Home"); click("Start Screen-Free Morning"); click("Start now")
            assertTrue(device.wait(Until.hasObject(By.text("Screen-Free Morning is running")), 5_000))
            click("Emergency exit — open apps now")
            assertTrue(device.wait(Until.hasObject(By.text("Screen-Free Morning receipt")), 5_000))
            main {
                val farm = app.coordinator.state.farm
                app.coordinator.replay(); assertEquals(farm, app.coordinator.state.farm)
                assertEquals("localGuest", app.coordinator.state.scope); assertFalse(app.coordinator.live())
            }
            click("See Farm progress")
            shell("settings put system font_scale 1.5")
            click("Settings"); click("Edit usual plan")
            screenshot("guest-plan-large-text")
            device.setOrientationLeft()
            assertTrue(device.wait(Until.hasObject(By.text("Your usual plan")), 5_000))
            screenshot("guest-plan-landscape")
            click("Save usual plan")
            main { assertFalse(app.coordinator.live()) }
        } finally {
            shell("settings put system font_scale 1.0"); device.setOrientationNatural(); device.unfreezeRotation()
            main { app.cancelGuestAction(); app.coordinator.end("emergency"); app.synchronize() }
            shell("settings delete secure enabled_accessibility_services"); shell("settings put secure accessibility_enabled 0")
        }
    }
}
