// Probes written for docs/scratch/kept-exercises-review-batch-C.md.
//
// Each PROBE asserts the behaviour a filmed participant or a judge needs. A
// failing PROBE is a finding, not something to fix here. FACT tests pin
// current behaviour the review relies on (they are expected to pass).
//
// All bodies are built in metres and converted at 200 px per metre, with the
// floor at image y = 400 (y grows downward). Each fixture states its assumed
// proportions. The far side of a side view sits on the same image point as the
// near side, with a larger z and a lower visibility (0.5, still above the 0.3
// confidence floor), and the facing is decided by detectCameraFacing.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/Sphinx_Pose/sphinx_stretch.dart';
import 'package:vika/exercise/butterfly_stretch/butterfly_stretch.dart';
import 'package:vika/exercise/butterfly_stretch/butterfly_stretch_report_builder.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/hold/rep_counted_hold_exercise.dart';
import 'package:vika/exercise/seated_forward_fold/seated_forward_fold.dart';
import 'package:vika/exercise/side_plank_dip/side_plank_dip.dart';
import 'package:vika/pose/vika_pose_landmark.dart';

const _ppm = 200.0;
const _floorY = 400.0;
const _imageWidth = 800.0;

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

PoseLandmark _mk(PoseLandmarkType type, double x, double y,
        {double z = 0, double visibility = 0.95}) =>
    poseLandmarkWithVikaConfidence(
        type: type, x: x, y: y, z: z, presence: 0.99, visibility: visibility);

/// (distance along the image X in metres, height above the floor in metres)
/// to pixels. [mirror] reflects about the image centre, for the other side.
(double, double) _px(double d, double h, {required bool mirror}) {
  final x = 150 + d * _ppm;
  return (mirror ? _imageWidth - x : x, _floorY - h * _ppm);
}

/// A side view: [near] points on the side nearer the camera, the far side on
/// the same image points. leftNear puts the head toward smaller X.
Map<PoseLandmarkType, PoseLandmark> _sideView(
    Map<String, (double, double)> near,
    {required bool leftNear}) {
  final pose = <PoseLandmarkType, PoseLandmark>{};
  for (final e in near.entries) {
    final (l, r) = _pairs[e.key]!;
    final (x, y) = _px(e.value.$1, e.value.$2, mirror: !leftNear);
    pose[l] = _mk(l, x, y,
        z: leftNear ? -0.1 : 0.1, visibility: leftNear ? 0.95 : 0.5);
    pose[r] = _mk(r, x, y,
        z: leftNear ? 0.1 : -0.1, visibility: leftNear ? 0.5 : 0.95);
  }
  return pose;
}

void _pump(RepCountedHoldExercise e, Map<PoseLandmarkType, PoseLandmark> pose,
    int ms) {
  e.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms);
  e.checkingPose(pose);
}

/// Frames every 100 ms from [fromMs] to [toMs] inclusive.
void _run(RepCountedHoldExercise e, Map<PoseLandmarkType, PoseLandmark> pose,
    {required int fromMs, required int toMs}) {
  for (var t = fromMs; t <= toMs; t += 100) {
    _pump(e, pose, t);
  }
}

/// Lets detectCameraFacing decide the facing, checks checkSafety and the start
/// gate on [start], then activates the set as the base class does after the
/// 3 s hold-still.
T _activate<T extends RepCountedHoldExercise>(
    T e, Map<PoseLandmarkType, PoseLandmark> start,
    {required Set<CameraFacing> accepted}) {
  var facing = CameraFacing.undefined;
  for (var i = 0; i < 6; i++) {
    facing = e.detectCameraFacing(start);
  }
  expect(accepted, contains(facing), reason: 'fixture precondition: facing');
  e.cameraFacing = facing;
  expect(e.checkSafety(start), isNull,
      reason: 'fixture precondition: checkSafety passes');
  expect(e.isInStartPosition(start), isTrue,
      reason: 'fixture precondition: start gate passes');
  e.exerciseState = ExerciseState.activated;
  e.onExerciseActivated();
  return e;
}

const _sides = {CameraFacing.left, CameraFacing.right};

// --- Side Plank -----------------------------------------------------------

/// Forearm side plank, chest toward the camera, body across the image.
/// Assumed body: shoulder-hip 0.50 m, hip-knee 0.45 m, knee-ankle 0.43 m;
/// support shoulder 0.33 m above the floor (vertical upper arm on the
/// forearm), bottom ankle 0.05 m; shoulders stacked 0.34 m apart, hips
/// 0.20 m, ankles 0.08 m. With [hipHeight] null the shoulder, hip and ankle
/// are collinear (hip 0.23 m up). The top hand rests on the top hip.
/// [leftSupport] = the left forearm is on the floor (head toward smaller X);
/// otherwise the right one is, mirrored. All z are 0 (chest to camera).
Map<PoseLandmarkType, PoseLandmark> _sidePlank({
  required bool leftSupport,
  double? hipHeight,
  bool kneeling = false,
  double topShoulderShift = 0,
}) {
  const sh = 0.33, ankleH = 0.05, torso = 0.50, leg = 0.88;
  double hipD, hipH, ankleD;
  if (kneeling) {
    // Resting on the bottom knee, shin folded back under the thigh.
    hipD = 0.45;
    hipH = 0.18;
    ankleD = 0.55;
  } else if (hipHeight == null) {
    const drop = sh - ankleH;
    final len = math.sqrt(math.pow(torso + leg, 2) - drop * drop);
    hipD = len * torso / (torso + leg);
    hipH = sh - drop * torso / (torso + leg);
    ankleD = len;
  } else {
    hipH = hipHeight;
    hipD = math.sqrt(torso * torso - math.pow(sh - hipH, 2));
    ankleD = hipD + math.sqrt(leg * leg - math.pow(hipH - ankleH, 2));
  }
  final kneeD = kneeling ? 0.85 : hipD + (ankleD - hipD) * 0.45 / leg;
  final kneeH = kneeling ? 0.05 : hipH + (ankleH - hipH) * 0.45 / leg;
  final bottom = <String, (double, double)>{
    'ear': (-0.15, 0.40),
    'shoulder': (0, sh),
    'elbow': (0, 0.03),
    'wrist': (-0.05, 0.02),
    'hip': (hipD, hipH),
    'knee': (kneeD, kneeH),
    'ankle': (ankleD, ankleH),
  };
  final top = <String, (double, double)>{
    'ear': (-0.15, 0.54),
    'shoulder': (topShoulderShift, sh + 0.34),
    'elbow': (0.28, sh + 0.30),
    'wrist': (hipD, hipH + 0.22),
    'hip': (hipD, hipH + 0.20),
    'knee': (kneeD, kneeH + 0.12),
    'ankle': (ankleD, ankleH + 0.08),
  };
  final pose = <PoseLandmarkType, PoseLandmark>{};
  void put(Map<String, (double, double)> pts, bool asLeft) {
    for (final e in pts.entries) {
      final (l, r) = _pairs[e.key]!;
      final type = asLeft ? l : r;
      final (x, y) = _px(e.value.$1, e.value.$2, mirror: !leftSupport);
      pose[type] = _mk(type, x, y);
    }
  }

  put(bottom, leftSupport);
  put(top, !leftSupport);
  return pose;
}

/// A person standing side-on to the camera, arms hanging, left side near.
/// Assumed: ankle 0.08 m, knee 0.50 m, hip 0.92 m, shoulder 1.42 m, ear
/// 1.58 m above the floor; far-side joints 0.03 m further along X
/// (perspective), so the shoulder X gap is 0.06 of the 0.50 m torso.
Map<PoseLandmarkType, PoseLandmark> _standingSideOn() {
  const near = <String, (double, double)>{
    'ear': (-0.02, 1.58),
    'shoulder': (0.02, 1.42),
    'elbow': (0.03, 1.12),
    'wrist': (0.03, 0.85),
    'hip': (0.0, 0.92),
    'knee': (0.0, 0.50),
    'ankle': (0.0, 0.08),
  };
  final pose = <PoseLandmarkType, PoseLandmark>{};
  for (final e in near.entries) {
    final (l, r) = _pairs[e.key]!;
    final (x, y) = _px(e.value.$1, e.value.$2, mirror: false);
    pose[l] = _mk(l, x, y, z: -0.1);
    pose[r] = _mk(r, x + 0.03 * _ppm, y, z: 0.1, visibility: 0.5);
  }
  return pose;
}

// --- Sphinx ---------------------------------------------------------------

/// Sphinx, side view. Assumed: forearm 0.25 m flat on the floor, elbow
/// 0.03 m up, upper arm vertical so the shoulder is 0.33 m up; shoulder-hip
/// 0.50 m, hip joint 0.11 m up (pelvis on the floor), knee 0.06 m, ankle
/// 0.08 m; ear 0.12 m ahead of and 0.10 m above the shoulder (head neutral).
/// Reads elbow 90, spine (shoulder-hip-knee) 160, neck 167.
Map<PoseLandmarkType, PoseLandmark> _sphinx({required bool leftNear}) {
  final hipD = math.sqrt(0.25 - 0.22 * 0.22);
  return _sideView({
    'ear': (-0.12, 0.43),
    'shoulder': (0, 0.33),
    'elbow': (0, 0.03),
    'wrist': (-0.25, 0.03),
    'hip': (hipD, 0.11),
    'knee': (hipD + 0.447, 0.06),
    'ankle': (hipD + 0.847, 0.08),
  }, leftNear: leftNear);
}

/// The same body after lowering the chest to rest without moving the
/// forearms: the shoulder drops to 0.12 m, which, with the upper arm
/// (0.30 m) pivoting on the fixed elbow, puts it 0.286 m behind the elbow.
/// Hip, knee and ankle heights as in [_sphinx]. Reads elbow 162.5 (inside
/// the 165 exit), spine 174.7 (inside the 175 exit).
Map<PoseLandmarkType, PoseLandmark> _sphinxChestDown(
    {required bool leftNear}) {
  const sD = 0.286;
  return _sideView({
    'ear': (sD - 0.15, 0.15),
    'shoulder': (sD, 0.12),
    'elbow': (0, 0.03),
    'wrist': (-0.25, 0.03),
    'hip': (sD + 0.5, 0.11),
    'knee': (sD + 0.5 + 0.447, 0.06),
    'ankle': (sD + 0.5 + 0.847, 0.08),
  }, leftNear: leftNear);
}

/// Repair test geometry (sphinx_form_test.dart): a ray layout where the
/// shoulder-hip-knee angle is exactly [spineDeg]; used only for the
/// hysteresis probe.
Map<PoseLandmarkType, PoseLandmark> _sphinxSpine(double spineDeg) {
  const hipX = 200.0, hipY = 300.0;
  final toShoulder = math.atan2(200 - hipY, 300 - hipX);
  final legDir = toShoulder + spineDeg * math.pi / 180;
  PoseLandmark p(PoseLandmarkType t, double x, double y) => _mk(t, x, y);
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

// --- Seated Forward Fold --------------------------------------------------

/// Seated, legs straight along X, side view. Assumed: hip joint 0.10 m up,
/// thigh 0.43 m to a knee 0.06 m up, shank 0.40 m to the heel 0.03 m up, toe
/// tip 0.19 m above and 0.05 m ahead of the heel (foot upright, ankle angle
/// 101); torso 0.50 m; the ear 0.16 m from the shoulder with the head flexed
/// 25 deg off the torso line (ear-shoulder-hip 155). [hipDeg] is the
/// shoulder-hip-knee angle; the thigh slopes 5.3 deg down, so a vertical
/// torso reads 95.3. Knee reads 179.
Map<PoseLandmarkType, PoseLandmark> _seated(
    {required bool leftNear, required double hipDeg}) {
  const hip = (0.0, 0.10);
  final thighDir = math.atan2(0.06 - 0.10, 0.43);
  final torsoDir = hipDeg * math.pi / 180 + thighDir;
  final shoulder = (
    hip.$1 + 0.5 * math.cos(torsoDir),
    hip.$2 + 0.5 * math.sin(torsoDir)
  );
  final earDir = torsoDir - 25 * math.pi / 180;
  return _sideView({
    'ear': (
      shoulder.$1 + 0.16 * math.cos(earDir),
      shoulder.$2 + 0.16 * math.sin(earDir)
    ),
    'shoulder': shoulder,
    'hip': hip,
    'knee': (0.43, 0.06),
    'heel': (0.83, 0.03),
    'foot': (0.88, 0.22),
  }, leftNear: leftNear);
}

double _seatedHipAngleForVerticalTorso() =>
    90 - math.atan2(0.06 - 0.10, 0.43) * 180 / math.pi;

// --- Butterfly ------------------------------------------------------------

/// Butterfly, front view, phone portrait. Assumed: shoulder joints 0.34 m
/// apart and 0.60 m above the floor, hip joints 0.18 m apart and 0.10 m up
/// (torso 0.50 m), knees 0.80 m apart and 0.25 m up (symmetric), ankles
/// 0.12 m apart and 0.06 m up, heels 0.05 m apart on the floor (soles
/// together). [shoulderWidth] and [torso] can be changed for the facing
/// probe.
Map<PoseLandmarkType, PoseLandmark> _butterfly({
  double shoulderWidth = 0.34,
  double torso = 0.50,
  double leftKneeLift = 0,
}) {
  const cx = 300.0;
  (double, double) at(double dx, double h) => (cx + dx * _ppm, _floorY - h * _ppm);
  final pts = <String, ((double, double), (double, double))>{
    'shoulder': (
      at(shoulderWidth / 2, 0.10 + torso),
      at(-shoulderWidth / 2, 0.10 + torso)
    ),
    'hip': (at(0.09, 0.10), at(-0.09, 0.10)),
    'knee': (at(0.40, 0.25 + leftKneeLift), at(-0.40, 0.25)),
    'ankle': (at(0.06, 0.06), at(-0.06, 0.06)),
    'heel': (at(0.025, 0.01), at(-0.025, 0.01)),
  };
  final pose = <PoseLandmarkType, PoseLandmark>{};
  for (final e in pts.entries) {
    final (l, r) = _pairs[e.key]!;
    pose[l] = _mk(l, e.value.$1.$1, e.value.$1.$2);
    pose[r] = _mk(r, e.value.$2.$1, e.value.$2.$2);
  }
  return pose;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Side Plank', () {
    for (final leftSupport in [true, false]) {
      final side = leftSupport ? 'left' : 'right';

      test(
          'PROBE clean ($side forearm): a straight forearm side plank counts '
          'one hold with no fault', () {
        final pose = _sidePlank(leftSupport: leftSupport);
        final e = _activate(SidePlankDip(maxHolds: 1, holdSeconds: 15), pose,
            accepted: _sides);
        _run(e, pose, fromMs: 0, toMs: 16000);
        expect(e.repCount, 1);
        expect(e.logger.repLogs, hasLength(1));
        expect(e.logger.repLogs.single.data['fault_types'], isEmpty);
        expect(e.logger.repLogs.single.correctForm, isTrue);
      });

      test(
          'PROBE hips on the floor ($side forearm): resting the hips on the '
          'floor (hip joint 0.13 m up) stops the clock', () {
        final e = _activate(SidePlankDip(maxHolds: 1, holdSeconds: 15),
            _sidePlank(leftSupport: leftSupport),
            accepted: _sides);
        _run(e, _sidePlank(leftSupport: leftSupport), fromMs: 0, toMs: 2000);
        _run(e, _sidePlank(leftSupport: leftSupport, hipHeight: 0.13),
            fromMs: 2100, toMs: 5000);
        expect(e.phase, HoldPhase.dropping,
            reason: 'body angle with the hips down reads '
                '${(e.debugData['sidePlankBodyAngle'] as double).toStringAsFixed(1)}'
                ' deg; the line fault needs < 155');
      }, skip: 'D1/S2: hip-sag detection needs a number from a phone, owner decision');
    }

    test(
        'PROBE hips-on-floor start: lying on the side propped on the forearm '
        'does not pass the start gate', () {
      final e = SidePlankDip(maxHolds: 1, holdSeconds: 15);
      final pose = _sidePlank(leftSupport: true, hipHeight: 0.13);
      e.cameraFacing = e.detectCameraFacing(pose);
      expect(e.isInStartPosition(pose), isFalse);
    }, skip: 'D1/S2: hip-sag detection needs a number from a phone, owner decision');

    test(
        'hip offset debug value (D1/S2, measurement only): about 0 for a '
        'straight side plank, clearly positive with the hips on the floor',
        () {
      for (final leftSupport in [true, false]) {
        double offset(Map<PoseLandmarkType, PoseLandmark> pose) {
          final e = _activate(SidePlankDip(maxHolds: 1, holdSeconds: 15),
              _sidePlank(leftSupport: leftSupport),
              accepted: _sides);
          _pump(e, pose, 0);
          return e.debugData['sidePlankHipOffset'] as double;
        }

        expect(offset(_sidePlank(leftSupport: leftSupport)),
            closeTo(0, 0.01));
        expect(
            offset(_sidePlank(leftSupport: leftSupport, hipHeight: 0.13)),
            greaterThan(0.1));
      }
    });

    test(
        'PROBE standing side-on: a person standing side-on with arms down '
        'earns no hold', () {
      final pose = _standingSideOn();
      // Fix batch C (S1): the start gate now refuses this pose, so _activate's
      // start-gate precondition cannot hold. Activate as the base class
      // would, to check that the hold gate also refuses it.
      final e = SidePlankDip(maxHolds: 1, holdSeconds: 15);
      for (var i = 0; i < 6; i++) {
        e.cameraFacing = e.detectCameraFacing(pose);
      }
      expect(e.checkSafety(pose), isNull);
      expect(e.isInStartPosition(pose), isFalse);
      e.exerciseState = ExerciseState.activated;
      e.onExerciseActivated();
      _run(e, pose, fromMs: 0, toMs: 16000);
      expect(e.repCount, 0,
          reason: 'nothing checks that the body is horizontal');
    });

    // The owner keeps this behaviour (D7): *_seconds are "time out of line,
    // rest included".
    test(
        'FACT kneel to rest: kneeling for 5 s after a break is logged as '
        'body-line fault time', () {
      final e = _activate(SidePlankDip(maxHolds: 1, holdSeconds: 15),
          _sidePlank(leftSupport: true),
          accepted: _sides);
      _run(e, _sidePlank(leftSupport: true), fromMs: 0, toMs: 5000);
      _run(e, _sidePlank(leftSupport: true, kneeling: true),
          fromMs: 5100, toMs: 10000);
      expect(e.phase, HoldPhase.dropping, reason: 'fixture precondition');
      _run(e, _sidePlank(leftSupport: true), fromMs: 10100, toMs: 21000);
      expect(e.repCount, 1, reason: 'fixture precondition');
      e.onSetComplete();
      expect(e.logger.setLogs['body_line_seconds'] as double,
          closeTo(5.0, 0.01),
          reason: 'the subclass timer adds every dropping frame with the '
              'line broken, including time spent resting on the knees');
    });

    test(
        'PROBE rotation noise: a 1.5 cm shoulder jitter does not stop the '
        'clock when the start-pose shoulder X gap was 3 cm', () {
      final start = _sidePlank(leftSupport: true, topShoulderShift: 0.03);
      final e = _activate(SidePlankDip(maxHolds: 1, holdSeconds: 15), start,
          accepted: _sides);
      _run(e, start, fromMs: 0, toMs: 1000);
      _pump(e, _sidePlank(leftSupport: true, topShoulderShift: 0.015), 1100);
      expect(e.phase, HoldPhase.holding,
          reason: 'baseline 6 px on a 100 px torso is just above the 0.05 '
              'skip; 3 px of jitter gives ratio 0.5 < 0.6');
    });

    test('PROBE no stuck: after a pause mid-hold the next full hold counts',
        () {
      final pose = _sidePlank(leftSupport: true);
      final e = _activate(SidePlankDip(maxHolds: 1, holdSeconds: 15), pose,
          accepted: _sides);
      _run(e, pose, fromMs: 0, toMs: 8000);
      e.onPauseReactivationStarted();
      expect(e.isInStartPosition(pose), isTrue);
      _run(e, pose, fromMs: 20000, toMs: 35500);
      expect(e.repCount, 1);
      expect(e.logger.repLogs.single.data['fault_types'], isEmpty);
    });
  });

  group('Sphinx', () {
    for (final leftNear in [true, false]) {
      final side = leftNear ? 'left' : 'right';

      test('PROBE clean ($side): a 30 s sphinx counts one hold, no fault', () {
        final pose = _sphinx(leftNear: leftNear);
        final e = _activate(SphinxStretch(maxHolds: 1, holdSeconds: 30), pose,
            accepted: _sides);
        _run(e, pose, fromMs: 0, toMs: 31000);
        expect(e.repCount, 1);
        expect(e.logger.repLogs, hasLength(1));
        expect(e.logger.repLogs.single.data['fault_types'], isEmpty);
      });

      test(
          'PROBE chest down ($side): lowering the chest to the floor without '
          'moving the forearms pauses the clock', () {
        final e = _activate(SphinxStretch(maxHolds: 1, holdSeconds: 30),
            _sphinx(leftNear: leftNear),
            accepted: _sides);
        _run(e, _sphinx(leftNear: leftNear), fromMs: 0, toMs: 2000);
        _run(e, _sphinxChestDown(leftNear: leftNear),
            fromMs: 2100, toMs: 4000);
        expect(e.phase, HoldPhase.dropping,
            reason: 'spine ${e.debugData['spineAngle'] ?? '(n/a)'}; '
                'elbow ${e.debugData['elbowAngle']}; the old exit (spine '
                '> 172) caught this, the new one (> 175) does not');
      });
    }

    test(
        'PROBE hysteresis: a spine angle jittering 174.6 / 175.4 does not '
        'flip the phase every frame', () {
      final e = SphinxStretch(maxHolds: 1, holdSeconds: 30)
        ..cameraFacing = CameraFacing.right
        ..exerciseState = ExerciseState.activated;
      e.onExerciseActivated();
      _pump(e, _sphinxSpine(170), 0);
      final phases = <HoldPhase>[];
      for (var i = 1; i <= 10; i++) {
        _pump(e, _sphinxSpine(i.isEven ? 174.6 : 175.4), i * 100);
        phases.add(e.phase);
      }
      expect(phases.toSet(), {HoldPhase.holding},
          reason: 'entry <= 175 and exit > 175 with 1-frame debounces: '
              'phases were $phases');
    },
        skip: 'D5 fixed as specified (entry <= 172, exit > 175): the 175.4 '
            'frame exits once and the phase then stays dropping, no flicker. '
            'Holding throughout would need an exit above 175.4, a new number. '
            'See "hysteresis (fix batch C)" below.');

    test(
        'hysteresis (fix batch C): a spine angle jittering 174.6 / 175.4 '
        'changes the phase at most once', () {
      final e = SphinxStretch(maxHolds: 1, holdSeconds: 30)
        ..cameraFacing = CameraFacing.right
        ..exerciseState = ExerciseState.activated;
      e.onExerciseActivated();
      _pump(e, _sphinxSpine(170), 0);
      final phases = <HoldPhase>[e.phase];
      for (var i = 1; i <= 10; i++) {
        _pump(e, _sphinxSpine(i.isEven ? 174.6 : 175.4), i * 100);
        phases.add(e.phase);
      }
      var changes = 0;
      for (var i = 1; i < phases.length; i++) {
        if (phases[i] != phases[i - 1]) changes++;
      }
      expect(changes, lessThanOrEqualTo(1), reason: 'phases were $phases');
    });

    test('PROBE no stuck: after a pause mid-hold the next full hold counts',
        () {
      final pose = _sphinx(leftNear: true);
      final e = _activate(SphinxStretch(maxHolds: 1, holdSeconds: 30), pose,
          accepted: _sides);
      _run(e, pose, fromMs: 0, toMs: 10000);
      e.onPauseReactivationStarted();
      _run(e, pose, fromMs: 20000, toMs: 50500);
      expect(e.repCount, 1);
      expect(e.logger.repLogs.single.data['fault_types'], isEmpty);
    });
  });

  group('Seated Forward Fold', () {
    for (final leftNear in [true, false]) {
      final side = leftNear ? 'left' : 'right';

      test(
          'PROBE clean ($side): sit at hip 100, fold to 50 over 2 s, hold '
          'still; one hold, no fault', () {
        final e = _activate(SeatedForwardFold(maxHolds: 1, holdSeconds: 30),
            _seated(leftNear: leftNear, hipDeg: 100),
            accepted: _sides);
        var t = 0;
        for (var hip = 100.0; hip >= 50; hip -= 2.5) {
          _pump(e, _seated(leftNear: leftNear, hipDeg: hip), t);
          t += 100;
        }
        _run(e, _seated(leftNear: leftNear, hipDeg: 50),
            fromMs: t, toMs: t + 32000);
        expect(e.repCount, 1);
        expect(e.logger.repLogs, hasLength(1));
        expect(e.logger.repLogs.single.data['fault_types'], isEmpty);
      });
    }

    test(
        'PROBE no fold: sitting upright (torso 1 deg forward of vertical) '
        'earns no hold', () {
      final upright = _seatedHipAngleForVerticalTorso(); // 95.3
      final e = _activate(SeatedForwardFold(maxHolds: 1, holdSeconds: 30),
          _seated(leftNear: true, hipDeg: upright),
          accepted: _sides);
      _run(e, _seated(leftNear: true, hipDeg: upright - 1),
          fromMs: 0, toMs: 32000);
      expect(e.repCount, 0,
          reason: 'target depth = max(setup - 6, 95) = 95, so any hip angle '
              'under 95 counts as folded');
    });

    test(
        'PROBE ease-back log: a hold that eases back once, resumes and '
        'completes 30 s is not logged with "tempo" (not long enough)', () {
      final e = _activate(SeatedForwardFold(maxHolds: 1, holdSeconds: 30),
          _seated(leftNear: true, hipDeg: 100),
          accepted: _sides);
      _run(e, _seated(leftNear: true, hipDeg: 50), fromMs: 0, toMs: 10000);
      _run(e, _seated(leftNear: true, hipDeg: 65), fromMs: 10100, toMs: 45000);
      expect(e.repCount, 1, reason: 'fixture precondition');
      expect(e.logger.repLogs.single.data['fault_types'], isEmpty);
    });

    test('PROBE no stuck: after a pause mid-hold the next full hold counts',
        () {
      final start = _seated(leftNear: true, hipDeg: 100);
      final e = _activate(SeatedForwardFold(maxHolds: 1, holdSeconds: 30),
          start,
          accepted: _sides);
      _run(e, _seated(leftNear: true, hipDeg: 50), fromMs: 0, toMs: 10000);
      e.onPauseReactivationStarted();
      expect(e.isInStartPosition(start), isTrue);
      _run(e, start, fromMs: 20000, toMs: 23000);
      _run(e, _seated(leftNear: true, hipDeg: 50), fromMs: 23100, toMs: 56000);
      expect(e.repCount, 1);
      expect(e.logger.repLogs.single.data['fault_types'], isEmpty);
    });
  });

  group('Butterfly', () {
    test('PROBE clean: a still, symmetric 30 s butterfly counts one hold, no '
        'fault', () {
      final pose = _butterfly();
      final e = _activate(ButterflyStretch(maxHolds: 1, holdSeconds: 30), pose,
          accepted: {CameraFacing.front});
      _run(e, pose, fromMs: 0, toMs: 32000);
      expect(e.repCount, 1);
      expect(e.logger.repLogs.single.data['fault_types'], isEmpty);
    });

    test(
        'FACT hold card (removed in fix batch C): a completed set logs '
        'total_hold_time equal to total_seconds, and the summary shows no '
        '"Thời gian Hold" ring that could only read 100%', () {
      final pose = _butterfly();
      final e = _activate(ButterflyStretch(maxHolds: 1, holdSeconds: 30), pose,
          accepted: {CameraFacing.front});
      _run(e, pose, fromMs: 0, toMs: 32000);
      expect(e.requestStop(), isTrue);
      e.onSetComplete();
      final labels = ButterflyReportBuilder()
          .buildDetailCards([e.logger])
          .map((c) => c.label);
      expect(labels, isNot(contains('Thời gian Hold')));
      expect(e.logger.setLogs['total_hold_time'],
          e.logger.setLogs['total_seconds']);
    });

    test(
        'FACT partial hold: 15 s held and not completed adds nothing to '
        'total_hold_time', () {
      final pose = _butterfly();
      final e = _activate(ButterflyStretch(maxHolds: 1, holdSeconds: 30), pose,
          accepted: {CameraFacing.front});
      _run(e, pose, fromMs: 0, toMs: 16000);
      expect(e.liveHoldSeconds, greaterThan(14));
      e.onSetComplete();
      expect(e.logger.setLogs['total_hold_time'], 0.0);
    });

    test(
        'PROBE straight legs: after the start, sitting still with the legs '
        'straight earns no hold', () {
      final e = _activate(ButterflyStretch(maxHolds: 1, holdSeconds: 30),
          _butterfly(),
          accepted: {CameraFacing.front});
      _run(e, _butterfly(), fromMs: 0, toMs: 5000);
      // Legs straight toward the camera: knees and ankles 0.20 m apart; the
      // feet are nearer the camera, so they project below the hips.
      final straight = _butterfly();
      for (final (type, dx, h) in [
        (PoseLandmarkType.leftKnee, 0.10, 0.0),
        (PoseLandmarkType.rightKnee, -0.10, 0.0),
        (PoseLandmarkType.leftAnkle, 0.10, -0.15),
        (PoseLandmarkType.rightAnkle, -0.10, -0.15),
        (PoseLandmarkType.leftHeel, 0.10, -0.18),
        (PoseLandmarkType.rightHeel, -0.10, -0.18),
      ]) {
        straight[type] = _mk(type, 300 + dx * _ppm, _floorY - h * _ppm);
      }
      _run(e, straight, fromMs: 5100, toMs: 40000);
      expect(e.repCount, 0,
          reason: 'the hold gate checks only that the knees are still; '
              'knees moving down never exits');
    });

    test('PROBE no stuck: after a pause mid-hold the next full hold counts',
        () {
      final pose = _butterfly();
      final e = _activate(ButterflyStretch(maxHolds: 1, holdSeconds: 30), pose,
          accepted: {CameraFacing.front});
      _run(e, pose, fromMs: 0, toMs: 10000);
      e.onPauseReactivationStarted();
      _run(e, pose, fromMs: 20000, toMs: 52000);
      expect(e.repCount, 1);
    });

    test(
        'FACT narrow shoulders: a seated front view with shoulder joints '
        '0.29 m apart and a 0.52 m torso is classified angled', () {
      final e = ButterflyStretch(maxHolds: 1, holdSeconds: 30);
      final pose = _butterfly(shoulderWidth: 0.29, torso: 0.52);
      var facing = CameraFacing.undefined;
      for (var i = 0; i < 6; i++) {
        facing = e.detectCameraFacing(pose);
      }
      expect(facing, CameraFacing.angled);
      e.cameraFacing = facing;
      expect(e.checkSafety(pose), isNotNull,
          reason: 'Butterfly shows "face the camera" and cannot start');
    });
  });
}
