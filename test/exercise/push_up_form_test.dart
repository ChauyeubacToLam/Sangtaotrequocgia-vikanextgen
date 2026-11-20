import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/push up/push_up.dart';
import 'package:vika/exercise/push up/push_up_report_builder.dart';
import 'package:vika/utils/exercise_logger.dart';

const _pairs = <String, (PoseLandmarkType, PoseLandmarkType)>{
  'shoulder': (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
  'elbow': (PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow),
  'wrist': (PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist),
  'hip': (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
  'knee': (PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee),
  'ankle': (PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle),
  'heel': (PoseLandmarkType.leftHeel, PoseLandmarkType.rightHeel),
  'foot': (PoseLandmarkType.leftFootIndex, PoseLandmarkType.rightFootIndex),
};

/// One physical push-up frame seen from the side. Same layout as
/// push_up_anti_cheat_test (head toward larger X), which is the right side
/// nearer the camera; the left-side-near view is the same body mirrored in X.
Map<PoseLandmarkType, PoseLandmark> _pose({
  required bool leftNear,
  required double bodyY,
  required double elbowX,
  required double elbowY,
  double hipDrop = 0, // + = hips lower than the shoulder-knee line (sag)
}) {
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
  final pose = <PoseLandmarkType, PoseLandmark>{};
  for (final entry in points.entries) {
    final (left, right) = _pairs[entry.key]!;
    final (px, py) = entry.value;
    final x = leftNear ? 500 - px : px;
    pose[left] = PoseLandmark(
        type: left, x: x, y: py, z: leftNear ? -0.1 : 0.1, likelihood: 0.99);
    pose[right] = PoseLandmark(
        type: right, x: x, y: py, z: leftNear ? 0.1 : -0.1, likelihood: 0.99);
  }
  return pose;
}

PushUp _activePushUp({required bool leftNear}) {
  final pushUp = PushUp(maxRep: 10);
  var facing = CameraFacing.undefined;
  for (var i = 0; i < 5; i++) {
    facing = pushUp.detectCameraFacing(
        _pose(leftNear: leftNear, bodyY: 220, elbowX: 400, elbowY: 260));
  }
  expect(facing, leftNear ? CameraFacing.left : CameraFacing.right);
  return pushUp
    ..cameraFacing = facing
    ..exerciseState = ExerciseState.activated;
}

void _pump(PushUp pushUp, Map<PoseLandmarkType, PoseLandmark> pose, int ms) {
  pushUp.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(ms);
  pushUp.checkingPose(pose);
}

/// Top, descent, and [bottomFrames] frames held at the bottom.
void _descendAndHold(PushUp pushUp,
    {required bool leftNear, double hipDrop = 0, int bottomFrames = 2}) {
  final top = _pose(leftNear: leftNear, bodyY: 220, elbowX: 400, elbowY: 260);
  expect(pushUp.isInStartPosition(top), isTrue);
  _pump(pushUp, top, 0);
  _pump(
      pushUp,
      _pose(
          leftNear: leftNear,
          bodyY: 235,
          elbowX: 408,
          elbowY: 272,
          hipDrop: hipDrop),
      100);
  _pump(
      pushUp,
      _pose(
          leftNear: leftNear,
          bodyY: 245,
          elbowX: 412,
          elbowY: 278,
          hipDrop: hipDrop),
      200);
  for (var i = 0; i < bottomFrames; i++) {
    _pump(
        pushUp,
        _pose(
            leftNear: leftNear,
            bodyY: 270,
            elbowX: 415,
            elbowY: 285,
            hipDrop: hipDrop),
        900 + i * 100);
  }
}

void _finishRep(PushUp pushUp, {required bool leftNear, required int fromMs}) {
  _pump(pushUp,
      _pose(leftNear: leftNear, bodyY: 245, elbowX: 412, elbowY: 278), fromMs);
  final top = _pose(leftNear: leftNear, bodyY: 220, elbowX: 400, elbowY: 260);
  _pump(pushUp, top, fromMs + 500);
  _pump(pushUp, top, fromMs + 900);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('same physical push-up, both camera facings', () {
    for (final leftNear in [true, false]) {
      final side = leftNear ? 'left' : 'right';

      test('a level full-body rep counts with good form ($side)', () {
        final pushUp = _activePushUp(leftNear: leftNear);
        _descendAndHold(pushUp, leftNear: leftNear);
        _finishRep(pushUp, leftNear: leftNear, fromMs: 1300);

        expect(pushUp.repCount, 1);
        final repLog = pushUp.logger.repLogs.single;
        expect(repLog.data['fault_types'], isEmpty);
        expect(repLog.correctForm, isTrue);
        expect(repLog.data['max_abs_trunk_deviation'] as num, lessThan(1e-9));
      });

      test('sagging hips log sag, not pike ($side)', () {
        final pushUp = _activePushUp(leftNear: leftNear);
        _descendAndHold(pushUp,
            leftNear: leftNear, hipDrop: 25, bottomFrames: 6);

        final messages =
            pushUp.trunkAlignmentMetric.faults.map((f) => f.message).toSet();
        expect(messages, {'Hông hơi chùng'});
      });
    }
  });

  group('depth', () {
    test('a counted rep always reached bottom, so depth never fires', () {
      final pushUp = _activePushUp(leftNear: true);
      _descendAndHold(pushUp, leftNear: true);
      _finishRep(pushUp, leftNear: true, fromMs: 1300);
      expect(pushUp.repCount, 1);
      expect(pushUp.depthMetric.faultsCount, 0);
      pushUp.onSetComplete();
      expect(pushUp.logger.setLogs.containsKey('depth_fails_count'), isFalse);
    });

    test('report praise never cites the structurally perfect depth score', () {
      final logger = ExerciseLogger()
        ..pushKey('max_rep', 10)
        ..pushKey('good_rep_count', 6)
        ..pushKey('trunk_alignment_fails_count', 4)
        ..pushKey('depth_fails_count', 0)
        ..pushKey('tempo_fails_count', 4);

      final builder = PushUpReportBuilder();
      final praise = builder.buildPraiseSentence(logger, setIndex: 0);
      expect(praise, isNot(contains('Độ sâu')));
      expect(builder.praiseMetricNames().keys,
          isNot(contains('depth_fails_count')));
    });
  });
}
