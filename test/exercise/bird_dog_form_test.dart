import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/1.Bird Dog/bird_dog.dart';
import 'package:vika/exercise/1.Bird Dog/bird_dog_report_builder.dart';
import 'package:vika/exercise/1.Bird Dog/metrics/bird_dog_metric_base.dart';
import 'package:vika/exercise/exercise_base.dart';

PoseLandmark _lm(PoseLandmarkType type, double x, double y) =>
    PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.99);

/// Quadruped, side view. Left-side landmarks sit 10 px above the right ones
/// so isPhysicalLeftSide can tell the sides apart. [extended] reaches the
/// left leg back and the right arm forward; [headDrop] lowers the right ear.
Map<PoseLandmarkType, PoseLandmark> _pose(
    {bool extended = false, double headDrop = 0}) {
  return {
    PoseLandmarkType.leftShoulder: _lm(PoseLandmarkType.leftShoulder, 150, 290),
    PoseLandmarkType.rightShoulder:
        _lm(PoseLandmarkType.rightShoulder, 150, 310),
    PoseLandmarkType.leftHip: _lm(PoseLandmarkType.leftHip, 300, 290),
    PoseLandmarkType.rightHip: _lm(PoseLandmarkType.rightHip, 300, 310),
    PoseLandmarkType.leftKnee: extended
        ? _lm(PoseLandmarkType.leftKnee, 390, 290)
        : _lm(PoseLandmarkType.leftKnee, 300, 400),
    PoseLandmarkType.leftAnkle: extended
        ? _lm(PoseLandmarkType.leftAnkle, 480, 290)
        : _lm(PoseLandmarkType.leftAnkle, 400, 400),
    PoseLandmarkType.rightKnee: _lm(PoseLandmarkType.rightKnee, 300, 400),
    PoseLandmarkType.rightAnkle: _lm(PoseLandmarkType.rightAnkle, 400, 400),
    PoseLandmarkType.leftWrist: _lm(PoseLandmarkType.leftWrist, 150, 400),
    PoseLandmarkType.rightWrist: extended
        ? _lm(PoseLandmarkType.rightWrist, 0, 310)
        : _lm(PoseLandmarkType.rightWrist, 150, 400),
    PoseLandmarkType.leftEar: _lm(PoseLandmarkType.leftEar, 100, 290),
    PoseLandmarkType.rightEar:
        _lm(PoseLandmarkType.rightEar, 100, 310 + headDrop),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('faults from a rejected (short-hold) attempt are not counted', () {
    final e = BirdDog(maxRep: 8)
      ..cameraFacing = CameraFacing.left
      ..exerciseState = ExerciseState.activated;
    expect(e.isInStartPosition(_pose()), isTrue);
    var t = 0;
    void pump(Map<PoseLandmarkType, PoseLandmark> p) {
      t += 100;
      e.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(t);
      e.checkingPose(p);
    }

    for (var i = 0; i < 3; i++) {
      pump(_pose());
    }
    pump(_pose(extended: true));
    pump(_pose(extended: true));
    for (var i = 0; i < 4; i++) {
      pump(_pose(extended: true, headDrop: 40));
    }
    expect(e.state, BirdDogState.hold_extended);
    pump(_pose());
    pump(_pose()); // leaves the hold after < 1.5 s: rejected
    expect(e.repCount, 0);
    expect(e.invalidAttemptCount, 1);
    e.onSetComplete();
    expect(e.logger.setLogs['alignment_fails_count'], 0);
  });

  test('report copy states the 1.5 s hold the code enforces', () {
    final b = BirdDogReportBuilder();
    for (final tip in b.faultToTipMap().values) {
      expect(tip.watch, isNot(contains('2s')));
      expect(tip.next, isNot(contains('2s')));
    }
    for (final sentence in b.praiseSentenceMap().values) {
      expect(sentence(1, 1), isNot(contains('2s')));
    }
  });
}
