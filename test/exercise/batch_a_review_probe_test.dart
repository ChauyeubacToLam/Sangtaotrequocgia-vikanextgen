// Probes written for docs/scratch/kept-exercises-review-batch-A.md.
//
// Each PROBE asserts the behaviour the coach comparison needs. A failing
// PROBE is a finding, not something to fix here. FACT tests pin current
// behaviour that the review relies on (they are expected to pass).
//
// Fixtures follow the batch A tests: in the image MediaPipe labels, "left side
// nearer the camera" (smaller z) puts the head toward smaller X.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/plank/plank.dart';
import 'package:vika/exercise/push up/push_up.dart';
import 'package:vika/exercise/squat/squat.dart';

const _pairs = <String, (PoseLandmarkType, PoseLandmarkType)>{
  'ear': (PoseLandmarkType.leftEar, PoseLandmarkType.rightEar),
  'shoulder': (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
  'elbow': (PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow),
  'wrist': (PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist),
  'hip': (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
  'knee': (PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee),
  'ankle': (PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle),
  'heel': (PoseLandmarkType.leftHeel, PoseLandmarkType.rightHeel),
  'foot': (PoseLandmarkType.leftFootIndex, PoseLandmarkType.rightFootIndex),
};

/// Both sides at the same image point; [zGap] sets which side is nearer.
/// Points are given with the head toward smaller X and are mirrored about
/// [mirrorAbout] for the right-side-near view.
Map<PoseLandmarkType, PoseLandmark> _build(
  Map<String, (double, double)> points, {
  required bool leftNear,
  required double mirrorAbout,
  double zGap = 0.1,
  double likelihood = 0.99,
}) {
  final pose = <PoseLandmarkType, PoseLandmark>{};
  for (final entry in points.entries) {
    final (left, right) = _pairs[entry.key]!;
    final (px, py) = entry.value;
    final x = leftNear ? px : 2 * mirrorAbout - px;
    pose[left] = PoseLandmark(
        type: left,
        x: x,
        y: py,
        z: leftNear ? -zGap : zGap,
        likelihood: likelihood);
    pose[right] = PoseLandmark(
        type: right,
        x: x,
        y: py,
        z: leftNear ? zGap : -zGap,
        likelihood: likelihood);
  }
  return pose;
}

// --- Plank fixtures -------------------------------------------------------

/// Batch A's level forearm plank (ankle at shoulder height), head toward
/// smaller X for leftNear.
Map<PoseLandmarkType, PoseLandmark> _levelPlank({
  required bool leftNear,
  double hipDrop = 0,
  double earDrop = 0,
  double zGap = 0.1,
  double likelihood = 0.99,
}) {
  const y = 220.0;
  return _build({
    'ear': (270, y + earDrop),
    'shoulder': (300, y),
    'elbow': (300, 280),
    'wrist': (230, 280),
    'hip': (400, y + hipDrop),
    'knee': (500, y + hipDrop / 2),
    'ankle': (600, y),
    'heel': (620, y),
    'foot': (620, y),
  }, leftNear: leftNear, mirrorAbout: 500, zGap: zGap, likelihood: likelihood);
}

/// A geometrically straight forearm plank with the feet on the floor.
/// 200 px per metre, floor at y = 300. Assumed body: shoulder 0.31 m above
/// the floor (upper arm on the forearm), ankle 0.10 m above the floor (on the
/// toes), shoulder-to-ankle 1.24 m, torso 0.48 m. Shoulder, hip, knee and
/// ankle are collinear (shoulder-hip-ankle = 180 deg).
Map<PoseLandmarkType, PoseLandmark> _straightForearmPlank(
    {required bool leftNear}) {
  const floor = 300.0;
  const shoulder = (300.0, floor - 0.31 * 200);
  const ankleY = floor - 0.10 * 200;
  const bodyLen = 1.24 * 200;
  final dy = ankleY - shoulder.$2;
  final dx = math.sqrt(bodyLen * bodyLen - dy * dy);
  (double, double) along(double fraction) =>
      (shoulder.$1 + dx * fraction, shoulder.$2 + dy * fraction);
  const earBeyond = -0.12 / 1.24; // ear 0.12 m past the shoulder, on the line
  return _build({
    'ear': along(earBeyond),
    'shoulder': shoulder,
    'elbow': (shoulder.$1, floor),
    'wrist': (shoulder.$1 - 70, floor),
    'hip': along(0.48 / 1.24),
    'knee': along(0.93 / 1.24),
    'ankle': along(1.0),
    'heel': (shoulder.$1 + dx + 20, ankleY - 10),
    'foot': (shoulder.$1 + dx + 15, floor),
  }, leftNear: leftNear, mirrorAbout: 500);
}

Plank _activePlank(Map<PoseLandmarkType, PoseLandmark> pose,
    {required CameraFacing expected}) {
  final plank = Plank(maxRep: 3)..exerciseState = ExerciseState.activated;
  var facing = CameraFacing.undefined;
  for (var i = 0; i < 5; i++) {
    facing = plank.detectCameraFacing(pose);
  }
  expect(facing, expected, reason: 'fixture precondition');
  return plank..cameraFacing = facing;
}

void _pump(ExerciseBase exercise, Map<PoseLandmarkType, PoseLandmark> pose,
    int ms) {
  exercise.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms);
  exercise.checkingPose(pose);
}

void _hold(Plank plank, Map<PoseLandmarkType, PoseLandmark> pose,
    {required int fromMs, required int toMs}) {
  for (var t = fromMs; t <= toMs; t += 100) {
    _pump(plank, pose, t);
  }
}

// --- Push-Up fixtures -----------------------------------------------------

/// Batch A's push-up frame (level body, ankle at shoulder height), head
/// toward smaller X for leftNear.
Map<PoseLandmarkType, PoseLandmark> _levelPushUp({
  required bool leftNear,
  required double bodyY,
  required double elbowX,
  required double elbowY,
  double hipDrop = 0,
}) {
  // Batch A writes these with the head toward larger X; flip once here so
  // _build's convention (head toward smaller X for leftNear) holds.
  final points = <String, (double, double)>{
    'shoulder': (400, bodyY),
    'elbow': (elbowX, elbowY),
    'wrist': (400, 300),
    'hip': (300, bodyY + hipDrop),
    'knee': (200, bodyY),
    'ankle': (120, bodyY),
    'heel': (95, 300),
    'foot': (95, 300),
  };
  return _build(
    {for (final e in points.entries) e.key: (500 - e.value.$1, e.value.$2)},
    leftNear: leftNear,
    mirrorAbout: 250,
  );
}

/// A straight high plank at the top of a push-up with the feet on the floor.
/// About 208 px per metre (torso 100 px = 0.48 m), floor at y = 300. Assumed:
/// shoulder 0.55 m above the floor (arm vertical), ankle 0.10 m (on the toes),
/// shoulder-to-ankle 1.24 m. Head toward smaller X for leftNear.
Map<PoseLandmarkType, PoseLandmark> _straightHighPlank(
    {required bool leftNear}) {
  const pxPerM = 100 / 0.48;
  const floor = 300.0;
  const shoulder = (100.0, floor - 0.55 * pxPerM);
  const ankleY = floor - 0.10 * pxPerM;
  const bodyLen = 1.24 * pxPerM;
  final dy = ankleY - shoulder.$2;
  final dx = math.sqrt(bodyLen * bodyLen - dy * dy);
  (double, double) along(double fraction) =>
      (shoulder.$1 + dx * fraction, shoulder.$2 + dy * fraction);
  return _build({
    'shoulder': shoulder,
    'elbow': (shoulder.$1 - 3, (shoulder.$2 + floor) / 2),
    'wrist': (shoulder.$1, floor),
    'hip': along(0.48 / 1.24),
    'knee': along(0.93 / 1.24),
    'ankle': along(1.0),
    'heel': (shoulder.$1 + dx + 20, floor),
    'foot': (shoulder.$1 + dx + 20, floor),
  }, leftNear: leftNear, mirrorAbout: 250);
}

PushUp _activePushUp({required bool leftNear}) {
  final pushUp = PushUp(maxRep: 10);
  var facing = CameraFacing.undefined;
  for (var i = 0; i < 5; i++) {
    facing = pushUp.detectCameraFacing(_levelPushUp(
        leftNear: leftNear, bodyY: 220, elbowX: 400, elbowY: 260));
  }
  expect(facing, leftNear ? CameraFacing.left : CameraFacing.right,
      reason: 'fixture precondition');
  return pushUp
    ..cameraFacing = facing
    ..exerciseState = ExerciseState.activated;
}

/// Batch A's full rep: top, descent, 6 bottom frames, ascent, top.
void _fullRep(PushUp pushUp,
    {required bool leftNear, double hipDrop = 0, int startMs = 0}) {
  Map<PoseLandmarkType, PoseLandmark> p(double bodyY, double ex, double ey,
          {double drop = 0}) =>
      _levelPushUp(
          leftNear: leftNear,
          bodyY: bodyY,
          elbowX: ex,
          elbowY: ey,
          hipDrop: drop);
  final top = p(220, 400, 260);
  expect(pushUp.isInStartPosition(top), isTrue, reason: 'fixture precondition');
  _pump(pushUp, top, startMs);
  _pump(pushUp, p(235, 408, 272, drop: hipDrop), startMs + 100);
  _pump(pushUp, p(245, 412, 278, drop: hipDrop), startMs + 200);
  for (var i = 0; i < 6; i++) {
    _pump(pushUp, p(270, 415, 285, drop: hipDrop), startMs + 900 + i * 100);
  }
  _pump(pushUp, p(245, 412, 278), startMs + 1600);
  _pump(pushUp, top, startMs + 2100);
  _pump(pushUp, top, startMs + 2500);
}

double _pushUpTrunkDeviation(PushUp pushUp) =>
    (pushUp.frameBuffer.frameBuffer.last.log['trunkDeviation'] as num)
        .toDouble();

// --- Squat fixtures (batch A's squat_form_test builder) --------------------

PoseLandmark _lm(PoseLandmarkType type, double x, double y) =>
    PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.99);

double _rad(double degrees) => degrees * math.pi / 180.0;

Map<PoseLandmarkType, PoseLandmark> _squatPose(
    {required double knee, double lean = 15, double heelLift = 1}) {
  const kneeX = 220.0;
  const kneeY = 290.0;
  final hipX = kneeX + 100 * math.sin(_rad(knee));
  final hipY = kneeY + 100 * math.cos(_rad(knee));
  final shoulderX = hipX + 90 * math.sin(_rad(lean));
  final shoulderY = hipY - 90 * math.cos(_rad(lean));
  const footX = kneeX + 24.0;
  const footY = kneeY + 108.0;
  return {
    PoseLandmarkType.rightShoulder:
        _lm(PoseLandmarkType.rightShoulder, shoulderX, shoulderY),
    PoseLandmarkType.rightHip: _lm(PoseLandmarkType.rightHip, hipX, hipY),
    PoseLandmarkType.rightKnee: _lm(PoseLandmarkType.rightKnee, kneeX, kneeY),
    PoseLandmarkType.rightAnkle:
        _lm(PoseLandmarkType.rightAnkle, kneeX, kneeY + 100),
    PoseLandmarkType.rightHeel:
        _lm(PoseLandmarkType.rightHeel, footX - 20, footY - heelLift),
    PoseLandmarkType.rightFootIndex:
        _lm(PoseLandmarkType.rightFootIndex, footX, footY),
  };
}

Squat _activeSquat() {
  final squat = Squat(maxRep: 5)
    ..exerciseState = ExerciseState.activated
    ..cameraFacing = CameraFacing.right;
  expect(squat.isInStartPosition(_squatPose(knee: 172)), isTrue,
      reason: 'fixture precondition');
  return squat;
}

void _squatFrames(Squat squat, List<double> knees,
    {required int startMs, double heelLift = 1}) {
  var t = startMs;
  for (final knee in knees) {
    _pump(squat, _squatPose(knee: knee, heelLift: heelLift), t);
    t += 100;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('head direction and facing', () {
    test(
        'PROBE facing-tie: a right-side view with one tied z-vote in every 4 '
        'frames is classified right', () {
      final plank = Plank(maxRep: 3);
      var facing = CameraFacing.undefined;
      for (var i = 0; i < 40; i++) {
        final tie = i % 4 == 3; // all |z| gaps <= 0.01: zero votes each side
        facing = plank.detectCameraFacing(
            _levelPlank(leftNear: false, zGap: tie ? 0.0 : 0.1));
      }
      expect(facing, CameraFacing.right,
          reason: 'a tie votes left and resets the 5-frame sticky counter, '
              'so a right-side user stays "left" (exercise_base.dart:735)');
    },
        skip: 'Open owner decision: the z-vote tie in exercise_base.dart '
            '_isLeftSide (shared file, out of scope). Plank and Push-Up no '
            'longer take the trunk sign from the label (fix D2).');

    test('FACT facing-tie: with no decisive z gap the facing is left', () {
      final plank = Plank(maxRep: 3);
      for (var i = 0; i < 10; i++) {
        expect(plank.detectCameraFacing(_levelPlank(leftNear: false, zGap: 0)),
            CameraFacing.left);
      }
    });

    test(
        'PROBE angled push-up: an angled view with the head toward larger X '
        'logs no trunk fault on a level rep', () {
      final pushUp = _activePushUp(leftNear: false)
        ..cameraFacing = CameraFacing.angled; // set by hand, see review
      expect(
          pushUp.checkSafety(_levelPushUp(
              leftNear: false, bodyY: 220, elbowX: 400, elbowY: 260)),
          isNull,
          reason: 'angled is accepted by PushUp.checkSafety');
      _fullRep(pushUp, leftNear: false);
      expect(pushUp.repCount, 1, reason: 'fixture precondition');
      expect(pushUp.logger.repLogs.single.data['fault_types'], isEmpty,
          reason: 'angled uses the facing-left target (270) whatever the head '
              'side, so this level body reads ~180 deg off');
    });
  });

  group('sag versus pike, both facings', () {
    test('PROBE mirror sweep (Plank): same posture, same deviation and neck',
        () {
      for (final hipDrop in <double>[-20, -9, -5, 0, 5, 12, 20]) {
        for (final earDrop in <double>[-20, 0, 20]) {
          final dev = <double>[];
          final neck = <double>[];
          for (final leftNear in [true, false]) {
            final pose = _levelPlank(
                leftNear: leftNear, hipDrop: hipDrop, earDrop: earDrop);
            final plank = _activePlank(pose,
                expected: leftNear ? CameraFacing.left : CameraFacing.right);
            _pump(plank, pose, 0);
            // debugData['trunkDev'] is e.g. "+9.8°" (and "+-0.0°" for -0.0).
            dev.add(double.parse((plank.debugData['trunkDev'] as String)
                .replaceAll('°', '')
                .replaceFirst('+', '')));
            neck.add(double.parse(plank.debugData['neckAngle'] as String));
          }
          final where = 'hipDrop=$hipDrop earDrop=$earDrop';
          expect(dev[0], closeTo(dev[1], 0.05), reason: where);
          expect(neck[0], closeTo(neck[1], 0.05), reason: where);
          if (hipDrop != 0) expect(dev[0].sign, hipDrop.sign, reason: where);
          if (earDrop != 0) {
            expect(neck[0] < 180, earDrop > 0,
                reason: '$where: below 180 = dropped');
          }
        }
      }
    });

    test('PROBE mirror sweep (Push-Up): same posture, same deviation', () {
      for (final hipDrop in <double>[-25, -10, 0, 10, 25]) {
        final devs = <double>[];
        for (final leftNear in [true, false]) {
          final pushUp = _activePushUp(leftNear: leftNear);
          _pump(
              pushUp,
              _levelPushUp(
                  leftNear: leftNear,
                  bodyY: 220,
                  elbowX: 400,
                  elbowY: 260,
                  hipDrop: hipDrop),
              0);
          devs.add(_pushUpTrunkDeviation(pushUp));
        }
        expect(devs[0], closeTo(devs[1], 1e-9), reason: 'hipDrop=$hipDrop');
        expect(devs[0].sign, hipDrop.sign,
            reason: 'positive = sag (hips low) for hipDrop=$hipDrop');
      }
    });

    for (final leftNear in [true, false]) {
      final side = leftNear ? 'left' : 'right';

      test(
          'PROBE straight forearm plank ($side): a body with shoulder, hip and '
          'ankle collinear and the feet on the floor holds clean', () {
        final pose = _straightForearmPlank(leftNear: leftNear);
        final plank = _activePlank(pose,
            expected: leftNear ? CameraFacing.left : CameraFacing.right);
        expect(plank.isInStartPosition(pose), isTrue,
            reason: 'fixture precondition: a valid forearm plank');
        _hold(plank, pose, fromMs: 0, toMs: 16000);
        expect(plank.repCount, 1, reason: 'fixture precondition');
        final repLog = plank.logger.repLogs.single;
        final why = 'trunk deviation is measured from horizontal, not from '
            'the shoulder-ankle line; this straight body reads '
            '${plank.debugData['trunkDev']} (sag warning above 8)';
        expect(repLog.data['fault_types'], isEmpty, reason: why);
        expect(repLog.correctForm, isTrue, reason: why);
      }, skip: 'D1: measurement reference, owner decision pending phone numbers');

      test(
          'PROBE straight high plank ($side): the top of a push-up with the '
          'feet on the floor reads within the sag-good band (<= 12 deg)', () {
        final pose = _straightHighPlank(leftNear: leftNear);
        final pushUp = PushUp(maxRep: 10)
          ..exerciseState = ExerciseState.activated
          ..cameraFacing = leftNear ? CameraFacing.left : CameraFacing.right;
        var facing = CameraFacing.undefined;
        for (var i = 0; i < 5; i++) {
          facing = pushUp.detectCameraFacing(pose);
        }
        expect(facing, leftNear ? CameraFacing.left : CameraFacing.right,
            reason: 'fixture precondition');
        expect(pushUp.isInStartPosition(pose), isTrue,
            reason: 'fixture precondition: a valid high-plank start');
        _pump(pushUp, pose, 0);
        final dev = _pushUpTrunkDeviation(pushUp);
        expect(dev, lessThanOrEqualTo(12.0),
            reason: 'a straight high plank is tilted head-up; read '
                '${dev.toStringAsFixed(1)} deg, and the trunk metric runs from '
                'the first descending frame');
      }, skip: 'D1: measurement reference, owner decision pending phone numbers');
    }
  });

  group('plank timing', () {
    test(
        'PROBE live timer: the hold timer shown to the user does not advance '
        'over frames skipped by checkSafety', () {
      final pose = _levelPlank(leftNear: true);
      final plank = _activePlank(pose, expected: CameraFacing.left);
      _hold(plank, pose, fromMs: 0, toMs: 1000);
      final dim = _levelPlank(leftNear: true, likelihood: 0.5);
      for (var t = 1100; t <= 4000; t += 100) {
        plank.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(t);
        expect(plank.checkSafety(dim), isNotNull);
      }
      expect(plank.liveHoldSeconds, closeTo(0.9, 0.11),
          reason: 'liveHoldSeconds reads frameTimestamp - holdStart and the '
              'gap is only cut on the next evaluated frame');
    });

    test(
        'PROBE boundaries: pause on the last second, then a pause during the '
        'rest; held time stays exact', () {
      final pose = _levelPlank(leftNear: true);
      final plank = _activePlank(pose, expected: CameraFacing.left);
      _hold(plank, pose, fromMs: 0, toMs: 14900); // hold started at 100 ms
      expect(plank.repCount, 0);
      plank.onPauseReactivationStarted(); // resume edge after a pause
      _pump(plank, pose, 30000); // first frame after the 3 s re-hold
      _pump(plank, pose, 30100);
      expect(plank.repCount, 0, reason: '14.9 s evaluated');
      _pump(plank, pose, 30200);
      expect(plank.repCount, 1, reason: '15.0 s evaluated');
      expect(plank.plankState, PlankState.resting);

      plank.onPauseReactivationStarted(); // pause during the rest: no effect
      _hold(plank, pose, fromMs: 36000, toMs: 51000);
      expect(plank.repCount, 2);

      plank.onSetComplete();
      expect(plank.logger.setLogs['total_seconds'] as num, closeTo(30.0, 1e-9));
    });
  });

  group('per-rep and per-hold log integrity', () {
    test(
        'a hold that breaks pauses and keeps its own short sag, which does '
        'not mark the hold as wrong', () {
      final plank = _activePlank(_levelPlank(leftNear: true),
          expected: CameraFacing.left);
      _hold(plank, _levelPlank(leftNear: true, hipDrop: 16),
          fromMs: 0, toMs: 1000);
      _pump(plank, _levelPlank(leftNear: true, hipDrop: 40), 1100);
      expect(plank.plankState, PlankState.paused,
          reason: 'body angle < 150 pauses the hold');
      _hold(plank, _levelPlank(leftNear: true), fromMs: 1200, toMs: 17000);
      expect(plank.repCount, 1);
      final repLog = plank.logger.repLogs.single;
      expect(repLog.data['fault_types'], ['Back']);
      expect(repLog.correctForm, isTrue);
    });

    test(
        'PROBE push-up no leak: a shallow attempt with sagging hips leaves no '
        'fault on the next counted rep', () {
      final pushUp = _activePushUp(leftNear: true);
      Map<PoseLandmarkType, PoseLandmark> p(double bodyY, double ex, double ey,
              {double drop = 0}) =>
          _levelPushUp(
              leftNear: true,
              bodyY: bodyY,
              elbowX: ex,
              elbowY: ey,
              hipDrop: drop);
      final top = p(220, 400, 260);
      expect(pushUp.isInStartPosition(top), isTrue);
      _pump(pushUp, top, 0);
      _pump(pushUp, p(235, 408, 272, drop: 25), 100);
      for (var i = 0; i < 6; i++) {
        _pump(pushUp, p(245, 412, 278, drop: 25), 200 + i * 100);
      }
      expect(pushUp.trunkAlignmentMetric.faults, isNotEmpty,
          reason: 'fixture precondition: sag fired during the attempt');
      _pump(pushUp, p(235, 408, 272), 900);
      _pump(pushUp, top, 1000);
      _pump(pushUp, top, 1100);
      expect(pushUp.repCount, 0, reason: 'shallow attempt is not counted');

      _fullRep(pushUp, leftNear: true, startMs: 2000);
      expect(pushUp.repCount, 1);
      expect(pushUp.logger.repLogs, hasLength(1));
      expect(pushUp.logger.repLogs.single.data['fault_types'], isEmpty);
    });

    test(
        'FACT push-up fault ids: a piked rep is logged with fault type "sag" '
        '(only the message says pike)', () {
      final pushUp = _activePushUp(leftNear: true);
      _fullRep(pushUp, leftNear: true, hipDrop: -25);
      expect(pushUp.repCount, 1);
      expect(pushUp.logger.repLogs.single.data['fault_types'], ['sag']);
      final phases = pushUp.setFeedback.single.values.single;
      expect(phases.values.expand((m) => m.values).join(' '), contains('cao'));
    });

    test(
        'PROBE squat no leak: a heel lift in a descent that was not counted '
        'stays out of the next rep', () {
      final squat = _activeSquat();
      _squatFrames(squat, [172, 166, 160, 154, 148, 142, 136, 130],
          startMs: 0);
      expect(squat.squatState, SquatState.descending,
          reason: 'fixture precondition');
      _squatFrames(squat, [130, 130, 130, 130, 130, 130],
          startMs: 800, heelLift: 20);
      _squatFrames(squat, [145, 160, 172, 174, 174], startMs: 1400);
      expect(squat.repCount, 0, reason: 'descending -> standing: not counted');

      _squatFrames(
          squat,
          [172, 166, 160, 154, 148, 142, 134, 126, 118, 110, 104, 104, 104,
            104, 104, 104, 104, 112, 125, 140, 155, 168, 174, 174],
          startMs: 3000);
      expect(squat.repCount, 1);
      expect(squat.logger.repLogs.single.data['fault_types'],
          isNot(contains('heel')));
    });

    test(
        'FACT squat half rep: a descent that turns around above 115 deg is '
        'counted once and carries a "depth" fault (owner keeps this)', () {
      final squat = _activeSquat();
      _squatFrames(squat, [172, 166, 160, 154, 148, 142, 136, 130, 125],
          startMs: 0);
      expect(squat.squatState, SquatState.descending,
          reason: 'fixture precondition');
      _squatFrames(
          squat, [129, 133, 137, 141, 145, 150, 155, 160, 165, 170, 174, 174],
          startMs: 900);
      expect(squat.repCount, 1);
      expect(squat.logger.repLogs, hasLength(1));
      final repLog = squat.logger.repLogs.single;
      expect(repLog.data['fault_types'], contains('depth'));
      expect(repLog.correctForm, isFalse,
          reason: 'the depth fault has affectsForm: true');
    });
  });

  // Regression tests for docs/scratch/kept-exercises-fix-batch-A.md.
  group('batch A fixes', () {
    test(
        'FIX D3: a broken hold that resumes keeps the set totals as '
        'integrated', () {
      final plank = _ClockedPlank();
      var facing = CameraFacing.undefined;
      for (var i = 0; i < 5; i++) {
        facing = plank.detectCameraFacing(_levelPlank(leftNear: true));
      }
      plank.cameraFacing = facing;

      void hold(Map<PoseLandmarkType, PoseLandmark> pose, int from, int to) {
        for (var t = from; t <= to; t += 100) {
          plank.clockMs = t;
          _pump(plank, pose, t);
        }
      }

      hold(_levelPlank(leftNear: true, hipDrop: 16), 0, 1000);
      hold(_levelPlank(leftNear: true, hipDrop: 40), 1100, 1100);
      expect(plank.plankState, PlankState.paused);
      hold(_levelPlank(leftNear: true), 1200, 17000);
      expect(plank.repCount, 1);
      expect(plank.logger.repLogs.single.data['fault_types'], ['Back']);

      plank.onSetComplete();
      final logs = plank.logger.setLogs;
      expect(logs['total_seconds'] as num, closeTo(15.0, 1e-9));
      expect(logs['trunk_seconds'] as num, closeTo(0.6, 1e-9));
      expect(logs['good_seconds'] as num, closeTo(14.2, 1e-9));
      expect(logs['neck_seconds'] as num, 0.0);
      expect(logs['knee_seconds'] as num, 0.0);
    });

    test(
        'FIX D1 log: on straight bodies line and bend read ~0; plank dev reads '
        'the horizontal tilt, push-up dev is the bend', () {
      final lines = <String>[];
      final saved = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null && message.startsWith('[Vika][facing]')) {
          lines.add(message);
        }
      };
      try {
        for (final leftNear in [true, false]) {
          final facing = leftNear ? CameraFacing.left : CameraFacing.right;
          final plankPose = _straightForearmPlank(leftNear: leftNear);
          _pump(_activePlank(plankPose, expected: facing), plankPose, 5000);
          for (final drop in <double>[16, -10]) {
            final pose = _levelPlank(leftNear: leftNear, hipDrop: drop);
            _pump(_activePlank(pose, expected: facing), pose, 5000);
          }
          final pushUpPose = _straightHighPlank(leftNear: leftNear);
          final pushUp = PushUp(maxRep: 10)
            ..exerciseState = ExerciseState.activated
            ..cameraFacing = facing;
          _pump(pushUp, pushUpPose, 5000);
        }
      } finally {
        debugPrint = saved;
      }

      final field = RegExp(r'(dev|line|bend)=(-?[0-9.]+)');
      Map<String, double> read(String line) => {
            for (final m in field.allMatches(line))
              m.group(1)!: double.parse(m.group(2)!),
          };
      expect(lines, hasLength(8));
      for (var side = 0; side < 2; side++) {
        final straight = read(lines[side * 4]);
        expect(lines[side * 4], startsWith('[Vika][facing] Plank'));
        expect(straight['dev']!, closeTo(9.8, 0.1));
        expect(straight['line']!, closeTo(0, 0.1));
        expect(straight['bend']!, closeTo(0, 0.1));

        final sag = read(lines[side * 4 + 1]);
        expect(sag['line']!, greaterThan(1), reason: 'hip below the line');
        expect(sag['bend']!, greaterThan(sag['line']!));
        final pike = read(lines[side * 4 + 2]);
        expect(pike['line']!, lessThan(-1), reason: 'hip above the line');
        expect(pike['bend']!, lessThan(pike['line']!));

        final pushUpTop = read(lines[side * 4 + 3]);
        expect(lines[side * 4 + 3], startsWith('[Vika][facing] PushUp'));
        expect(pushUpTop['dev']!, closeTo(0, 0.1));
        expect(pushUpTop['line']!, closeTo(0, 0.1));
        expect(pushUpTop['bend']!, closeTo(0, 0.1));
      }
    });
  });
}

/// Plank whose session stopwatch is driven by the test, so the integrated
/// set totals are deterministic.
class _ClockedPlank extends Plank {
  _ClockedPlank() : super(maxRep: 3) {
    exerciseState = ExerciseState.activated;
  }

  int clockMs = 0;

  @override
  int get elapsedMs => clockMs;
}
