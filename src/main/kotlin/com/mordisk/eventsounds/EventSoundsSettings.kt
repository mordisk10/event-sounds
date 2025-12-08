package com.mordisk.eventsounds

import com.intellij.openapi.components.*

data class SettingsState(
    var enableOnRunStart: Boolean = true,
    var enableOnRunNotStarted: Boolean = true,
    var customRunStartPath: String = "",
    var customRunNotStartedPath: String = ""
)

@State(name = "EventSoundsSettings", storages = [Storage("EventSoundsSettings.xml")])
@Service(Service.Level.APP)
class EventSoundsSettings : PersistentStateComponent<SettingsState> {
    private var state = SettingsState()

    override fun getState(): SettingsState = state

    override fun loadState(state: SettingsState) {
        this.state = state
    }

    companion object {
        @JvmStatic
        fun getInstance(): EventSoundsSettings = service()
    }
}
