package com.mordisk.eventsounds

import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

/**
 * Covers the rule that decides what a given event actually plays.
 *
 * The important guarantee is the fallback: no matter how broken the configured
 * path is, an enabled event must still resolve to the bundled sound rather than
 * going silent.
 */
class SoundResolverTest {

    @get:Rule
    val tmp = TemporaryFolder()

    private fun bundled(name: String) = SoundSource.Bundled("$name.mp3")

    @Test
    fun `resource name is derived from the event name`() {
        assertEquals("success.mp3", SoundResolver.resourceNameFor("success"))
        assertEquals("error.mp3", SoundResolver.resourceNameFor("error"))
    }

    @Test
    fun `null path falls back to the bundled sound`() {
        assertEquals(bundled("success"), SoundResolver.resolve("success", null))
    }

    @Test
    fun `empty path falls back to the bundled sound`() {
        assertEquals(bundled("success"), SoundResolver.resolve("success", ""))
    }

    @Test
    fun `blank path falls back to the bundled sound`() {
        assertEquals(bundled("error"), SoundResolver.resolve("error", "   "))
    }

    @Test
    fun `missing file falls back to the bundled sound`() {
        val absent = File(tmp.root, "deleted-by-the-user.mp3")
        assertEquals(bundled("error"), SoundResolver.resolve("error", absent.absolutePath))
    }

    @Test
    fun `directory falls back to the bundled sound`() {
        val dir = tmp.newFolder("sounds")
        assertEquals(bundled("success"), SoundResolver.resolve("success", dir.absolutePath))
    }

    @Test
    fun `readable file is used instead of the bundled sound`() {
        val custom = tmp.newFile("airhorn.mp3")
        custom.writeBytes(byteArrayOf(1, 2, 3))

        assertEquals(
            SoundSource.CustomFile(custom),
            SoundResolver.resolve("success", custom.absolutePath)
        )
    }

    @Test
    fun `each event resolves to its own bundled sound`() {
        assertEquals(bundled("success"), SoundResolver.resolve("success", null))
        assertEquals(bundled("error"), SoundResolver.resolve("error", null))
    }
}
