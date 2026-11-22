// Probes written for docs/scratch/kept-exercises-review-batch-B.md.
//
// Each PROBE asserts what a filmed participant or a judge needs: a clean rep
// counts exactly once and logs no fault. A failing PROBE is a finding, not
// something to fix here. FACT tests pin current behaviour the review relies on
// (they are expected to pass).
//
// Conventions (copied in spirit from batch_a_review_probe_test.dart, nothing
// imported from it):
// - Bodies are built in metres and converted with a stated pixels-per-metre
//   value k, with the floor at a stated image y. Segment lengths: torso
//   (shoulder-hip) 0.48-0.50 m, thigh 0.45 m, shin 0.43-0.45 m, upper arm
//   0.30 m, forearm 0.27 m, shoulder-to-wrist 0.57-0.60 m.
// - Side views are written with the head / front toward smaller X and the left
//   side nearer the camera (smaller z). leftNear: false mirrors the image in X
//   and swaps the side labels, which is the same body with the right side to
//   the camera. detectCameraFacing decides the facing from z, as in the app.
// - Frames are 33 ms apart (30 fps). checkSafety runs on every frame and a
//   non-null signal skips the frame, as ExerciseBase.processPose does.
//   processPose itself is not called (it needs the presence gate), so the
//   base scale factor is written here from the camera-side shoulder and hip.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/1.Bird Dog/bird_dog.dart';
import 'package:vika/exercise/12.Dead Bug/dead_bug.dart';
import 'package:vika/exercise/2.Sit-Up/sit_up.dart';
import 'package:vika/exercise/4.Mountain Climber/mountain_climber.dart';
import 'package:vika/exercise/5.Superman/superman.dart';
import 'package:vika/exercise/8.Leg Raises (Supine)/leg_raise.dart';
import 'package:vika/exercise/Jump_Squat/jump_squat.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/jumping jack/jumping_jack.dart';
import 'package:vika/exercise/lunge/lunge.dart';
import 'package:vika/exercise/wall_push_up/wall_push_up.dart';
import 'package:vika/exercise/10.Vup/v_up.dart';
import 'package:vika/exercise/curl_up/curl_up.dart';
import 'package:vika/exercise/tricep_dip/tricep_dip.dart';

typedef _P = (double, double);
typedef _Pose = Map<PoseLandmarkType, PoseLandmark>;

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

double _rad(double deg) => deg * math.pi / 180;
double _ease(double s) => (1 - math.cos(math.pi * s)) / 2;
double _lerp(double a, double b, double s) => a + (b - a) * s;
_P _add(_P a, _P b) => (a.$1 + b.$1, a.$2 + b.$2);
_P _sub(_P a, _P b) => (a.$1 - b.$1, a.$2 - b.$2);
_P _scale(_P a, double f) => (a.$1 * f, a.$2 * f);
_P _mid(_P a, _P b) => ((a.$1 + b.$1) / 2, (a.$2 + b.$2) / 2);
double _len(_P a) => math.sqrt(a.$1 * a.$1 + a.$2 * a.$2);

/// Side view. [near] goes to the left labels when [leftNear] (z = -zGap),
/// [far] to the other side (z = +zGap). For leftNear false the image is
/// mirrored about [mirrorAbout] and the labels swap.
_Pose _side({
  required Map<String, _P> near,
  Map<String, _P>? far,
  _P? nose,
  required bool leftNear,
  required double mirrorAbout,
  double zGap = 0.1,
}) {
  final pose = <PoseLandmarkType, PoseLandmark>{};
  double mx(double x) => leftNear ? x : 2 * mirrorAbout - x;
  void put(PoseLandmarkType t, _P p, double z) => pose[t] =
      PoseLandmark(type: t, x: mx(p.$1), y: p.$2, z: z, likelihood: 0.99);
  for (final e in near.entries) {
    final (l, r) = _pairs[e.key]!;
    put(leftNear ? l : r, e.value, -zGap);
  }
  for (final e in (far ?? near).entries) {
    final (l, r) = _pairs[e.key]!;
    put(leftNear ? r : l, e.value, zGap);
  }
  if (nose != null) put(PoseLandmarkType.nose, nose, 0);
  return pose;
}

/// Drives an exercise frame by frame the way processPose does after the
/// presence gate: facing, checkSafety, scale factor, checkingPose.
class _Run {
  _Run(this.e);
  final ExerciseBase e;
  int ms = 0;
  int skipped = 0;

  void _facing(_Pose pose) => e.cameraFacing = e.detectCameraFacing(pose);

  void _writeScale(_Pose pose) {
    if (e.cameraFacing != CameraFacing.left &&
        e.cameraFacing != CameraFacing.right) {
      return;
    }
    final right = e.cameraFacing == CameraFacing.right;
    final s = pose[right
        ? PoseLandmarkType.rightShoulder
        : PoseLandmarkType.leftShoulder];
    final h =
        pose[right ? PoseLandmarkType.rightHip : PoseLandmarkType.leftHip];
    if (s == null || h == null) return;
    e.scaleFactor = _len((s.x - h.x, s.y - h.y));
  }

  /// Settles the facing, checks the start gate, and activates as the base
  /// does after the 3 s hold (the hold itself is not replayed).
  void activate(_Pose start) {
    for (var i = 0; i < 6; i++) {
      ms += 33;
      e.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms);
      _facing(start);
    }
    expect(e.checkSafety(start), isNull,
        reason: 'fixture precondition: checkSafety accepts the start pose '
            '(facing ${e.cameraFacing})');
    _writeScale(start);
    expect(e.isInStartPosition(start), isTrue,
        reason: 'fixture precondition: the start gate accepts the start pose');
    e.exerciseState = ExerciseState.activated;
    e.onExerciseActivated();
  }

  void frame(_Pose pose) {
    ms += 33;
    e.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms);
    _facing(pose);
    if (e.checkSafety(pose) != null) {
      skipped++;
      return;
    }
    _writeScale(pose);
    e.checkingPose(pose);
  }

  void hold(_Pose pose, int n) {
    for (var i = 0; i < n; i++) {
      frame(pose);
    }
  }

  /// [n] frames with s running from 1/n to 1.
  void ramp(int n, _Pose Function(double s) at) {
    for (var i = 1; i <= n; i++) {
      frame(at(i / n));
    }
  }

  List<List<String>> get faultTypes => [
        for (final log in e.logger.repLogs)
          (log.data['fault_types'] as List).cast<String>()
      ];
}

// --- Sit-Up -----------------------------------------------------------------

/// Landscape side view, k = 300 px/m, floor y = 620. Supine, knees bent 90
/// deg, feet flat: hip joint 0.10 m above the floor, ankle 0.08 m, thigh 0.45,
/// shin 0.43, torso 0.48. [theta] is the trunk angle above horizontal.
_Pose _sitUp(double theta, {required bool leftNear}) {
  const k = 300.0, floor = 620.0;
  const hip = (700.0, floor - 0.10 * k);
  final a = _rad(43.7);
  final knee = (hip.$1 + 0.45 * k * math.cos(a), hip.$2 - 0.45 * k * math.sin(a));
  final ankle = (hip.$1 + 0.6224 * k, floor - 0.08 * k);
  final t = _rad(theta);
  final shoulder =
      (hip.$1 - 0.48 * k * math.cos(t), hip.$2 - 0.48 * k * math.sin(t));
  return _side(
    near: {'shoulder': shoulder, 'hip': hip, 'knee': knee, 'ankle': ankle},
    leftNear: leftNear,
    mirrorAbout: 640,
  );
}

// --- Lunge ------------------------------------------------------------------

/// Portrait side view, k = 350 px/m, floor y = 1150, front toward smaller X.
/// Lead ankle fixed 0.08 m above the floor; thigh and shin 0.45 m; torso
/// 0.50 m. Angles in degrees: phi = thigh angle forward of vertical, kappa =
/// knee flexion (interior knee angle = 180 - kappa), lean = trunk forward of
/// vertical. The lead foot is flat (heel 0.03 m, toe 0.01 m above the floor);
/// a stepped-back trail foot stands on its toes.
_Pose _lunge({
  required bool leftNear,
  required bool leadIsNear,
  required double lp,
  required double lk,
  required double tp,
  required double tk,
  required double lean,
  double zGap = 0.1,
}) {
  const k = 350.0, floor = 1150.0;
  const leadAnkle = (330.0, floor - 0.08 * k);
  _P thigh(double phi) =>
      (-0.45 * k * math.sin(_rad(phi)), 0.45 * k * math.cos(_rad(phi)));
  _P shin(double phi, double kappa) => (
        -0.45 * k * math.sin(_rad(phi - kappa)),
        0.45 * k * math.cos(_rad(phi - kappa))
      );
  final hip = _sub(_sub(leadAnkle, thigh(lp)), shin(lp, lk));
  final leadKnee = _add(hip, thigh(lp));
  final trailKnee = _add(hip, thigh(tp));
  final trailAnkle = _add(trailKnee, shin(tp, tk));
  final shoulder = _add(
      hip, (-0.5 * k * math.sin(_rad(lean)), -0.5 * k * math.cos(_rad(lean))));
  final lead = {
    'shoulder': shoulder,
    'hip': hip,
    'knee': leadKnee,
    'ankle': leadAnkle,
    'heel': _add(leadAnkle, (0.06 * k, 0.05 * k)),
    'foot': _add(leadAnkle, (-0.15 * k, 0.07 * k)),
  };
  final steppedBack = tp < -5;
  final trail = {
    'shoulder': shoulder,
    'hip': hip,
    'knee': trailKnee,
    'ankle': trailAnkle,
    'heel': _add(trailAnkle,
        steppedBack ? (0.05 * k, -0.02 * k) : (0.06 * k, 0.05 * k)),
    'foot': _add(trailAnkle, (-0.15 * k, 0.07 * k)),
  };
  return _side(
    near: leadIsNear ? lead : trail,
    far: leadIsNear ? trail : lead,
    leftNear: leftNear,
    mirrorAbout: 360,
    zGap: zGap,
  );
}

/// One reverse lunge. [swingFlex] is the extra knee flexion of the stepping
/// leg at mid-swing (0 = a straight-legged step).
void _reverseLunge(_Run r,
    {required bool leftNear,
    required bool leadIsNear,
    double swingFlex = 10,
    double zGap = 0.1}) {
  _Pose at(double lp, double lk, double tp, double tk, double lean) => _lunge(
      leftNear: leftNear,
      leadIsNear: leadIsNear,
      lp: lp,
      lk: lk,
      tp: tp,
      tk: tk,
      lean: lean,
      zGap: zGap);
  r.hold(at(0, 5, 0, 5, 5), 10); // standing
  r.ramp(
      12,
      (s) => at(0, _lerp(5, 10, s), -25 * s,
          5 + 15 * s + swingFlex * math.sin(math.pi * s), 5)); // step back
  r.hold(at(0, 10, -25, 20, 5), 6); // brief pause, feet apart
  r.ramp(
      20,
      (s) => at(90 * _ease(s), _lerp(10, 90, _ease(s)), _lerp(-25, -17, _ease(s)),
          _lerp(20, 80, _ease(s)), _lerp(5, 12, _ease(s)))); // descent
  r.hold(at(90, 90, -17, 80, 12), 5); // bottom
  r.ramp(
      20,
      (s) => at(90 * (1 - _ease(s)), _lerp(90, 10, _ease(s)),
          _lerp(-17, -25, _ease(s)), _lerp(80, 20, _ease(s)),
          _lerp(12, 5, _ease(s)))); // ascent
  r.hold(at(0, 10, -25, 20, 5), 6);
  r.ramp(12, (s) => at(0, _lerp(10, 5, s), -25 * (1 - s), _lerp(20, 5, s), 5));
  r.hold(at(0, 5, 0, 5, 5), 10);
}

// --- Jumping Jack ------------------------------------------------------------

/// Front view (portrait), k = 350 px/m, floor y = 1150, body centred at
/// x = 360. Heights: ankle 0.08, knee 0.53, hip 0.98, shoulder 1.45, nose
/// 1.58 m. Shoulder width 0.36 m, hip width 0.26 m, shoulder-to-wrist 0.57 m.
/// [s] = 0 is closed (feet 0.12 m apart, arms at the sides), 1 is open (feet
/// 0.80 m apart, arms overhead, elbows straight).
_Pose _jack(double s) {
  const k = 350.0, floor = 1150.0, cx = 360.0;
  double y(double h) => floor - h * k;
  final w = _rad(8 + 164 * s);
  final pose = <PoseLandmarkType, PoseLandmark>{};
  void put(PoseLandmarkType t, double x, double yy) =>
      pose[t] = PoseLandmark(type: t, x: x, y: yy, z: 0, likelihood: 0.99);
  for (final sign in [1.0, -1.0]) {
    final left = sign > 0;
    PoseLandmarkType t(String name) =>
        left ? _pairs[name]!.$1 : _pairs[name]!.$2;
    put(t('ankle'), cx + sign * (0.06 + 0.34 * s) * k, y(0.08));
    put(t('heel'), cx + sign * (0.06 + 0.34 * s) * k, y(0.03));
    put(t('foot'), cx + sign * (0.08 + 0.34 * s) * k, y(0.01));
    put(t('knee'), cx + sign * (0.08 + 0.17 * s) * k, y(0.53));
    put(t('hip'), cx + sign * 0.13 * k, y(0.98));
    put(t('shoulder'), cx + sign * 0.18 * k, y(1.45));
    put(t('ear'), cx + sign * 0.07 * k, y(1.60));
    put(t('elbow'), cx + sign * (0.18 + 0.285 * math.sin(w)) * k,
        y(1.45 - 0.285 * math.cos(w)));
    put(t('wrist'), cx + sign * (0.18 + 0.57 * math.sin(w)) * k,
        y(1.45 - 0.57 * math.cos(w)));
  }
  put(PoseLandmarkType.nose, cx, y(1.58));
  return pose;
}

// --- Leg Raise --------------------------------------------------------------

/// Landscape side view, k = 300 px/m, floor y = 620, head toward smaller X.
/// Supine: shoulder and hip joints 0.10 m above the floor, torso 0.48 m, legs
/// straight (thigh 0.45, hip-to-ankle 0.88 m), arms straight along the body
/// with the wrists beside the hips. [psi] is the leg angle above horizontal
/// (-2.6 = heels on the floor).
_Pose _legRaise(double psi, {required bool leftNear}) {
  const k = 300.0, floor = 620.0;
  const hip = (700.0, floor - 0.10 * k);
  const shoulder = (700.0 - 0.48 * k, floor - 0.10 * k);
  final p = _rad(psi);
  final dir = (math.cos(p), -math.sin(p));
  return _side(
    near: {
      'shoulder': shoulder,
      'hip': hip,
      'knee': _add(hip, _scale(dir, 0.45 * k)),
      'ankle': _add(hip, _scale(dir, 0.88 * k)),
      'elbow': (shoulder.$1 + 0.27 * k, floor - 0.05 * k),
      'wrist': (shoulder.$1 + 0.50 * k, floor - 0.04 * k),
    },
    leftNear: leftNear,
    mirrorAbout: 640,
  );
}

// --- Jump Squat -------------------------------------------------------------

/// Portrait side view, k = 350 px/m, floor y = 1150, front toward smaller X.
/// Shin and thigh 0.45 m, torso 0.50 m. [knee] is the interior knee angle;
/// the shin tilts forward by 45% of the flexion, the thigh back by 55%, the
/// trunk leans forward by 35%. [heelRise] lifts ankle and heel (toes stay
/// down, plantar flexion at push-off); [lift] lifts the whole body (flight).
_Pose _jumpSquat(double knee,
    {double heelRise = 0, double lift = 0, required bool leftNear}) {
  const k = 350.0, floor = 1150.0;
  final f = 180 - knee;
  final a = _rad(f * 0.45), b = _rad(f * 0.55), g = _rad(f * 0.35);
  final ankle = (360.0, floor - (0.08 + heelRise + lift) * k);
  final kneeP =
      _add(ankle, (-0.45 * k * math.sin(a), -0.45 * k * math.cos(a)));
  final hip = _add(kneeP, (0.45 * k * math.sin(b), -0.45 * k * math.cos(b)));
  final shoulder = _add(hip, (-0.5 * k * math.sin(g), -0.5 * k * math.cos(g)));
  final heel = _add(ankle, (0.06 * k, 0.05 * k));
  final foot = (360.0 - 0.15 * k, floor - (0.01 + lift) * k);
  return _side(
    near: {
      'shoulder': shoulder,
      'hip': hip,
      'knee': kneeP,
      'ankle': ankle,
      'heel': heel,
      'foot': foot,
    },
    nose: _add(shoulder, (-0.08 * k, -0.15 * k)),
    leftNear: leftNear,
    mirrorAbout: 360,
  );
}

/// Push-off (8 frames, knee 95 -> 175, heel rising 0.10 m), flight (10
/// frames, peak 0.15 m), landing (contact at 170, then 20 deg/frame down to
/// 100). Leaves the body at the bottom of the landing.
void _jumpFromBottom(_Run r, {required bool leftNear}) {
  r.ramp(8, (s) => _jumpSquat(95 + 80 * s, heelRise: 0.10 * s * s,
      leftNear: leftNear));
  for (var i = 1; i <= 10; i++) {
    r.frame(_jumpSquat(175,
        heelRise: 0.10, lift: 0.15 * math.sin(math.pi * i / 11),
        leftNear: leftNear));
  }
  final landing = <double>[170, 150, 130, 115, 105, 100];
  for (var i = 0; i < landing.length; i++) {
    r.frame(_jumpSquat(landing[i],
        heelRise: i == 0 ? 0.05 : 0, leftNear: leftNear));
  }
}

// --- Mountain Climber -------------------------------------------------------

/// Landscape side view, k = 300 px/m, floor y = 640, head toward smaller X.
/// High plank: wrist under the shoulder, shoulder 0.57 m above the floor,
/// shoulder-to-ankle 1.24 m with the ankle 0.10 m up (body line 22.3 deg
/// below horizontal), hip on that line 0.48 m from the shoulder. A knee drive
/// [s] = 1 brings the thigh 45 deg below horizontal pointing forward (knee
/// 0.13 m above the floor) and the foot back under the hip (interior knee 50
/// deg). [nearDrive] / [farDrive] drive the camera-side / far-side leg.
_Pose _climber(
    {double nearDrive = 0, double farDrive = 0, required bool leftNear}) {
  const k = 300.0, floor = 640.0;
  const shoulder = (300.0, floor - 0.57 * k);
  const eps = 22.3;
  final u = (math.cos(_rad(eps)), math.sin(_rad(eps)));
  final hip = _add(shoulder, _scale(u, 0.48 * k));
  Map<String, _P> leg(double s) {
    final tt = _rad(eps + 112.7 * s), ts = _rad(eps - 17.3 * s);
    final knee = _add(hip, (0.45 * k * math.cos(tt), 0.45 * k * math.sin(tt)));
    final ankle =
        _add(knee, (0.43 * k * math.cos(ts), 0.43 * k * math.sin(ts)));
    return {
      'shoulder': shoulder,
      'elbow': (shoulder.$1 - 3, floor - 0.30 * k),
      'wrist': (shoulder.$1, floor - 0.02 * k),
      'hip': hip,
      'knee': knee,
      'ankle': ankle,
    };
  }

  return _side(
    near: leg(nearDrive),
    far: leg(farDrive),
    leftNear: leftNear,
    mirrorAbout: 640,
  );
}

// --- Wall Push-Up -----------------------------------------------------------

/// Portrait side view, k = 350 px/m, floor y = 1150, wall toward smaller X at
/// x = 100. Feet 1.0 m from the wall (arm's length + 35 cm, the setup copy),
/// flat (heel 0.03 m, toe 0.01 m up), ankle 0.08 m up. The body is a rigid
/// line ankle-hip-shoulder (ankle-to-shoulder 1.37 m, shoulder-hip 0.50 m)
/// pivoting at the ankle. Hands on the wall at 1.39 m (shoulder height at the
/// top). Upper arm 0.30 m, forearm 0.27 m, elbows tucked (the elbow drops
/// below the shoulder-wrist line in the side view). [elbow] is the interior
/// elbow angle.
_Pose _wallPushUp(double elbow, {required bool leftNear}) {
  const k = 350.0, floor = 1150.0;
  const ankle = (100.0 + 1.0 * k, floor - 0.08 * k);
  const wrist = (100.0 + 0.02 * k, floor - 1.39 * k);
  const a = 0.30, b = 0.27;
  final d = math.sqrt(a * a + b * b - 2 * a * b * math.cos(_rad(elbow))) * k;
  _P shoulderAt(double t) => _add(
      ankle, (-1.37 * k * math.cos(_rad(t)), -1.37 * k * math.sin(_rad(t))));
  var lo = 30.0, hi = 89.0;
  for (var i = 0; i < 60; i++) {
    final m = (lo + hi) / 2;
    if (_len(_sub(shoulderAt(m), wrist)) > d) {
      hi = m;
    } else {
      lo = m;
    }
  }
  final t = (lo + hi) / 2;
  final shoulder = shoulderAt(t);
  final v = _sub(wrist, shoulder);
  final vl = _len(v);
  final angA = math.asin((b * k) * math.sin(_rad(elbow)) / vl);
  _P rot(_P p, double ang) => (p.$1 * math.cos(ang) - p.$2 * math.sin(ang),
      p.$1 * math.sin(ang) + p.$2 * math.cos(ang));
  final e1 = _add(shoulder, _scale(rot(v, angA), a * k / vl));
  final e2 = _add(shoulder, _scale(rot(v, -angA), a * k / vl));
  final elbowP = e1.$2 > e2.$2 ? e1 : e2; // the lower one: tucked
  final line = (-math.cos(_rad(t)), -math.sin(_rad(t)));
  final hip = _add(ankle, _scale(line, 0.87 * k));
  final ear = _add(_add(shoulder, _scale(line, 0.12 * k)), (-0.03 * k, 0));
  return _side(
    near: {
      'shoulder': shoulder,
      'elbow': elbowP,
      'wrist': wrist,
      'hip': hip,
      'knee': _add(ankle, _scale(line, 0.45 * k)),
      'ankle': ankle,
      'heel': _add(ankle, (0.06 * k, 0.05 * k)),
      'foot': _add(ankle, (-0.15 * k, 0.07 * k)),
      'ear': ear,
    },
    nose: _add(ear, (-0.08 * k, 0.02 * k)),
    leftNear: leftNear,
    mirrorAbout: 360,
  );
}

// --- Bird Dog ---------------------------------------------------------------

/// Landscape side view, k = 300 px/m, floor y = 640, head toward smaller X.
/// Quadruped: shoulder 0.62 m above the floor with the wrist under it, hip
/// 0.58 m up and 0.50 m behind the shoulder, knee on the floor under the hip,
/// ankle 0.40 m behind the knee. Extended leg: straight (0.88 m hip-to-ankle),
/// 5 deg below horizontal. Extended arm: straight (0.60 m), 5 deg below
/// horizontal. [farDy] is the image offset of every far-side landmark (a
/// side view puts left and right almost on top of each other; the sign of
/// the small offset depends on the camera height).
_Pose _birdDog({
  required bool leftNear,
  double nearLeg = 0,
  double farLeg = 0,
  double nearArm = 0,
  double farArm = 0,
  required double farDy,
}) {
  const k = 300.0, floor = 640.0;
  const shoulder = (400.0, floor - 0.62 * k);
  const hip = (400.0 + 0.50 * k, floor - 0.58 * k);
  final legDir = (math.cos(_rad(5)), math.sin(_rad(5)));
  final armDir = (-math.cos(_rad(5)), math.sin(_rad(5)));
  Map<String, _P> side(double leg, double arm, double dy) {
    final knee0 = (hip.$1, floor - 0.05 * k);
    final ankle0 = (hip.$1 + 0.40 * k, floor - 0.06 * k);
    final wrist0 = (shoulder.$1, floor - 0.03 * k);
    final knee = _add(knee0,
        _scale(_sub(_add(hip, _scale(legDir, 0.45 * k)), knee0), leg));
    final ankle = _add(ankle0,
        _scale(_sub(_add(hip, _scale(legDir, 0.88 * k)), ankle0), leg));
    final wrist = _add(wrist0,
        _scale(_sub(_add(shoulder, _scale(armDir, 0.60 * k)), wrist0), arm));
    final m = <String, _P>{
      'ear': (shoulder.$1 - 0.16 * k, floor - 0.67 * k),
      'shoulder': shoulder,
      'elbow': _mid(shoulder, wrist),
      'wrist': wrist,
      'hip': hip,
      'knee': knee,
      'ankle': ankle,
    };
    return m.map((key, p) => MapEntry(key, (p.$1, p.$2 + dy)));
  }

  return _side(
    near: side(nearLeg, nearArm, 0),
    far: side(farLeg, farArm, farDy),
    nose: (shoulder.$1 - 0.22 * k, floor - 0.63 * k),
    leftNear: leftNear,
    mirrorAbout: 640,
  );
}

// --- Superman ---------------------------------------------------------------

/// Landscape side view, k = 300 px/m, floor y = 640, head toward smaller X.
/// Prone: shoulder joint 0.12 m and hip joint 0.11 m above the floor, torso
/// 0.50 m, arms straight overhead (0.60 m) with the wrists on the floor, legs
/// straight (0.88 m) with the ankles 0.07 m up, face down. [s] = 1: chest up
/// (shoulder 0.22 m), arms 12 deg above horizontal (wrist about 0.12 m above
/// the shoulder), legs 10 deg above horizontal (ankle about 0.15 m above the
/// hip).
_Pose _superman(double s, {required bool leftNear}) {
  const k = 300.0, floor = 640.0;
  final shoulder = (400.0, floor - _lerp(0.12, 0.22, s) * k);
  const hip = (400.0 + 0.50 * k, floor - 0.11 * k);
  final armUp = _rad(_lerp(-8.6, 12, s)); // -8.6: wrist on the floor
  final legUp = _rad(_lerp(-2.6, 10, s)); // -2.6: ankle 0.07 m up
  final wrist = _add(shoulder,
      (-0.60 * k * math.cos(armUp), -0.60 * k * math.sin(armUp)));
  final ankle =
      _add(hip, (0.88 * k * math.cos(legUp), -0.88 * k * math.sin(legUp)));
  final ear = _add(shoulder, (-0.15 * k, -0.08 * k));
  return _side(
    near: {
      'ear': ear,
      'shoulder': shoulder,
      'elbow': _mid(shoulder, wrist),
      'wrist': wrist,
      'hip': hip,
      'knee': _mid(hip, ankle),
      'ankle': ankle,
      'heel': _add(ankle, (0.03 * k, -0.05 * k)),
      'foot': _add(ankle, (0.08 * k, 0.06 * k)),
    },
    nose: _add(ear, (-0.07 * k, 0.04 * k)),
    leftNear: leftNear,
    mirrorAbout: 640,
  );
}

// --- Dead Bug ---------------------------------------------------------------

/// Landscape side view, k = 300 px/m, floor y = 640, head toward smaller X.
/// Supine: shoulder joint 0.08 m and hip joint 0.10 m above the floor, torso
/// 0.48 m. Rest: arms straight up (hip-shoulder-wrist 90), thighs vertical
/// (shoulder-hip-knee 90), knees bent 90 (shins level). [nearX] / [farX] in
/// 0..1 extend the camera-side / far-side arm and the opposite leg: arm and
/// hip angles 90 -> 155 (limbs about 25 deg above the floor), knee flexion
/// 90 -> 10.
_Pose _deadBug({double nearX = 0, double farX = 0, required bool leftNear}) {
  const k = 300.0, floor = 640.0;
  const shoulder = (400.0, floor - 0.08 * k);
  const hip = (400.0 + 0.48 * k, floor - 0.10 * k);
  Map<String, _P> side(double arm, double leg) {
    final alpha = _lerp(90, 155, arm), beta = _lerp(90, 155, leg);
    final flex = _lerp(90, 10, leg);
    final armAng = _rad(-alpha), thighAng = _rad(beta - 180);
    final shinAng = thighAng + _rad(flex);
    final wrist = _add(
        shoulder, (0.60 * k * math.cos(armAng), 0.60 * k * math.sin(armAng)));
    final knee = _add(
        hip, (0.45 * k * math.cos(thighAng), 0.45 * k * math.sin(thighAng)));
    final ankle = _add(
        knee, (0.43 * k * math.cos(shinAng), 0.43 * k * math.sin(shinAng)));
    return {
      'shoulder': shoulder,
      'elbow': _mid(shoulder, wrist),
      'wrist': wrist,
      'hip': hip,
      'knee': knee,
      'ankle': ankle,
    };
  }

  // nearX moves the near arm and the far leg; farX the far arm and near leg.
  final near = side(nearX, farX);
  final far = side(farX, nearX);
  return _side(near: near, far: far, leftNear: leftNear, mirrorAbout: 640);
}

// --- V-Up, McGill Curl-Up, Tricep Dip (added by fix batch B) ----------------

/// Landscape side view, k = 300 px/m, floor y = 640, head toward smaller X.
/// Supine; the hip joint stays 0.10 m above the floor (a V-up balances on the
/// buttocks). Torso 0.50 m, straight leg hip-to-ankle 0.88 m (knee half way),
/// straight arm shoulder-to-wrist 0.57 m. [s] = 0: torso, legs and arms flat,
/// arms overhead in line with the torso. [s] = 1: torso and legs each 50 deg
/// above horizontal (shoulder-hip-ankle 80 deg), arms pointing at the ankles.
/// The arm swings up over the head on the way (never through the floor).
_Pose _vUp(double s, {required bool leftNear}) {
  const k = 300.0, floor = 640.0;
  const hip = (700.0, floor - 0.10 * k);
  final t = _rad(50 * s);
  final shoulder =
      (hip.$1 - 0.50 * k * math.cos(t), hip.$2 - 0.50 * k * math.sin(t));
  final ankle =
      (hip.$1 + 0.88 * k * math.cos(t), hip.$2 - 0.88 * k * math.sin(t));
  final toAnkle = math.atan2(ankle.$2 - shoulder.$2, ankle.$1 - shoulder.$1);
  final a = _lerp(-math.pi, toAnkle, s);
  final wrist =
      _add(shoulder, (0.57 * k * math.cos(a), 0.57 * k * math.sin(a)));
  return _side(
    near: {
      'ear': _add(shoulder, _scale(_sub(shoulder, hip), 0.30)),
      'shoulder': shoulder,
      'elbow': _mid(shoulder, wrist),
      'wrist': wrist,
      'hip': hip,
      'knee': _mid(hip, ankle),
      'ankle': ankle,
    },
    leftNear: leftNear,
    mirrorAbout: 640,
  );
}

/// Landscape side view, k = 300 px/m, floor y = 640, head toward smaller X.
/// McGill curl-up: supine, hip joint 0.10 m up, torso 0.50 m; ear 0.16 m
/// beyond the shoulder along the torso line and 0.03 m higher (head neutral,
/// moving with the torso). Camera-side knee bent: thigh 0.45 m rising 45 deg,
/// shin 0.43 m down to the ankle 0.08 m up. Far leg straight on the floor
/// (knee and ankle 0.08 m up). Hands under the lower back. [theta] lifts head
/// and shoulders as one piece, rotating the hip-shoulder line about the hip
/// (10 deg lifts the shoulder joint about 9 cm).
_Pose _curlUp(double theta, {required bool leftNear}) {
  const k = 300.0, floor = 640.0;
  const hip = (700.0, floor - 0.10 * k);
  final t = _rad(theta);
  final dir = (-math.cos(t), -math.sin(t));
  final shoulder = _add(hip, _scale(dir, 0.50 * k));
  final ear = _add(_add(shoulder, _scale(dir, 0.16 * k)),
      _scale((dir.$2, -dir.$1), 0.03 * k));
  final knee = _add(
      hip, (0.45 * k * math.cos(_rad(45)), -0.45 * k * math.sin(_rad(45))));
  final ankleX = knee.$1 +
      math.sqrt(math.pow(0.43 * k, 2) -
          math.pow(floor - 0.08 * k - knee.$2, 2));
  final upper = <String, _P>{
    'ear': ear,
    'shoulder': shoulder,
    'elbow': _add(hip, (-0.05 * k, 0.05 * k)),
    'wrist': _add(hip, (-0.10 * k, 0.07 * k)),
    'hip': hip,
  };
  return _side(
    near: {...upper, 'knee': knee, 'ankle': (ankleX, floor - 0.08 * k)},
    far: {
      ...upper,
      'knee': (hip.$1 + 0.45 * k, floor - 0.08 * k),
      'ankle': (hip.$1 + 0.88 * k, floor - 0.08 * k),
    },
    leftNear: leftNear,
    mirrorAbout: 640,
  );
}

/// Landscape side view, k = 300 px/m, floor y = 640, head toward smaller X.
/// Floor tricep dip: seated, hip joint 0.10 m up; torso 0.50 m leaning back
/// 20 deg from vertical; hands on the floor 0.30 m behind the hip (wrist
/// 0.02 m up), feet flat 0.55 m in front of the hip (ankle 0.08 m up), knees
/// bent. [lift] raises the hips by that many metres; the torso goes up with
/// them, elbows and knees by half; hands and feet stay on the floor.
_Pose _tricepDip(double lift, {required bool leftNear}) {
  const k = 300.0, floor = 640.0;
  final h = lift * k;
  final hip = (700.0, floor - 0.10 * k - h);
  final shoulder = _add(
      hip, (-0.50 * k * math.sin(_rad(20)), -0.50 * k * math.cos(_rad(20))));
  final wrist = (hip.$1 - 0.30 * k, floor - 0.02 * k);
  final ankle = (hip.$1 + 0.55 * k, floor - 0.08 * k);
  final elbow = _mid(shoulder, wrist);
  return _side(
    near: {
      'ear': _add(shoulder, (0.04 * k, -0.17 * k)),
      'shoulder': shoulder,
      'elbow': (elbow.$1 - 0.03 * k, elbow.$2),
      'wrist': wrist,
      'hip': hip,
      'knee': (hip.$1 + 0.38 * k, floor - 0.45 * k - h / 2),
      'ankle': ankle,
    },
    leftNear: leftNear,
    mirrorAbout: 640,
  );
}

_Pose _tricepDipBent(double lift, {required bool leftNear}) {
  const k = 300.0, floor = 640.0, arm = 0.36 * k;
  final h = lift * k;
  final hip = (700.0, floor - 0.10 * k - h);
  final shoulder = _add(
      hip, (-0.50 * k * math.sin(_rad(20)), -0.50 * k * math.cos(_rad(20))));
  final wrist = (hip.$1 - 0.30 * k, floor - 0.02 * k);
  final reach = _sub(shoulder, wrist);
  final d = math.sqrt(reach.$1 * reach.$1 + reach.$2 * reach.$2);
  final bend = math.sqrt(arm * arm - d * d / 4);
  final mid = _mid(shoulder, wrist);
  final elbow = (mid.$1 + bend * reach.$2 / d, mid.$2 - bend * reach.$1 / d);
  return _side(
    near: {
      'ear': _add(shoulder, (0.04 * k, -0.17 * k)),
      'shoulder': shoulder,
      'elbow': elbow,
      'wrist': wrist,
      'hip': hip,
      'knee': (hip.$1 + 0.38 * k, floor - 0.45 * k - h / 2),
      'ankle': (hip.$1 + 0.55 * k, floor - 0.08 * k),
    },
    leftNear: leftNear,
    mirrorAbout: 640,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final leftNear in [true, false]) {
    final side = leftNear ? 'left' : 'right';

    test('PROBE mountain climber slow ($side): four slow drives (1.2 s each, '
        'alternating legs) count four', () {
      final r = _Run(MountainClimber(maxRep: 30));
      r.activate(_climber(leftNear: leftNear));
      r.hold(_climber(leftNear: leftNear), 6);
      for (var i = 0; i < 2; i++) {
        for (final near in [true, false]) {
          for (var f = 1; f <= 36; f++) {
            final s = math.pow(math.sin(math.pi * f / 36), 2).toDouble();
            r.frame(_climber(
                nearDrive: near ? s : 0,
                farDrive: near ? 0 : s,
                leftNear: leftNear));
          }
        }
      }
      r.hold(_climber(leftNear: leftNear), 6);
      expect(r.e.repCount, 4,
          reason: 'KneePeakRepCounter enters and exits its zone on the same '
              'frame when the knee angle is 145-150 and the knee is still '
              'far from the shoulder; the real exit then counts again once '
              'the 850 ms same-side cooldown has passed');
    });

    _Run deadBugReps(int reachFrames) {
      final r = _Run(DeadBug(maxRep: 10));
      r.activate(_deadBug(leftNear: leftNear));
      r.hold(_deadBug(leftNear: leftNear), 10);
      for (final near in [true, false]) {
        _Pose at(double s) => _deadBug(
            nearX: near ? s : 0, farX: near ? 0 : s, leftNear: leftNear);
        r.ramp(reachFrames, (s) => at(_ease(s)));
        r.hold(at(1), 30);
        r.ramp(45, (s) => at(1 - _ease(s)));
        r.hold(at(0), 10);
      }
      return r;
    }

    test('PROBE dead bug ($side): two alternating clean reps (3.5 s reach, '
        '1 s hold) count two with no fault', () {
      final r = deadBugReps(105);
      expect(r.skipped, 0);
      expect(r.e.repCount, 2);
      expect(r.faultTypes.expand((t) => t), isEmpty);
    });

    test('PROBE dead bug tempo ($side): a steady 2.5 s reach is not logged as '
        'faster than the 0.8 s target', () {
      final r = deadBugReps(75);
      expect(r.e.repCount, 2, reason: 'fixture precondition');
      final times = [
        for (final l in r.e.logger.repLogs) l.data['extending_time']
      ];
      expect(r.faultTypes.expand((t) => t), isNot(contains('tempo')),
          reason: 'extending_time $times s: the clock runs only while the '
              'pair angle goes 108 -> 138, about half of a 90 -> 155 reach');
    });
  }

  for (final leftNear in [true, false]) {
    final side = leftNear ? 'left' : 'right';

    test('PROBE sit-up ($side): one clean sit-up (1.0 s up, 1.5 s down) '
        'counts once with no fault', () {
      final r = _Run(SitUp(maxRep: 10));
      r.activate(_sitUp(0, leftNear: leftNear));
      r.hold(_sitUp(0, leftNear: leftNear), 10);
      r.ramp(30, (s) => _sitUp(80 * _ease(s), leftNear: leftNear));
      r.hold(_sitUp(80, leftNear: leftNear), 10);
      r.ramp(45, (s) => _sitUp(80 * (1 - _ease(s)), leftNear: leftNear));
      r.hold(_sitUp(0, leftNear: leftNear), 10);
      expect(r.skipped, 0);
      expect(r.e.repCount, 1);
      expect(r.faultTypes.single, isEmpty);
    });

    test('PROBE lunge ($side): a clean reverse lunge counts once with no '
        'fault', () {
      final r = _Run(Lunge(maxRep: 10));
      // With the feet together the ankles share an X, so Lunge settles on
      // the right label as lead in both facings; the left leg steps back.
      final leadIsNear = !leftNear;
      r.activate(_lunge(
          leftNear: leftNear,
          leadIsNear: leadIsNear,
          lp: 0,
          lk: 5,
          tp: 0,
          tk: 5,
          lean: 5));
      _reverseLunge(r, leftNear: leftNear, leadIsNear: leadIsNear);
      expect(r.skipped, 0);
      expect(r.e.repCount, 1);
      expect(r.faultTypes.single, isEmpty);
    });

    test('PROBE lunge step ($side): stepping back with the leg Lunge holds as '
        'lead, knee flexing to 113 deg mid-swing, still counts one rep', () {
      final r = _Run(Lunge(maxRep: 10));
      final leadIsNear = leftNear; // the right label steps back
      r.activate(_lunge(
          leftNear: leftNear,
          leadIsNear: leadIsNear,
          lp: 0,
          lk: 5,
          tp: 0,
          tk: 5,
          lean: 5));
      _reverseLunge(r,
          leftNear: leftNear, leadIsNear: leadIsNear, swingFlex: 55);
      expect(r.e.repCount, 1,
          reason: 'the swing of the stepping leg goes descending -> bottom -> '
              'ascending -> standing on the leg Lunge currently treats as '
              'lead (no debounce, lead locked at the first frame < 145)');
    });

    test('PROBE leg raise ($side): a straight-leg raise lowered over a full '
        '2.0 s logs no tempo fault', () {
      final r = _Run(LegRaise(maxRep: 10));
      r.activate(_legRaise(-2.6, leftNear: leftNear));
      r.hold(_legRaise(-2.6, leftNear: leftNear), 10);
      r.ramp(36, (s) => _legRaise(_lerp(-2.6, 90, _ease(s)), leftNear: leftNear));
      r.hold(_legRaise(90, leftNear: leftNear), 9);
      r.ramp(60, (s) => _legRaise(_lerp(90, -2.6, _ease(s)), leftNear: leftNear));
      r.hold(_legRaise(-2.6, leftNear: leftNear), 10);
      expect(r.e.repCount, 1, reason: 'fixture precondition');
      final log = r.e.logger.repLogs.single;
      expect(r.faultTypes.single, isEmpty,
          reason: 'lowering_time ${log.data['lowering_time']} s: the clock '
              'runs only from lowering (hip > 145) to lying (hip > 150), '
              'i.e. while the legs pass 35 -> 30 deg above the floor');
    });

    test('PROBE jump squat ($side): one clean jump squat counts once with no '
        'fault', () {
      final r = _Run(JumpSquat(maxRep: 10));
      r.activate(_jumpSquat(175, leftNear: leftNear));
      r.hold(_jumpSquat(175, leftNear: leftNear), 15);
      r.ramp(12, (s) => _jumpSquat(175 - 80 * _ease(s), leftNear: leftNear));
      r.hold(_jumpSquat(95, leftNear: leftNear), 2);
      _jumpFromBottom(r, leftNear: leftNear);
      r.ramp(15, (s) => _jumpSquat(100 + 75 * _ease(s), leftNear: leftNear));
      r.hold(_jumpSquat(175, leftNear: leftNear), 15);
      expect(r.skipped, 0);
      expect(r.e.repCount, 1);
      expect(r.faultTypes.single, isEmpty);
    });

    test('PROBE jump squat rebound ($side): two jumps linked without standing '
        'up in between count two', () {
      final r = _Run(JumpSquat(maxRep: 10));
      r.activate(_jumpSquat(175, leftNear: leftNear));
      r.hold(_jumpSquat(175, leftNear: leftNear), 15);
      r.ramp(12, (s) => _jumpSquat(175 - 80 * _ease(s), leftNear: leftNear));
      r.hold(_jumpSquat(95, leftNear: leftNear), 2);
      _jumpFromBottom(r, leftNear: leftNear);
      r.hold(_jumpSquat(95, leftNear: leftNear), 2); // straight into jump 2
      _jumpFromBottom(r, leftNear: leftNear);
      r.ramp(15, (s) => _jumpSquat(100 + 75 * _ease(s), leftNear: leftNear));
      r.hold(_jumpSquat(175, leftNear: leftNear), 15);
      expect(r.e.repCount, 2,
          reason: 'from landing the only exit is standing (knee > 150, hip '
              'not rising, feet down); a jump taken from landing is not a '
              'new attempt');
    });

    test('PROBE mountain climber ($side): eight alternating clean knee drives '
        'count eight and log no trunk fault', () {
      final r = _Run(MountainClimber(maxRep: 30));
      r.activate(_climber(leftNear: leftNear));
      r.hold(_climber(leftNear: leftNear), 6);
      for (var i = 0; i < 4; i++) {
        for (final near in [true, false]) {
          for (var f = 1; f <= 18; f++) {
            final s = math.pow(math.sin(math.pi * f / 18), 2).toDouble();
            r.frame(_climber(
                nearDrive: near ? s : 0,
                farDrive: near ? 0 : s,
                leftNear: leftNear));
          }
        }
      }
      r.hold(_climber(leftNear: leftNear), 6);
      expect(r.skipped, 0);
      expect(r.e.repCount, 8, reason: 'fixture precondition');
      final faulted = r.e.logger.repLogs
          .where((l) => (l.data['fault_types'] as List).isNotEmpty)
          .map((l) => '${l.data['side']}:${l.data['fault_types']}')
          .toList();
      expect(faulted, isEmpty,
          reason: 'trunkAngle is shoulder-hip-ankle with the camera-side '
              'ankle, so the camera-side knee drive itself reads as a sag');
    });

    test('mountain climber shallow drive ($side): four drives that bend the '
        'knee to 115 deg but keep it 1.71 scale from the shoulder (quality '
        'limit 1.42) count four, each logged with rom', () {
      final r = _Run(MountainClimber(maxRep: 30));
      r.activate(_climber(leftNear: leftNear));
      r.hold(_climber(leftNear: leftNear), 6);
      for (var i = 0; i < 2; i++) {
        for (final near in [true, false]) {
          for (var f = 1; f <= 18; f++) {
            final s = 0.5 * math.pow(math.sin(math.pi * f / 18), 2).toDouble();
            r.frame(_climber(
                nearDrive: near ? s : 0,
                farDrive: near ? 0 : s,
                leftNear: leftNear));
          }
        }
      }
      r.hold(_climber(leftNear: leftNear), 6);
      expect(r.e.repCount, 4);
      expect(r.faultTypes, everyElement(contains('rom')));
    });

    test('PROBE wall push-up ($side): one clean rep with flat heels and tucked '
        'elbows (1.2 s down, 1.0 s up) counts once with no fault', () {
      final r = _Run(WallPushUp(maxRep: 10));
      r.activate(_wallPushUp(175, leftNear: leftNear));
      r.hold(_wallPushUp(175, leftNear: leftNear), 10);
      r.ramp(36, (s) => _wallPushUp(175 - 85 * _ease(s), leftNear: leftNear));
      r.hold(_wallPushUp(90, leftNear: leftNear), 3);
      r.ramp(30, (s) => _wallPushUp(90 + 85 * _ease(s), leftNear: leftNear));
      r.hold(_wallPushUp(175, leftNear: leftNear), 10);
      expect(r.skipped, 0);
      expect(r.e.repCount, 1, reason: 'fixture precondition');
      expect(r.faultTypes.single, isEmpty,
          reason: 'elbow flare is hip-shoulder-elbow; with the body leaning '
              '65-72 deg and the hands at shoulder height, tucked elbows '
              'read above 65 (warning) and above 82 (error) early in the '
              'descent');
    });

    for (final farDy in [-8.0, 8.0]) {
      test('PROBE bird dog ($side, far side ${farDy > 0 ? 'below' : 'above'} '
          'near by 8 px): two alternating 2 s holds count two', () {
        final r = _Run(BirdDog(maxRep: 10));
        _Pose p(
                {double nl = 0, double fl = 0, double na = 0, double fa = 0}) =>
            _birdDog(
                leftNear: leftNear,
                nearLeg: nl,
                farLeg: fl,
                nearArm: na,
                farArm: fa,
                farDy: farDy);
        r.activate(p());
        r.hold(p(), 10);
        r.ramp(10, (s) => p(nl: s, fa: s)); // near leg + far arm
        r.hold(p(nl: 1, fa: 1), 60);
        r.ramp(10, (s) => p(nl: 1 - s, fa: 1 - s));
        r.hold(p(), 10);
        r.ramp(10, (s) => p(fl: s, na: s)); // far leg + near arm
        r.hold(p(fl: 1, na: 1), 60);
        r.ramp(10, (s) => p(fl: 1 - s, na: 1 - s));
        r.hold(p(), 10);
        final dog = r.e as BirdDog;
        expect(dog.repCount, 2,
            reason: 'rejected attempts: ${dog.invalidAttemptCount}; the side '
                'of the moving limb comes from a 2D dot product with the '
                'left-right hip (shoulder) axis, which a side view makes '
                'a few pixels long');
      });
    }

    test('PROBE superman ($side): one clean lift held 1.7 s counts once with '
        'no fault', () {
      final r = _Run(Superman(maxRep: 10));
      r.activate(_superman(0, leftNear: leftNear));
      r.hold(_superman(0, leftNear: leftNear), 10);
      r.ramp(15, (s) => _superman(_ease(s), leftNear: leftNear));
      r.hold(_superman(1, leftNear: leftNear), 50);
      r.ramp(15, (s) => _superman(1 - _ease(s), leftNear: leftNear));
      r.hold(_superman(0, leftNear: leftNear), 10);
      expect(r.skipped, 0);
      expect(r.e.repCount, 1);
      expect(r.faultTypes.single, isEmpty);
    });
  }

  test('PROBE jumping jack: three wide jacks count three with no fault',
      () {
    final r = _Run(JumpingJack(maxRep: 10));
    r.activate(_jack(0));
    for (var rep = 0; rep < 3; rep++) {
      r.hold(_jack(0), 6);
      r.ramp(8, (s) => _jack(_ease(s)));
      r.hold(_jack(1), 3);
      r.ramp(8, (s) => _jack(1 - _ease(s)));
      r.hold(_jack(0), 4);
    }
    expect(r.skipped, 0);
    expect(r.e.repCount, 3);
    expect(r.faultTypes.expand((t) => t), isEmpty);
  });

  test('PROBE lunge tie: a clean right-side lunge whose z-vote ties (facing '
      'read as left) logs no fault', () {
    final r = _Run(Lunge(maxRep: 10));
    _Pose start() => _lunge(
        leftNear: false,
        leadIsNear: true,
        lp: 0,
        lk: 5,
        tp: 0,
        tk: 5,
        lean: 5,
        zGap: 0);
    r.activate(start());
    expect(r.e.cameraFacing, CameraFacing.left,
        reason: 'fixture precondition: a tied vote reads as left '
            '(exercise_base.dart _isLeftSide)');
    _reverseLunge(r, leftNear: false, leadIsNear: true, zGap: 0);
    expect(r.e.repCount, 1, reason: 'fixture precondition');
    expect(r.faultTypes.single, isEmpty,
        reason: 'lead leg, heel, lumbar and trunk sign all follow '
            'cameraFacing');
  },
      skip: 'Owner decision open: the tied z-vote resolves to left in '
          'exercise_base.dart (_isLeftSide); shared code, not fixed in '
          'fix batch B.');

  // Probes added by fix batch B for the three exercises the review checked by
  // reading only. Nothing these find is fixed in that run.
  for (final leftNear in [true, false]) {
    final side = leftNear ? 'left' : 'right';

    test('PROBE v-up ($side): one clean V-up (1.0 s up, 0.3 s at the top, '
        '1.5 s down) counts once with no fault', () {
      final r = _Run(VUp(maxRep: 10));
      r.activate(_vUp(0, leftNear: leftNear));
      r.hold(_vUp(0, leftNear: leftNear), 10);
      r.ramp(30, (s) => _vUp(_ease(s), leftNear: leftNear));
      r.hold(_vUp(1, leftNear: leftNear), 10);
      r.ramp(45, (s) => _vUp(1 - _ease(s), leftNear: leftNear));
      r.hold(_vUp(0, leftNear: leftNear), 15);
      expect(r.e.repCount, 1);
      expect(r.faultTypes.expand((t) => t), isEmpty,
          reason: 'rep logs: ${r.e.logger.repLogs.map((l) => l.data)}');
    },
        skip: 'Follow-up B: the clock now starts at the rep\'s most closed V '
            '(lowering_time 0.66 -> 0.92 s) but still stops at `lying` '
            '(shoulder-hip-ankle >= 145, about 60% through this eased 1.5 s '
            'descent), so a clean rep still reads under the 1.0 s limit. '
            'Moving the stop or the limit needs a new number; owner decision.');

    test('v-up drop ($side): a V-up lowered in 0.4 s is logged with tempo',
        () {
      final r = _Run(VUp(maxRep: 10));
      r.activate(_vUp(0, leftNear: leftNear));
      r.hold(_vUp(0, leftNear: leftNear), 10);
      r.ramp(30, (s) => _vUp(_ease(s), leftNear: leftNear));
      r.hold(_vUp(1, leftNear: leftNear), 10);
      r.ramp(12, (s) => _vUp(1 - _ease(s), leftNear: leftNear));
      r.hold(_vUp(0, leftNear: leftNear), 15);
      expect(r.e.repCount, 1, reason: 'fixture precondition');
      expect(r.faultTypes.single, contains('tempo'),
          reason: 'lowering_time '
              '${r.e.logger.repLogs.single.data['lowering_time']} s');
    });

    test('PROBE mcgill curl-up ($side): one clean curl-up (10 deg, 1.0 s up, '
        '2 s hold, 1.0 s down) counts once with no fault', () {
      final r = _Run(CurlUp(maxRep: 10));
      r.activate(_curlUp(0, leftNear: leftNear));
      r.hold(_curlUp(0, leftNear: leftNear), 10);
      r.ramp(30, (s) => _curlUp(10 * _ease(s), leftNear: leftNear));
      r.hold(_curlUp(10, leftNear: leftNear), 60);
      r.ramp(30, (s) => _curlUp(10 * (1 - _ease(s)), leftNear: leftNear));
      r.hold(_curlUp(0, leftNear: leftNear), 15);
      expect(r.e.repCount, 1);
      expect(r.faultTypes.expand((t) => t), isEmpty,
          reason: 'rep logs: ${r.e.logger.repLogs.map((l) => l.data)}');
    },
        skip: 'Finding (not fixed): 0 reps. A 10 deg lift over 1.0 s changes '
            'the trunk angle at most about 0.5 deg per 33 ms frame, under '
            'ANGLE_STABLE_GATE (0.8), so every frame reads "stable": the state '
            'never leaves resting and the resting baseline follows the trunk '
            'up. A lift slower than about 24 deg/s is never counted.');

    test('PROBE tricep dip ($side): hips up 0.15 m and back with the arms '
        'kept straight is not a rep', () {
      final r = _Run(TricepDip(maxRep: 10));
      r.activate(_tricepDip(0, leftNear: leftNear));
      r.hold(_tricepDip(0, leftNear: leftNear), 10);
      r.ramp(30, (s) => _tricepDip(0.15 * _ease(s), leftNear: leftNear));
      r.hold(_tricepDip(0.15, leftNear: leftNear), 15);
      r.ramp(
          30, (s) => _tricepDip(0.15 * (1 - _ease(s)), leftNear: leftNear));
      r.hold(_tricepDip(0, leftNear: leftNear), 15);
      expect(r.e.repCount, 0);
    });

    test('PROBE tricep dip ($side): one dip from straight arms (163 deg) down '
        'to 103 deg over 1.0 s and back counts once with no fault', () {
      final r = _Run(TricepDip(maxRep: 10));
      r.activate(_tricepDipBent(0.15, leftNear: leftNear));
      r.hold(_tricepDipBent(0.15, leftNear: leftNear), 10);
      r.ramp(30,
          (s) => _tricepDipBent(0.15 * (1 - _ease(s)), leftNear: leftNear));
      r.hold(_tricepDipBent(0, leftNear: leftNear), 15);
      r.ramp(30, (s) => _tricepDipBent(0.15 * _ease(s), leftNear: leftNear));
      r.hold(_tricepDipBent(0.15, leftNear: leftNear), 15);
      expect(r.e.repCount, 1);
      expect(r.faultTypes.expand((t) => t), isEmpty,
          reason: 'rep logs: ${r.e.logger.repLogs.map((l) => l.data)}');
      expect(r.e.logger.repLogs.single.data['min_elbow_angle'] as double,
          closeTo(103, 3));
    });
  }
}
