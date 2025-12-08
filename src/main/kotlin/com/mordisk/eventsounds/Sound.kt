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
import java.io.File
import java.io.FileInputStream

private val log = Logger.getInstance(Sound::class.java)

@Suppress("NULLABILITY_MISMATCH_BASED_ON_JAVA_ANNOTATIONS")
class Sound(private val name: String) {

    var player: Player? = null

    /**
     * Play a sound. If [customPath] is provided and points to an existing file, that file is used.
     * Otherwise, a bundled resource with the name provided in the constructor is used.
     */
    fun play(customPath: String? = null) {
        val resourceFilename = "$name.mp3"
        try {
            // Stop currently playing sound for this instance before starting new one
            stop()

            val input = if (!customPath.isNullOrBlank()) {
                val file = File(customPath)
                if (file.exists() && file.isFile) {
                    BufferedInputStream(FileInputStream(file))
                } else {
                    log.warn("Custom sound path not found or not a file: ${'$'}customPath. Falling back to resource ${'$'}resourceFilename")
                    BufferedInputStream(javaClass.getResourceAsStream(resourceFilename))
                }
            } else {
                BufferedInputStream(javaClass.getResourceAsStream(resourceFilename))
            }

            player = Player(input)
            // run in new thread to play in background
            object : Thread("EventSounds-Player-${'$'}name") {
                override fun run() {
                    try {
                        player?.play()
                    } catch (e: Exception) {
                        log.error("Problem playing sound ${'$'}{customPath ?: resourceFilename}", e)
                    }
                }
            }.start()
        } catch (e: Exception) {
            log.error("Problem preparing sound ${'$'}{customPath ?: resourceFilename}", e)
        }
    }

    fun stop() {
        player?.close()
    }
}
