package com.mordisk.eventsounds

import java.io.File

/**
 * Where the audio bytes for a sound come from.
 *
 * Kept free of IntelliJ Platform types so the decision can be unit tested
 * without booting the IDE.
 */
sealed class SoundSource {
    /** A file the user picked in the settings screen. */
    data class CustomFile(val file: File) : SoundSource()

    /** A sound shipped inside the plugin jar, resolved next to [SoundSource]. */
    data class Bundled(val resourceName: String) : SoundSource()
}

/**
 * Decides which file a given event should actually play.
 *
 * The rule: a custom file wins, but only when it is genuinely usable. Anything
 * else — no path set, a path that no longer exists, a directory, a file the IDE
 * cannot read — falls back to the sound bundled with the plugin, so a stale
 * setting can never leave an event silent.
 */
object SoundResolver {

    fun resourceNameFor(name: String): String = "$name.mp3"

    fun resolve(name: String, customPath: String?): SoundSource {
        val bundled = SoundSource.Bundled(resourceNameFor(name))
        if (customPath.isNullOrBlank()) return bundled

        val file = File(customPath)
        return if (file.isFile && file.canRead()) SoundSource.CustomFile(file) else bundled
    }
}
