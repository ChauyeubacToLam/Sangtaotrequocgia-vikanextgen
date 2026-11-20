import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/plank/metrics/head_neck_metric.dart';
import 'package:vika/exercise/plank/metrics/knee_extension_metric.dart';
import 'package:vika/exercise/plank/metrics/plank_metric_base.dart';
import 'package:vika/exercise/plank/metrics/trunk_alignment_metric.dart';
import 'package:vika/exercise/plank/plank.dart';

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

/// One physical forearm plank seen from the side. In the image MediaPipe
/// labels, the left side nearer the camera (smaller z) puts the head toward
/// smaller X; the right-side-near view is the same body mirrored in X.
Map<PoseLandmarkType, PoseLandmark> _plank({
  required bool leftNear,
  double hipDrop = 0, // + = hips lower (sag), - = hips higher (pike)
  double earDrop = 0, // + = ear lower (head dropped), - = lifted
  double likelihood = 0.99,
}) {
  const y = 220.0;
  final points = <String, (double, double)>{
    'ear': (270, y + earDrop),
    'shoulder': (300, y),
    'elbow': (300, 280),
    'wrist': (230, 280),
    'hip': (400, y + hipDrop),
    'knee': (500, y + hipDrop / 2),
    'ankle': (600, y),
    'heel': (620, y),
    'foot': (620, y),
  };
  final pose = <PoseLandmarkType, PoseLandmark>{};
  for (final entry in points.entries) {
    final (left, right) = _pairs[entry.key]!;
    final (px, py) = entry.value;
    final x = leftNear ? px : 1000 - px;
    pose[left] = PoseLandmark(
        type: left, x: x, y: py, z: leftNear ? -0.1 : 0.1,
        likelihood: likelihood);
    pose[right] = PoseLandmark(
        type: right, x: x, y: py, z: leftNear ? 0.1 : -0.1,
        likelihood: likelihood);
  }
  return pose;
}

Plank _activePlank({required bool leftNear, int maxRep = 3}) {
  final plank = Plank(maxRep: maxRep)..exerciseState = ExerciseState.activated;
  var facing = CameraFacing.undefined;
  // The left/right debouncer needs 5 consistent frames to flip.
  for (var i = 0; i < 5; i++) {
    facing = plank.detectCameraFacing(_plank(leftNear: leftNear));
  }
  expect(facing, leftNear ? CameraFacing.left : CameraFacing.right);
  return plank..cameraFacing = facing;
}

void _pump(Plank plank, Map<PoseLandmarkType, PoseLandmark> pose, int ms) {
  plank.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms);
  plank.checkingPose(pose);
}

void _hold(Plank plank, Map<PoseLandmarkType, PoseLandmark> pose,
    {required int fromMs, required int toMs}) {
  for (var t = fromMs; t <= toMs; t += 100) {
    _pump(plank, pose, t);
  }
}

List<String> _messages(PlankMetricBase metric) =>
    metric.faults.map((f) => f.message).toList();

RepContext _ctx({double trunk = 0, double neck = 180, double knee = 180}) =>
    RepContext(
      trunkDeviation: trunk,
      neckAngle: neck,
      kneeAngle: knee,
      plankState: PlankState.holding,
      frameTimestamp: 0,
      resultIssues: ResultIssues(),
    );

List<String> _after(PlankMetricBase metric, RepContext ctx, int frames) {
  for (var i = 0; i < frames; i++) {
    metric.update(ctx);
  }
  return _messages(metric);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('same physical posture, both camera facings', () {
    for (final leftNear in [true, false]) {
      final side = leftNear ? 'left' : 'right';

      test('level plank reads ~0 deg and holds ($side)', () {
        final plank = _activePlank(leftNear: leftNear);
        _hold(plank, _plank(leftNear: leftNear), fromMs: 0, toMs: 1000);
        expect(plank.plankState, PlankState.holding);
        expect(plank.trunkAlignmentMetric.faults, isEmpty);
      });

      test('sagging hips log sag, not pike ($side)', () {
        final plank = _activePlank(leftNear: leftNear);
        _hold(plank, _plank(leftNear: leftNear, hipDrop: 16),
            fromMs: 0, toMs: 1000);
        expect(_messages(plank.trunkAlignmentMetric), ['Hông hơi chùng']);
      });

      test('piked hips log pike, not sag ($side)', () {
        final plank = _activePlank(leftNear: leftNear);
        _hold(plank, _plank(leftNear: leftNear, hipDrop: -10),
            fromMs: 0, toMs: 1000);
        expect(_messages(plank.trunkAlignmentMetric), ['Hông hơi cao']);
      });

      test('dropped head logs drop ($side)', () {
        final plank = _activePlank(leftNear: leftNear);
        _hold(plank, _plank(leftNear: leftNear, earDrop: 15),
            fromMs: 0, toMs: 1500);
        expect(_messages(plank.headNeckMetric), ['Đầu hơi cúi']);
      });

      test('lifted head logs lift ($side)', () {
        final plank = _activePlank(leftNear: leftNear);
        _hold(plank, _plank(leftNear: leftNear, earDrop: -15),
            fromMs: 0, toMs: 1500);
        expect(_messages(plank.headNeckMetric), ['Đầu hơi ngẩng']);
      });
    }
  });

  group('hold time', () {
    test('total_seconds is the time actually held, not maxRep x 15', () {
      final plank = _activePlank(leftNear: true);
      _hold(plank, _plank(leftNear: true), fromMs: 0, toMs: 4000);
      // Unconfident landmarks: geometry fails and the hold breaks.
      _pump(plank, _plank(leftNear: true, likelihood: 0.1), 4100);
      expect(plank.plankState, PlankState.setup);

      plank.onSetComplete();
      // Hold confirmed at 100 ms, last evaluated holding frame at 4000 ms.
      expect(plank.logger.setLogs['total_seconds'] as num, closeTo(3.9, 1e-9));
    });

    test('frames skipped by checkSafety do not count toward the 15 s hold',
        () {
      final plank = _activePlank(leftNear: true);
      _hold(plank, _plank(leftNear: true), fromMs: 0, toMs: 1000);

      // 3 s of low-confidence frames: checkSafety returns a signal, so the
      // base class never calls checkingPose for them.
      final dim = _plank(leftNear: true, likelihood: 0.5);
      for (var t = 1100; t <= 4000; t += 100) {
        plank.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(t);
        expect(plank.checkSafety(dim), isNotNull);
      }

      _hold(plank, _plank(leftNear: true), fromMs: 4100, toMs: 16000);
      expect(plank.repCount, 0, reason: 'only ~12.8 s evaluated so far');
      expect(plank.plankState, PlankState.holding);

      _hold(plank, _plank(leftNear: true), fromMs: 16100, toMs: 18300);
      expect(plank.repCount, 1);
    });

    test('a presence-gate pause does not count toward the hold', () {
      final plank = _activePlank(leftNear: true);
      _hold(plank, _plank(leftNear: true), fromMs: 0, toMs: 1000);
      plank.onPauseReactivationStarted();
      _hold(plank, _plank(leftNear: true), fromMs: 11000, toMs: 15000);
      expect(plank.repCount, 0);
      expect(plank.liveHoldSeconds, closeTo(4.9, 1e-9));
    });
  });

  group('TrunkAlignmentMetric', () {
    test('sag and pike bands', () {
      expect(_after(TrunkAlignmentMetric(), _ctx(trunk: 7.9), 10), isEmpty);
      expect(_after(TrunkAlignmentMetric(), _ctx(trunk: 9), 10),
          ['Hông hơi chùng']);
      expect(_after(TrunkAlignmentMetric(), _ctx(trunk: 13), 10),
          ['Hông chùng quá mức']);
      expect(_after(TrunkAlignmentMetric(), _ctx(trunk: -3.9), 10), isEmpty);
      expect(_after(TrunkAlignmentMetric(), _ctx(trunk: -5), 10),
          ['Hông hơi cao']);
      expect(_after(TrunkAlignmentMetric(), _ctx(trunk: -9), 10),
          ['Hông quá cao']);
    });

    test('needs 5 consecutive frames', () {
      expect(_after(TrunkAlignmentMetric(), _ctx(trunk: 13), 4), isEmpty);
      expect(_after(TrunkAlignmentMetric(), _ctx(trunk: 13), 5), isNotEmpty);
    });

    test('affects form only above 45% fault time', () {
      final heavy = TrunkAlignmentMetric();
      _after(heavy, _ctx(trunk: 13), 20); // 16 of 20 frames debounced
      heavy.finalizeHold();
      expect(heavy.faults.single.affectsForm, isTrue);

      final light = TrunkAlignmentMetric();
      _after(light, _ctx(trunk: 13), 6); // 2 of 20 frames debounced
      _after(light, _ctx(), 14);
      light.finalizeHold();
      expect(light.faults.single.affectsForm, isFalse);
    });
  });

  group('HeadNeckMetric', () {
    test('drop and lift bands', () {
      expect(_after(HeadNeckMetric(), _ctx(neck: 166), 10), isEmpty);
      expect(_after(HeadNeckMetric(), _ctx(neck: 160), 10), ['Đầu hơi cúi']);
      expect(_after(HeadNeckMetric(), _ctx(neck: 145), 10),
          ['Cúi đầu quá mức']);
      expect(_after(HeadNeckMetric(), _ctx(neck: 194), 10), isEmpty);
      expect(_after(HeadNeckMetric(), _ctx(neck: 200), 10), ['Đầu hơi ngẩng']);
      expect(_after(HeadNeckMetric(), _ctx(neck: 215), 10),
          ['Ngẩng đầu quá mức']);
    });

    test('needs 8 consecutive frames', () {
      expect(_after(HeadNeckMetric(), _ctx(neck: 145), 7), isEmpty);
      expect(_after(HeadNeckMetric(), _ctx(neck: 145), 8), isNotEmpty);
    });
  });

  group('KneeExtensionMetric', () {
    test('warning and error bands', () {
      expect(_after(KneeExtensionMetric(), _ctx(knee: 158), 10), isEmpty);
      expect(_after(KneeExtensionMetric(), _ctx(knee: 150), 10),
          ['Đầu gối hơi gập']);
      expect(_after(KneeExtensionMetric(), _ctx(knee: 140), 10),
          ['Đầu gối gập quá nhiều']);
    });

    test('needs 8 consecutive frames', () {
      expect(_after(KneeExtensionMetric(), _ctx(knee: 140), 7), isEmpty);
      expect(_after(KneeExtensionMetric(), _ctx(knee: 140), 8), isNotEmpty);
    });
  });
}
