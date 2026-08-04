package com.mordisk.eventsounds

import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Guards the plugin's packaged audio.
 *
 * If a resource is renamed, moved out of the Kotlin package directory, or
 * dropped from the jar, every event silently stops making noise — the plugin
 * looks installed and does nothing. These tests turn that into a build failure.
 */
class BundledSoundsTest {

    private val events = listOf("success", "error")

    private fun bytesFor(event: String): ByteArray? =
        Sound::class.java.getResourceAsStream(SoundResolver.resourceNameFor(event))?.use { it.readBytes() }

    @Test
    fun `every event has a bundled sound on the classpath`() {
        events.forEach { event ->
            assertNotNull("Missing bundled resource for '$event'", bytesFor(event))
        }
    }

    @Test
    fun `bundled sounds are not empty`() {
        events.forEach { event ->
            val bytes = bytesFor(event)!!
            assertTrue("Bundled sound for '$event' is suspiciously small: ${bytes.size} bytes", bytes.size > 1024)
        }
    }

    @Test
    fun `bundled sounds are decodable mp3 files`() {
        events.forEach { event ->
            val bytes = bytesFor(event)!!
            assertTrue(
                "Bundled sound for '$event' does not start with an ID3 tag or MPEG frame sync",
                isMp3(bytes)
            )
        }
    }

    /** An MP3 starts either with an ID3v2 tag or directly with an MPEG frame sync word. */
    private fun isMp3(bytes: ByteArray): Boolean {
        if (bytes.size < 3) return false
        val id3 = bytes[0] == 'I'.code.toByte() && bytes[1] == 'D'.code.toByte() && bytes[2] == '3'.code.toByte()
        val frameSync = bytes[0] == 0xFF.toByte() && (bytes[1].toInt() and 0xE0) == 0xE0
        return id3 || frameSync
    }
}
