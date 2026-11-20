import '../exercise/bow_pose/bow_pose.dart';
import '../exercise/exercise_base.dart';
import '../voice/voice_content.dart' show CueType;
import '../voice/voice_sink.dart';
import 'bow_pose_voice_assets.dart';
import 'generic_exercise_voice_assets.dart';
import 'queued_asset_voice_player.dart';

abstract class BowPoseVoicePlayer {
  Future<void> speak(String text);
  Future<void> waitUntilIdle({Duration timeout = const Duration(seconds: 4)}) {
    return Future<void>.value();
  }

  void clearQueue();
  void clearPendingButKeepCurrent();
  void dispose() {}
}

class _BowPoseAssetVoicePlayer implements BowPoseVoicePlayer {
  _BowPoseAssetVoicePlayer({QueuedAssetVoicePlayer? player})
      : _sink = AssetVoiceSink(
          player: player ??
              QueuedAssetVoicePlayer(
                assetMap: {
                  ...GenericExerciseVoiceAssets.commonFiles,
                  ...BowPoseVoiceAssets.files,
                },
                assetSourcePrefix: BowPoseVoiceAssets.assetSourcePrefix,
                assetBundlePrefix: BowPoseVoiceAssets.assetBundlePrefix,
                assetResolver: GenericExerciseVoiceAssets.resolveAsset,
                logTag: 'BowPoseVoice',
              ),
          voiceSet: const VoiceSet(
            name: 'bow_pose_v1',
            resolve: _resolveBowPoseAsset,
          ),
        );

  static String? _resolveBowPoseAsset(String logicalKey) {
    final key = logicalKey.trim();
    if (key.isEmpty) return null;
    return BowPoseVoiceAssets.files[key] ?? VoiceSet.vika_v1.resolve(key);
  }

  VoiceSink _sink;

  void wrapSink(VoiceSink Function(VoiceSink inner) wrap) {
    _sink = wrap(_sink);
  }

  Future<void> speakWithContext(
    String text, {
    CueType? cueType,
    String? fault,
    bool clearPendingBeforePlay = false,
  }) {
    final sink = _sink;
    if (sink is ContextualVoiceSink) {
      return sink.playKeyWithContext(
        text,
        cueType: cueType,
        fault: fault,
        clearPendingBeforePlay: clearPendingBeforePlay,
      );
    }
    if (clearPendingBeforePlay) {
      sink.clearPending();
    }
    return sink.playKey(text);
  }

  @override
  Future<void> speak(String text) => _sink.playKey(text);

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) =>
      _sink.waitUntilIdle(timeout: timeout);

  @override
  void clearQueue() {
    _sink.stop();
  }

  @override
  void clearPendingButKeepCurrent() => _sink.clearPending();

  @override
  void dispose() => _sink.dispose();
}

class BowPoseVoiceCoach implements ExerciseVoiceCoach {
  BowPoseVoiceCoach({BowPoseVoicePlayer? voicePlayer})
      : _voicePlayer = voicePlayer ?? _BowPoseAssetVoicePlayer();

  final BowPoseVoicePlayer _voicePlayer;

  void wrapSink(VoiceSink Function(VoiceSink inner) wrap) {
    final p = _voicePlayer;
    if (p is _BowPoseAssetVoicePlayer) {
      p.wrapSink(wrap);
    }
  }

  void _emit(
    String text, {
    CueType? cueType,
    String? fault,
    bool clearPendingBeforePlay = false,
  }) {
    final p = _voicePlayer;
    if (p is _BowPoseAssetVoicePlayer) {
      p.speakWithContext(
        text,
        cueType: cueType,
        fault: fault,
        clearPendingBeforePlay: clearPendingBeforePlay,
      );
    } else {
      if (clearPendingBeforePlay) {
        p.clearPendingButKeepCurrent();
      }
      p.speak(text);
    }
  }

  int _lastRepCount = 0;
  bool _didSpeakSetup = false;
  bool _didAnnounceReady = false;
  bool _didAnnounceSetComplete = false;

  @override
  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required bool hasPose,
    required Map<String, String> feedback,
  }) {
    final repIncreased = repCount > _lastRepCount;

    if (exercise.exerciseState == ExerciseState.notActivated) {
      _speakSetup(exercise);
      _lastRepCount = repCount;
      return;
    }

    if (exercise.exerciseState == ExerciseState.completed) {
      if (!_didAnnounceSetComplete) {
        _voicePlayer.clearPendingButKeepCurrent();
        if (repIncreased) {
          _speakRepOutcome(exercise, repCount);
        }
        _emit('Hoàn thành bài tập', cueType: CueType.setup);
        _didAnnounceSetComplete = true;
      }
      _lastRepCount = repCount;
      return;
    }

    if (exercise.exerciseState != ExerciseState.activated ||
        exercise.isPaused ||
        !hasPose) {
      _lastRepCount = repCount;
      return;
    }

    if (!_didAnnounceReady) {
      _emit('Sẵn sàng', cueType: CueType.setup);
      _didAnnounceReady = true;
    }

    if (repIncreased) {
      _speakRepOutcome(exercise, repCount, clearPendingFirst: true);
      _lastRepCount = repCount;
      return;
    }

    _lastRepCount = repCount;
  }

  void _speakSetup(ExerciseBase exercise) {
    if (_didSpeakSetup) return;

    final script =
        GenericExerciseVoiceAssets.scriptForExerciseName(exercise.exerciseName);
    _emit(exercise.setupOrientationIntroVoiceKey, cueType: CueType.setup);
    _emit(script.cueKey('setup_position'), cueType: CueType.setup);
    _emit(script.cueKey('active_intro'), cueType: CueType.setup);
    _didSpeakSetup = true;
  }

  void _speakRepOutcome(
    ExerciseBase exercise,
    int repCount, {
    bool clearPendingFirst = false,
  }) {
    _emit(
      '$repCount',
      cueType: CueType.count,
      clearPendingBeforePlay: clearPendingFirst,
    );

    if (exercise is BowPose && exercise.lastRepWasClean) {
      _emit('common.correct', cueType: CueType.praise);
      return;
    }

    _speakCorrection(exercise, repCount);
  }

  void _speakCorrection(ExerciseBase exercise, int repNumber) {
    if (exercise is! BowPose) return;

    final voice = exercise.lastRepTopVoiceMessage;
    if (voice == null || voice.isEmpty) {
      _emit('common.fix_pose', cueType: CueType.criticalFault);
      return;
    }
    _emit(
      voice,
      cueType: CueType.criticalFault,
      fault: _faultIdForBowPoseVoice(voice),
    );
  }

  static String? _faultIdForBowPoseVoice(String voice) {
    return switch (voice) {
      'Nắm chân chắc hơn' => 'Connection',
      'Giữ lâu hơn một chút' => 'HoldDuration',
      'Giữ người yên hơn' => 'Stability',
      'Mở ngực thêm một chút' ||
      'Nâng đùi cao hơn nếu lưng vẫn thoải mái' =>
        'LiftForm',
      _ => null,
    };
  }

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) {
    return _voicePlayer.waitUntilIdle(timeout: timeout);
  }

  @override
  void dispose() {
    _voicePlayer.clearQueue();
    _voicePlayer.dispose();
  }
}
