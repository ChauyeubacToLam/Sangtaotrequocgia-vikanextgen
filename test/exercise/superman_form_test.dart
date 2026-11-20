import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/5.Superman/superman.dart';
import 'package:vika/exercise/5.Superman/superman_report_builder.dart';
import 'package:vika/exercise/5.Superman/metrics/hold_time_metric.dart';
import 'package:vika/exercise/5.Superman/metrics/superman_metric_base.dart';
import 'package:vika/exercise/exercise_base.dart';

PoseLandmark _lm(PoseLandmarkType type, double x, double y) =>
    PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.99);

/// Prone, side view, torso 150 px. [arm] / [leg] are wrist and ankle lift
/// above shoulder / hip height, in torso lengths.
Map<PoseLandmarkType, PoseLandmark> _pose(double arm, double leg) => {
      PoseLandmarkType.nose: _lm(PoseLandmarkType.nose, 120, 305),
      PoseLandmarkType.leftEar: _lm(PoseLandmarkType.leftEar, 160, 300),
      PoseLandmarkType.rightEar: _lm(PoseLandmarkType.rightEar, 160, 300),
      PoseLandmarkType.leftShoulder: _lm(PoseLandmarkType.leftShoulder, 200, 300),
      PoseLandmarkType.rightShoulder:
          _lm(PoseLandmarkType.rightShoulder, 200, 300),
      PoseLandmarkType.leftHip: _lm(PoseLandmarkType.leftHip, 350, 300),
      PoseLandmarkType.rightHip: _lm(PoseLandmarkType.rightHip, 350, 300),
      PoseLandmarkType.leftWrist:
          _lm(PoseLandmarkType.leftWrist, 50, 300 - arm * 150),
      PoseLandmarkType.rightWrist:
          _lm(PoseLandmarkType.rightWrist, 50, 300 - arm * 150),
      PoseLandmarkType.leftAnkle:
          _lm(PoseLandmarkType.leftAnkle, 550, 300 - leg * 150),
      PoseLandmarkType.rightAnkle:
          _lm(PoseLandmarkType.rightAnkle, 550, 300 - leg * 150),
    };

Superman _active() {
  final s = Superman(maxRep: 10)..cameraFacing = CameraFacing.left;
  expect(s.isInStartPosition(_pose(0, 0)), isTrue);
  s.exerciseState = ExerciseState.activated;
  return s;
}

int _t = 0;
void _pump(Superman s, double arm, double leg, [int frames = 1]) {
  for (var i = 0; i < frames; i++) {
    _t += 100;
    s.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(_t);
    s.checkingPose(_pose(arm, leg));
  }
}

void _liftAndHold(Superman s, {int holdFrames = 12}) {
  _pump(s, 0, 0, 3);
  _pump(s, 0.04, 0.04, 3); // lifting
  _pump(s, 0.06, 0.06, holdFrames); // hold
}

List<String> _types(Superman s) =>
    (s.logger.repLogs.last.data['fault_types'] as List).cast<String>();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('one clean rep lowered normally has no elevation fault', () {
    final s = _active();
    _liftAndHold(s);
    _pump(s, 0.02, 0.02, 3); // normal lowering out of the hold
    _pump(s, 0, 0, 3);
    expect(s.repCount, 1);
    expect(_types(s), isNot(contains('elevation_arm')));
    expect(_types(s), isNot(contains('elevation_leg')));
    expect(s.logger.repLogs.single.correctForm, isTrue);
  });

  test('a dip below the lift line during the hold is still a fault', () {
    final s = _active();
    _liftAndHold(s, holdFrames: 6);
    _pump(s, 0.02, 0.06); // arms sag for one frame, then recover
    _pump(s, 0.06, 0.06, 6);
    _pump(s, 0.02, 0.02, 3);
    _pump(s, 0, 0, 3);
    expect(s.repCount, 1);
    expect(_types(s), contains('elevation_arm'));
  });

  test('an aborted lift is counted in rejected_attempts_count', () {
    final s = _active();
    _pump(s, 0, 0, 3);
    _pump(s, 0.04, 0.04, 3); // lifting
    _pump(s, 0, 0, 2); // back down without reaching the hold
    expect(s.repCount, 0);
    s.onSetComplete();
    expect(s.logger.setLogs['rejected_attempts_count'], 1);
  });

  test('hold copy states the 1 s the code requires', () {
    final s = _active();
    _liftAndHold(s);
    _pump(s, 0.02, 0.02, 3);
    _pump(s, 0, 0, 3);
    s.onSetComplete();
    final cards = SupermanReportBuilder().buildDetailCards([s.logger]);
    final hold =
        cards.singleWhere((c) => c.label == 'Thời gian giữ trung bình');
    expect(hold.subLabel, isNot(contains('2.0')));
    expect(hold.subLabel, contains('1.0'));

    final metric = HoldTimeMetric()
      ..evaluateRepEnd(SupermanRepContext(
        armElevation: 0,
        legElevation: 0,
        hipElevation: 0,
        spineAngle: 0,
        scaleFactor: 150,
        currentState: SupermanState.lowering,
        frameTimestampMs: 0,
        resultIssues: ResultIssues(),
      ));
    expect(metric.faults.single.voiceMessage, isNot(contains('2 giây')));
  });
}
