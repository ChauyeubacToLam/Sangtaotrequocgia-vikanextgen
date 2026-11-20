import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/curl_up/curl_up.dart';
import 'package:vika/exercise/exercise_base.dart';

PoseLandmark _lm(PoseLandmarkType type, double x, double y) =>
    PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.99);

/// Same layout as curl_up_orientation_test (facing right, hip at (200,100)),
/// with the trunk raised [trunkDeg] above horizontal and the ankle placed so
/// the knee angle is [kneeDeg].
Map<PoseLandmarkType, PoseLandmark> _pose(double trunkDeg,
    {double kneeDeg = 90}) {
  final t = trunkDeg * math.pi / 180;
  final k = kneeDeg * math.pi / 180;
  return {
    PoseLandmarkType.rightEar:
        _lm(PoseLandmarkType.rightEar, 200 - 120 * math.cos(t), 100 - 120 * math.sin(t)),
    PoseLandmarkType.rightShoulder:
        _lm(PoseLandmarkType.rightShoulder, 200 - 100 * math.cos(t), 100 - 100 * math.sin(t)),
    PoseLandmarkType.rightHip: _lm(PoseLandmarkType.rightHip, 200, 100),
    PoseLandmarkType.rightKnee: _lm(PoseLandmarkType.rightKnee, 200, 50),
    PoseLandmarkType.rightAnkle: _lm(PoseLandmarkType.rightAnkle,
        200 + 50 * math.sin(k), 50 + 50 * math.cos(k)),
  };
}

CurlUp _active(Map<PoseLandmarkType, PoseLandmark> start) {
  final c = CurlUp(maxRep: 50)..cameraFacing = CameraFacing.right;
  expect(c.isInStartPosition(start), isTrue);
  c.exerciseState = ExerciseState.activated;
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('knee chip on the straight-start path is readable Vietnamese', () {
    final c = _active(_pose(0, kneeDeg: 150));
    var t = 0;
    for (final deg in [0.0, 0.0, 4.0, 8.0, 12.0]) {
      t += 33;
      c.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(t);
      c.checkingPose(_pose(deg, kneeDeg: 150));
    }
    expect(c.currentPhaseKey, 'ascending');
    expect(c.resultIssues.feedback['Knee'], '✅ Gối tốt');
  });

  // Measured 2026-11-17 (batch B): uniform frame-to-frame jitter on a still
  // body, 300 frames at 30 fps. +-2 deg counts nothing; +-3 deg counts 1-4
  // phantom reps per 10 s, all logged as clean. Behaviour is documented, not
  // changed; the proposed fix is in docs/scratch/kept-exercises-report-batch-B.md.
  int jitterReps(double amp, int seed) {
    final c = _active(_pose(0));
    final rnd = math.Random(seed);
    var t = 0;
    for (var i = 0; i < 300; i++) {
      t += 33;
      c.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(t);
      c.checkingPose(_pose((rnd.nextDouble() * 2 - 1) * amp));
    }
    return c.repCount;
  }

  test('2 deg jitter on a still body counts no rep', () {
    for (final seed in [1, 7, 42]) {
      expect(jitterReps(2.0, seed), 0, reason: 'seed $seed');
    }
  });

  test('3 deg jitter on a still body counts phantom reps (known, reported)',
      () {
    expect(jitterReps(3.0, 7), greaterThan(0));
  });
}
