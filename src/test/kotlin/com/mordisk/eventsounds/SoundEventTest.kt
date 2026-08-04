package com.mordisk.eventsounds

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Covers the mapping from an IDE event to the settings that govern it.
 *
 * This is where a wiring mistake would be invisible at runtime: crossing the
 * two events would make a failed run play the success sound, and nothing would
 * crash to reveal it.
 */
class SoundEventTest {

    @Test
    fun `each event uses its own bundled sound`() {
        assertEquals("success", SoundEvent.RUN_STARTED.soundName)
        assertEquals("error", SoundEvent.RUN_FAILED_TO_START.soundName)
    }

    @Test
    fun `every event is enabled by default`() {
        val fresh = SettingsState()
        SoundEvent.entries.forEach { event ->
            assertTrue("$event should be enabled on a fresh install", event.isEnabledIn(fresh))
        }
    }

    @Test
    fun `each event reads its own enable toggle`() {
        val onlyRunStart = SettingsState(enableOnRunStart = true, enableOnRunNotStarted = false)
        assertTrue(SoundEvent.RUN_STARTED.isEnabledIn(onlyRunStart))
        assertFalse(SoundEvent.RUN_FAILED_TO_START.isEnabledIn(onlyRunStart))

        val onlyFailure = SettingsState(enableOnRunStart = false, enableOnRunNotStarted = true)
        assertFalse(SoundEvent.RUN_STARTED.isEnabledIn(onlyFailure))
        assertTrue(SoundEvent.RUN_FAILED_TO_START.isEnabledIn(onlyFailure))
    }

    @Test
    fun `each event reads its own custom path`() {
        val state = SettingsState(
            customRunStartPath = "/sounds/tada.mp3",
            customRunNotStartedPath = "/sounds/trombone.mp3"
        )
        assertEquals("/sounds/tada.mp3", SoundEvent.RUN_STARTED.customPathIn(state))
        assertEquals("/sounds/trombone.mp3", SoundEvent.RUN_FAILED_TO_START.customPathIn(state))
    }

    @Test
    fun `an unset custom path reads as null rather than empty`() {
        val fresh = SettingsState()
        SoundEvent.entries.forEach { event ->
            assertNull("$event should report no custom path", event.customPathIn(fresh))
        }
    }

    @Test
    fun `a whitespace-only custom path reads as null`() {
        val state = SettingsState(customRunStartPath = "   ")
        assertNull(SoundEvent.RUN_STARTED.customPathIn(state))
    }

    @Test
    fun `default settings resolve every event to its bundled sound`() {
        val fresh = SettingsState()
        assertEquals(SoundSource.Bundled("success.mp3"), SoundEvent.RUN_STARTED.resolveSource(fresh))
        assertEquals(SoundSource.Bundled("error.mp3"), SoundEvent.RUN_FAILED_TO_START.resolveSource(fresh))
    }

    @Test
    fun `a stale custom path still resolves to the bundled sound`() {
        val state = SettingsState(customRunStartPath = "/nowhere/deleted.mp3")
        assertEquals(SoundSource.Bundled("success.mp3"), SoundEvent.RUN_STARTED.resolveSource(state))
    }
}
