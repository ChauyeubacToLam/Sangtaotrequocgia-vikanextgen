import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/squat/squat.dart';

PoseLandmark _landmark(PoseLandmarkType type, double x, double y) =>
    PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.99);

double _radians(double degrees) => degrees * math.pi / 180.0;

/// Right side to the camera, front toward larger X (same builder as
/// squat_rep_peak_tracking_test). Torso length 90 px.
Map<PoseLandmarkType, PoseLandmark> _pose({
  required double knee,
  double lean = 15,
  double heelLift = 1,
}) {
  const kneeX = 220.0;
  const kneeY = 290.0;
  final hipX = kneeX + 100 * math.sin(_radians(knee));
  final hipY = kneeY + 100 * math.cos(_radians(knee));
  final shoulderX = hipX + 90 * math.sin(_radians(lean));
  final shoulderY = hipY - 90 * math.cos(_radians(lean));
  const footX = kneeX + 24.0;
  const footY = kneeY + 108.0;
  return {
    PoseLandmarkType.rightShoulder:
        _landmark(PoseLandmarkType.rightShoulder, shoulderX, shoulderY),
    PoseLandmarkType.rightHip: _landmark(PoseLandmarkType.rightHip, hipX, hipY),
    PoseLandmarkType.rightKnee:
        _landmark(PoseLandmarkType.rightKnee, kneeX, kneeY),
    PoseLandmarkType.rightAnkle:
        _landmark(PoseLandmarkType.rightAnkle, kneeX, kneeY + 100),
    PoseLandmarkType.rightHeel:
        _landmark(PoseLandmarkType.rightHeel, footX - 20, footY - heelLift),
    PoseLandmarkType.rightFootIndex:
        _landmark(PoseLandmarkType.rightFootIndex, footX, footY),
  };
}

class _Run {
  _Run(this.squat);
  final Squat squat;
  int t = 0;
  final seen = <String>[];

  void frame(double knee, {double lean = 15, double heelLift = 1}) {
    squat.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(t);
    squat.checkingPose(_pose(knee: knee, lean: lean, heelLift: heelLift));
    seen
      ..addAll(squat.resultIssues.feedback.values)
      ..addAll(squat.resultIssues.phaseStatus.values);
    squat.resultIssues.feedback.clear();
    t += 100;
  }
}

/// A rep that reaches bottom, holds 0.6 s with lifted heels, and stands up
/// on frames that match the old calibrated clean-rep constants (knee ~174,
/// trunk lean 15, heel lift ~1% of torso).
void _deepRepWithHeelLift(_Run run) {
  for (final knee in <double>[172, 166, 160, 154, 148, 142, 134, 126, 118, 110]) {
    run.frame(knee);
  }
  for (var i = 0; i < 7; i++) {
    run.frame(104, heelLift: 20);
  }
  for (final knee in <double>[112, 125, 140, 155, 168, 174, 174]) {
    run.frame(knee);
  }
}

Squat _activeSquat() {
  final squat = Squat(maxRep: 5)
    ..exerciseState = ExerciseState.activated
    ..cameraFacing = CameraFacing.right;
  expect(squat.isInStartPosition(_pose(knee: 172)), isTrue);
  return squat;
}

final _vietnameseLetter = RegExp(
    r'[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ]',
    caseSensitive: false);
final _asciiWord = RegExp(r'[A-Za-z]{3,}');

bool _looksEnglish(String text) =>
    _asciiWord.hasMatch(text) && !_vietnameseLetter.hasMatch(text);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('faults that fired stay logged when the final frame looks "clean"', () {
    final squat = _activeSquat();
    _deepRepWithHeelLift(_Run(squat));

    expect(squat.repCount, 1);
    final repLog = squat.logger.repLogs.single;
    expect(repLog.data['fault_types'], contains('heel'));
    expect(repLog.correctForm, isFalse);
  });

  test('every logged message and live text is Vietnamese', () {
    final squat = _activeSquat();
    final run = _Run(squat);
    _deepRepWithHeelLift(run);
    // A second rep that leans far forward and never reaches bottom.
    for (final knee in <double>[172, 166, 160, 154, 148, 142, 136, 130, 124, 120]) {
      run.frame(knee, lean: 65);
    }
    for (final knee in <double>[128, 136, 144, 152, 160, 168, 174, 174]) {
      run.frame(knee);
    }
    expect(squat.repCount, 2);

    final messages = [
      for (final entry in squat.setFeedback)
        for (final phase in (entry as Map).values.single.values)
          ...(phase as Map<String, String>).values,
    ];
    expect(messages, isNotEmpty);
    final visible = [
      ...messages,
      ...run.seen,
      Squat.descendingStatus,
      Squat.bottomHoldStatus(0.2),
    ];
    expect(visible.where(_looksEnglish).toSet(), isEmpty);
  });
}
