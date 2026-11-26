import '../exercise/exercise_base.dart';
import '../pose/pose_landmarker_channel.dart';
import '../utils/exercise_logger.dart';

const bool kRepReplayEnabled = true;

String faultTitle(String message) {
  final head = message.split(RegExp(r'[:(]')).first.trim();
  return head.isEmpty ? message.trim() : head;
}

Map<String, String> faultTitlesFromSetFeedback(
  List<Map<bool, Map<String, Map<String, String>>>> setFeedback,
) {
  final titles = <String, String>{};
  for (final rep in setFeedback) {
    for (final byPhase in rep.values) {
      for (final byType in byPhase.values) {
        byType.forEach((type, message) {
          if (message.trim().isNotEmpty) titles[type] = faultTitle(message);
        });
      }
    }
  }
  return titles;
}

class RepReplayEntry {
  const RepReplayEntry({
    required this.clipId,
    required this.repNumber,
    required this.faultTypes,
    required this.label,
  });

  final String clipId;
  final int repNumber;
  final List<String> faultTypes;
  final String label;
}

class RepReplayCollector {
  RepReplayCollector({
    Future<int> Function(String id, int durationMs)? saveClip,
    Future<void> Function()? startCapture,
    Future<void> Function()? stopCapture,
  })  : _saveClip = saveClip ?? PoseLandmarkerChannel().saveReplayClip,
        _startCapture = startCapture ?? PoseLandmarkerChannel().startReplayCapture,
        _stopCapture = stopCapture ?? PoseLandmarkerChannel().stopReplayCapture;

  static const int maxFaultClips = 3;
  static const int minClipMs = 800;
  static const int maxClipMs = 3500;

  final Future<int> Function(String id, int durationMs) _saveClip;
  final Future<void> Function() _startCapture;
  final Future<void> Function() _stopCapture;

  RepReplayEntry? goodRep;
  final List<RepReplayEntry> faultReps = <RepReplayEntry>[];

  int _seenReps = 0;
  int? _lastRepEndMs;
  bool _capturing = false;
  final Set<String> _capturedFaultKeys = <String>{};

  bool get hasReplay => faultReps.isNotEmpty;

  void begin() {
    goodRep = null;
    faultReps.clear();
    _capturedFaultKeys.clear();
    _seenReps = 0;
    _lastRepEndMs = null;
    _capturing = true;
    _startCapture();
  }

  void end() {
    if (!_capturing) return;
    _capturing = false;
    _stopCapture();
  }

  void observe(ExerciseBase exercise) {
    onFrame(
      nowMs: exercise.frameTimestampMs,
      activated: exercise.exerciseState == ExerciseState.activated,
      logger: exercise.logger,
      mutedFaultTypes: exercise.mutedFaultTypes,
      describe: (type) => _latestMessage(exercise.setFeedback, type),
    );
  }

  void onFrame({
    required int nowMs,
    required bool activated,
    required ExerciseLogger logger,
    Set<String> mutedFaultTypes = const <String>{},
    String? Function(String type)? describe,
  }) {
    if (!_capturing) return;
    if (activated && _lastRepEndMs == null) _lastRepEndMs = nowMs;
    final count = logger.repLogCount;
    if (count < _seenReps) _seenReps = count;
    for (var i = _seenReps; i < count; i++) {
      _onRep(logger.repLogAt(i), nowMs, mutedFaultTypes, describe);
    }
    _seenReps = count;
  }

  void _onRep(
    RepLog rep,
    int nowMs,
    Set<String> muted,
    String? Function(String type)? describe,
  ) {
    final start = _lastRepEndMs ?? nowMs - maxClipMs;
    final durationMs = (nowMs - start).clamp(minClipMs, maxClipMs);
    _lastRepEndMs = nowMs;
    if (!ExerciseLogger.isFormJudged(rep)) return;

    if (rep.correctForm) {
      goodRep = RepReplayEntry(
        clipId: 'good',
        repNumber: rep.repNumber,
        faultTypes: const <String>[],
        label: 'Rep ${rep.repNumber} · đúng',
      );
      _saveClip('good', durationMs);
      return;
    }

    if (faultReps.length >= maxFaultClips) return;
    final types = formFaultTypes(rep)
        .where((type) => !muted.contains(type))
        .toList();
    final names = <String>[
      for (final type in types) describe?.call(type) ?? type,
    ];
    final keys = <String>{
      for (var i = 0; i < types.length; i++)
        '${types[i]}|${faultTitle(names[i])}',
    };
    if (keys.isEmpty || keys.every(_capturedFaultKeys.contains)) return;
    _capturedFaultKeys.addAll(keys);

    final id = 'fault_${faultReps.length}';
    faultReps.add(RepReplayEntry(
      clipId: id,
      repNumber: rep.repNumber,
      faultTypes: types,
      label: 'Rep ${rep.repNumber} · ${names.join(' · ')}',
    ));
    _saveClip(id, durationMs);
  }

  static List<String> formFaultTypes(RepLog rep) {
    final affects = rep.data['fault_affects_form'];
    if (affects is Map) {
      return <String>[
        for (final entry in affects.entries)
          if (entry.value == true) entry.key.toString(),
      ];
    }
    final types = rep.data['fault_types'];
    return types is List ? types.map((t) => t.toString()).toList() : <String>[];
  }

  static String? _latestMessage(
    List<Map<bool, Map<String, Map<String, String>>>> setFeedback,
    String type,
  ) {
    for (final rep in setFeedback.reversed) {
      for (final byPhase in rep.values) {
        for (final byType in byPhase.values) {
          final message = byType[type];
          if (message != null && message.trim().isNotEmpty) return message;
        }
      }
    }
    return null;
  }
}
