import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/fault_record.dart';
import 'package:vika/exercise/presence_gate.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/utils/person_detector.dart';

class _FakePresenceSource implements PosePresenceSource {
  @override
  bool personDetected = true;
  @override
  double presenceScore = 1.0;

  @override
  Future<bool> detect([Object? _]) async => personDetected;

  @override
  Future<void> triggerCheck({String reason = 'unknown'}) async {}

  @override
  Future<void> useActivatedCadence() async {}

  @override
  Future<void> usePausedCadence() async {}

  @override
  Future<void> close() async {}
}

class _SkipTestExercise extends ExerciseBase {
  _SkipTestExercise({super.gate}) : super(targetReps: 99);

  GuidanceSignal? safety;
  bool throwInCheckingPose = false;
  int checkingPoseCalls = 0;

  @override
  List<FaultRecord> get liveFaults => [
        FaultRecord(phase: 'bottom', type: 'depth', message: 'Nông'),
        FaultRecord(phase: 'bottom', type: 'trunk', message: 'Đổ người'),
      ];

  @override
  String get exerciseName => 'Skip Test';

  @override
  String get currentPhaseKey => 'bottom';

  @override
  String get currentPhaseLabel => 'Test';

  @override
  GuidanceSignal? checkSafety(
          Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) =>
      safety;

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    checkingPoseCalls++;
    if (throwInCheckingPose) throw StateError('missing landmark');
    repCount++;
    resultIssues.feedback['Depth'] = 'Xuống sâu hơn';
    logger.addRepLog(RepLog(
      repNumber: repCount,
      correctForm: false,
      data: <String, dynamic>{
        'fault_types': <String>['depth'],
      },
    ));
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) =>
      false;

  @override
  void onSetComplete() {}

  @override
  bool requestStop() => false;
}

Map<PoseLandmarkType, PoseLandmark> _allLandmarks() {
  return {
    for (final t in PoseLandmarkType.values)
      t: PoseLandmark(type: t, x: 200, y: 400, z: 0, likelihood: 0.99),
  };
}

_SkipTestExercise _activated() {
  return _SkipTestExercise(
    gate: PresenceGate(detector: _FakePresenceSource()),
  )..exerciseState = ExerciseState.activated;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an unskipped safety signal blocks the frame as before', () {
    final exercise = _activated()
      ..safety = const GuidanceSignal.lighting();

    exercise.processPose(_allLandmarks());

    expect(exercise.checkingPoseCalls, 0);
    expect(exercise.guidanceSignal?.kind, GuidanceClass.lighting);
    expect(exercise.isFormJudgingSuspended, isFalse);
  });

  test('only camera-quality guidance can be skipped', () {
    final exercise = _activated();

    expect(exercise.skipGuidance(GuidanceClass.lighting), isTrue);
    expect(exercise.skipGuidance(GuidanceClass.lighting), isFalse);
    expect(exercise.skipGuidance(GuidanceClass.turnSide), isTrue);
    expect(exercise.skipGuidance(GuidanceClass.faceCamera), isTrue);
    expect(exercise.skipGuidance(GuidanceClass.bodyInFrame), isFalse);
    expect(exercise.skipGuidance(GuidanceClass.paused), isFalse);
    expect(exercise.skipGuidance(GuidanceClass.searching), isFalse);
    expect(exercise.skipGuidance(GuidanceClass.phoneLandscape), isFalse);
  });

  test('a skipped signal keeps counting but does not judge form', () {
    final exercise = _activated()
      ..safety = const GuidanceSignal.turnSide();
    exercise.skipGuidance(GuidanceClass.turnSide);

    final result = exercise.processPose(_allLandmarks());

    expect(exercise.checkingPoseCalls, 1);
    expect(exercise.repCount, 1);
    expect(exercise.guidanceSignal, isNull);
    expect(exercise.formJudgingSuspendedBy, GuidanceClass.turnSide);
    expect(exercise.judgedLiveFaults, isEmpty);
    expect(exercise.cueableLiveFaults, isEmpty);
    expect((result![1] as Map<String, String>), isEmpty);

    final rep = exercise.logger.repLogs.single;
    expect(rep.data['fault_types'], isEmpty);
    expect(ExerciseLogger.isFormJudged(rep), isFalse);
  });

  test('judging resumes on the first frame the camera sees well again', () {
    final exercise = _activated()
      ..safety = const GuidanceSignal.lighting();
    exercise.skipGuidance(GuidanceClass.lighting);
    exercise.processPose(_allLandmarks());

    exercise.safety = null;
    exercise.processPose(_allLandmarks());

    expect(exercise.isFormJudgingSuspended, isFalse);
    expect(exercise.judgedLiveFaults, hasLength(2));
    final second = exercise.logger.repLogs.last;
    expect(second.data['fault_types'], <String>['depth']);
    expect(ExerciseLogger.isFormJudged(second), isTrue);
  });

  test('a crash in exercise logic while skipped drops the frame only', () {
    final exercise = _activated()
      ..safety = const GuidanceSignal.turnSide()
      ..throwInCheckingPose = true;
    exercise.skipGuidance(GuidanceClass.turnSide);

    final result = exercise.processPose(_allLandmarks());

    expect(exercise.checkingPoseCalls, 1);
    expect(result, isNotNull);
    expect(exercise.repCount, 0);
  });

  test('disputed faults are muted from cues but kept in the judged log', () {
    final exercise = _activated()..mutedFaultTypes = <String>{'depth'};

    exercise.processPose(_allLandmarks());

    expect(exercise.judgedLiveFaults.map((f) => f.type),
        containsAll(<String>['depth', 'trunk']));
    expect(exercise.cueableLiveFaults.map((f) => f.type), <String>['trunk']);
    expect(exercise.logger.repLogs.single.data['fault_types'],
        <String>['depth']);
  });

  test('an unjudged mark only applies to the next rep', () {
    final logger = ExerciseLogger()..markFormUnjudged();

    logger.addRepLog(RepLog(
      repNumber: 1,
      correctForm: false,
      data: <String, dynamic>{'fault_types': <String>['depth']},
    ));
    logger.addRepLog(RepLog(
      repNumber: 2,
      correctForm: false,
      data: <String, dynamic>{'fault_types': <String>['depth']},
    ));

    expect(ExerciseLogger.isFormJudged(logger.repLogAt(0)), isFalse);
    expect(logger.repLogAt(0).correctForm, isTrue);
    expect(ExerciseLogger.isFormJudged(logger.repLogAt(1)), isTrue);
    expect(logger.repLogAt(1).data['fault_types'], <String>['depth']);
  });
}
