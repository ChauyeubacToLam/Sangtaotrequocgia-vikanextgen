import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/glute bridge/glute_bridge.dart';

Map<PoseLandmarkType, PoseLandmark> _supine(double hipY) {
  final points = <(PoseLandmarkType, PoseLandmarkType), (double, double)>{
    (PoseLandmarkType.leftEar, PoseLandmarkType.rightEar): (60, 300),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder):
        (100, 300),
    (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip): (200, hipY),
    (PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee): (270, 240),
    (PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle): (310, 300),
  };
  return {
    for (final e in points.entries) ...{
      e.key.$1: PoseLandmark(
          type: e.key.$1, x: e.value.$1, y: e.value.$2, z: 0, likelihood: 0.99),
      e.key.$2: PoseLandmark(
          type: e.key.$2, x: e.value.$1, y: e.value.$2, z: 0, likelihood: 0.99),
    },
  };
}

List<double> _steps(double from, double to) {
  final step = to > from ? 4.0 : -4.0;
  return [for (var y = from + step; (to - y) * step >= 0; y += step) y];
}

GluteBridge _run(List<double> hips) {
  final bridge = GluteBridge(maxRep: 20)
    ..exerciseState = ExerciseState.activated
    ..cameraFacing = CameraFacing.right
    ..scaleFactor = 100;
  var t = 0;
  for (final hip in hips) {
    bridge.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(t);
    bridge.checkingPose(_supine(hip));
    t += 33;
  }
  return bridge;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final rest = List.filled(8, 300.0);

  test('lowering only half way and lifting again is one rep, not three', () {
    final bridge = _run([
      ...rest,
      ..._steps(300, 240),
      ..._steps(240, 272),
      ..._steps(272, 240),
      ..._steps(240, 272),
      ..._steps(272, 240),
      ..._steps(240, 300),
      ...rest,
    ]);
    expect(bridge.repCount, 1);
  });

  test('touching the floor and lifting straight away counts every rep', () {
    final bridge = _run([
      ...rest,
      ..._steps(300, 240),
      ..._steps(240, 296),
      ..._steps(296, 240),
      ..._steps(240, 296),
      ..._steps(296, 240),
      ..._steps(240, 300),
      ...rest,
    ]);
    expect(bridge.repCount, 3);
  });
}
