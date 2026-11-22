import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/tricep_dip/tricep_dip.dart';

PoseLandmark _landmark(PoseLandmarkType type, double x, double y) {
  return PoseLandmark(
    type: type,
    x: x,
    y: y,
    z: 0,
    likelihood: 0.99,
  );
}

Map<PoseLandmarkType, PoseLandmark> _dipPose({
  double elbowAngle = 180,
  double hipY = 350,
}) {
  final offset =
      elbowAngle >= 180 ? 0.0 : 111.8 / math.tan(elbowAngle * math.pi / 360);
  return {
    PoseLandmarkType.leftEar: _landmark(PoseLandmarkType.leftEar, 180, 160),
    PoseLandmarkType.leftShoulder:
        _landmark(PoseLandmarkType.leftShoulder, 200, 200),
    PoseLandmarkType.leftElbow: _landmark(PoseLandmarkType.leftElbow,
        250 - 0.894 * offset, 300 + 0.447 * offset),
    PoseLandmarkType.leftWrist: _landmark(PoseLandmarkType.leftWrist, 300, 400),
    PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, 400, hipY),
    PoseLandmarkType.leftAnkle: _landmark(PoseLandmarkType.leftAnkle, 600, 400),
  };
}

var _clockMs = 0;

TricepDip _started() {
  final exercise = TricepDip(maxRep: 10)
    ..cameraFacing = CameraFacing.left
    ..exerciseState = ExerciseState.activated;
  expect(exercise.isInStartPosition(_dipPose()), isTrue);
  return exercise;
}

void _run(TricepDip exercise, List<double> elbowAngles, {double hipY = 350}) {
  for (final angle in elbowAngles) {
    _clockMs += 100;
    exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(_clockMs);
    exercise.checkingPose(_dipPose(elbowAngle: angle, hipY: hipY));
  }
}

const _oneDip = <double>[170, 135, 135, 90, 90, 90, 135, 135, 170, 170, 170];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a bend below 120 deg and a push back to straight arms is one rep', () {
    final exercise = _started();

    _run(exercise, _oneDip);

    expect(exercise.repCount, 1);
    expect(exercise.tricepState, TricepDipState.setup_top);
    final data = exercise.logger.repLogs.single.data;
    expect(data['min_elbow_angle'] as double, closeTo(90, 1));
    expect(data['top_elbow_angle'] as double,
        greaterThanOrEqualTo(TricepDipConfig.TOP_ELBOW_ANGLE));

    _run(exercise, [170, 170, 170]);
    expect(exercise.repCount, 1, reason: 'straight arms must not repeat-count');
  });

  test('dips with the hips off the floor count without sitting back down', () {
    final exercise = _started();

    _run(exercise, [..._oneDip, ..._oneDip], hipY: 300);

    expect(exercise.repCount, 2);
  });

  test('a hip lift without bending the elbows is not a rep', () {
    final exercise = _started();

    for (final hipY in <double>[350, 300, 280, 280, 280, 300, 350, 350]) {
      _run(exercise, [180], hipY: hipY);
    }

    expect(exercise.repCount, 0);
  });

  test('a shallow bend that never reaches 120 deg is not a rep', () {
    final exercise = _started();

    _run(exercise, [170, 135, 135, 128, 128, 135, 170, 170, 170]);

    expect(exercise.repCount, 0);
    expect(exercise.tricepState, TricepDipState.setup_top);
  });
}
