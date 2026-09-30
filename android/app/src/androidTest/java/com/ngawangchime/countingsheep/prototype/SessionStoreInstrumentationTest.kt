package com.ngawangchime.countingsheep.prototype

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.ngawangchime.countingsheep.prototype.data.SessionStore
import com.ngawangchime.countingsheep.prototype.domain.PrototypeState
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class SessionStoreInstrumentationTest {
    @Test fun atomicRoundTripAndCorruptLatestAreRecoverableWithoutResumingProtection() {
        val directory = File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir, "isolated-store-test")
        directory.deleteRecursively(); directory.mkdirs()
        try {
            val store = SessionStore(directory)
            assertEquals(PrototypeState(), store.load())
            val first = PrototypeState(generation = 1, consent = true, selection = setOf("synthetic.package"))
            store.save(first)
            store.save(first.copy(generation = 2))
            assertEquals(2, SessionStore(directory).load().generation)
            val primary = File(directory, "session.json")
            primary.writeText("corrupt latest")
            val reopened = SessionStore(directory)
            val recovered = reopened.load()
            assertEquals(1, recovered.generation)
            assertTrue(recovered.repairRequired)
            assertThrows(IllegalStateException::class.java) { reopened.save(first.copy(generation = 3)) }
            assertEquals("corrupt latest", primary.readText())
        } finally { directory.deleteRecursively() }
    }
}
