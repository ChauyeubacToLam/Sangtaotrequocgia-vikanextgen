import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/Sphinx_Pose/sphinx_report_builder.dart';
import 'package:vika/exercise/Sphinx_Pose/sphinx_stretch.dart';
import 'package:vika/exercise/exercise_base.dart';

PoseLandmark _lm(PoseLandmarkType type, double x, double y,
        {double likelihood = 0.99}) =>
    PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: likelihood);

/// Right-side sphinx: shoulder (300,200), hip (200,300), elbow 90 deg.
/// Knee and ankle lie on a ray from the hip at [spineDeg] from the hip→shoulder
/// direction, so shoulder-hip-knee = shoulder-hip-ankle = [spineDeg].
Map<PoseLandmarkType, PoseLandmark> _pose({
  double spineDeg = 170,
  PoseLandmarkType? lowConfidence,
}) {
  const hipX = 200.0, hipY = 300.0;
  final toShoulder = math.atan2(200 - hipY, 300 - hipX); // -45 deg
  final legDir = toShoulder + spineDeg * math.pi / 180;
  PoseLandmark p(PoseLandmarkType t, double x, double y) =>
      _lm(t, x, y, likelihood: t == lowConfidence ? 0.1 : 0.99);
  return {
    PoseLandmarkType.rightEar: p(PoseLandmarkType.rightEar, 350, 150),
    PoseLandmarkType.rightShoulder: p(PoseLandmarkType.rightShoulder, 300, 200),
    PoseLandmarkType.rightElbow: p(PoseLandmarkType.rightElbow, 300, 300),
    PoseLandmarkType.rightWrist: p(PoseLandmarkType.rightWrist, 400, 300),
    PoseLandmarkType.rightHip: p(PoseLandmarkType.rightHip, hipX, hipY),
    PoseLandmarkType.rightKnee: p(PoseLandmarkType.rightKnee,
        hipX + 100 * math.cos(legDir), hipY + 100 * math.sin(legDir)),
    PoseLandmarkType.rightAnkle: p(PoseLandmarkType.rightAnkle,
        hipX + 200 * math.cos(legDir), hipY + 200 * math.sin(legDir)),
  };
}

SphinxStretch _active({int holdSeconds = 30}) {
  final e = SphinxStretch(maxHolds: 1, holdSeconds: holdSeconds)
    ..cameraFacing = CameraFacing.right
    ..exerciseState = ExerciseState.activated;
  e.onExerciseActivated();
  return e;
}

void _pump(SphinxStretch e, Map<PoseLandmarkType, PoseLandmark> pose, int ms) {
  e.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms);
  e.checkingPose(pose);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a hold entered at or below 172 deg keeps running at 174 deg', () {
    final e = _active();
    _pump(e, _pose(spineDeg: 172), 0);
    expect(e.phase, HoldPhase.holding);
    for (var ms = 100; ms <= 1000; ms += 100) {
      _pump(e, _pose(spineDeg: 174), ms);
      expect(e.phase, HoldPhase.holding, reason: 'frame at $ms ms');
    }
    expect(e.liveHoldSeconds, closeTo(1.0, 1e-9));
  });

  test('a still 174 deg spine does not start a hold', () {
    final e = _active();
    for (var ms = 0; ms <= 1000; ms += 100) {
      _pump(e, _pose(spineDeg: 174), ms);
      expect(e.phase, isNot(HoldPhase.holding), reason: 'frame at $ms ms');
    }
    expect(e.liveHoldSeconds ?? 0, 0);
  });

  test('a spine angle above the 175 deg entry limit still pauses the clock',
      () {
    final e = _active();
    _pump(e, _pose(), 0);
    expect(e.phase, HoldPhase.holding);
    _pump(e, _pose(spineDeg: 177), 100);
    expect(e.phase, HoldPhase.dropping);
  });

  for (final type in const [
    PoseLandmarkType.rightElbow,
    PoseLandmarkType.rightWrist,
    PoseLandmarkType.rightKnee,
    PoseLandmarkType.rightEar,
  ]) {
    test('a low-confidence ${type.name} interrupts the hold', () {
      final e = _active();
      _pump(e, _pose(), 0);
      _pump(e, _pose(), 100);
      expect(e.phase, HoldPhase.holding);
      _pump(e, _pose(lowConfidence: type), 200);
      expect(e.phase, HoldPhase.dropping);
      expect(e.liveHoldSeconds, closeTo(0.1, 1e-9));
    });
  }

  test('no hip_seconds is pushed or read: there is no hip metric', () {
    final e = _active(holdSeconds: 1);
    var ms = 0;
    while (e.repCount == 0 && ms < 3000) {
      _pump(e, _pose(), ms);
      ms += 100;
    }
    expect(e.repCount, 1);
    e.onSetComplete();
    expect(e.logger.setLogs.containsKey('hip_seconds'), isFalse);

    final b = SphinxReportBuilder();
    final readKeys = {
      ...b.faultToTipMap().keys,
      ...b.praiseMetricNames().keys,
      for (final keys in b.painToFaultMap().values) ...keys,
    };
    expect(readKeys, isNot(contains('hip_seconds')));
    expect(b.painToFaultMap().containsKey('lower_back'), isFalse);
    expect(b.praiseSentenceMap().containsKey('Hông'), isFalse);
  });
}
