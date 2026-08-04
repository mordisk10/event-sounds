package com.mordisk.eventsounds

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Covers the persisted settings object.
 *
 * Defaults matter more than they look: they are what every user sees on a fresh
 * install, and a flipped default would ship a plugin that is silent out of the box.
 */
class EventSoundsSettingsTest {

    @Test
    fun `both events are enabled on a fresh install`() {
        val state = SettingsState()
        assertTrue("Run Start should make noise by default", state.enableOnRunStart)
        assertTrue("Run Failed should make noise by default", state.enableOnRunNotStarted)
    }

    @Test
    fun `no custom sounds are configured on a fresh install`() {
        val state = SettingsState()
        assertEquals("", state.customRunStartPath)
        assertEquals("", state.customRunNotStartedPath)
    }

    @Test
    fun `fresh defaults resolve to the bundled sounds`() {
        val state = SettingsState()
        assertEquals(
            SoundSource.Bundled("success.mp3"),
            SoundResolver.resolve("success", state.customRunStartPath.ifBlank { null })
        )
        assertEquals(
            SoundSource.Bundled("error.mp3"),
            SoundResolver.resolve("error", state.customRunNotStartedPath.ifBlank { null })
        )
    }

    @Test
    fun `loaded state is handed back unchanged`() {
        val settings = EventSoundsSettings()
        val loaded = SettingsState(
            enableOnRunStart = false,
            enableOnRunNotStarted = true,
            customRunStartPath = "/home/dev/sounds/tada.mp3",
            customRunNotStartedPath = ""
        )

        settings.loadState(loaded)

        assertSame(loaded, settings.state)
        assertEquals(false, settings.state.enableOnRunStart)
        assertEquals("/home/dev/sounds/tada.mp3", settings.state.customRunStartPath)
    }

    @Test
    fun `edits made through the settings screen survive on the state object`() {
        val settings = EventSoundsSettings()

        // Mirrors what EventSoundsConfigurable.apply() does.
        settings.state.enableOnRunStart = false
        settings.state.customRunNotStartedPath = "/home/dev/sounds/sad-trombone.mp3"

        assertEquals(false, settings.state.enableOnRunStart)
        assertEquals("/home/dev/sounds/sad-trombone.mp3", settings.state.customRunNotStartedPath)
    }

    @Test
    fun `states with the same values compare equal`() {
        assertEquals(SettingsState(), SettingsState())
        assertEquals(
            SettingsState(enableOnRunStart = false),
            SettingsState(enableOnRunStart = false)
        )
    }
}
