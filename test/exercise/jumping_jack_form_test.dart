import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/jumping jack/jumping_jack.dart';

PoseLandmark _lm(PoseLandmarkType type, double x, double y) =>
    PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.99);

/// Front view. Shoulder width 60 px. [spread] is ankle distance / shoulder
/// width; [arm] is each arm's angle out from hanging straight down (0 = at the
/// sides, 180 = straight overhead). [elbowBend] moves the elbows off the
/// shoulder-wrist line.
Map<PoseLandmarkType, PoseLandmark> _pose(double spread, double arm,
    {double elbowBend = 0}) {
  final r = arm * math.pi / 180;
  final dx = 100 * math.sin(r), dy = 100 * math.cos(r);
  return {
    PoseLandmarkType.nose: _lm(PoseLandmarkType.nose, 200, 100),
    PoseLandmarkType.leftShoulder: _lm(PoseLandmarkType.leftShoulder, 170, 150),
    PoseLandmarkType.rightShoulder:
        _lm(PoseLandmarkType.rightShoulder, 230, 150),
    PoseLandmarkType.leftElbow:
        _lm(PoseLandmarkType.leftElbow, 170 - dx / 2 + elbowBend, 150 + dy / 2),
    PoseLandmarkType.rightElbow: _lm(
        PoseLandmarkType.rightElbow, 230 + dx / 2 - elbowBend, 150 + dy / 2),
    PoseLandmarkType.leftWrist:
        _lm(PoseLandmarkType.leftWrist, 170 - dx, 150 + dy),
    PoseLandmarkType.rightWrist:
        _lm(PoseLandmarkType.rightWrist, 230 + dx, 150 + dy),
    PoseLandmarkType.leftHip: _lm(PoseLandmarkType.leftHip, 180, 280),
    PoseLandmarkType.rightHip: _lm(PoseLandmarkType.rightHip, 220, 280),
    PoseLandmarkType.leftAnkle:
        _lm(PoseLandmarkType.leftAnkle, 200 - spread * 30, 450),
    PoseLandmarkType.rightAnkle:
        _lm(PoseLandmarkType.rightAnkle, 200 + spread * 30, 450),
  };
}

int _t = 0;
void _pump(JumpingJack jj, Map<PoseLandmarkType, PoseLandmark> pose,
    [int frames = 1]) {
  for (var i = 0; i < frames; i++) {
    _t += 33;
    jj.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(_t);
    jj.checkingPose(pose);
  }
}

/// One rep: closed, open to [openSpread] for a few frames, then a normal
/// closing movement where feet and arms come back together.
void _rep(JumpingJack jj,
    {double openSpread = 1.6, double openArm = 170, double elbowBend = 0}) {
  _pump(jj, _pose(0.3, 10), 3);
  _pump(jj, _pose(openSpread, openArm, elbowBend: elbowBend), 6);
  for (final (spread, arm) in [
    (openSpread * 0.8, 130.0),
    (0.9, 100.0),
    (0.7, 70.0),
    (0.5, 40.0),
    (0.3, 15.0),
  ]) {
    _pump(jj, _pose(spread, arm));
  }
  _pump(jj, _pose(0.3, 10), 2);
}

JumpingJack _active() => JumpingJack(maxRep: 10)
  ..cameraFacing = CameraFacing.front
  ..exerciseState = ExerciseState.activated;

List<String> _faultTypes(JumpingJack jj) =>
    (jj.logger.repLogs.last.data['fault_types'] as List).cast<String>();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a wide, correct rep counts once with no leg or arm fault', () {
    final jj = _active();
    _rep(jj);
    expect(jj.repCount, 1);
    expect(_faultTypes(jj), isEmpty);
    expect(jj.logger.repLogs.single.correctForm, isTrue);
  });

  test('narrow legs (0.95x and 1.3x shoulder width) count and log legs', () {
    for (final spread in [0.95, 1.3]) {
      final jj = _active();
      _rep(jj, openSpread: spread);
      expect(jj.repCount, 1, reason: '$spread');
      expect(_faultTypes(jj), ['legs'], reason: '$spread');
      expect(jj.logger.repLogs.single.data['peak_ankle_spread'],
          closeTo(spread, 0.01));
    }
  });

  test('arms raised only to shoulder height count and log arms', () {
    final jj = _active();
    _rep(jj, openArm: 110);
    expect(jj.repCount, 1);
    expect(_faultTypes(jj), ['arms']);
    expect(jj.logger.repLogs.single.data['peak_arm_elevation'], lessThan(150));
  });

  test('bent elbows with hands overhead are not an arms fault', () {
    final jj = _active();
    _rep(jj, elbowBend: 60);
    expect(jj.repCount, 1);
    expect(_faultTypes(jj), isEmpty);
  });
}
