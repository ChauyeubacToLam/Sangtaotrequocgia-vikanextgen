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
final _landing = _pose(kneeAngle: 95, hipY: 235);

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

Map<PoseLandmarkType, PoseLandmark> _torso(double shoulderWidth) => {
      PoseLandmarkType.leftShoulder:
          _lm(PoseLandmarkType.leftShoulder, 200, 100),
      PoseLandmarkType.rightShoulder:
          _lm(PoseLandmarkType.rightShoulder, 200 + shoulderWidth, 100),
      PoseLandmarkType.leftHip: _lm(PoseLandmarkType.leftHip, 200, 200),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an angled reading mid-set keeps the side view, facing the camera does not',
      () {
    final exercise = JumpSquat(maxRep: 4);
    final side = exercise.detectCameraFacing(_torso(10));
    expect(side, anyOf(CameraFacing.left, CameraFacing.right));
    expect(exercise.detectCameraFacing(_torso(45)), CameraFacing.angled);
    exercise.exerciseState = ExerciseState.activated;
    expect(exercise.detectCameraFacing(_torso(45)), side);
    expect(exercise.detectCameraFacing(_torso(80)), CameraFacing.front);
  });

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

  test('a jump from a 150 deg dip counts and is faulted takeoff_depth', () {
    final exercise = _active();
    _pump(exercise, _standing, 2);
    _pump(exercise, _pose(kneeAngle: 150, hipY: 215), 2);
    expect(exercise.jumpSquatState, JumpSquatState.squatting);
    _pump(exercise, _airborne, 2);
    _landAndStand(exercise);
    expect(exercise.repCount, 1);
    expect(exercise.logger.repLogs.single.data['fault_types'],
        contains('takeoff_depth'));
  });

  test('a 105 deg takeoff dip is shallow; a 90 deg dip is not', () {
    for (final (dip, faulted) in [(105.0, true), (90.0, false)]) {
      final exercise = _active();
      _pump(exercise, _standing, 2);
      _pump(exercise, _pose(kneeAngle: dip, hipY: 240), 2);
      _pump(exercise, _airborne, 2);
      _landAndStand(exercise);
      final data = exercise.logger.repLogs.single.data;
      expect((data['fault_types'] as List).contains('takeoff_depth'), faulted,
          reason: '$dip');
      expect(data['takeoff_knee'], closeTo(dip, 0.5));
      expect(data['landing_knee'], closeTo(95, 0.5));
      expect(data['jump_height_ratio'], greaterThan(0.3));
    }
  });

  test('landing with the knee only bent to 115 deg marks the rep wrong', () {
    final exercise = _active();
    _pump(exercise, _standing, 2);
    _pump(exercise, _deepSquat, 2);
    _pump(exercise, _airborne, 2);
    _pump(exercise, _pose(kneeAngle: 115, hipY: 220), 2);
    _pump(exercise, _standing, 3);
    final rep = exercise.logger.repLogs.single;
    expect(rep.data['fault_types'], contains('landing_depth'));
    expect(rep.correctForm, isFalse);
  });

  test('landing further from the camera than the takeoff still counts', () {
    final exercise = _active();
    _pump(exercise, _standing, 2);
    _pump(exercise, _deepSquat, 2);
    _pump(exercise, _airborne, 2);
    expect(exercise.jumpSquatState, JumpSquatState.airborne);
    _pump(exercise, _pose(kneeAngle: 170, hipY: 150, supportY: 330));
    _pump(exercise, _pose(kneeAngle: 115, hipY: 200, supportY: 380), 3);
    expect(exercise.jumpSquatState, JumpSquatState.landing);
    _pump(exercise, _pose(kneeAngle: 175, hipY: 180, supportY: 380), 4);
    expect(exercise.repCount, 1);
  });

  test('a jump never seen landing ends after the airborne time limit', () {
    final exercise = _active();
    _pump(exercise, _standing, 2);
    _pump(exercise, _deepSquat, 2);
    _pump(exercise, _airborne, 2);
    _pump(exercise, _pose(kneeAngle: 175, hipY: 160, supportY: 335), 10);
    expect(exercise.jumpSquatState, isNot(JumpSquatState.airborne));
  });

  test('standing still at a new spot re-anchors the floor', () {
    final exercise = _active();
    _pump(exercise, _standing, 2);
    _pump(exercise, _pose(kneeAngle: 175, hipY: 170, supportY: 370), 10);
    expect(exercise.jumpSquatState, JumpSquatState.standing);
    expect(exercise.debugData['SupportLift'], '0.0');
    expect(exercise.debugData['HipLift'], '0.0');
  });

  test('setup copy asks for the side view checkSafety requires', () {
    final def = exerciseDefinitions.firstWhere((d) => d.id == 'jump__squat');
    expect(def.cameraHint, isNot(contains('đối diện')));
    expect(def.cameraHint, contains('nghiêng'));
    expect(def.subtitle, isNot('Chưa có mô tả'));
    expect(def.description, isNot(startsWith('Bản xem trước')));
  });
}
