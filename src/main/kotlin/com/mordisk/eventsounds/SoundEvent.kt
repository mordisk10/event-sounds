package com.mordisk.eventsounds

/**
 * The IDE moments this plugin reacts to.
 *
 * Each constant owns the whole mapping for one event: which bundled sound it
 * uses, which toggle enables it, and which custom-path setting overrides it.
 * Adding an event means adding a constant here and a row in the settings
 * screen, rather than threading a new pair of fields through the listener.
 *
 * Deliberately free of IntelliJ Platform types so it can be unit tested.
 */
enum class SoundEvent(val soundName: String) {

    /** A run or debug configuration launched successfully. */
    RUN_STARTED("success"),

    /** A run or debug configuration could not be launched at all. */
    RUN_FAILED_TO_START("error");

    fun isEnabledIn(state: SettingsState): Boolean = when (this) {
        RUN_STARTED -> state.enableOnRunStart
        RUN_FAILED_TO_START -> state.enableOnRunNotStarted
    }

    /** The user's custom file for this event, or null when none is configured. */
    fun customPathIn(state: SettingsState): String? = when (this) {
        RUN_STARTED -> state.customRunStartPath
        RUN_FAILED_TO_START -> state.customRunNotStartedPath
    }.ifBlank { null }

    /** What this event would actually play under [state]. */
    fun resolveSource(state: SettingsState): SoundSource =
        SoundResolver.resolve(soundName, customPathIn(state))
}
