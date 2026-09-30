package com.ngawangchime.countingsheep.prototype.data

import android.util.AtomicFile
import com.ngawangchime.countingsheep.prototype.domain.PrototypeState
import java.io.File

/** One internal transaction covers sessions, access, guest inventory and settlement; backup remains excluded. */
class SessionStore(directory: File, private val checkpoint: (String) -> Unit = {}) {
    private val primary = AtomicFile(File(directory, "session.json"))
    private val recovery = AtomicFile(File(directory, "session.recovery.json"))
    private var blocked = false
    fun load(): PrototypeState {
        if (!primary.baseFile.exists() && !File(primary.baseFile.path + ".bak").exists() && !recovery.baseFile.exists()) return PrototypeState()
        return try { SessionDocument.decode(primary.readFully()) } catch (_: Exception) {
            blocked = true
            val previous = runCatching { SessionDocument.decode(recovery.readFully()) }.getOrDefault(PrototypeState())
            previous.copy(repairRequired = true, failure = "Local file unreadable; original files preserved. Export before isolated reinstall.",
                session = previous.session?.copy(status = "failed", coverage = "Unknown; recovery file used"),
                mornings = previous.mornings.map { if (it.live) it.copy(outcome = "skipped", coverage = "Unknown; recovery file used") else it })
        }
    }
    private fun write(file: AtomicFile, bytes: ByteArray, name: String) {
        val stream = file.startWrite()
        try {
            stream.write(bytes)
            checkpoint("$name-before-finish")
            file.finishWrite(stream)
        } catch (error: Exception) { file.failWrite(stream); throw error }
    }
    fun save(state: PrototypeState) {
        check(!blocked) { "Preserved incompatible local storage" }
        val bytes = SessionDocument.encode(state)
        check(SessionDocument.decode(bytes) == state)
        if (primary.baseFile.exists()) write(recovery, primary.readFully(), "recovery")
        checkpoint("before-primary")
        write(primary, bytes, "primary")
        checkpoint("after-primary")
        check(SessionDocument.decode(primary.readFully()) == state)
    }
}
