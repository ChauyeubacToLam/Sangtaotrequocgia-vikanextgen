import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/neck_side_stretch/neck_side_stretch.dart';

Map<PoseLandmarkType, PoseLandmark> _pose({
  double tiltDeg = 0,
  double shoulderLift = 0,
  bool earsConfident = true,
}) {
  final theta = tiltDeg * math.pi / 180;
  final midX = 320 + 70 * math.sin(theta);
  final midY = 300 - 70 * math.cos(theta);
  final dx = 35 * math.cos(theta);
  final dy = 35 * math.sin(theta);
  PoseLandmark lm(PoseLandmarkType type, double x, double y, [double c = 0.99]) =>
      PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: c);
  final earConfidence = earsConfident ? 0.99 : 0.1;
  return {
    PoseLandmarkType.leftShoulder:
        lm(PoseLandmarkType.leftShoulder, 395, 300 - shoulderLift),
    PoseLandmarkType.rightShoulder:
        lm(PoseLandmarkType.rightShoulder, 245, 300 - shoulderLift),
    PoseLandmarkType.leftHip: lm(PoseLandmarkType.leftHip, 360, 500),
    PoseLandmarkType.rightHip: lm(PoseLandmarkType.rightHip, 280, 500),
    PoseLandmarkType.leftEar:
        lm(PoseLandmarkType.leftEar, midX + dx, midY + dy, earConfidence),
    PoseLandmarkType.rightEar:
        lm(PoseLandmarkType.rightEar, midX - dx, midY - dy, earConfidence),
    PoseLandmarkType.leftEye:
        lm(PoseLandmarkType.leftEye, midX + dx / 2, midY + dy / 2 - 10, 0.1),
    PoseLandmarkType.rightEye:
        lm(PoseLandmarkType.rightEye, midX - dx / 2, midY - dy / 2 - 10, 0.1),
  };
}

class _Harness {
  _Harness({int maxHolds = 2, int holdSeconds = 3})
      : exercise =
            NeckSideStretch(maxHolds: maxHolds, holdSeconds: holdSeconds) {
    final start = _pose();
    exercise.cameraFacing = exercise.detectCameraFacing(start);
    expect(exercise.cameraFacing, CameraFacing.front);
    expect(exercise.isInStartPosition(start), isTrue);
    exercise.exerciseState = ExerciseState.activated;
    exercise.onExerciseActivated();
  }

  final NeckSideStretch exercise;
  int _timestampMs = 0;
  final List<HoldPhase> phases = [];

  void frame(Map<PoseLandmarkType, PoseLandmark> pose) {
    exercise.frameTimestamp =
        DateTime.fromMillisecondsSinceEpoch(_timestampMs += 100);
    exercise.cameraFacing = exercise.detectCameraFacing(pose);
    expect(exercise.checkSafety(pose), isNull);
    exercise.checkingPose(pose);
    phases.add(exercise.phase);
  }

  void tiltTo(double from, double to, {int frames = 6}) {
    for (var i = 1; i <= frames; i++) {
      frame(_pose(tiltDeg: from + (to - from) * i / frames));
    }
  }

  void hold(double tilt, int frames) {
    for (var i = 0; i < frames; i++) {
      frame(_pose(tiltDeg: tilt));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a 30 degree tilt held for the target counts one hold on that side', () {
    final h = _Harness();
    h.hold(0, 3);
    h.tiltTo(0, 30);
    h.hold(30, 40);

    expect(h.exercise.repCount, 1);
    expect(h.exercise.phase, HoldPhase.resting);
    final data = h.exercise.logger.repLogs.single.data;
    expect(data['hold_time'], 3.0);
    expect(data['hold_side'], 'left');
    expect(data['max_tilt'] as double, greaterThan(28));
    expect(data['fault_types'], isEmpty);
  });

  test('the next hold must use the other side', () {
    final h = _Harness();
    h.hold(0, 3);
    h.tiltTo(0, 30);
    h.hold(30, 40);
    expect(h.exercise.repCount, 1);

    h.hold(30, 80);
    expect(h.exercise.phase, HoldPhase.reArming);
    expect(h.exercise.holdStillElapsedMs, isNull);
    expect(h.exercise.repCount, 1);

    h.tiltTo(30, -30, frames: 12);
    h.hold(-30, 80);
    expect(h.exercise.repCount, 2);
    expect(
      h.exercise.logger.repLogs.map((rep) => rep.data['hold_side']),
      ['left', 'right'],
    );
    expect(h.exercise.requestStop(), isTrue);
  });

  test('a shallow 15 degree tilt never starts the hold clock', () {
    final h = _Harness();
    h.hold(0, 3);
    h.tiltTo(0, 15);
    h.hold(15, 60);

    expect(h.exercise.repCount, 0);
    expect(h.exercise.phase, HoldPhase.setup);
    expect(h.exercise.liveHoldSeconds, isNull);
  });

  test('one or two noisy head frames do not break the hold', () {
    final h = _Harness(holdSeconds: 4);
    h.hold(0, 3);
    h.tiltTo(0, 30);
    h.hold(30, 10);
    expect(h.exercise.phase, HoldPhase.holding);
    final heldBefore = h.exercise.liveHoldSeconds!;

    h.frame(_pose(tiltDeg: -35));
    h.frame(_pose(tiltDeg: -35));
    h.hold(30, 3);
    h.frame(_pose(tiltDeg: 0));
    h.hold(30, 3);
    h.frame(_pose(tiltDeg: 30, earsConfident: false));
    h.frame(_pose(tiltDeg: 30, earsConfident: false));
    h.hold(30, 3);

    final sinceHoldStart =
        h.phases.skipWhile((phase) => phase != HoldPhase.holding).toList();
    expect(sinceHoldStart, everyElement(HoldPhase.holding));
    expect(h.exercise.liveHoldSeconds! - heldBefore, closeTo(1.4, 0.01));

    h.hold(30, 40);
    expect(h.exercise.repCount, 1);
    expect(h.exercise.logger.repLogs.single.data['hold_time'], 4.0);
  });

  test('shrugging the shoulders pauses the hold and is reported', () {
    final h = _Harness();
    h.hold(0, 3);
    h.tiltTo(0, 30);
    h.hold(30, 5);
    expect(h.exercise.phase, HoldPhase.holding);

    for (var i = 0; i < 10; i++) {
      h.frame(_pose(tiltDeg: 30, shoulderLift: 20));
    }
    expect(h.exercise.phase, HoldPhase.dropping);
    expect(
      h.exercise.liveFaults.map((fault) => fault.type),
      contains('shrug'),
    );

    h.hold(30, 60);
    expect(h.exercise.repCount, 1);
    final rep = h.exercise.logger.repLogs.single;
    expect(rep.data['fault_types'], contains('shrug'));
    expect(rep.correctForm, isFalse);
    h.exercise.onSetComplete();
    expect(h.exercise.logger.setLogs['shrug_fails_count'], 1);
    expect(h.exercise.logger.setLogs['shoulder_fails_count'], 0);
  });
}
