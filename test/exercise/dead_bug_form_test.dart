import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/12.Dead Bug/dead_bug.dart';
import 'package:vika/exercise/12.Dead Bug/dead_bug_report_builder.dart';
import 'package:vika/exercise/exercise_base.dart';

PoseLandmark _landmark(
  PoseLandmarkType type,
  double x,
  double y, {
  double z = 0,
  double likelihood = 0.99,
}) {
  return PoseLandmark(
    type: type,
    x: x,
    y: y,
    z: z,
    likelihood: likelihood,
  );
}

({double x, double y}) _pointAt({
  required double x,
  required double y,
  required double angleDegrees,
  required double length,
}) {
  final radians = angleDegrees * math.pi / 180.0;
  return (
    x: x + math.cos(radians) * length,
    y: y + math.sin(radians) * length,
  );
}

({double x, double y}) _armPoint({
  required double shoulderX,
  required double shoulderY,
  required double angle,
}) {
  return _pointAt(
    x: shoulderX,
    y: shoulderY,
    angleDegrees: -angle,
    length: 100,
  );
}

({double x, double y}) _kneePoint({
  required double hipX,
  required double hipY,
  required double angle,
}) {
  final vectorAngle = angle <= 90 ? -90.0 : 180.0 - angle;
  return _pointAt(
    x: hipX,
    y: hipY,
    angleDegrees: vectorAngle,
    length: 100,
  );
}

Map<PoseLandmarkType, PoseLandmark> _deadBugPose({
  double leftArmAngle = 90,
  double rightArmAngle = 90,
  double leftLegAngle = 90,
  double rightLegAngle = 90,
  double hipLift = 0,
}) {
  const leftShoulderX = 100.0;
  const leftShoulderY = 200.0;
  const rightShoulderX = 100.0;
  const rightShoulderY = 220.0;
  const leftHipX = 220.0;
  final leftHipY = 200.0 - hipLift;
  const rightHipX = 220.0;
  final rightHipY = 220.0 - hipLift;

  final leftWrist = _armPoint(
    shoulderX: leftShoulderX,
    shoulderY: leftShoulderY,
    angle: leftArmAngle,
  );
  final rightWrist = _armPoint(
    shoulderX: rightShoulderX,
    shoulderY: rightShoulderY,
    angle: rightArmAngle,
  );
  final leftKnee = _kneePoint(
    hipX: leftHipX,
    hipY: leftHipY,
    angle: leftLegAngle,
  );
  final rightKnee = _kneePoint(
    hipX: rightHipX,
    hipY: rightHipY,
    angle: rightLegAngle,
  );

  PoseLandmark mark(PoseLandmarkType type, double x, double y) =>
      _landmark(type, x, y);

  return {
    PoseLandmarkType.leftShoulder:
        mark(PoseLandmarkType.leftShoulder, leftShoulderX, leftShoulderY),
    PoseLandmarkType.rightShoulder:
        mark(PoseLandmarkType.rightShoulder, rightShoulderX, rightShoulderY),
    PoseLandmarkType.leftWrist:
        mark(PoseLandmarkType.leftWrist, leftWrist.x, leftWrist.y),
    PoseLandmarkType.rightWrist:
        mark(PoseLandmarkType.rightWrist, rightWrist.x, rightWrist.y),
    PoseLandmarkType.leftHip:
        mark(PoseLandmarkType.leftHip, leftHipX, leftHipY),
    PoseLandmarkType.rightHip:
        mark(PoseLandmarkType.rightHip, rightHipX, rightHipY),
    PoseLandmarkType.leftKnee:
        mark(PoseLandmarkType.leftKnee, leftKnee.x, leftKnee.y),
    PoseLandmarkType.rightKnee:
        mark(PoseLandmarkType.rightKnee, rightKnee.x, rightKnee.y),
    PoseLandmarkType.leftAnkle: mark(
      PoseLandmarkType.leftAnkle,
      leftKnee.x + (leftKnee.x - leftHipX) * 0.6,
      leftKnee.y + (leftKnee.y - leftHipY) * 0.6,
    ),
    PoseLandmarkType.rightAnkle: mark(
      PoseLandmarkType.rightAnkle,
      rightKnee.x + (rightKnee.x - rightHipX) * 0.6,
      rightKnee.y + (rightKnee.y - rightHipY) * 0.6,
    ),
  };
}

void _pump(
  DeadBug exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

void _completeDeadBugRep({
  required DeadBug exercise,
  required Map<PoseLandmarkType, PoseLandmark> topPose,
  required Map<PoseLandmarkType, PoseLandmark> returningPose,
  required int startMs,
}) {
  final setupPose = _deadBugPose();

  _pump(exercise, topPose, startMs);
  _pump(exercise, topPose, startMs + 100);
  _pump(exercise, topPose, startMs + 1700);
  _pump(exercise, topPose, startMs + 1800);
  _pump(exercise, returningPose, startMs + 2000);
  _pump(exercise, returningPose, startMs + 2100);
  _pump(exercise, setupPose, startMs + 2200);
  _pump(exercise, setupPose, startMs + 2300);
}

DeadBug _activatedDeadBug() {
  return DeadBug(maxRep: 4)
    ..cameraFacing = CameraFacing.left
    ..exerciseState = ExerciseState.activated;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stable_limbs fires when a support limb straightens during a rep', () {
    final e = _activatedDeadBug();
    _pump(e, _deadBugPose(), 0);
    _pump(e, _deadBugPose(), 50);
    // Left arm + right leg extend; the right (support) arm drifts to 150.
    final top =
        _deadBugPose(leftArmAngle: 155, rightLegAngle: 155, rightArmAngle: 150);
    for (var i = 0; i < 8; i++) {
      _pump(e, top, 100 + i * 200);
    }
    final ret = _deadBugPose(leftArmAngle: 120, rightLegAngle: 120);
    _pump(e, ret, 2000);
    _pump(e, ret, 2100);
    _pump(e, _deadBugPose(), 2200);
    _pump(e, _deadBugPose(), 2300);
    expect(e.repCount, 1);
    expect(e.logger.repLogs.single.data['fault_types'], contains('stable_limbs'));
  });

  test('a clean rep with tabletop support limbs has no stable_limbs fault', () {
    final e = _activatedDeadBug();
    _pump(e, _deadBugPose(), 0);
    _pump(e, _deadBugPose(), 50);
    final top = _deadBugPose(leftArmAngle: 155, rightLegAngle: 155);
    for (var i = 0; i < 8; i++) {
      _pump(e, top, 100 + i * 200);
    }
    final ret = _deadBugPose(leftArmAngle: 120, rightLegAngle: 120);
    _pump(e, ret, 2000);
    _pump(e, ret, 2100);
    _pump(e, _deadBugPose(), 2200);
    _pump(e, _deadBugPose(), 2300);
    expect(e.repCount, 1);
    expect(e.logger.repLogs.single.data['fault_types'],
        isNot(contains('stable_limbs')));
  });

  test('faults of an aborted extension are not counted', () {
    final e = _activatedDeadBug();
    _pump(e, _deadBugPose(), 0);
    _pump(e, _deadBugPose(), 50);
    final partial = _deadBugPose(leftArmAngle: 125, rightLegAngle: 125);
    final partialArched =
        _deadBugPose(leftArmAngle: 125, rightLegAngle: 125, hipLift: 20);
    _pump(e, partial, 100);
    _pump(e, partial, 200);
    for (var i = 0; i < 4; i++) {
      _pump(e, partialArched, 300 + i * 100);
    }
    _pump(e, _deadBugPose(), 800); // abort: back to setup without a hold
    expect(e.repCount, 0);
    e.onSetComplete();
    expect(e.logger.setLogs['anti_extension_fails_count'], 0);
  });

  test('scale comes from the camera side', () {
    final e = DeadBug(maxRep: 4)
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;
    final pose = _deadBugPose();
    final rh = pose[PoseLandmarkType.rightHip]!;
    pose[PoseLandmarkType.rightHip] =
        _landmark(PoseLandmarkType.rightHip, rh.x + 30, rh.y);
    _pump(e, pose, 0);
    final rs = pose[PoseLandmarkType.rightShoulder]!;
    expect(e.scaleFactor,
        closeTo(math.sqrt(math.pow(rh.x + 30 - rs.x, 2) + math.pow(rh.y - rs.y, 2)), 1e-9));
  });

  test('tempo card states the 0.8 s the code enforces', () {
    final e = _activatedDeadBug();
    _pump(e, _deadBugPose(), 0);
    _pump(e, _deadBugPose(), 50);
    _completeDeadBugRep(
        exercise: e,
        topPose: _deadBugPose(leftArmAngle: 155, rightLegAngle: 155),
        returningPose: _deadBugPose(leftArmAngle: 120, rightLegAngle: 120),
        startMs: 100);
    e.onSetComplete();
    final cards = DeadBugReportBuilder().buildDetailCards([e.logger]);
    final tempo = cards.singleWhere((c) => c.label == 'Tốc độ hạ (Tempo)');
    expect(tempo.subLabel, isNot(contains('1.5')));
    expect(tempo.subLabel, contains('0.8'));
  });
}
