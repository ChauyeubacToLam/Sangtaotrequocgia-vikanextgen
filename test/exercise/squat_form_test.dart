import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/squat/squat.dart';
import 'package:vika/utils/exercise_logger.dart';

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
  _Run(this.squat, {this.stepMs = 100});
  final Squat squat;
  final int stepMs;
  int t = 0;
  final seen = <String>[];

  void frame(double knee, {double lean = 15, double heelLift = 1}) {
    squat.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(t);
    squat.checkingPose(_pose(knee: knee, lean: lean, heelLift: heelLift));
    seen
      ..addAll(squat.resultIssues.feedback.values)
      ..addAll(squat.resultIssues.phaseStatus.values);
    squat.resultIssues.feedback.clear();
    t += stepMs;
  }
}

List<double> _ramp(double from, double to, int frames) =>
    [for (var i = 1; i <= frames; i++) from + (to - from) * i / frames];

RepLog _timedRep({required int descentFrames}) {
  final squat = _activeSquat();
  final run = _Run(squat, stepMs: 50);
  for (final knee in [
    ...List.filled(6, 174.0),
    ..._ramp(174, 80, descentFrames),
    ...List.filled(8, 80.0),
    ..._ramp(80, 174, 16),
    ...List.filled(4, 174.0),
  ]) {
    run.frame(knee);
  }
  expect(squat.repCount, 1, reason: 'fixture precondition: one rep');
  return squat.logger.repLogs.single;
}

void _deepRep(_Run run, {double bottomLean = 15, double bottomHeelLift = 1}) {
  for (final knee in <double>[172, 166, 160, 154, 148, 142, 134, 126, 118, 110]) {
    run.frame(knee);
  }
  for (var i = 0; i < 7; i++) {
    run.frame(104, lean: bottomLean, heelLift: bottomHeelLift);
  }
  for (final knee in <double>[112, 125, 140, 155, 168, 174, 174]) {
    run.frame(knee);
  }
}

RepLog _ascentLeanRep(List<double> ascentLeans,
    {CameraFacing? facingDuringFirstAscentFrames}) {
  final squat = _activeSquat();
  final run = _Run(squat);
  for (final knee in <double>[172, 166, 160, 154, 148, 142, 134, 126, 118, 110]) {
    run.frame(knee, lean: 25);
  }
  for (var i = 0; i < 7; i++) {
    run.frame(104, lean: 33);
  }
  final ascentKnees = _ramp(104, 174, ascentLeans.length);
  for (var i = 0; i < ascentKnees.length; i++) {
    squat.cameraFacing = i < 3 && facingDuringFirstAscentFrames != null
        ? facingDuringFirstAscentFrames
        : CameraFacing.right;
    run.frame(ascentKnees[i], lean: ascentLeans[i]);
  }
  run
    ..frame(174, lean: 3)
    ..frame(174, lean: 3);
  expect(squat.repCount, 1, reason: 'fixture precondition: one rep');
  return squat.logger.repLogs.single;
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
    _deepRep(_Run(squat), bottomLean: 65);

    expect(squat.repCount, 1);
    final repLog = squat.logger.repLogs.single;
    expect(repLog.data['fault_types'], contains('trunk'));
    expect(repLog.correctForm, isFalse);
  });

  test('a 0.8 s descent from standing to 80 deg is timed in full', () {
    final rep = _timedRep(descentFrames: 16);
    expect(rep.data['descending_time'] as double, closeTo(0.75, 0.1));
    expect(rep.data['fault_types'], isNot(contains('tempo')));
  });

  test('a 0.25 s drop from standing to 80 deg is still a tempo fault', () {
    final rep = _timedRep(descentFrames: 5);
    expect(rep.data['descending_time'] as double, lessThan(0.3));
    expect(rep.data['fault_types'], contains('tempo'));
  });

  test('hips and shoulders rising at the same speed is not a sync fault', () {
    final rep = _ascentLeanRep(
        [33, 33, 33, 33, 33, 33, 33, 30, 25, 18, 12, 6]);
    expect(rep.data['fault_types'], isNot(contains('sync')));
    expect(rep.data['ascent_lean_rise'] as double, lessThan(1));
    expect(rep.correctForm, isTrue);
  });

  test('trunk tipping 15 deg forward while standing up is a sync fault', () {
    final rep = _ascentLeanRep(
        [33, 37, 42, 46, 48, 48, 44, 36, 26, 16, 8, 4]);
    expect(rep.data['fault_types'], contains('sync'));
    expect(rep.data['ascent_lean_rise'] as double, closeTo(15, 0.5));
  });

  test('trunk lean appearing when the camera view turns side-on is ignored',
      () {
    final rep = _ascentLeanRep(
        [33, 33, 33, 33, 33, 33, 33, 30, 25, 18, 12, 6],
        facingDuringFirstAscentFrames: CameraFacing.angled);
    expect(rep.data['fault_types'], isNot(contains('sync')));
  });

  test('lifted heels never log a heel fault', () {
    final squat = _activeSquat();
    _deepRep(_Run(squat), bottomHeelLift: 40);
    squat.onSetComplete();

    expect(squat.repCount, 1);
    expect(squat.logger.repLogs.single.data['fault_types'],
        isNot(contains('heel')));
    expect(squat.logger.setLogs['heel_fails_count'], 0);
  });

  test('every logged message and live text is Vietnamese', () {
    final squat = _activeSquat();
    final run = _Run(squat);
    _deepRep(run, bottomHeelLift: 20);
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
