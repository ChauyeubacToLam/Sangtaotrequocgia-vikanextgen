import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/10.Vup/v_up.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'dart:io' show sleep;

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

Map<PoseLandmarkType, PoseLandmark> _vUpPose({
  required double shoulderX,
  required double shoulderY,
  required double wristX,
  required double wristY,
  required double hipX,
  required double hipY,
  required double kneeX,
  required double kneeY,
  required double ankleX,
  required double ankleY,
}) {
  return {
    PoseLandmarkType.leftShoulder:
        _landmark(PoseLandmarkType.leftShoulder, shoulderX, shoulderY),
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, shoulderX, shoulderY),
    PoseLandmarkType.leftWrist:
        _landmark(PoseLandmarkType.leftWrist, wristX, wristY),
    PoseLandmarkType.rightWrist:
        _landmark(PoseLandmarkType.rightWrist, wristX, wristY),
    PoseLandmarkType.leftHip: _landmark(PoseLandmarkType.leftHip, hipX, hipY),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, hipX, hipY),
    PoseLandmarkType.leftKnee:
        _landmark(PoseLandmarkType.leftKnee, kneeX, kneeY),
    PoseLandmarkType.rightKnee:
        _landmark(PoseLandmarkType.rightKnee, kneeX, kneeY),
    PoseLandmarkType.leftAnkle:
        _landmark(PoseLandmarkType.leftAnkle, ankleX, ankleY),
    PoseLandmarkType.rightAnkle:
        _landmark(PoseLandmarkType.rightAnkle, ankleX, ankleY),
  };
}

Map<PoseLandmarkType, PoseLandmark> _flatStartPose() {
  return _vUpPose(
    shoulderX: 180,
    shoulderY: 300,
    wristX: 60,
    wristY: 300,
    hipX: 300,
    hipY: 300,
    kneeX: 420,
    kneeY: 300,
    ankleX: 540,
    ankleY: 300,
  );
}

Map<PoseLandmarkType, PoseLandmark> _risingPose() {
  return _vUpPose(
    shoulderX: 210,
    shoulderY: 250,
    wristX: 250,
    wristY: 245,
    hipX: 300,
    hipY: 300,
    kneeX: 400,
    kneeY: 275,
    ankleX: 500,
    ankleY: 250,
  );
}

Map<PoseLandmarkType, PoseLandmark> _strictTopPose() {
  return _vUpPose(
    shoulderX: 240,
    shoulderY: 170,
    wristX: 380,
    wristY: 170,
    hipX: 300,
    hipY: 300,
    kneeX: 340,
    kneeY: 235,
    ankleX: 380,
    ankleY: 170,
  );
}

void _pump(
  VUp exercise,
  Map<PoseLandmarkType, PoseLandmark> pose,
  int timestampMs,
) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  exercise.checkingPose(pose);
}

VUp _activatedVUp() {
  return VUp(maxRep: 12)
    ..cameraFacing = CameraFacing.left
    ..exerciseState = ExerciseState.activated;
}

// Bent knees mid-rise (knee angle ~124 deg, below the 130 the knee metric
// allows); the rest of the V-up is the clean one from v_up_anti_cheat_test.
Map<PoseLandmarkType, PoseLandmark> _bentKneeRisingPose() {
  return _vUpPose(
    shoulderX: 210,
    shoulderY: 250,
    wristX: 250,
    wristY: 245,
    hipX: 300,
    hipY: 300,
    kneeX: 360,
    kneeY: 330,
    ankleX: 500,
    ankleY: 250,
  );
}

/// Flat, rise, [bentFrames] bent-knee frames, strict top, lower, flat.
void _vUp(VUp vUp, int t0, {int bentFrames = 0}) {
  final flat = _flatStartPose();
  final rising = _risingPose();
  final top = _strictTopPose();
  var t = t0;
  void p(Map<PoseLandmarkType, PoseLandmark> pose, int dt) {
    t += dt;
    _pump(vUp, pose, t);
  }

  p(flat, 0);
  p(flat, 100);
  p(flat, 100);
  p(rising, 200);
  p(rising, 100);
  for (var i = 0; i < bentFrames; i++) {
    p(_bentKneeRisingPose(), 100);
  }
  p(top, 400);
  p(top, 100);
  p(rising, 300);
  p(rising, 100);
  p(flat, 1200);
  p(flat, 100);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a bent-knee V-up counts and logs knee', () {
    final vUp = _activatedVUp();
    _vUp(vUp, 0, bentFrames: 3);
    expect(vUp.repCount, 1);
    expect(vUp.logger.repLogs.single.data['fault_types'], contains('knee'));
    expect(vUp.logger.repLogs.single.correctForm, isFalse);
  });

  test('one log per rep, numbered 1..n, with a bent-knee rep in between', () {
    final vUp = _activatedVUp();
    _vUp(vUp, 0);
    _vUp(vUp, 10000, bentFrames: 3);
    _vUp(vUp, 20000);
    expect(vUp.repCount, 3);
    expect(vUp.logger.repLogs.map((l) => l.repNumber), [1, 2, 3]);
  });

  test('knee_fails_count counts knee-disqualified attempts', () {
    final vUp = _activatedVUp();
    _vUp(vUp, 0, bentFrames: 3);
    vUp.onSetComplete();
    expect(vUp.logger.setLogs['knee_fails_count'], 1);
  });

  test('activation runs the base hook (session clock starts)', () {
    final vUp = _activatedVUp()..onExerciseActivated();
    sleep(const Duration(milliseconds: 5));
    expect(vUp.elapsedMs, greaterThan(0));
  });
}
