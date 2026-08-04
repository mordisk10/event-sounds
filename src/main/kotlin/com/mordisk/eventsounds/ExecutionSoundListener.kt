package com.mordisk.eventsounds

import com.intellij.execution.ExecutionListener
import com.intellij.execution.process.ProcessHandler
import com.intellij.execution.runners.ExecutionEnvironment

/**
 * Bridges the IDE's execution message bus to the sound player.
 *
 * Registered declaratively through `<projectListeners>` in plugin.xml, which
 * replaces the deprecated `ProjectComponent` registration this plugin used
 * previously. The platform instantiates it lazily, per project, the first time
 * an execution event fires.
 */
class ExecutionSoundListener : ExecutionListener {

    override fun processStarted(executorId: String, env: ExecutionEnvironment, handler: ProcessHandler) {
        EventSoundsPlayer.getInstance().play(SoundEvent.RUN_STARTED)
    }

    override fun processNotStarted(executorId: String, env: ExecutionEnvironment) {
        EventSoundsPlayer.getInstance().play(SoundEvent.RUN_FAILED_TO_START)
    }
}
