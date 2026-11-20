import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/seated_forward_fold/metrics/seated_forward_metric_base.dart';
import 'package:vika/exercise/seated_forward_fold/metrics/spinal_alignment_metric.dart';
import 'package:vika/exercise/seated_forward_fold/seated_forward_fold.dart';
import 'package:vika/exercise/seated_forward_fold/seated_forward_report_builder.dart';
import 'package:vika/utils/exercise_logger.dart';

PoseLandmark _lm(PoseLandmarkType type, double x, double y) =>
    PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.99);

/// Left side to camera, legs along +X from the hip at (300,300).
/// [hipDeg] = shoulder-hip-knee, [kneeDeg] = hip-knee-heel. The ear continues
/// the hip→shoulder line, so the ear-shoulder-hip angle is 180 (no head drop).
Map<PoseLandmarkType, PoseLandmark> _pose({
  double hipDeg = 100,
  double kneeDeg = 180,
}) {
  const hipX = 300.0, hipY = 300.0;
  final a = hipDeg * math.pi / 180;
  final sx = hipX + 150 * math.cos(a), sy = hipY - 150 * math.sin(a);
  final ex = hipX + 190 * math.cos(a), ey = hipY - 190 * math.sin(a);
  const kx = 450.0, ky = 300.0;
  final b = (180 - kneeDeg) * math.pi / 180; // shank tilts down from the thigh
  final hx = kx + 150 * math.cos(b), hy = ky + 150 * math.sin(b);
  return {
    PoseLandmarkType.leftEar: _lm(PoseLandmarkType.leftEar, ex, ey),
    PoseLandmarkType.leftShoulder: _lm(PoseLandmarkType.leftShoulder, sx, sy),
    PoseLandmarkType.leftHip: _lm(PoseLandmarkType.leftHip, hipX, hipY),
    PoseLandmarkType.leftKnee: _lm(PoseLandmarkType.leftKnee, kx, ky),
    PoseLandmarkType.leftHeel: _lm(PoseLandmarkType.leftHeel, hx, hy),
    PoseLandmarkType.leftFootIndex:
        _lm(PoseLandmarkType.leftFootIndex, hx + 10, hy - 30),
  };
}

SeatedForwardFold _active({int holdSeconds = 30}) {
  final e = SeatedForwardFold(maxHolds: 1, holdSeconds: holdSeconds)
    ..cameraFacing = CameraFacing.left
    ..exerciseState = ExerciseState.activated;
  expect(e.isInStartPosition(_pose()), isTrue);
  e.onExerciseActivated();
  return e;
}

void _pump(
    SeatedForwardFold e, Map<PoseLandmarkType, PoseLandmark> pose, int ms) {
  e.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms);
  e.checkingPose(pose);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fold, ease back 15 deg, hold still: the clock restarts', () {
    final e = _active();
    _pump(e, _pose(), 0);
    for (var ms = 200; ms <= 1500; ms += 100) {
      _pump(e, _pose(hipDeg: 60), ms);
    }
    expect(e.phase, HoldPhase.holding);
    final firstSegment = e.liveHoldSeconds!;
    expect(firstSegment, greaterThan(0));

    _pump(e, _pose(hipDeg: 75), 1600); // > 60 + 12: release
    expect(e.phase, HoldPhase.dropping);

    for (var ms = 1700; ms <= 3700; ms += 100) {
      _pump(e, _pose(hipDeg: 75), ms);
    }
    expect(e.phase, HoldPhase.holding);
    expect(e.liveHoldSeconds, closeTo(firstSegment + 1.0, 1e-9));
  });

  test('easing back from the new segment still releases', () {
    final e = _active();
    _pump(e, _pose(), 0);
    for (var ms = 200; ms <= 1500; ms += 100) {
      _pump(e, _pose(hipDeg: 60), ms);
    }
    _pump(e, _pose(hipDeg: 75), 1600);
    for (var ms = 1700; ms <= 2800; ms += 100) {
      _pump(e, _pose(hipDeg: 75), ms);
    }
    expect(e.phase, HoldPhase.holding);
    _pump(e, _pose(hipDeg: 88), 2900); // > 75 + 12
    expect(e.phase, HoldPhase.dropping);
  });

  test('start gate uses the 125 deg knee limit the hold faults on', () {
    final e = SeatedForwardFold(maxHolds: 1, holdSeconds: 30)
      ..cameraFacing = CameraFacing.left;
    expect(e.isInStartPosition(_pose(kneeDeg: 120)), isFalse);
    expect(e.isInStartPosition(_pose(kneeDeg: 130)), isTrue);
  });

  test('onSetComplete pushes max_rep and good_rep_count', () {
    final e = _active(holdSeconds: 1);
    _pump(e, _pose(), 0);
    var ms = 200;
    while (e.repCount == 0 && ms < 4000) {
      _pump(e, _pose(hipDeg: 60), ms);
      ms += 100;
    }
    expect(e.repCount, 1);
    e.onSetComplete();
    expect(e.logger.setLogs['max_rep'], 1);
    expect(e.logger.setLogs['good_rep_count'], 1);
  });

  test('SpineRound copy describes the head and neck, not the lower back', () {
    final metric = SpinalAlignmentMetric();
    final issues = ResultIssues();
    for (var i = 0; i < 6; i++) {
      metric.update(SeatedForwardContext(
        kneeAngle: 180,
        hipAngle: 60,
        hipVelocity: 0,
        spineAngle: 80,
        ankleAngle: 100,
        scaleFactor: 150,
        state: SeatedForwardState.isometricHold,
        frameTimestampMs: i * 100,
        resultIssues: issues,
      ));
    }
    final fault = metric.faults.single;
    for (final text in [
      fault.message,
      fault.voiceMessage ?? '',
      issues.feedback['Spine']!,
    ]) {
      expect(text, isNot(contains('lưng')), reason: text);
    }
    expect(fault.message.toLowerCase(), contains('đầu'));

    final b = SeatedForwardReportBuilder();
    final tip = b.faultToTipMap()['spine_round_seconds']!;
    expect(tip.watch, isNot(contains('lưng')));
    expect(tip.watch, contains('đầu'));
    final painKeys = {
      for (final entry in b.painToFaultMap().entries)
        if (entry.value.contains('spine_round_seconds')) entry.key,
    };
    expect(painKeys, isEmpty);
    final cards = b.buildDetailCards([
      ExerciseLogger()
        ..pushKey('total_seconds', 30)
        ..pushKey('good_seconds', 28)
        ..pushKey('knee_bent_seconds', 0)
        ..pushKey('spine_round_seconds', 2),
    ]);
    expect(cards.map((c) => c.label), isNot(contains('Lưng tròn')));
  });
}
