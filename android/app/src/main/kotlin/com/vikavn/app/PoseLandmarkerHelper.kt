package com.vikavn.app

import android.content.Context
import android.graphics.Bitmap
import android.os.SystemClock
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.components.containers.Landmark
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.roundToInt

class PoseLandmarkerHelper(
    context: Context,
    private val onResult: (Map<String, Any?>) -> Unit,
    private val onError: (String, String?) -> Unit,
) {
    private val appContext = context.applicationContext
    private var poseLandmarker: PoseLandmarker? = null
    private var lastSubmittedTimestampMs: Long = Long.MIN_VALUE
    private val pendingFrames = ConcurrentHashMap<Long, FramePayload>()
    @Volatile private var currentOrientationCode: String? = null
    @Volatile private var currentOrientationIsFrontCamera = true
    private var perfWindowStartMs = 0L
    private var perfResults = 0
    private var perfLatencyMs = 0L
    @Volatile private var activeDelegate = Delegate.CPU
    @Volatile private var gpuDisabled = false
    @Volatile private var gpuVerified = false
    @Volatile private var pendingCpuFallback = false

    init {
        setupPoseLandmarker()
    }

    fun setOrientation(orientation: String?, isFrontCamera: Boolean) {
        currentOrientationCode = orientation
        currentOrientationIsFrontCamera = isFrontCamera
    }

    fun setupPoseLandmarker() {
        clearPoseLandmarker()
        if (!gpuDisabled) {
            try {
                poseLandmarker = createPoseLandmarker(Delegate.GPU)
                activeDelegate = Delegate.GPU
                gpuVerified = false
                Log.d(TAG, "pose landmarker delegate=GPU")
                return
            } catch (exception: Exception) {
                gpuDisabled = true
                Log.w(TAG, "GPU delegate unavailable, using CPU: " + exception.message)
            }
        }
        poseLandmarker = createPoseLandmarker(Delegate.CPU)
        activeDelegate = Delegate.CPU
        Log.d(TAG, "pose landmarker delegate=CPU")
    }

    private fun createPoseLandmarker(delegate: Delegate): PoseLandmarker {
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath(MODEL_ASSET_NAME)
            .setDelegate(delegate)
            .build()

        val options = PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumPoses(1)
            .setMinPoseDetectionConfidence(0.5f)
            .setMinPosePresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .setResultListener(this::returnLivestreamResult)
            .setErrorListener(this::returnLivestreamError)
            .build()

        return PoseLandmarker.createFromOptions(appContext, options)
    }

    private fun scheduleCpuFallbackIfGpuUnverified(reason: String?) {
        if (activeDelegate != Delegate.GPU || gpuVerified) {
            return
        }
        gpuDisabled = true
        pendingCpuFallback = true
        Log.w(TAG, "GPU inference failed before first result, switching to CPU: " + reason)
    }

    fun clearPoseLandmarker() {
        poseLandmarker?.close()
        poseLandmarker = null
        releasePendingFrames()
        lastSubmittedTimestampMs = Long.MIN_VALUE
    }

    fun releasePendingFrames() {
        pendingFrames.values.forEach { it.onComplete() }
        pendingFrames.clear()
    }

    fun detectLiveStream(
        bitmap: Bitmap,
        timestampMs: Long,
        frameWidth: Int,
        frameHeight: Int,
        rotationDegrees: Int,
        rotationDurationMs: Double,
        isFrontCamera: Boolean,
        onComplete: () -> Unit,
    ): Boolean {
        var pendingTimestampMs: Long? = null

        if (pendingCpuFallback) {
            pendingCpuFallback = false
            setupPoseLandmarker()
        }

        try {
            val activeLandmarker = poseLandmarker ?: return false
            if (timestampMs <= lastSubmittedTimestampMs) {
                return false
            }

            val submittedTimestampMs = timestampMs
            pendingTimestampMs = submittedTimestampMs
            val reportScale = REPORTED_LONG_SIDE / maxOf(bitmap.width, bitmap.height).toDouble()
            pendingFrames[submittedTimestampMs] = FramePayload(
                frameWidth = frameWidth,
                frameHeight = frameHeight,
                imageWidth = (bitmap.width * reportScale).roundToInt(),
                imageHeight = (bitmap.height * reportScale).roundToInt(),
                rotationDegrees = rotationDegrees,
                rotationDurationMs = rotationDurationMs,
                isFrontCamera = isFrontCamera,
                orientation = currentOrientationCode,
                submittedAtMs = SystemClock.elapsedRealtime(),
                onComplete = onComplete,
            )
            trimPendingFrames()

            val mpImage = BitmapImageBuilder(bitmap).build()
            lastSubmittedTimestampMs = submittedTimestampMs
            activeLandmarker.detectAsync(mpImage, submittedTimestampMs)
            return true
        } catch (exception: Exception) {
            pendingTimestampMs?.let { timestamp ->
                pendingFrames.remove(timestamp)?.onComplete()
            }
            scheduleCpuFallbackIfGpuUnverified(exception.message)
            onError("pose_landmarker_detection", exception.message)
            return false
        }
    }

    private fun returnLivestreamResult(result: PoseLandmarkerResult, input: MPImage) {
        val timestampMs = result.timestampMs()
        val framePayload = pendingFrames.remove(timestampMs)

        try {
            if (framePayload == null) {
                return
            }
            gpuVerified = true
            recordPerf(SystemClock.elapsedRealtime() - framePayload.submittedAtMs)

            if (result.landmarks().isEmpty()) {
                onResult(framePayload.toEventPayload(timestampMs, emptyList(), emptyList()))
                return
            }

            val pose = result.landmarks().first()
            val worldPose = result.worldLandmarks().firstOrNull().orEmpty()

            val landmarkList = pose.mapIndexed { index, landmark ->
                landmarkToMap(index, landmark)
            }
            val worldLandmarkList = worldPose.mapIndexed { index, landmark ->
                worldLandmarkToMap(index, landmark)
            }

            onResult(framePayload.toEventPayload(timestampMs, landmarkList, worldLandmarkList))
        } catch (exception: Exception) {
            onError("pose_landmarker_result", exception.message)
        } finally {
            input.close()
            framePayload?.onComplete()
        }
    }

    private fun returnLivestreamError(exception: RuntimeException) {
        scheduleCpuFallbackIfGpuUnverified(exception.message)
        onError("pose_landmarker_stream", exception.message)
    }

    private fun landmarkToMap(index: Int, landmark: NormalizedLandmark): Map<String, Any> {
        return mapOf(
            "type" to index,
            "x" to landmark.x(),
            "y" to landmark.y(),
            "z" to landmark.z(),
            "presence" to landmark.presence()
                .orElse(landmark.visibility().orElse(0.0f)),
            "visibility" to landmark.visibility()
                .orElse(landmark.presence().orElse(0.0f)),
            "likelihood" to landmark.visibility()
                .orElse(landmark.presence().orElse(0.0f)),
        )
    }

    private fun worldLandmarkToMap(index: Int, landmark: Landmark): Map<String, Any> {
        return mapOf(
            "type" to index,
            "x" to landmark.x(),
            "y" to landmark.y(),
            "z" to landmark.z(),
            "presence" to landmark.presence()
                .orElse(landmark.visibility().orElse(0.0f)),
            "visibility" to landmark.visibility()
                .orElse(landmark.presence().orElse(0.0f)),
            "likelihood" to landmark.visibility()
                .orElse(landmark.presence().orElse(0.0f)),
        )
    }

    private fun recordPerf(latencyMs: Long) {
        val now = SystemClock.elapsedRealtime()
        if (perfWindowStartMs == 0L) {
            perfWindowStartMs = now
        }
        perfResults += 1
        perfLatencyMs += latencyMs
        val elapsedMs = now - perfWindowStartMs
        if (elapsedMs < PERF_LOG_WINDOW_MS) {
            return
        }
        Log.d(
            TAG,
            "perf resultFps=" + String.format("%.1f", perfResults * 1000.0 / elapsedMs) +
                " inferenceLatencyMs=" + (perfLatencyMs / perfResults) +
                " delegate=" + activeDelegate,
        )
        perfWindowStartMs = now
        perfResults = 0
        perfLatencyMs = 0L
    }

    private fun trimPendingFrames(maxEntries: Int = 4) {
        if (pendingFrames.size <= maxEntries) {
            return
        }

        val keysToDrop = pendingFrames.keys.toList().sorted().take(pendingFrames.size - maxEntries)
        for (key in keysToDrop) {
            pendingFrames.remove(key)?.onComplete()
        }
    }

    private data class FramePayload(
        val frameWidth: Int,
        val frameHeight: Int,
        val imageWidth: Int,
        val imageHeight: Int,
        val rotationDegrees: Int,
        val rotationDurationMs: Double,
        val isFrontCamera: Boolean,
        val orientation: String?,
        val submittedAtMs: Long,
        val onComplete: () -> Unit,
    ) {
        fun toEventPayload(
            timestampMs: Long,
            landmarks: List<Map<String, Any>>,
            worldLandmarks: List<Map<String, Any>>,
        ): Map<String, Any?> {
            return mapOf(
                "landmarks" to landmarks,
                "worldLandmarks" to worldLandmarks,
                "imageWidth" to imageWidth,
                "imageHeight" to imageHeight,
                "frameWidth" to frameWidth,
                "frameHeight" to frameHeight,
                "rotationDegrees" to rotationDegrees,
                "rotationDurationMs" to rotationDurationMs,
                "isFrontCamera" to isFrontCamera,
                "orientation" to orientation,
                "timestampMs" to timestampMs,
            )
        }
    }

    companion object {
        private const val TAG = "PoseLandmarkerHelper"
        private const val MODEL_ASSET_NAME = "pose_landmarker_lite.task"
        private const val REPORTED_LONG_SIDE = 1280.0
        private const val PERF_LOG_WINDOW_MS = 3000L
    }
}
