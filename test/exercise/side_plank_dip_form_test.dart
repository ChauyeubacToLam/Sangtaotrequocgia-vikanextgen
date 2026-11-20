import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/side_plank_dip/side_plank_dip.dart';
import 'package:vika/exercise/side_plank_dip/side_plank_dip_report_builder_v2.dart';

PoseLandmark _lm(PoseLandmarkType type, double x, double y) =>
    PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.99);

// Same layout as side_plank_hold_test.dart: left forearm support, body along X.
Map<PoseLandmarkType, PoseLandmark> _pose({double hipY = 300}) => {
      PoseLandmarkType.leftShoulder: _lm(PoseLandmarkType.leftShoulder, 200, 300),
      PoseLandmarkType.rightShoulder:
          _lm(PoseLandmarkType.rightShoulder, 210, 295),
      PoseLandmarkType.leftElbow: _lm(PoseLandmarkType.leftElbow, 200, 400),
      PoseLandmarkType.rightElbow: _lm(PoseLandmarkType.rightElbow, 210, 300),
      PoseLandmarkType.leftHip: _lm(PoseLandmarkType.leftHip, 400, hipY),
      PoseLandmarkType.rightHip: _lm(PoseLandmarkType.rightHip, 410, hipY - 5),
      PoseLandmarkType.leftAnkle: _lm(PoseLandmarkType.leftAnkle, 600, 300),
      PoseLandmarkType.rightAnkle: _lm(PoseLandmarkType.rightAnkle, 610, 295),
    };

void _pump(SidePlankDip e, Map<PoseLandmarkType, PoseLandmark> pose, int ms) {
  e.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms);
  e.checkingPose(pose);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('time spent with a fault while the clock is paused is reported', () {
    final e = SidePlankDip(maxHolds: 1, holdSeconds: 1)
      ..cameraFacing = CameraFacing.left
      ..exerciseState = ExerciseState.activated;
    expect(e.isInStartPosition(_pose()), isTrue);
    e.onExerciseActivated();

    // Frames 0..200 clean (clock runs 0.2 s), 300..700 hips sagging.
    for (var ms = 0; ms <= 200; ms += 100) {
      _pump(e, _pose(), ms);
    }
    expect(e.phase, HoldPhase.holding);
    for (var ms = 300; ms <= 700; ms += 100) {
      _pump(e, _pose(hipY: 410), ms);
    }
    // The clock still stops on the first faulting frame (unchanged).
    expect(e.phase, HoldPhase.dropping);
    expect(e.liveHoldSeconds, closeTo(0.2, 1e-9));

    var ms = 800;
    while (e.repCount == 0 && ms < 5000) {
      _pump(e, _pose(), ms);
      ms += 100;
    }
    expect(e.repCount, 1);
    expect(e.logger.repLogs.single.data['hold_time'], 1.0);

    e.onSetComplete();
    final logs = e.logger.setLogs;
    // Five 100 ms gaps ending on faulting frames (300..700).
    expect(logs['body_line_seconds'], closeTo(0.5, 1e-9));
    expect(logs['shoulder_seconds'], 0.0);
    expect(logs['dip_depth_fails_count'], 1);
    expect(logs['good_rep_count'], 0);
  });

  test('report copy talks about holds, not reps or hip dips', () {
    final b = SidePlankDipReportBuilderV2();
    for (final sentence in b.praiseSentenceMap().values) {
      final text = sentence(2, 3);
      expect(text, isNot(contains(' rep')), reason: text);
      expect(text, isNot(contains('hiệp')), reason: text);
      expect(text, contains('2/3 lần giữ'), reason: text);
    }
    for (final tip in b.faultToTipMap().values) {
      expect(tip.next, isNot(contains('hạ hông')), reason: tip.next);
    }
  });
}
