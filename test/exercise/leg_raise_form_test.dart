import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/8.Leg Raises (Supine)/leg_raise.dart';
import 'package:vika/exercise/8.Leg Raises (Supine)/leg_raise_report_builder.dart';
import 'package:vika/exercise/8.Leg Raises (Supine)/metrics/leg_raise_metric_base.dart';
import 'package:vika/exercise/exercise_base.dart';

PoseLandmark _lm(PoseLandmarkType type, double x, double y) =>
    PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.99);

/// Supine, side view, left side. [hipFlexion] is shoulder-hip-knee (180 =
/// legs flat); [kneeBend] bends the knee by that many degrees.
Map<PoseLandmarkType, PoseLandmark> _pose(double hipFlexion,
    {double kneeBend = 0, double hipY = 300}) {
  final e = (180 - hipFlexion) * math.pi / 180;
  final knee = (300 + 100 * math.cos(e), hipY - 100 * math.sin(e));
  final s = e - kneeBend * math.pi / 180;
  final ankle = (knee.$1 + 100 * math.cos(s), knee.$2 - 100 * math.sin(s));
  return {
    PoseLandmarkType.leftShoulder: _lm(PoseLandmarkType.leftShoulder, 100, 300),
    PoseLandmarkType.leftElbow: _lm(PoseLandmarkType.leftElbow, 200, 305),
    PoseLandmarkType.leftWrist: _lm(PoseLandmarkType.leftWrist, 290, 305),
    PoseLandmarkType.leftHip: _lm(PoseLandmarkType.leftHip, 300, hipY),
    PoseLandmarkType.leftKnee: _lm(PoseLandmarkType.leftKnee, knee.$1, knee.$2),
    PoseLandmarkType.leftAnkle:
        _lm(PoseLandmarkType.leftAnkle, ankle.$1, ankle.$2),
  };
}

LegRaise _active() {
  final e = LegRaise(maxRep: 10)
    ..cameraFacing = CameraFacing.left
    ..exerciseState = ExerciseState.activated;
  expect(e.isInStartPosition(_pose(180)), isTrue);
  return e;
}

int _t = 0;
void _pump(LegRaise e, Map<PoseLandmarkType, PoseLandmark> pose,
    [int frames = 1]) {
  for (var i = 0; i < frames; i++) {
    _t += 100;
    e.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(_t);
    e.checkingPose(pose);
  }
}

void _fullRaise(LegRaise e, {double kneeBend = 0}) {
  _pump(e, _pose(180), 3);
  _pump(e, _pose(150, kneeBend: kneeBend), 2);
  _pump(e, _pose(90, kneeBend: kneeBend), 3);
  _pump(e, _pose(147, kneeBend: kneeBend), 17);
  _pump(e, _pose(175), 3);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a full straight-leg raise counts once', () {
    final e = _active();
    _fullRaise(e);
    expect(e.repCount, 1);
  });

  test('a partial raise returns to lying without leaking into the next rep',
      () {
    final e = _active();
    _pump(e, _pose(180), 3);
    // Bent-knee partial raise that never reaches the top, then back down.
    _pump(e, _pose(150, kneeBend: 60), 4);
    _pump(e, _pose(175), 3);
    expect(e.state, LegRaiseState.lying);
    // A clean full raise must count, not be rejected by the earlier knee.
    _fullRaise(e);
    expect(e.repCount, 1);
    expect(e.logger.repLogs.single.data['fault_types'],
        isNot(contains('knee')));
  });

  test('rejected bent-knee attempts are counted in knee_fails_count', () {
    final e = _active();
    _fullRaise(e, kneeBend: 60);
    expect(e.repCount, 0);
    _fullRaise(e);
    expect(e.repCount, 1);
    e.onSetComplete();
    expect(e.logger.setLogs['knee_fails_count'], 1);
    final cards = LegRaiseReportBuilder().buildDetailCards([e.logger]);
    final knee = cards.singleWhere((c) => c.label.contains('gập gối'));
    expect(knee.value, '1');
    expect(LegRaiseReportBuilder().praiseMetricNames().keys,
        isNot(contains('knee_fails_count')));
  });

  test('scale and hip Y come from the camera side', () {
    final e = LegRaise(maxRep: 10)
      ..cameraFacing = CameraFacing.right
      ..exerciseState = ExerciseState.activated;
    final pose = _pose(180);
    pose[PoseLandmarkType.rightShoulder] =
        _lm(PoseLandmarkType.rightShoulder, 100, 310);
    pose[PoseLandmarkType.rightHip] = _lm(PoseLandmarkType.rightHip, 300, 320);
    pose[PoseLandmarkType.rightKnee] = _lm(PoseLandmarkType.rightKnee, 400, 320);
    pose[PoseLandmarkType.rightAnkle] =
        _lm(PoseLandmarkType.rightAnkle, 500, 320);
    _pump(e, pose);
    expect(e.debugData['hipY'], 320);
  });

  test('lowering-time card states the 1.2 s the code enforces', () {
    final e = _active();
    _fullRaise(e);
    e.onSetComplete();
    final cards = LegRaiseReportBuilder().buildDetailCards([e.logger]);
    final tempo = cards.singleWhere((c) => c.label == 'Kiểm soát hạ chân');
    expect(tempo.subLabel, isNot(contains('2.0')));
    expect(tempo.subLabel, contains('1.2'));
  });
}
