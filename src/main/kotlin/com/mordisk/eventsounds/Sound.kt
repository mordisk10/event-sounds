/*
 * MIT License
 *
 * Copyright (c) 2018 Ivan Prymak
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */

package com.mordisk.eventsounds

import com.intellij.openapi.diagnostic.Logger
import javazoom.jl.player.Player
import java.io.BufferedInputStream
import java.io.FileInputStream
import java.io.InputStream

private val log = Logger.getInstance(Sound::class.java)

class Sound(private val name: String) {

    @Volatile
    var player: Player? = null
        private set

    /**
     * Play a sound. If [customPath] points at a readable file, that file is used;
     * otherwise the bundled sound for this instance's name is played.
     */
    fun play(customPath: String? = null) {
        val source = SoundResolver.resolve(name, customPath)
        try {
            // Stop whatever this instance is currently playing before starting again.
            stop()

            val input = openStream(source) ?: return
            val current = Player(input)
            player = current

            // Play off the calling thread so the IDE never waits on audio.
            object : Thread("EventSounds-Player-$name") {
                override fun run() {
                    try {
                        current.play()
                    } catch (e: Exception) {
                        log.warn("Problem playing sound $source", e)
                    } finally {
                        current.close()
                    }
                }
            }.start()
        } catch (e: Exception) {
            log.warn("Problem preparing sound $source", e)
        }
    }

    private fun openStream(source: SoundSource): InputStream? = when (source) {
        is SoundSource.CustomFile -> BufferedInputStream(FileInputStream(source.file))
        is SoundSource.Bundled -> {
            val stream = javaClass.getResourceAsStream(source.resourceName)
            if (stream == null) {
                log.warn("Bundled sound ${source.resourceName} is missing from the plugin jar")
                null
            } else {
                BufferedInputStream(stream)
            }
        }
    }

    fun stop() {
        player?.close()
        player = null
    }
}
