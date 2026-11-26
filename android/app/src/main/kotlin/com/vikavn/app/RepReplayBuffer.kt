package com.vikavn.app

import android.graphics.Bitmap
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.roundToInt

class RepReplayBuffer {
    private class Clip(val frames: List<Pair<Long, Bitmap>>, val mirrored: Boolean)

    private val lock = Any()
    private val frames = ArrayDeque<Pair<Long, Bitmap>>()
    private val clips = HashMap<String, Clip>()
    private var lastCaptureMs = Long.MIN_VALUE
    private var mirrored = false

    @Volatile var enabled = false
        private set

    fun start() {
        synchronized(lock) {
            frames.clear()
            clips.clear()
            lastCaptureMs = Long.MIN_VALUE
            enabled = true
        }
    }

    fun stop() {
        enabled = false
    }

    fun offer(source: Bitmap, timestampMs: Long, isFrontCamera: Boolean) {
        if (!enabled) return
        if (lastCaptureMs != Long.MIN_VALUE && timestampMs - lastCaptureMs < CAPTURE_INTERVAL_MS) {
            return
        }
        lastCaptureMs = timestampMs
        val scale = THUMB_LONG_SIDE.toFloat() / max(source.width, source.height)
        val width = max(1, (source.width * scale).roundToInt())
        val height = max(1, (source.height * scale).roundToInt())
        val thumb = Bitmap.createScaledBitmap(source, width, height, true)
        synchronized(lock) {
            frames.addLast(timestampMs to thumb)
            while (frames.isNotEmpty() && timestampMs - frames.first().first > BUFFER_MS) {
                frames.removeFirst()
            }
            mirrored = isFrontCamera
        }
    }

    fun saveClip(id: String, durationMs: Long): Int {
        synchronized(lock) {
            val end = frames.lastOrNull()?.first ?: return 0
            val clip = frames.filter { it.first >= end - durationMs }
            clips[id] = Clip(clip, mirrored)
            return clip.size
        }
    }

    fun encodeClip(id: String): Map<String, Any>? {
        val clip = synchronized(lock) { clips[id] } ?: return null
        if (clip.frames.isEmpty()) return null
        val jpegs = clip.frames.map { (_, bitmap) ->
            ByteArrayOutputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)
                out.toByteArray()
            }
        }
        val first = clip.frames.first().second
        return mapOf(
            "frames" to jpegs,
            "timestampsMs" to clip.frames.map { it.first },
            "width" to first.width,
            "height" to first.height,
            "mirrored" to clip.mirrored,
        )
    }

    fun clear() {
        synchronized(lock) {
            enabled = false
            frames.clear()
            clips.clear()
        }
    }

    companion object {
        private const val CAPTURE_INTERVAL_MS = 90L
        private const val BUFFER_MS = 4000L
        private const val THUMB_LONG_SIDE = 320
        private const val JPEG_QUALITY = 75
    }
}
