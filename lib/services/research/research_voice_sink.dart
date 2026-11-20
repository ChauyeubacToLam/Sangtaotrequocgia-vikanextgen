import 'package:flutter/services.dart' show AssetManifest, rootBundle;

import '../../exercise/exercise_base.dart' show ExerciseVoiceCoach;
import '../../voice/policy_voice_coach.dart';
import '../../voice/voice_content.dart' show CueType;
import '../../voice/voice_sink.dart';
import '../bow_pose_voice_coach.dart';
import '../generic_exercise_voice_assets.dart';
import '../plank_voice_coach.dart';
import 'set_recorder.dart';

class ResearchVoiceSink implements ContextualVoiceSink {
  ResearchVoiceSink({
    required VoiceSink inner,
    required void Function({
      required String key,
      required bool played,
      String? fault,
    }) onCue,
    required this.controlCondition,
    bool Function(String key)? hasAudio,
  })  : _inner = inner is ResearchVoiceSink ? inner.unwrapInner : inner,
        _onCue = onCue,
        _hasAudio = hasAudio;

  final VoiceSink _inner;
  final void Function({
    required String key,
    required bool played,
    String? fault,
  }) _onCue;
  final bool controlCondition;
  final bool Function(String key)? _hasAudio;

  static Set<String>? _bundledAudioAssets;
  static Future<void>? _manifestWarmUp;

  /// Off-frame warm-up that caches bundled `assets/audio/...` keys in memory so
  /// [_checkHasAudio] can verify real `.mp3` existence in O(1) without frame I/O.
  static Future<void> warmUpAssetManifest() {
    if (_bundledAudioAssets != null) return Future<void>.value();
    return _manifestWarmUp ??= _loadBundledAudioAssets();
  }

  static Future<void> _loadBundledAudioAssets() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final prefix = '${GenericExerciseVoiceAssets.assetBundlePrefix}/';
      final audioAssets = <String>{
        for (final asset in manifest.listAssets())
          if (asset.startsWith(prefix)) asset,
      };
      if (audioAssets.isNotEmpty) {
        _bundledAudioAssets = audioAssets;
      }
    } catch (_) {
      // Safe no-op in plain-Dart unit tests without a bound asset bundle.
    } finally {
      _manifestWarmUp = null;
    }
  }

  static void resetAssetCacheForTesting([Set<String>? overrideAssets]) {
    _bundledAudioAssets = overrideAssets;
    _manifestWarmUp = null;
  }

  VoiceSink get unwrapInner {
    final inner = _inner;
    return inner is ResearchVoiceSink ? inner.unwrapInner : inner;
  }

  /// Exact keys allowed in the control condition when no [CueType] is supplied.
  /// These cover framing, orientation, pause/resume, and structural set start/end.
  static const Set<String> controlAllowedExactKeys = <String>{
    'common.ngang_intro',
    'common.thang_intro',
    'common.ready',
    'common.start',
    'common.keep_full_body',
    'common.side_orientation',
    'common.rotate_landscape',
    'common.rotate_portrait',
    'common.body_in_frame',
    'common.paused',
    'common.resume',
    'common.hold_still',
    'common.set_complete',
    'common.exercise_complete',
    'Sẵn sàng',
    'Hoàn thành bài tập',
    'Giữ cả người trong khung hình',
  };

  /// Suffixes for per-exercise setup instructions allowed in the control condition.
  static const List<String> controlAllowedSuffixes = <String>[
    '.setup_intro',
    '.setup_position',
    '.active_intro',
    '.set_next_setup',
  ];

  static bool isAllowedInControl(String key, {CueType? cueType}) {
    if (cueType != null) {
      return cueType == CueType.setup || cueType == CueType.safety;
    }
    if (controlAllowedExactKeys.contains(key)) {
      return true;
    }
    for (final suffix in controlAllowedSuffixes) {
      if (key.endsWith(suffix)) return true;
    }
    return false;
  }

  bool _checkHasAudio(String key) {
    final custom = _hasAudio;
    if (custom != null) return custom(key);
    final inner = _inner;
    final resolved = inner is AssetVoiceSink
        ? inner.voiceSet.resolve(key)
        : VoiceSet.vika_v1.resolve(key);
    if (resolved == null) return false;
    final bundled = _bundledAudioAssets;
    if (bundled != null) {
      return bundled.contains(
        '${GenericExerciseVoiceAssets.assetBundlePrefix}/$resolved',
      );
    }
    return true;
  }

  @override
  bool get isBusy => _inner.isBusy;

  @override
  Future<void> playKey(
    String logicalKey, {
    bool Function()? isStillRelevant,
  }) {
    return playKeyWithContext(
      logicalKey,
      isStillRelevant: isStillRelevant,
    );
  }

  @override
  Future<void> playKeyWithContext(
    String logicalKey, {
    bool Function()? isStillRelevant,
    CueType? cueType,
    String? fault,
    bool clearPendingBeforePlay = false,
  }) async {
    final trimmed = logicalKey.trim();
    final audioAvailable = trimmed.isNotEmpty && _checkHasAudio(trimmed);
    final suppressed =
        controlCondition && !isAllowedInControl(trimmed, cueType: cueType);
    final played = !suppressed && audioAvailable;

    _onCue(key: logicalKey, played: played, fault: fault);

    if (suppressed) {
      return;
    }
    if (clearPendingBeforePlay) {
      _inner.clearPending();
    }
    await _inner.playKey(logicalKey, isStillRelevant: isStillRelevant);
  }

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) =>
      _inner.waitUntilIdle(timeout: timeout);

  @override
  void clearPending() => _inner.clearPending();

  @override
  Future<void> stop() => _inner.stop();

  @override
  void dispose() => _inner.dispose();
}

void wrapExerciseVoiceCoach(
  ExerciseVoiceCoach? coach, {
  required SetRecorder? recorder,
  required bool controlCondition,
}) {
  if (coach == null) return;

  VoiceSink wrap(VoiceSink inner) {
    final baseInner = inner is ResearchVoiceSink ? inner.unwrapInner : inner;
    if (recorder == null && !controlCondition) {
      return baseInner;
    }
    return ResearchVoiceSink(
      inner: baseInner,
      controlCondition: controlCondition,
      onCue: ({required String key, required bool played, String? fault}) {
        recorder?.recordCue(key: key, played: played, fault: fault);
      },
    );
  }

  if (coach is PolicyVoiceCoach) {
    coach.wrapSink(wrap);
  } else if (coach is PlankVoiceCoach) {
    coach.wrapSink(wrap);
  } else if (coach is BowPoseVoiceCoach) {
    coach.wrapSink(wrap);
  }
}
