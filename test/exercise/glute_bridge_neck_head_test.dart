import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/glute bridge/glute_bridge.dart';
import 'package:vika/exercise/glute bridge/metrics/glute_bridge_metric_base.dart';
import 'package:vika/exercise/glute bridge/metrics/glute_bridge_neck_head.dart';
import 'package:vika/exercise/glute bridge/metrics/glute_bridge_speed_control.dart';

/// Torso 100 px; the ear 30 px above the shoulder is a lift of 0.30 torso,
/// well past the 0.14 threshold.
RepContext _ctx(GluteBridgeState state, {bool headLifted = true}) =>
    RepContext(
      hipY: 300,
      shoulderY: 300,
      hipVelocity: 0,
      shoulderHipKneeAngle: 170,
      normalizedHipDeviation: 0,
      kneeAngle: 100,
      scaleFactor: 100,
      headY: headLifted ? 270 : 305,
      state: state,
      frameTimestamp: 0,
      baselineHipY: 300,
      resultIssues: ResultIssues(),
    );

/// Lying on the back, side-on, head toward smaller X; both sides identical.
Map<PoseLandmarkType, PoseLandmark> _supine(
    {required double hipY, required bool headLifted}) {
  final points = <(PoseLandmarkType, PoseLandmarkType), (double, double)>{
    (PoseLandmarkType.leftEar, PoseLandmarkType.rightEar):
        (60, headLifted ? 270 : 300),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('neck_head', () {
    test('a head lift while resting at the bottom is not recorded', () {
      final metric = NeckHeadMetric();
      for (var i = 0; i < 15; i++) {
        metric.onBottomFrame(_ctx(GluteBridgeState.bottom));
      }
      expect(metric.faults, isEmpty);
    });

    test('lifted frames at the bottom do not count toward the next ascent', () {
      final metric = NeckHeadMetric();
      for (var i = 0; i < 9; i++) {
        metric.onBottomFrame(_ctx(GluteBridgeState.bottom));
      }
      metric.update(_ctx(GluteBridgeState.ascending));
      expect(metric.faults, isEmpty);
    });

    test('a sustained head lift during the bridge is still recorded', () {
      final metric = NeckHeadMetric();
      for (var i = 0; i < NeckHeadConfig.DEBOUNCE_FRAMES; i++) {
        metric.update(_ctx(GluteBridgeState.ascending));
      }
      expect(metric.faults.single.type, 'neck_head');
      expect(metric.faults.single.affectsForm, isTrue);
    });
  });

  test(
      'a head lift during an aborted ascent (ascending -> bottom, no rep) is '
      'not attached to the next counted rep', () {
    final bridge = GluteBridge(maxRep: 10)
      ..exerciseState = ExerciseState.activated
      ..cameraFacing = CameraFacing.right
      ..scaleFactor = 100; // shoulder-hip distance of the fixture
    var t = 0;
    var neckFaultWhileAscending = false;
    final states = <GluteBridgeState>[];
    void frame(double hipY, {required bool headLifted}) {
      bridge.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(t);
      bridge.checkingPose(_supine(hipY: hipY, headLifted: headLifted));
      if (states.isEmpty || states.last != bridge.gluteState) {
        states.add(bridge.gluteState);
      }
      if (bridge.gluteState == GluteBridgeState.ascending &&
          bridge.neckHeadMetric.faults.isNotEmpty) {
        neckFaultWhileAscending = true;
      }
      t += 33;
    }

    // Aborted attempt, head up to watch the phone: the hips twitch up 10 px
    // (0.1 torso) for about 0.2 s and settle back without becoming a rep.
    for (final hip in <double>[300, 300, 300, 300, 300, 300, 295, 290, 290,
      290, 290, 290, 295, 300, 300, 300, 300, 300, 300, 300, 300]) {
      frame(hip, headLifted: true);
    }
    expect(states, [GluteBridgeState.bottom, GluteBridgeState.ascending,
        GluteBridgeState.bottom], reason: 'fixture precondition: an abort');
    expect(neckFaultWhileAscending, isTrue,
        reason: 'fixture precondition: the head lift fired during the ascent');
    expect(bridge.repCount, 0);

    // One full bridge with the head down.
    for (final hip in <double>[
      296, 292, 288, 284, 280, 276, 272, 268, 264, 260, //
      260, 260, 260, 260, 260, 260, 260, 260, //
      264, 268, 272, 276, 280, 284, 288, 292, 296, 300, //
      300, 300, 300, 300, 300, 300, 300, 300,
    ]) {
      frame(hip, headLifted: false);
    }
    expect(bridge.repCount, 1, reason: 'fixture precondition: states $states');
    expect(bridge.logger.repLogs.single.data['fault_types'],
        isNot(contains('neck_head')));
  });

  test('pacing message states the 1.3x ratio the code enforces', () {
    final metric = SpeedControlMetric()
      ..onStateTransition(
          GluteBridgeState.bottom, GluteBridgeState.ascending, 0)
      ..onStateTransition(
          GluteBridgeState.ascending, GluteBridgeState.topHold, 1000)
      ..onStateTransition(
          GluteBridgeState.topHold, GluteBridgeState.descending, 1000)
      ..checkRepCompletion(2200);

    final message = metric.faults.single.message;
    expect(message, contains('1,3'));
    expect(message, isNot(contains('gấp đôi')));
  });
}
