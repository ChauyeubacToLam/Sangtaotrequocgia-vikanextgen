import 'package:flutter/services.dart';
import 'package:vika/exercise/exercise_base.dart';

class PoseLandmarkerChannel {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.vikavn.app/pose_landmarker',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.vikavn.app/pose_landmarker_stream',
  );

  Stream<Map<String, dynamic>> get landmarkStream {
    return _eventChannel.receiveBroadcastStream().map(
          (event) => Map<String, dynamic>.from(event as Map),
        );
  }

  Future<int> initialize({
    bool useFrontCamera = true,
    VikaImageOrientation initialOrientation = VikaImageOrientation.portrait,
    bool? isFrontCamera,
  }) async {
    final arguments = <String, dynamic>{'useFrontCamera': useFrontCamera};
    if (ExerciseBase.kLandscapeRotationEnabled) {
      arguments.addAll(<String, dynamic>{
        'initialOrientation': initialOrientation.channelCode,
        'isFrontCamera': isFrontCamera ?? useFrontCamera,
      });
    }

    final textureId = await _methodChannel.invokeMethod<int>(
      'initialize',
      arguments,
    );
    if (textureId == null) {
      throw PlatformException(
        code: 'pose_landmarker_init',
        message: 'Native pose preview did not return a texture id.',
      );
    }
    return textureId;
  }

  Future<void> setOrientation({
    required VikaImageOrientation orientation,
    required bool isFrontCamera,
  }) async {
    if (!ExerciseBase.kLandscapeRotationEnabled) return;
    await _methodChannel.invokeMethod<void>('setOrientation', <String, dynamic>{
      'orientation': orientation.channelCode,
      'isFrontCamera': isFrontCamera,
    });
  }

  Future<void> dispose() => _methodChannel.invokeMethod<void>('dispose');

  Future<void> warmUp() => _methodChannel.invokeMethod<void>('warmUp');

  Future<void> startDetection() =>
      _methodChannel.invokeMethod<void>('startDetection');

  Future<void> stopDetection() =>
      _methodChannel.invokeMethod<void>('stopDetection');

  Future<void> switchCamera() =>
      _methodChannel.invokeMethod<void>('switchCamera');

  Future<void> startReplayCapture() => _quiet(
      () => _methodChannel.invokeMethod<void>('startReplayCapture'), null);

  Future<void> stopReplayCapture() => _quiet(
      () => _methodChannel.invokeMethod<void>('stopReplayCapture'), null);

  Future<void> clearReplayClips() => _quiet(
      () => _methodChannel.invokeMethod<void>('clearReplayClips'), null);

  Future<int> saveReplayClip(String id, int durationMs) async =>
      await _quiet(
        () => _methodChannel.invokeMethod<int>('saveReplayClip',
            <String, dynamic>{'id': id, 'durationMs': durationMs}),
        0,
      ) ??
      0;

  Future<Map<String, dynamic>?> loadReplayClip(String id) async {
    final raw = await _quiet(
      () => _methodChannel.invokeMethod<Map<Object?, Object?>>(
          'loadReplayClip', <String, dynamic>{'id': id}),
      null,
    );
    return raw == null ? null : Map<String, dynamic>.from(raw);
  }

  static Future<T?> _quiet<T>(Future<T?> Function() call, T? fallback) async {
    try {
      return await call();
    } on MissingPluginException {
      return fallback;
    } on PlatformException {
      return fallback;
    }
  }

  /// Throttles (or restores) native pose-landmarker inference cadence.
  /// `minDetectionIntervalMs` 0 = full rate; >0 = minimum gap between
  /// processed frames (native drops frames arriving inside that window).
  /// Redundant/repeated calls are safe — native applies this on its session
  /// queue. See ADR "Pose inference throttles to ~1fps while paused"
  /// (docs/decisions.md, 2026-07-06): the exercise gate pauses (auto or
  /// manual) throttle pose to ~1fps here while segmentation cadence
  /// (PersonDetectorConfig, a separate channel) is untouched.
  Future<void> setDetectionInterval(int minDetectionIntervalMs) =>
      _methodChannel.invokeMethod<void>('setDetectionInterval', <String, dynamic>{
        'minDetectionIntervalMs': minDetectionIntervalMs,
      });
}
