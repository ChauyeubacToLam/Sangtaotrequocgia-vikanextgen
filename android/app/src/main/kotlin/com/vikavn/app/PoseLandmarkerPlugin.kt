package com.vikavn.app

import android.annotation.SuppressLint
import android.graphics.Bitmap
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CaptureRequest
import android.graphics.Matrix
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.util.Range
import android.util.Size
import android.view.Surface
import androidx.camera.camera2.interop.Camera2CameraInfo
import androidx.camera.camera2.interop.Camera2Interop
import androidx.camera.core.ExtendableBuilder
import androidx.camera.core.ImageProxy
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class PoseLandmarkerPlugin(
    private val activity: FlutterActivity,
    flutterEngine: FlutterEngine,
    private val segmentationHelper: SelfieSegmentationHelper?,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val methodChannel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        METHOD_CHANNEL_NAME,
    )
    private val eventChannel = EventChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        EVENT_CHANNEL_NAME,
    )
    private val textureRegistry: TextureRegistry = flutterEngine.renderer
    private val mainHandler = Handler(Looper.getMainLooper())

    private var eventSink: EventChannel.EventSink? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var previewSurface: Surface? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var cameraExecutor: ExecutorService? = null
    private var preview: Preview? = null
    private var imageAnalysis: ImageAnalysis? = null
    @Volatile private var poseLandmarkerHelper: PoseLandmarkerHelper? = null
    private val landmarkerExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val landmarkerLoading = AtomicBoolean(false)
    private val replayBuffer = RepReplayBuffer()
    private val replayExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var useFrontCamera = true
    @Volatile private var currentOrientationCode: String? = null
    @Volatile private var currentOrientationIsFrontCamera = true
    @Volatile private var currentTargetRotation: Int? = null
    @Volatile private var previewGeometry: PreviewGeometry? = null
    private val previewBindingGeneration = AtomicInteger(0)
    private var rotationLogFrameCount = 0
    private var detectionEnabled = true
    // Last frame timestamp (ms) that passed the analysis throttle. Read/written
    // only on the single-threaded cameraExecutor, mirroring the segmentation
    // helper's throttle; @Volatile keeps it visible to a fresh executor after
    // a pause/resume re-bind.
    @Volatile private var lastAnalyzedTimestampMs = Long.MIN_VALUE
    private var aeFpsRange: Range<Int>? = null
    private var perfWindowStartMs = 0L
    private var perfCameraFrames = 0
    private var perfAnalyzedFrames = 0
    private var perfConvertNs = 0L

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "warmUp" -> {
                try {
                    ensureRuntimeSupport()
                    ensurePoseLandmarkerAsync()
                } catch (_: Exception) {
                }
                result.success(null)
            }
            "setOrientation" -> {
                val orientation = call.argument<String>("orientation")
                if (orientation == null) {
                    result.error("pose_landmarker_orientation", "Missing orientation.", null)
                    return
                }
                val isFrontCamera = call.argument<Boolean>("isFrontCamera") ?: useFrontCamera
                setOrientation(orientation, isFrontCamera)
                result.success(null)
            }
            "dispose" -> {
                disposeResources(releaseTexture = true)
                result.success(null)
            }
            "switchCamera" -> {
                val previousLens = useFrontCamera
                try {
                    useFrontCamera = !useFrontCamera
                    currentOrientationCode?.let { orientation ->
                        setOrientation(orientation, useFrontCamera)
                    }
                    bindCameraUseCases()
                    result.success(null)
                } catch (exception: Exception) {
                    useFrontCamera = previousLens
                    result.error("pose_landmarker_switch_camera", exception.message, null)
                }
            }
            "startDetection" -> {
                detectionEnabled = true
                result.success(null)
            }
            "stopDetection" -> {
                detectionEnabled = false
                result.success(null)
            }
            "startReplayCapture" -> {
                replayBuffer.start()
                result.success(null)
            }
            "stopReplayCapture" -> {
                replayBuffer.stop()
                result.success(null)
            }
            "saveReplayClip" -> {
                val id = call.argument<String>("id")
                val durationMs = call.argument<Number>("durationMs")?.toLong()
                if (id == null || durationMs == null) {
                    result.error("replay_clip", "Missing id or durationMs.", null)
                    return
                }
                result.success(replayBuffer.saveClip(id, durationMs))
            }
            "loadReplayClip" -> {
                val id = call.argument<String>("id")
                if (id == null) {
                    result.error("replay_clip", "Missing id.", null)
                    return
                }
                replayExecutor.execute {
                    val clip = try {
                        replayBuffer.encodeClip(id)
                    } catch (_: Throwable) {
                        null
                    }
                    mainHandler.post { result.success(clip) }
                }
            }
            "clearReplayClips" -> {
                replayBuffer.clear()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun dispose() {
        disposeResources(releaseTexture = true)
        poseLandmarkerHelper?.clearPoseLandmarker()
        poseLandmarkerHelper = null
        landmarkerExecutor.shutdown()
        replayBuffer.clear()
        replayExecutor.shutdown()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    private fun ensurePoseLandmarkerAsync() {
        if (poseLandmarkerHelper != null || !landmarkerLoading.compareAndSet(false, true)) {
            return
        }
        landmarkerExecutor.execute {
            try {
                poseLandmarkerHelper = PoseLandmarkerHelper(
                    context = activity.applicationContext,
                    onResult = ::emitResult,
                    onError = ::emitError,
                )
            } catch (error: Throwable) {
                emitError("pose_landmarker_init", errorMessageForRuntime(error))
            } finally {
                landmarkerLoading.set(false)
            }
        }
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        useFrontCamera = call.argument<Boolean>("useFrontCamera") ?: true
        applyInitialOrientation(call)
        detectionEnabled = true

        try {
            ensureRuntimeSupport()

            if (textureEntry == null) {
                textureEntry = textureRegistry.createSurfaceTexture()
            }
            if (cameraExecutor == null || cameraExecutor?.isShutdown == true) {
                cameraExecutor = Executors.newSingleThreadExecutor()
            }
            ensurePoseLandmarkerAsync()
            poseLandmarkerHelper?.setOrientation(
                currentOrientationCode,
                currentOrientationIsFrontCamera,
            )
            segmentationHelper?.setOrientation(
                currentOrientationCode,
                currentOrientationIsFrontCamera,
            )

            val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)
            cameraProviderFuture.addListener(
                {
                    try {
                        cameraProvider = cameraProviderFuture.get()
                        bindCameraUseCases()
                        result.success(textureEntry?.id())
                    } catch (exception: Exception) {
                        result.error("pose_landmarker_init", exception.message, null)
                    }
                },
                ContextCompat.getMainExecutor(activity),
            )
        } catch (error: UnsatisfiedLinkError) {
            disposeResources(releaseTexture = false)
            result.error("pose_landmarker_init", errorMessageForRuntime(error), null)
        } catch (exception: Exception) {
            disposeResources(releaseTexture = false)
            result.error("pose_landmarker_init", exception.message, null)
        }
    }

    private fun applyInitialOrientation(call: MethodCall) {
        val initialOrientation = call.argument<String>("initialOrientation")
        if (initialOrientation == null) {
            currentOrientationCode = null
            currentOrientationIsFrontCamera = useFrontCamera
            currentTargetRotation = null
            poseLandmarkerHelper?.setOrientation(null, useFrontCamera)
            segmentationHelper?.setOrientation(null, useFrontCamera)
            return
        }

        val isFrontCamera = call.argument<Boolean>("isFrontCamera") ?: useFrontCamera
        setOrientation(initialOrientation, isFrontCamera)
    }

    private fun setOrientation(orientation: String, isFrontCamera: Boolean) {
        val previousTargetRotation = currentTargetRotation
        currentOrientationCode = orientation
        currentOrientationIsFrontCamera = isFrontCamera
        currentTargetRotation = targetRotationForOrientation(orientation)

        // Push the new rotation onto the existing use cases. For
        // ImageAnalysis this is enough — `imageInfo.rotationDegrees` updates
        // for subsequent frames, and the analyzer rotates the bitmap before
        // handing it to MediaPipe. For Preview the targetRotation property is
        // best-effort metadata (CameraX only re-rotates the Surface buffer
        // when the SurfaceRequest is re-issued), so the actual rebind below
        // is what makes the on-screen preview follow the device.
        currentTargetRotation?.let { targetRotation ->
            preview?.targetRotation = targetRotation
            imageAnalysis?.targetRotation = targetRotation
        }

        poseLandmarkerHelper?.setOrientation(orientation, isFrontCamera)
        segmentationHelper?.setOrientation(orientation, isFrontCamera)

        // When the device actually rotates we re-bind the use cases so
        // CameraX issues a new SurfaceRequest. The new SurfaceTexture frames
        // carry an updated transform matrix encoding the new rotation, and
        // Flutter's engine applies that matrix during shader sampling — same
        // mechanism native TextureView uses. This keeps the GPU camera
        // pipeline intact (no per-frame CPU blit) and matches the pattern the
        // canonical CameraX "transform-output" guidance recommends.
        if (currentTargetRotation != previousTargetRotation &&
            cameraProvider != null
        ) {
            try {
                bindCameraUseCases()
            } catch (exception: Exception) {
                emitError("pose_landmarker_orientation_rebind", exception.message)
            }
        }
    }

    private fun ensureRuntimeSupport() {
        val supportedAbis = Build.SUPPORTED_ABIS?.toList().orEmpty()
        if (supportedAbis.any { it.equals("x86_64", ignoreCase = true) }) {
            throw IllegalStateException(
                "MediaPipe Pose Landmarker is not available on x86_64 Android emulators. Use a physical ARM phone or an ARM emulator image."
            )
        }
    }

    private fun errorMessageForRuntime(error: Throwable): String {
        val message = error.message.orEmpty()
        if (message.contains("libmediapipe_tasks_vision_jni.so")) {
            return "MediaPipe Pose Landmarker native library could not be loaded on this device. Use a physical ARM phone or an ARM emulator image."
        }
        return message.ifBlank { "Failed to initialize MediaPipe Pose Landmarker." }
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun bindCameraUseCases() {
        val provider = cameraProvider ?: throw IllegalStateException("Camera provider is not ready.")
        val surfaceTextureEntry =
            textureEntry ?: throw IllegalStateException("Flutter texture is not initialized.")
        val executor = cameraExecutor ?: throw IllegalStateException("Camera executor is not ready.")

        val cameraSelector = resolveCameraSelector(provider)
        currentOrientationIsFrontCamera = useFrontCamera
        poseLandmarkerHelper?.setOrientation(currentOrientationCode, useFrontCamera)
        segmentationHelper?.setOrientation(currentOrientationCode, useFrontCamera)

        aeFpsRange = preferredAeFpsRange(provider, cameraSelector)
        val bindingGeneration = previewBindingGeneration.incrementAndGet()
        previewGeometry = null
        provider.unbindAll()

        // Preview writes camera frames straight to the Flutter SurfaceTexture
        // through CameraX's GPU pipeline. The SurfaceTexture's transform
        // matrix carries the rotation information; Flutter Android's engine
        // (`SurfaceTextureExternalTexture::DrawFrame`) applies that matrix
        // when sampling the OES texture, so no per-frame CPU work is needed
        // to display the preview correctly. Re-binding on rotation change
        // (in `setOrientation`) is what keeps that matrix up to date.
        val previewUseCase = Preview.Builder()
            .setTargetResolution(Size(PREVIEW_WIDTH, PREVIEW_HEIGHT))
            .apply { applyAeFpsRange(this) }
            .build()
            .also { configuredPreview ->
                currentTargetRotation?.let { configuredPreview.targetRotation = it }
                configuredPreview.setSurfaceProvider { request ->
                    // A CameraX Preview is the raw buffer plus this transform
                    // metadata. ImageAnalysis has a separate output geometry,
                    // so Flutter must not size the Texture from pose-frame
                    // dimensions when the device rotates.
                    request.setTransformationInfoListener(executor) { info ->
                        if (previewBindingGeneration.get() != bindingGeneration) {
                            return@setTransformationInfoListener
                        }

                        val cropRect = info.cropRect
                        previewGeometry = PreviewGeometry(
                            bufferWidth = request.resolution.width,
                            bufferHeight = request.resolution.height,
                            cropLeft = cropRect.left,
                            cropTop = cropRect.top,
                            cropRight = cropRect.right,
                            cropBottom = cropRect.bottom,
                            rotationDegrees = info.rotationDegrees,
                        )
                    }

                    val surfaceTexture = surfaceTextureEntry.surfaceTexture()
                    surfaceTexture.setDefaultBufferSize(
                        request.resolution.width,
                        request.resolution.height,
                    )

                    val surface = Surface(surfaceTexture)
                    previewSurface = surface

                    request.provideSurface(surface, executor) {
                        if (previewSurface === surface) {
                            previewSurface = null
                        }
                        surface.release()
                    }
                }
            }

        val analysisUseCase = ImageAnalysis.Builder()
            .setTargetResolution(Size(ANALYSIS_WIDTH, ANALYSIS_HEIGHT))
            .apply { applyAeFpsRange(this) }
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .setOutputImageRotationEnabled(true)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build()
            .also { configuredAnalysis ->
                currentTargetRotation?.let { configuredAnalysis.targetRotation = it }
                configuredAnalysis.setAnalyzer(executor) { imageProxy ->
                    if (!detectionEnabled) {
                        imageProxy.close()
                        return@setAnalyzer
                    }

                    analyzeFrame(imageProxy)
                }
            }

        preview = previewUseCase
        imageAnalysis = analysisUseCase

        val boundCamera = provider.bindToLifecycle(
            activity,
            cameraSelector,
            previewUseCase,
            analysisUseCase,
        )
        boundCamera.cameraControl.setLinearZoom(0.0f)
    }

    private fun analyzeFrame(imageProxy: ImageProxy) {
        val helper = poseLandmarkerHelper
        val timestampMs = imageProxy.imageInfo.timestamp / 1_000_000L
        // Thermal guard: cap analysis cadence before decoding the frame so we
        // skip the per-frame bitmap work entirely on dropped frames. No-op on
        // ~30fps sensors; sheds redundant frames on faster ones.
        if (!shouldAnalyzeFrame(timestampMs)) {
            recordPerf(analyzed = false, convertNs = 0L)
            imageProxy.close()
            return
        }
        try {
            val convertStartedNs = SystemClock.elapsedRealtimeNanos()
            val rotationDegrees = imageProxy.imageInfo.rotationDegrees
            val rawBitmap = rgbaImageProxyToBitmap(imageProxy)
            val rotationStartedNs = SystemClock.elapsedRealtimeNanos()
            val processedBitmap = rotateBitmap(rawBitmap, rotationDegrees)
            val rotationDurationMs =
                (SystemClock.elapsedRealtimeNanos() - rotationStartedNs) / 1_000_000.0
            logRotationDuration(rotationDegrees, rotationDurationMs)
            if (processedBitmap !== rawBitmap) {
                rawBitmap.recycle()
            }
            recordPerf(
                analyzed = true,
                convertNs = SystemClock.elapsedRealtimeNanos() - convertStartedNs,
            )

            if (replayBuffer.enabled) {
                try {
                    replayBuffer.offer(processedBitmap, timestampMs, useFrontCamera)
                } catch (_: Throwable) {
                }
            }

            val frameOwner = SharedBitmapFrame(processedBitmap)

            frameOwner.retain()
            val segmentationRelease = frameOwner.releaseCallback()
            val segmentationStarted = segmentationHelper?.detectLiveStream(
                bitmap = processedBitmap,
                timestampMs = timestampMs,
                onComplete = segmentationRelease,
            ) ?: false
            if (!segmentationStarted) {
                segmentationRelease()
            }

            frameOwner.retain()
            val poseRelease = frameOwner.releaseCallback()
            helper?.setOrientation(currentOrientationCode, useFrontCamera)
            val poseStarted = helper?.detectLiveStream(
                bitmap = processedBitmap,
                timestampMs = timestampMs,
                frameWidth = imageProxy.width,
                frameHeight = imageProxy.height,
                rotationDegrees = rotationDegrees,
                rotationDurationMs = rotationDurationMs,
                isFrontCamera = useFrontCamera,
                onComplete = poseRelease,
            ) ?: false
            if (!poseStarted) {
                poseRelease()
            }

            frameOwner.release()
        } catch (exception: Exception) {
            emitError("pose_landmarker_frame", exception.message)
        } finally {
            imageProxy.close()
        }
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun preferredAeFpsRange(
        provider: ProcessCameraProvider,
        selector: CameraSelector,
    ): Range<Int>? {
        val info = selector.filter(provider.availableCameraInfos).firstOrNull() ?: return null
        val ranges = Camera2CameraInfo.from(info)
            .getCameraCharacteristic(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES)
            ?: return null
        return ranges
            .filter { it.upper <= MAX_CAPTURE_FPS }
            .maxWithOrNull(compareBy<Range<Int>>({ it.lower }, { it.upper }))
    }

    @SuppressLint("UnsafeOptInUsageError")
    private fun <T> applyAeFpsRange(builder: ExtendableBuilder<T>) {
        val range = aeFpsRange ?: return
        Camera2Interop.Extender(builder)
            .setCaptureRequestOption(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, range)
    }

    private fun recordPerf(analyzed: Boolean, convertNs: Long) {
        val now = SystemClock.elapsedRealtime()
        if (perfWindowStartMs == 0L) {
            perfWindowStartMs = now
        }
        perfCameraFrames += 1
        if (analyzed) {
            perfAnalyzedFrames += 1
            perfConvertNs += convertNs
        }
        val elapsedMs = now - perfWindowStartMs
        if (elapsedMs < PERF_LOG_WINDOW_MS) {
            return
        }
        val seconds = elapsedMs / 1000.0
        val convertMs =
            if (perfAnalyzedFrames == 0) 0.0 else perfConvertNs / 1_000_000.0 / perfAnalyzedFrames
        Log.d(
            TAG,
            "perf cameraFps=" + String.format("%.1f", perfCameraFrames / seconds) +
                " analyzedFps=" + String.format("%.1f", perfAnalyzedFrames / seconds) +
                " convertMs=" + String.format("%.1f", convertMs) +
                " aeFpsRange=" + aeFpsRange,
        )
        perfWindowStartMs = now
        perfCameraFrames = 0
        perfAnalyzedFrames = 0
        perfConvertNs = 0L
    }

    private fun shouldAnalyzeFrame(timestampMs: Long): Boolean {
        val last = lastAnalyzedTimestampMs
        if (last != Long.MIN_VALUE && timestampMs - last < MIN_FRAME_INTERVAL_MS) {
            return false
        }
        lastAnalyzedTimestampMs = timestampMs
        return true
    }

    private fun rgbaImageProxyToBitmap(imageProxy: ImageProxy): Bitmap {
        val plane = imageProxy.planes.firstOrNull()
            ?: throw IllegalStateException("RGBA camera frame has no image plane.")
        val width = imageProxy.width
        val height = imageProxy.height
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val rowPadding = rowStride - pixelStride * width
        val bitmapWidth = width + rowPadding / pixelStride

        plane.buffer.rewind()
        val paddedBitmap = Bitmap.createBitmap(bitmapWidth, height, Bitmap.Config.ARGB_8888)
        paddedBitmap.copyPixelsFromBuffer(plane.buffer)

        if (bitmapWidth == width) {
            return paddedBitmap
        }

        val croppedBitmap = Bitmap.createBitmap(paddedBitmap, 0, 0, width, height)
        paddedBitmap.recycle()
        return croppedBitmap
    }

    private fun rotateBitmap(bitmap: Bitmap, rotationDegrees: Int): Bitmap {
        if (rotationDegrees == 0) {
            return bitmap
        }

        val matrix = Matrix().apply {
            postRotate(rotationDegrees.toFloat())
            // Prompt 3 (Revised), Option A: do not mirror front-camera frames here.
            // iOS Pose Landmarker cannot consume mirrored orientation tokens, so both
            // platforms intentionally keep un-mirrored inference input and let the
            // existing painter mirror only the visual preview/skeleton.
        }

        return Bitmap.createBitmap(
            bitmap,
            0,
            0,
            bitmap.width,
            bitmap.height,
            matrix,
            true,
        )
    }

    private fun logRotationDuration(rotationDegrees: Int, rotationDurationMs: Double) {
        if (currentOrientationCode == null && rotationDurationMs < ROTATION_SLOW_FRAME_MS) {
            return
        }

        rotationLogFrameCount = (rotationLogFrameCount + 1) % ROTATION_LOG_SAMPLE_RATE
        if (rotationLogFrameCount != 0 && rotationDurationMs < ROTATION_SLOW_FRAME_MS) {
            return
        }

        Log.d(
            TAG,
            "rotationDegrees=$rotationDegrees " +
                "rotationDurationMs=${"%.3f".format(rotationDurationMs)} " +
                "orientation=${currentOrientationCode ?: "cameraX"} " +
                "isFrontCamera=$useFrontCamera",
        )
    }

    private class SharedBitmapFrame(private val bitmap: Bitmap) {
        private val references = AtomicInteger(1)

        fun retain() {
            references.incrementAndGet()
        }

        fun release() {
            if (references.decrementAndGet() == 0 && !bitmap.isRecycled) {
                bitmap.recycle()
            }
        }

        fun releaseCallback(): () -> Unit {
            val didRelease = AtomicBoolean(false)
            return {
                if (didRelease.compareAndSet(false, true)) {
                    release()
                }
            }
        }
    }

    private fun resolveCameraSelector(provider: ProcessCameraProvider): CameraSelector {
        val preferredSelector = if (useFrontCamera) {
            CameraSelector.DEFAULT_FRONT_CAMERA
        } else {
            CameraSelector.DEFAULT_BACK_CAMERA
        }
        if (provider.hasCameraSafely(preferredSelector)) {
            return preferredSelector
        }

        val fallbackSelector = if (useFrontCamera) {
            CameraSelector.DEFAULT_BACK_CAMERA
        } else {
            CameraSelector.DEFAULT_FRONT_CAMERA
        }
        if (provider.hasCameraSafely(fallbackSelector)) {
            useFrontCamera = !useFrontCamera
            return fallbackSelector
        }

        throw IllegalStateException("No compatible camera is available on this device.")
    }

    private fun ProcessCameraProvider.hasCameraSafely(selector: CameraSelector): Boolean {
        return try {
            hasCamera(selector)
        } catch (_: Exception) {
            false
        }
    }

    private fun emitResult(payload: Map<String, Any?>) {
        val eventPayload = payload.toMutableMap()
        previewGeometry?.let { geometry ->
            eventPayload.putAll(geometry.toEventPayload())
        }
        mainHandler.post {
            eventSink?.success(eventPayload)
        }
    }

    private fun emitError(code: String, message: String?) {
        mainHandler.post {
            eventSink?.error(code, message, null)
        }
    }

    private fun disposeResources(releaseTexture: Boolean) {
        detectionEnabled = false
        previewBindingGeneration.incrementAndGet()
        previewGeometry = null
        imageAnalysis?.clearAnalyzer()
        cameraProvider?.unbindAll()
        preview = null
        imageAnalysis = null
        previewSurface?.release()
        previewSurface = null

        poseLandmarkerHelper?.releasePendingFrames()

        cameraExecutor?.shutdown()
        cameraExecutor = null

        if (releaseTexture) {
            textureEntry?.release()
            textureEntry = null
        }
    }

    private data class PreviewGeometry(
        val bufferWidth: Int,
        val bufferHeight: Int,
        val cropLeft: Int,
        val cropTop: Int,
        val cropRight: Int,
        val cropBottom: Int,
        val rotationDegrees: Int,
    ) {
        fun toEventPayload(): Map<String, Any> = mapOf(
            "previewBufferWidth" to bufferWidth,
            "previewBufferHeight" to bufferHeight,
            "previewCropLeft" to cropLeft,
            "previewCropTop" to cropTop,
            "previewCropRight" to cropRight,
            "previewCropBottom" to cropBottom,
            "previewRotationDegrees" to rotationDegrees,
        )
    }

    companion object {
        private const val TAG = "PoseLandmarkerPlugin"
        private const val METHOD_CHANNEL_NAME = "com.vikavn.app/pose_landmarker"
        private const val EVENT_CHANNEL_NAME = "com.vikavn.app/pose_landmarker_stream"
        private const val ROTATION_LOG_SAMPLE_RATE = 30
        private const val ROTATION_SLOW_FRAME_MS = 12.0
        private const val MIN_FRAME_INTERVAL_MS = 30L
        private const val PREVIEW_WIDTH = 1440
        private const val PREVIEW_HEIGHT = 1080
        private const val ANALYSIS_WIDTH = 960
        private const val ANALYSIS_HEIGHT = 720
        private const val MAX_CAPTURE_FPS = 30
        private const val PERF_LOG_WINDOW_MS = 3000L

        private fun targetRotationForOrientation(orientation: String): Int {
            // Match Flutter's camera_android_camerax orientation table:
            // DeviceOrientation.landscapeLeft -> Surface.ROTATION_90 and
            // DeviceOrientation.landscapeRight -> Surface.ROTATION_270.
            // Reversing these two leaves CameraX's preview and analyzer
            // upright in the wrong landscape side, which appears as a 180°
            // flip when Dart rotates the exercise UI from the same sensor.
            return when (orientation) {
                "landscapeLeft" -> Surface.ROTATION_90
                "portraitUpsideDown" -> Surface.ROTATION_180
                "landscapeRight" -> Surface.ROTATION_270
                else -> Surface.ROTATION_0
            }
        }
    }
}
