import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/Jump_Squat/jump_squat.dart';
import 'package:vika/exercise/Jump_Squat/metrics/jump_squat_metric_base.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/models/exercise_definition.dart';

// Same side-view fixture as jump_squat_anti_cheat_test (facing left).
PoseLandmark _lm(PoseLandmarkType type, double x, double y) =>
    PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.99);

Map<PoseLandmarkType, PoseLandmark> _pose({
  required double kneeAngle,
  required double hipY,
  double supportY = 400,
}) {
  const hipX = 180.0;
  final kneeY = hipY + 100;
  final radians = (-90 + kneeAngle) * math.pi / 180.0;
  final ankleX = hipX + math.cos(radians) * 100;
  final ankleY = math.min(kneeY + math.sin(radians) * 100, supportY);
  return {
    PoseLandmarkType.nose: _lm(PoseLandmarkType.nose, hipX, hipY - 170),
    PoseLandmarkType.leftShoulder:
        _lm(PoseLandmarkType.leftShoulder, hipX, hipY - 120),
    PoseLandmarkType.leftHip: _lm(PoseLandmarkType.leftHip, hipX, hipY),
    PoseLandmarkType.leftKnee: _lm(PoseLandmarkType.leftKnee, hipX, kneeY),
    PoseLandmarkType.leftAnkle: _lm(PoseLandmarkType.leftAnkle, ankleX, ankleY),
    PoseLandmarkType.leftHeel:
        _lm(PoseLandmarkType.leftHeel, ankleX - 12, supportY),
    PoseLandmarkType.leftFootIndex:
        _lm(PoseLandmarkType.leftFootIndex, ankleX + 24, supportY),
  };
}

final _standing = _pose(kneeAngle: 175, hipY: 200);
final _deepSquat = _pose(kneeAngle: 85, hipY: 260);
final _shallowDip = _pose(kneeAngle: 135, hipY: 225);
final _airborne = _pose(kneeAngle: 170, hipY: 155, supportY: 335);
final _landing = _pose(kneeAngle: 115, hipY: 220);

JumpSquat _active() {
  final exercise = JumpSquat(maxRep: 4)
    ..cameraFacing = CameraFacing.left
    ..exerciseState = ExerciseState.activated;
  expect(exercise.isInStartPosition(_standing), isTrue);
  return exercise;
}

int _t = 0;
void _pump(JumpSquat exercise, Map<PoseLandmarkType, PoseLandmark> pose,
    [int frames = 1]) {
  for (var i = 0; i < frames; i++) {
    _t += 100;
    exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(_t);
    exercise.checkingPose(pose);
  }
}

void _landAndStand(JumpSquat exercise) {
  _pump(exercise, _landing, 2);
  _pump(exercise, _standing, 3);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a squat without a jump returns to standing and is not counted', () {
    final exercise = _active();
    _pump(exercise, _standing, 2);
    _pump(exercise, _deepSquat, 2);
    expect(exercise.jumpSquatState, JumpSquatState.squatting);
    _pump(exercise, _standing, 3);
    expect(exercise.jumpSquatState, JumpSquatState.standing);
    expect(exercise.repCount, 0);
    expect(exercise.logger.repLogs, isEmpty);
  });

  test('a shallow jump after an aborted deep squat is faulted on its own dip',
      () {
    final exercise = _active();
    _pump(exercise, _standing, 2);
    _pump(exercise, _deepSquat, 2);
    _pump(exercise, _standing, 3);
    _pump(exercise, _shallowDip, 2);
    _pump(exercise, _pose(kneeAngle: 155, hipY: 210));
    _pump(exercise, _pose(kneeAngle: 165, hipY: 190));
    _pump(exercise, _airborne, 2);
    _landAndStand(exercise);
    expect(exercise.repCount, 1);
    expect(exercise.logger.repLogs.single.data['fault_types'],
        contains('takeoff_depth'));
  });

  test('takeoff_depth is evaluated when squatting goes straight to airborne',
      () {
    final exercise = _active();
    _pump(exercise, _standing, 2);
    _pump(exercise, _shallowDip, 2);
    expect(exercise.jumpSquatState, JumpSquatState.squatting);
    _pump(exercise, _airborne, 2);
    expect(exercise.jumpSquatState, JumpSquatState.airborne);
    _landAndStand(exercise);
    expect(exercise.repCount, 1);
    expect(exercise.logger.repLogs.single.data['fault_types'],
        contains('takeoff_depth'));
  });

  test('a deep jump squat still counts clean', () {
    final exercise = _active();
    _pump(exercise, _standing, 2);
    _pump(exercise, _deepSquat, 2);
    _pump(exercise, _pose(kneeAngle: 110, hipY: 245));
    _pump(exercise, _pose(kneeAngle: 130, hipY: 225));
    _pump(exercise, _airborne, 2);
    _landAndStand(exercise);
    expect(exercise.repCount, 1);
    expect(exercise.logger.repLogs.single.correctForm, isTrue);
  });

  test('setup copy asks for the side view checkSafety requires', () {
    final def = exerciseDefinitions.firstWhere((d) => d.id == 'jump__squat');
    expect(def.cameraHint, isNot(contains('đối diện')));
    expect(def.cameraHint, contains('nghiêng'));
    expect(def.subtitle, isNot('Chưa có mô tả'));
    expect(def.description, isNot(startsWith('Bản xem trước')));
  });
}
