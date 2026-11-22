import 'dart:io' show sleep;
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/wall_push_up/metrics/wall_contact.dart';
import 'package:vika/exercise/wall_push_up/wall_push_up.dart';

PoseLandmark _lm(PoseLandmarkType type, double x, double y) =>
    PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.99);

/// Same side-view layout as wall_push_up_anti_cheat_test (facing right), with
/// the heel flat on the floor (heel Y == foot index Y).
Map<PoseLandmarkType, PoseLandmark> _flatHeelPose({
  required double shoulderX,
  required double shoulderY,
  required double hipX,
  required double hipY,
  required double elbowX,
  required double elbowY,
}) =>
    {
      PoseLandmarkType.rightShoulder:
          _lm(PoseLandmarkType.rightShoulder, shoulderX, shoulderY),
      PoseLandmarkType.rightElbow:
          _lm(PoseLandmarkType.rightElbow, elbowX, elbowY),
      PoseLandmarkType.rightWrist: _lm(PoseLandmarkType.rightWrist, 420, 200),
      PoseLandmarkType.rightHip: _lm(PoseLandmarkType.rightHip, hipX, hipY),
      PoseLandmarkType.rightAnkle: _lm(PoseLandmarkType.rightAnkle, 150, 490),
      PoseLandmarkType.rightHeel: _lm(PoseLandmarkType.rightHeel, 140, 500),
      PoseLandmarkType.rightFootIndex:
          _lm(PoseLandmarkType.rightFootIndex, 170, 500),
    };

final _top = _flatHeelPose(
    shoulderX: 300,
    shoulderY: 200,
    hipX: 250,
    hipY: 300,
    elbowX: 360,
    elbowY: 200);
final _down1 = _flatHeelPose(
    shoulderX: 320,
    shoulderY: 220,
    hipX: 263.3,
    hipY: 313.3,
    elbowX: 360,
    elbowY: 230);
final _down2 = _flatHeelPose(
    shoulderX: 345,
    shoulderY: 245,
    hipX: 280,
    hipY: 330,
    elbowX: 380,
    elbowY: 240);
final _bottom = _flatHeelPose(
    shoulderX: 360,
    shoulderY: 260,
    hipX: 290,
    hipY: 340,
    elbowX: 400,
    elbowY: 260);

void _pump(WallPushUp e, Map<PoseLandmarkType, PoseLandmark> pose, int ms) {
  e.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms);
  e.checkingPose(pose);
}

Map<PoseLandmarkType, PoseLandmark> _elbowAt(double degrees) =>
    _flatHeelPose(
        shoulderX: 300,
        shoulderY: 200,
        hipX: 250,
        hipY: 300,
        elbowX: 360,
        elbowY: 200 + 60 / math.tan(degrees / 2 * math.pi / 180));

WallPushUp _runElbow(List<double> elbows) {
  final e = WallPushUp(maxRep: 10)..cameraFacing = CameraFacing.right;
  expect(e.isInStartPosition(_elbowAt(160)), isTrue);
  e
    ..exerciseState = ExerciseState.activated
    ..onExerciseActivated();
  var t = 0;
  for (final elbow in elbows) {
    _pump(e, _elbowAt(elbow), t);
    t += 40;
  }
  return e;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('start position accepts flat heels (no raised-heel requirement)', () {
    final e = WallPushUp(maxRep: 10)..cameraFacing = CameraFacing.right;
    expect(e.isInStartPosition(_top), isTrue);
  });

  test('a rep with flat heels counts with no heel fault', () {
    final e = WallPushUp(maxRep: 10)..cameraFacing = CameraFacing.right;
    // Start on raised heels (accepted before and after the change), then
    // perform the rep with heels flat.
    final raisedTop = Map.of(_top)
      ..[PoseLandmarkType.rightHeel] =
          _lm(PoseLandmarkType.rightHeel, 140, 480);
    expect(e.isInStartPosition(raisedTop), isTrue);
    e
      ..exerciseState = ExerciseState.activated
      ..onExerciseActivated();

    _pump(e, _top, 0);
    _pump(e, _down1, 100);
    _pump(e, _down2, 200);
    for (var i = 0; i < 8; i++) {
      _pump(e, _bottom, 900 + i * 100);
    }
    _pump(e, _down2, 1900);
    _pump(e, _top, 2400);

    expect(e.repCount, 1);
    final log = e.logger.repLogs.single;
    expect(log.data['fault_types'], isNot(contains('heel')));
    expect(log.correctForm, isTrue);
  });

  test('a brief elbow opening on the way down does not split one rep in two',
      () {
    final e = _runElbow([
      160, 150, 140, 133, 129, 129, 142, 142, 130, 120, 117, 117, //
      125, 135, 145, 155, 160, 160,
    ]);
    expect(e.repCount, 1);
    expect(e.logger.repLogs.single.data['min_elbow_angle'] as double,
        closeTo(117, 0.5));
  });

  test('a one-frame jump at the bottom does not end the rep early', () {
    final e = _runElbow([
      160, 133, 128, 124, 145, 141, 130, 110, 90, 85, 100, 120, 140, 160, 160,
    ]);
    expect(e.repCount, 1);
    expect(e.logger.repLogs.single.data['min_elbow_angle'] as double,
        closeTo(85, 0.5));
  });

  test('a shallow rep that returns to the top still counts', () {
    final e = _runElbow([160, 133, 128, 128, 140, 150, 158, 160]);
    expect(e.repCount, 1);
  });

  test('activation runs the base hook (session clock starts)', () {
    final e = WallPushUp(maxRep: 10)..cameraFacing = CameraFacing.right;
    e.onExerciseActivated();
    sleep(const Duration(milliseconds: 5));
    expect(e.elapsedMs, greaterThan(0));
  });

  group('wall contact is judged inside each rep', () {
    RepContext frame(double wristX) => RepContext(
          elbowAngle: 120,
          bodyLineAngle: 175,
          shrugRatio: null,
          forwardHeadAngle: null,
          neckTiltAngle: null,
          elbowFlareAngle: 40,
          wristAnchorX: wristX,
          wristAnchorY: 100,
          shoulderAnchorX: 300,
          shoulderAnchorY: 100,
          footAnchorX: 500,
          footAnchorY: 600,
          bodyFootAngle: null,
          heelRaiseRatio: null,
          shoulderHipFootLineAngle: null,
          trunkInclinationAngle: null,
          scaleFactor: 100,
          state: WallPushUpState.bottom,
          frameTimestamp: 0,
          resultIssues: ResultIssues(),
        );

    test('hands re-placed between reps are not a fault', () {
      final metric = WallContactMetric()..captureBaseline(100);
      for (var i = 0; i < 12; i++) {
        metric.update(frame(200));
      }
      metric.resetAndCountFault();
      for (var i = 0; i < 12; i++) {
        metric.update(frame(240));
      }
      expect(metric.faults, isEmpty);
      expect(metric.faultsCount, 0);
    });

    test('a hand sliding during the rep is a fault', () {
      final metric = WallContactMetric()..captureBaseline(100);
      metric.update(frame(200));
      for (var i = 0; i < 8; i++) {
        metric.update(frame(220));
      }
      expect(metric.faults.map((f) => f.type), ['hand']);
    });
  });
}
