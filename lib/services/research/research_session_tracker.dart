import 'dart:io';

import '../../exercise/exercise_base.dart';
import 'json_sanitizer.dart';
import 'research_log_storage.dart';
import 'research_preferences.dart';
import 'set_recorder.dart';

class ResearchSetSlot {
  ResearchSetSlot({
    required this.seq,
    required this.exerciseId,
    required this.setIndex,
    required this.fileName,
  });

  int seq;
  String exerciseId;
  int setIndex;
  String fileName;
  bool flushing = false;
  bool recorded = false;
  bool discarded = false;
}

class ResearchSession {
  ResearchSession({
    required String sessionId,
    required ResearchConfig config,
    required this.startedAtUtc,
  })  : _sessionId = sessionId,
        _config = config;

  String _sessionId;
  ResearchConfig _config;
  final DateTime startedAtUtc;
  final List<String> setFiles = <String>[];
  final Map<String, int> _setCountByExercise = <String, int>{};
  int _seqCounter = 0;
  bool isEnded = false;
  String? sessionFileName;

  String get sessionId => _sessionId;
  ResearchConfig get config => _config;

  String get expectedSessionFileName => 'vika_${_sessionId}_session.json';

  // Faults the user marked "Báo sai" on the rest screen, keyed by the set's
  // slot so a late exercise-id rekey is still reflected at session end.
  final Map<ResearchSetSlot, Set<String>> _faultReports =
      <ResearchSetSlot, Set<String>>{};

  void setFaultReported(
    ResearchSetSlot slot,
    String fault, {
    required bool reported,
  }) {
    if (isEnded) return;
    final faults = _faultReports.putIfAbsent(slot, () => <String>{});
    reported ? faults.add(fault) : faults.remove(fault);
    if (faults.isEmpty) _faultReports.remove(slot);
  }

  List<Map<String, Object?>> get faultReportsJson => <Map<String, Object?>>[
        for (final entry in _faultReports.entries)
          for (final fault in (entry.value.toList()..sort()))
            <String, Object?>{
              'exercise_id': entry.key.exerciseId,
              'set_index': entry.key.setIndex,
              'file': entry.key.fileName,
              'fault': fault,
            },
      ];

  List<String> get allExportFileNames => <String>[
        ...setFiles,
        if (sessionFileName != null) sessionFileName!,
      ];

  void updateConfigBeforeFirstSet(
    ResearchConfig nextConfig, {
    ResearchSetSlot? pendingSlot,
  }) {
    if (isEnded || setFiles.isNotEmpty) return;
    _config = nextConfig;
    _sessionId =
        '${formatSessionTimestampUtc(startedAtUtc)}-${nextConfig.participantId}';
    if (pendingSlot != null && !pendingSlot.recorded && !pendingSlot.discarded) {
      pendingSlot.fileName = _buildSetFileName(
        sessionId: _sessionId,
        seq: pendingSlot.seq,
        rawExerciseId: pendingSlot.exerciseId,
        setIdx: pendingSlot.setIndex,
      );
    }
  }

  ResearchSetSlot allocateSetSlot(String rawExerciseId) {
    _seqCounter += 1;
    final setIdx = (_setCountByExercise[rawExerciseId] ?? 0) + 1;
    _setCountByExercise[rawExerciseId] = setIdx;
    final fileName = _buildSetFileName(
      sessionId: _sessionId,
      seq: _seqCounter,
      rawExerciseId: rawExerciseId,
      setIdx: setIdx,
    );
    return ResearchSetSlot(
      seq: _seqCounter,
      exerciseId: rawExerciseId,
      setIndex: setIdx,
      fileName: fileName,
    );
  }

  void discardUnrecordedSlot(ResearchSetSlot slot) {
    if (slot.recorded || slot.flushing || slot.discarded) return;
    slot.discarded = true;
    if (_seqCounter == slot.seq) {
      _seqCounter -= 1;
    }
    final currentExIdx = _setCountByExercise[slot.exerciseId];
    if (currentExIdx != null && currentExIdx == slot.setIndex) {
      if (currentExIdx <= 1) {
        _setCountByExercise.remove(slot.exerciseId);
      } else {
        _setCountByExercise[slot.exerciseId] = currentExIdx - 1;
      }
    }
  }

  void rekeyPendingSlotExerciseId(
    ResearchSetSlot slot,
    String rawExerciseId,
  ) {
    if (isEnded || slot.recorded || slot.discarded) return;
    if (slot.exerciseId == rawExerciseId || rawExerciseId.trim().isEmpty) {
      return;
    }
    final oldId = slot.exerciseId;
    final oldIdx = _setCountByExercise[oldId];
    if (oldIdx != null && oldIdx == slot.setIndex) {
      if (oldIdx <= 1) {
        _setCountByExercise.remove(oldId);
      } else {
        _setCountByExercise[oldId] = oldIdx - 1;
      }
    }
    final nextIdx = (_setCountByExercise[rawExerciseId] ?? 0) + 1;
    _setCountByExercise[rawExerciseId] = nextIdx;
    slot.exerciseId = rawExerciseId;
    slot.setIndex = nextIdx;
    slot.fileName = _buildSetFileName(
      sessionId: _sessionId,
      seq: slot.seq,
      rawExerciseId: rawExerciseId,
      setIdx: nextIdx,
    );
  }

  static String _buildSetFileName({
    required String sessionId,
    required int seq,
    required String rawExerciseId,
    required int setIdx,
  }) {
    final safeExerciseId = _sanitizeId(rawExerciseId);
    final seqStr = seq.toString().padLeft(2, '0');
    return 'vika_${sessionId}_${seqStr}_${safeExerciseId}_set$setIdx.json';
  }

  static String _sanitizeId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return 'unknown';
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }
}

class ResearchSessionTracker {
  ResearchSessionTracker({ResearchLogStorage? storage})
      : _storage = storage ?? ResearchLogStorage.instance;

  static final ResearchSessionTracker instance = ResearchSessionTracker();

  final ResearchLogStorage _storage;
  ResearchSession? _activeSession;

  ResearchSession? get activeSession => _activeSession;

  ResearchLogStorage get storage => _storage;

  ResearchSession beginOrContinueSession({
    required ResearchConfig config,
    required bool isContinuation,
    DateTime? nowUtc,
  }) {
    final existing = _activeSession;
    if (isContinuation && existing != null && !existing.isEnded) {
      return existing;
    }

    if (existing != null && !existing.isEnded && existing.setFiles.isNotEmpty) {
      // Flush previous unfinished session off-path before starting a new one.
      endSession(satisfaction: null, endedAtUtc: nowUtc);
    }

    final started = (nowUtc ?? DateTime.now()).toUtc();
    final sessionId =
        '${formatSessionTimestampUtc(started)}-${config.participantId}';
    final fresh = ResearchSession(
      sessionId: sessionId,
      config: config,
      startedAtUtc: started,
    );
    _activeSession = fresh;
    return fresh;
  }

  ResearchSetSlot nextSetSlot(String exerciseId) {
    final session = _activeSession ??
        beginOrContinueSession(
          config: const ResearchConfig(),
          isContinuation: false,
        );
    return session.allocateSetSlot(exerciseId);
  }

  Future<File?> finishSet({
    required ResearchSetSlot slot,
    required SetRecorder recorder,
    required Map<String, dynamic> setLogs,
    ExerciseBase? exercise,
    ResearchSession? session,
  }) {
    if (slot.recorded) {
      return Future<File?>.value(null);
    }
    slot.recorded = true;
    final targetSession = session ?? _activeSession;
    if (targetSession != null &&
        !targetSession.setFiles.contains(slot.fileName)) {
      targetSession.setFiles.add(slot.fileName);
    }
    final payload = recorder.buildSetJson(
      setLogs: setLogs,
      exercise: exercise,
    );
    return _storage.writeJsonFile(
      fileName: slot.fileName,
      payload: payload,
    );
  }

  void detachActiveSession(ResearchSession? session) {
    if (session != null && identical(_activeSession, session)) {
      _activeSession = null;
    }
  }

  void discardSessionIfEmpty(ResearchSession? session) {
    final target = session ?? _activeSession;
    if (target == null || target.isEnded || target.setFiles.isNotEmpty) {
      return;
    }
    target.isEnded = true;
    if (identical(_activeSession, target)) {
      _activeSession = null;
    }
  }

  Future<File?> endSession({
    int? satisfaction,
    DateTime? endedAtUtc,
    ResearchSession? session,
  }) {
    final target = session ?? _activeSession;
    if (target == null || target.isEnded) {
      return Future<File?>.value(null);
    }
    target.isEnded = true;
    if (identical(_activeSession, target)) {
      _activeSession = null;
    }
    final ended = (endedAtUtc ?? DateTime.now()).toUtc();
    final fileName = target.expectedSessionFileName;
    target.sessionFileName = fileName;
    final payload = <String, Object?>{
      'schema': 1,
      'kind': 'session',
      'session_id': target.sessionId,
      'participant_id': target.config.participantId,
      'condition': target.config.condition.storageValue,
      'started_at_utc': formatUtcIsoMillis(target.startedAtUtc),
      'ended_at_utc': formatUtcIsoMillis(ended),
      'satisfaction': satisfaction,
      'fault_reports': target.faultReportsJson,
      'files': List<String>.from(target.setFiles),
    };
    return _storage.writeJsonFile(
      fileName: fileName,
      payload: payload,
    );
  }
}
