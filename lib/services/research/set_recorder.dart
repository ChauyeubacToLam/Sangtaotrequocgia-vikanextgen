import 'dart:io' show Platform;

import '../../exercise/exercise_base.dart';
import '../../exercise/fault_record.dart';
import '../../utils/exercise_logger.dart';
import 'json_sanitizer.dart';

class SetRecorder {
  SetRecorder({
    required String sessionId,
    required String participantId,
    required String condition,
    required String exerciseId,
    required int setIndex,
    String? appVersion,
    String? platform,
    String? osVersion,
    DateTime Function()? clockUtc,
    void Function()? onFirstActivationBeep,
  })  : _sessionId = sessionId,
        _participantId = participantId,
        _condition = condition,
        _exerciseId = exerciseId,
        _setIndex = setIndex,
        appVersion = appVersion ?? defaultAppVersion,
        platform = platform ?? Platform.operatingSystem,
        osVersion = osVersion ?? Platform.operatingSystemVersion,
        _clockUtc = clockUtc,
        _onFirstActivationBeep = onFirstActivationBeep;

  static const String defaultAppVersion = '1.0.3+155';

  String _sessionId;
  String _participantId;
  String _condition;
  String _exerciseId;
  int _setIndex;

  String get sessionId => _sessionId;
  String get participantId => _participantId;
  String get condition => _condition;
  String get exerciseId => _exerciseId;
  int get setIndex => _setIndex;

  void updateSessionMetadata({
    required String sessionId,
    required String participantId,
    required String condition,
    String? exerciseId,
    int? setIndex,
  }) {
    _sessionId = sessionId;
    _participantId = participantId;
    _condition = condition;
    if (exerciseId != null && exerciseId.isNotEmpty) {
      _exerciseId = exerciseId;
    }
    if (setIndex != null) {
      _setIndex = setIndex;
    }
  }

  void updateExerciseId(String exerciseId, {int? setIndex}) {
    if (exerciseId.isNotEmpty) {
      _exerciseId = exerciseId;
    }
    if (setIndex != null) {
      _setIndex = setIndex;
    }
  }
  final String appVersion;
  final String platform;
  final String osVersion;

  final DateTime Function()? _clockUtc;
  void Function()? _onFirstActivationBeep;

  final List<Map<String, Object?>> _events = <Map<String, Object?>>[];
  final List<String> _activeFaultTypes = <String>[];
  final List<String> _activeFaultMessages = <String>[];

  int _totalFrames = 0;
  int _framesWithPose = 0;
  int _firstFrameMs = 0;
  int _prevRawFrameMs = 0;
  int _currentTMs = 0;
  int _maxGapMs = 0;
  bool _clockFrozenByOrientationGate = false;

  int _fpsWindowStartMs = -1;
  int _fpsWindowCount = 0;
  int? _minFps1s;

  int _activeMs = 0;
  int _unseenMs = 0;
  int _pausedMs = 0;

  DateTime? _startedAtUtc;
  int? _syncBeepTMs;
  bool _didPlaySyncBeep = false;

  ExerciseState _prevState = ExerciseState.notActivated;
  GuidanceClass? _prevGuidanceKind;
  bool _prevUnseenPhaseIsActive = false;
  bool _prevPaused = false;
  int _loggedRepCount = 0;
  int _lastRepCount = 0;
  int _goodLoggedReps = 0;
  bool _completed = false;
  int _completedTMs = -1;

  int get totalFrames => _totalFrames;
  int? get syncBeepTMs => _syncBeepTMs;
  bool get isCompleted => _completed;
  List<Map<String, Object?>> get events => List.unmodifiable(_events);

  /// Share of activated (non-paused) time the AI could judge, i.e.
  /// `1 - unseen_ms / active_ms`. Null until some activated time elapsed.
  double? get visibleRatio => _activeMs <= 0
      ? null
      : (1 - _unseenMs / _activeMs).clamp(0.0, 1.0).toDouble();

  void setOnFirstActivationBeep(void Function()? callback) {
    _onFirstActivationBeep = callback;
  }

  static DateTime _defaultUtcNow() => DateTime.now().toUtc();

  void onFrame(ExerciseBase exercise, {required bool hasPose}) {
    final paused = exercise.isPaused;
    final state = exercise.exerciseState;
    onState(
      frameTimestampMs: exercise.frameTimestampMs,
      hasPose: hasPose,
      exerciseState: state,
      guidanceSignal: exercise.guidanceSignal,
      isPaused: paused,
      liveFaults: (!paused && state == ExerciseState.activated)
          ? exercise.liveFaults
          : const <FaultRecord>[],
      logger: exercise.logger,
      repCount: exercise.repCount,
    );
  }

  void onState({
    required int frameTimestampMs,
    required bool hasPose,
    required ExerciseState exerciseState,
    GuidanceSignal? guidanceSignal,
    required bool isPaused,
    List<FaultRecord> liveFaults = const <FaultRecord>[],
    required ExerciseLogger logger,
    int repCount = 0,
  }) {
    if (_completed) return;

    _lastRepCount = repCount;
    final rawSignal = (isPaused || exerciseState == ExerciseState.completed)
        ? null
        : guidanceSignal;
    final kind =
        (rawSignal == null || rawSignal.kind == GuidanceClass.paused)
            ? null
            : rawSignal.kind;
    final isOrientationGateSignal = kind == GuidanceClass.phoneLandscape ||
        kind == GuidanceClass.phonePortrait;

    final int tMs;
    var skipCatchUpFrameStats = false;
    if (_totalFrames == 0) {
      _firstFrameMs = frameTimestampMs;
      _prevRawFrameMs = frameTimestampMs;
      _startedAtUtc = (_clockUtc ?? _defaultUtcNow)();
      tMs = 0;
    } else {
      final clockFrozenNow =
          isOrientationGateSignal && frameTimestampMs == _prevRawFrameMs;
      final resumingFromFrozenGate =
          _clockFrozenByOrientationGate && frameTimestampMs != _prevRawFrameMs;
      if (clockFrozenNow) {
        _clockFrozenByOrientationGate = true;
      } else if (resumingFromFrozenGate) {
        _clockFrozenByOrientationGate = false;
        skipCatchUpFrameStats = true;
      }
      _prevRawFrameMs = frameTimestampMs;

      final rawT = frameTimestampMs - _firstFrameMs;
      tMs = rawT >= _currentTMs ? rawT : _currentTMs;
      final dt = tMs - _currentTMs;
      if (_prevPaused) {
        _pausedMs += dt;
      } else {
        if (!skipCatchUpFrameStats && dt > _maxGapMs) {
          _maxGapMs = dt;
        }
        if (_prevState == ExerciseState.activated) {
          _activeMs += dt;
          if (_prevUnseenPhaseIsActive) {
            _unseenMs += dt;
          }
        }
      }
    }

    _currentTMs = tMs;
    _totalFrames++;
    if (hasPose) {
      _framesWithPose++;
    }

    if (!_prevPaused &&
        !_clockFrozenByOrientationGate &&
        !skipCatchUpFrameStats &&
        _fpsWindowStartMs >= 0) {
      final winElapsed = tMs - _fpsWindowStartMs;
      if (winElapsed >= 1000) {
        if (_minFps1s == null || _fpsWindowCount < _minFps1s!) {
          _minFps1s = _fpsWindowCount;
        }
        final wholeSeconds = winElapsed ~/ 1000;
        if (wholeSeconds >= 2) {
          _minFps1s = 0;
        }
        _fpsWindowStartMs += wholeSeconds * 1000;
        _fpsWindowCount = 0;
      }
    }

    if (isPaused || _clockFrozenByOrientationGate) {
      _fpsWindowStartMs = -1;
      _fpsWindowCount = 0;
    } else if (_fpsWindowStartMs < 0 || skipCatchUpFrameStats) {
      _fpsWindowStartMs = tMs;
      _fpsWindowCount = 1;
    } else {
      _fpsWindowCount++;
    }

    final phaseIsActive = exerciseState == ExerciseState.activated;
    final effectiveLiveFaults = (!isPaused && phaseIsActive)
        ? liveFaults
        : const <FaultRecord>[];

    // 1. Pause state changes
    if (isPaused != _prevPaused) {
      if (isPaused) {
        if (_activeFaultTypes.isNotEmpty) {
          _diffLiveFaults(const <FaultRecord>[], tMs);
        }
        if (_prevGuidanceKind != null) {
          _events.add(<String, Object?>{
            't_ms': tMs,
            'type': 'unseen_end',
          });
          _prevGuidanceKind = null;
          _prevUnseenPhaseIsActive = false;
        }
        _events.add(<String, Object?>{
          't_ms': tMs,
          'type': 'pause_start',
        });
      } else {
        _events.add(<String, Object?>{
          't_ms': tMs,
          'type': 'pause_end',
        });
      }
      _prevPaused = isPaused;
    }

    // 2. Guidance / unseen transitions + activation
    var activatedEmitted = false;
    final activatingNow = exerciseState == ExerciseState.activated &&
        _prevState != ExerciseState.activated;

    if (kind != _prevGuidanceKind ||
        (kind != null && phaseIsActive != _prevUnseenPhaseIsActive)) {
      if (_prevGuidanceKind != null) {
        _events.add(<String, Object?>{
          't_ms': tMs,
          'type': 'unseen_end',
        });
      }
      if (activatingNow && kind != null) {
        _emitActivated(tMs);
        activatedEmitted = true;
      }
      if (kind != null) {
        _events.add(<String, Object?>{
          't_ms': tMs,
          'type': 'unseen_start',
          'phase': phaseIsActive ? 'active' : 'setup',
          'reason': kind.name,
        });
      }
      _prevGuidanceKind = kind;
      _prevUnseenPhaseIsActive = kind != null && phaseIsActive;
    }

    if (activatingNow && !activatedEmitted) {
      _emitActivated(tMs);
    }
    _prevState = exerciseState;

    // 3. Live faults diff
    if (effectiveLiveFaults.isNotEmpty || _activeFaultTypes.isNotEmpty) {
      _diffLiveFaults(effectiveLiveFaults, tMs);
    }

    // 4. RepLog diff
    final repLogLen = logger.repLogCount;
    if (repLogLen < _loggedRepCount) {
      _loggedRepCount = repLogLen;
      _goodLoggedReps = 0;
      for (var i = 0; i < repLogLen; i++) {
        if (logger.repLogAt(i).correctForm) _goodLoggedReps++;
      }
    } else if (repLogLen > _loggedRepCount) {
      for (var i = _loggedRepCount; i < repLogLen; i++) {
        final repLog = logger.repLogAt(i);
        if (repLog.correctForm) _goodLoggedReps++;
        final rawFaults = repLog.data['fault_types'];
        final faults = rawFaults is List
            ? List<Object?>.from(rawFaults)
            : <Object?>[];
        _events.add(<String, Object?>{
          't_ms': tMs,
          'type': 'rep',
          'n': repLog.repNumber,
          'correct': repLog.correctForm,
          'faults': faults,
          'data': Map<String, dynamic>.from(repLog.data),
        });
      }
      _loggedRepCount = repLogLen;
    }

    // 5. Set completion
    if (exerciseState == ExerciseState.completed) {
      _completed = true;
      _completedTMs = tMs;
      _events.add(<String, Object?>{
        't_ms': tMs,
        'type': 'set_complete',
      });
    }
  }

  void _emitActivated(int tMs) {
    if (!_didPlaySyncBeep) {
      _didPlaySyncBeep = true;
      final beep = _onFirstActivationBeep;
      if (beep != null) {
        _syncBeepTMs = tMs;
        beep();
      }
    }
    _events.add(<String, Object?>{
      't_ms': tMs,
      'type': 'activated',
    });
  }

  void _diffLiveFaults(List<FaultRecord> liveFaults, int tMs) {
    var changed = false;

    for (var i = 0; i < liveFaults.length; i++) {
      final f = liveFaults[i];
      if (!_containsPair(
        _activeFaultTypes,
        _activeFaultMessages,
        f.type,
        f.message,
      )) {
        changed = true;
        break;
      }
    }

    if (!changed) {
      for (var j = 0; j < _activeFaultTypes.length; j++) {
        if (!_liveContainsPair(
          liveFaults,
          _activeFaultTypes[j],
          _activeFaultMessages[j],
        )) {
          changed = true;
          break;
        }
      }
    }

    if (!changed) return;

    for (var j = 0; j < _activeFaultTypes.length; j++) {
      final oldType = _activeFaultTypes[j];
      final oldMsg = _activeFaultMessages[j];
      if (!_liveContainsPair(liveFaults, oldType, oldMsg)) {
        _events.add(<String, Object?>{
          't_ms': tMs,
          'type': 'fault_end',
          'fault': oldType,
          'message': oldMsg,
        });
      }
    }

    final nextTypes = <String>[];
    final nextMessages = <String>[];
    for (var i = 0; i < liveFaults.length; i++) {
      final f = liveFaults[i];
      if (_containsPair(nextTypes, nextMessages, f.type, f.message)) {
        continue;
      }
      nextTypes.add(f.type);
      nextMessages.add(f.message);
      if (!_containsPair(
        _activeFaultTypes,
        _activeFaultMessages,
        f.type,
        f.message,
      )) {
        _events.add(<String, Object?>{
          't_ms': tMs,
          'type': 'fault_start',
          'fault': f.type,
          'message': f.message,
        });
      }
    }

    _activeFaultTypes
      ..clear()
      ..addAll(nextTypes);
    _activeFaultMessages
      ..clear()
      ..addAll(nextMessages);
  }

  static bool _containsPair(
    List<String> types,
    List<String> messages,
    String type,
    String message,
  ) {
    for (var i = 0; i < types.length; i++) {
      if (types[i] == type && messages[i] == message) return true;
    }
    return false;
  }

  static bool _liveContainsPair(
    List<FaultRecord> liveFaults,
    String type,
    String message,
  ) {
    for (var i = 0; i < liveFaults.length; i++) {
      final f = liveFaults[i];
      if (f.type == type && f.message == message) return true;
    }
    return false;
  }

  void recordCue({
    required String key,
    required bool played,
    String? fault,
  }) {
    final event = <String, Object?>{
      't_ms': _currentTMs,
      'type': 'cue',
      'key': key,
      'played': played,
      if (fault != null && fault.isNotEmpty) 'fault': fault,
    };
    if (_completed) {
      if (_currentTMs == _completedTMs &&
          _events.isNotEmpty &&
          _events.last['type'] == 'set_complete') {
        _events.insert(_events.length - 1, event);
      }
      return;
    }
    _events.add(event);
  }

  Map<String, Object?> buildSetJson({
    required Map<String, dynamic> setLogs,
    ExerciseBase? exercise,
  }) {
    final startedUtc = _startedAtUtc ?? (_clockUtc ?? _defaultUtcNow)();
    final durationMs = _currentTMs;
    final meanFps = durationMs > 0
        ? ((_totalFrames * 10000.0 / durationMs).round() / 10.0)
        : 0.0;

    final int reps;
    final int goodReps;
    if (_loggedRepCount > 0) {
      reps = _loggedRepCount;
      goodReps = _goodLoggedReps;
    } else if (exercise != null) {
      final logger = exercise.logger;
      final repLogLen = logger.repLogCount;
      if (repLogLen > 0) {
        reps = repLogLen;
        var good = 0;
        for (var i = 0; i < repLogLen; i++) {
          if (logger.repLogAt(i).correctForm) good++;
        }
        goodReps = good;
      } else {
        reps = exercise.repCount;
        final loggedGood = setLogs['good_rep_count'];
        goodReps = loggedGood is int ? loggedGood : 0;
      }
    } else {
      reps = _lastRepCount;
      final loggedGood = setLogs['good_rep_count'];
      goodReps = loggedGood is int ? loggedGood : 0;
    }

    return <String, Object?>{
      'schema': 1,
      'kind': 'exercise_set',
      'session_id': sessionId,
      'participant_id': participantId,
      'condition': condition,
      'app_version': appVersion,
      'platform': platform,
      'os_version': osVersion,
      'exercise_id': exerciseId,
      'set_index': setIndex,
      'started_at_utc': formatUtcIsoMillis(startedUtc),
      'sync_beep_t_ms': _syncBeepTMs,
      'frames': <String, Object?>{
        'total': _totalFrames,
        'with_pose': _framesWithPose,
        'duration_ms': durationMs,
        'mean_fps': meanFps,
        'min_fps_1s': _minFps1s ?? 0,
        'max_gap_ms': _maxGapMs,
      },
      'events': List<Map<String, Object?>>.from(_events),
      'set_log': Map<String, dynamic>.from(setLogs),
      'summary': <String, Object?>{
        'reps': reps,
        'good_reps': goodReps,
        'active_ms': _activeMs,
        'unseen_ms': _unseenMs,
        'paused_ms': _pausedMs,
      },
    };
  }
}
