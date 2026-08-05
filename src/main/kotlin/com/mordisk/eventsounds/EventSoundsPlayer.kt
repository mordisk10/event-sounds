package com.mordisk.eventsounds

import com.intellij.openapi.Disposable
import com.intellij.openapi.components.Service
import com.intellij.openapi.components.service

/**
 * Owns the audio for the whole IDE.
 *
 * Application-scoped on purpose: sounds belong to the user, not to a project.
 * When several projects are open, a run in one of them should interrupt a sound
 * started by another rather than layering on top of it.
 */
@Service(Service.Level.APP)
class EventSoundsPlayer : Disposable {

    // values() rather than entries: the Kotlin stdlib comes from the target
    // platform, which is older than the compiler and has no EnumEntries.
    private val sounds = SoundEvent.values().associateWith { Sound(it.soundName) }

    fun play(event: SoundEvent) {
        val state = EventSoundsSettings.getInstance().state
        if (!event.isEnabledIn(state)) return

        stopAll()
        sounds.getValue(event).play(event.customPathIn(state))
    }

    fun stopAll() = sounds.values.forEach(Sound::stop)

    override fun dispose() = stopAll()

    companion object {
        fun getInstance(): EventSoundsPlayer = service()
    }
}
