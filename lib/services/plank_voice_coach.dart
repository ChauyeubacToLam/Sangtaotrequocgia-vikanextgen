import '../exercise/exercise_base.dart';
import '../exercise/plank/plank.dart';
import '../voice/voice_content.dart' show CueType;
import '../voice/voice_sink.dart';
import 'generic_exercise_voice_assets.dart';
import 'plank_voice_assets.dart';
import 'queued_asset_voice_player.dart';

abstract class PlankVoicePlayer {
  Future<void> speak(String text);
  Future<void> waitUntilIdle({Duration timeout = const Duration(seconds: 4)}) {
    return Future<void>.value();
  }

  void clearQueue();
  void clearPendingButKeepCurrent();
  void dispose() {}
}

class _PlankAssetVoicePlayer implements PlankVoicePlayer {
  _PlankAssetVoicePlayer({QueuedAssetVoicePlayer? player})
      : _sink = AssetVoiceSink(
          player: player ??
              QueuedAssetVoicePlayer(
                assetMap: {
                  ...GenericExerciseVoiceAssets.commonFiles,
                  ...PlankVoiceAssets.files,
                },
                assetSourcePrefix: PlankVoiceAssets.assetSourcePrefix,
                assetBundlePrefix: PlankVoiceAssets.assetBundlePrefix,
                assetResolver: GenericExerciseVoiceAssets.resolveAsset,
                logTag: 'PlankVoice',
              ),
          voiceSet: const VoiceSet(
            name: 'plank_v1',
            resolve: _resolvePlankAsset,
          ),
        );

  static String? _resolvePlankAsset(String logicalKey) {
    final key = logicalKey.trim();
    if (key.isEmpty) return null;
    return PlankVoiceAssets.files[key] ?? VoiceSet.vika_v1.resolve(key);
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

class PlankVoiceCoach implements ExerciseVoiceCoach {
  PlankVoiceCoach({PlankVoicePlayer? voicePlayer})
      : _voicePlayer = voicePlayer ?? _PlankAssetVoicePlayer();

  static const int _faultCueCooldownMs = 2500;

  final PlankVoicePlayer _voicePlayer;

  void wrapSink(VoiceSink Function(VoiceSink inner) wrap) {
    final p = _voicePlayer;
    if (p is _PlankAssetVoicePlayer) {
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
    if (p is _PlankAssetVoicePlayer) {
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
  int _lastFaultCueAtMs = 0;
  bool _didSpeakSetup = false;
  bool _didAnnounceReady = false;
  bool _didAnnounceSetComplete = false;
  String? _lastFaultVoice;

  @override
  void processFrame({
    required ExerciseBase exercise,
    required int repCount,
    required bool hasPose,
    required Map<String, String> feedback,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
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
          _emit('common.correct', cueType: CueType.praise);
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
      _emit(
        'common.correct',
        cueType: CueType.praise,
        clearPendingBeforePlay: true,
      );
      _lastRepCount = repCount;
      return;
    }

    final holdStopped = exercise is Plank &&
        exercise.previousPlankState == PlankState.holding &&
        exercise.plankState == PlankState.setup;
    final faultVoice = _faultVoice(exercise, feedback) ??
        (holdStopped ? 'common.fix_pose' : null);
    final shouldSpeakFault = faultVoice != null &&
        holdStopped &&
        (faultVoice != _lastFaultVoice ||
            nowMs - _lastFaultCueAtMs >= _faultCueCooldownMs);

    if (shouldSpeakFault) {
      _lastFaultVoice = faultVoice;
      _lastFaultCueAtMs = nowMs;
      final isFraming = faultVoice == 'Giữ cả người trong khung hình';
      _emit(
        faultVoice,
        cueType: isFraming ? CueType.safety : CueType.criticalFault,
        fault: isFraming ? null : _faultIdForPlankVoice(faultVoice),
        clearPendingBeforePlay: true,
      );
    }

    _lastRepCount = repCount;
  }

  static String? _faultIdForPlankVoice(String voice) {
    return switch (voice) {
      'Gồng cơ bụng, nâng hông lên' ||
      'Hạ hông xuống, giữ thân thẳng' ||
      'Giữ thân người thẳng' =>
        'Back',
      'Giữ cổ thẳng, nhìn xuống nhẹ' => 'Neck',
      'Thẳng đầu gối ra' => 'Knees',
      _ => null,
    };
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

  String? _faultVoice(
    ExerciseBase exercise,
    Map<String, String> feedback,
  ) {
    if (exercise is Plank) {
      final latestHoldBreak = exercise.lastHoldFaultVoiceMessage;
      if (latestHoldBreak != null && latestHoldBreak.isNotEmpty) {
        return latestHoldBreak;
      }
    }

    final arms = feedback['Arms'] ?? '';
    if (arms.contains('cẳng tay')) return 'Chống bằng cẳng tay';

    final body = feedback['Body'] ?? '';
    if (body.contains('thẳng')) return 'Giữ thân người thẳng';

    final knees = feedback['Knees'] ?? '';
    if (knees.contains('gối')) return 'Thẳng đầu gối ra';

    final back = feedback['Back'] ?? '';
    if (back.contains('võng') || back.contains('bụng')) {
      return 'Gồng cơ bụng, nâng hông lên';
    }
    if (back.contains('cao hông') || back.contains('Hông quá cao')) {
      return 'Hạ hông xuống, giữ thân thẳng';
    }

    final neck = feedback['Neck'] ?? '';
    if (neck.contains('cúi') || neck.contains('ngẩng')) {
      return 'Giữ cổ thẳng, nhìn xuống nhẹ';
    }

    return null;
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
