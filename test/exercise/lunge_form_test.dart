import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/lunge/lunge.dart';
import 'package:vika/exercise/lunge/metrics/lunge_depth_metric.dart';
import 'package:vika/exercise/lunge/metrics/lunge_lumbar_proxy_metric.dart';
import 'package:vika/exercise/lunge/metrics/lunge_metric_base.dart';
import 'package:vika/exercise/lunge/metrics/lunge_trunk_lean_metric.dart';

/// One physical lunge frame seen from the side, laid out with the front
/// toward smaller X (the near-side-left convention settled in batch A). The
/// lead leg is the near leg. [leftNear] false mirrors the image in X and swaps
/// the side labels, which is the same body with the right side to the camera.
Map<PoseLandmarkType, PoseLandmark> _pose({
  required bool leftNear,
  required (double, double) hip,
  required (double, double) leadKnee,
  required (double, double) leadAnkle,
  required (double, double) trailKnee,
  (double, double) trailAnkle = (300, 540),
}) {
  final shoulder = (hip.$1, hip.$2 - 200);
  final lead = <String, (double, double)>{
    'shoulder': shoulder,
    'hip': hip,
    'knee': leadKnee,
    'ankle': leadAnkle,
    'heel': (leadAnkle.$1 + 10, 545),
    'foot': (leadAnkle.$1 - 30, 545),
  };
  final trail = <String, (double, double)>{
    'shoulder': shoulder,
    'hip': hip,
    'knee': trailKnee,
    'ankle': trailAnkle,
    'heel': (trailAnkle.$1 + 10, 530),
    'foot': (trailAnkle.$1 - 20, 545),
  };
  const leftTypes = {
    'shoulder': PoseLandmarkType.leftShoulder,
    'hip': PoseLandmarkType.leftHip,
    'knee': PoseLandmarkType.leftKnee,
    'ankle': PoseLandmarkType.leftAnkle,
    'heel': PoseLandmarkType.leftHeel,
    'foot': PoseLandmarkType.leftFootIndex,
  };
  const rightTypes = {
    'shoulder': PoseLandmarkType.rightShoulder,
    'hip': PoseLandmarkType.rightHip,
    'knee': PoseLandmarkType.rightKnee,
    'ankle': PoseLandmarkType.rightAnkle,
    'heel': PoseLandmarkType.rightHeel,
    'foot': PoseLandmarkType.rightFootIndex,
  };
  final nearTypes = leftNear ? leftTypes : rightTypes;
  final farTypes = leftNear ? rightTypes : leftTypes;
  final pose = <PoseLandmarkType, PoseLandmark>{};
  void put(PoseLandmarkType type, (double, double) p, double z) {
    final x = leftNear ? p.$1 : 400 - p.$1;
    pose[type] = PoseLandmark(type: type, x: x, y: p.$2, z: z, likelihood: 0.99);
  }

  for (final key in lead.keys) {
    put(nearTypes[key]!, lead[key]!, -0.1);
    put(farTypes[key]!, trail[key]!, 0.1);
  }
  return pose;
}

Map<PoseLandmarkType, PoseLandmark> _standing(bool leftNear) => _pose(
      leftNear: leftNear,
      hip: (200, 300),
      leadKnee: (170, 420),
      leadAnkle: (140, 540),
      trailKnee: (240, 420),
    );

Map<PoseLandmarkType, PoseLandmark> _halfway(bool leftNear) => _pose(
      leftNear: leftNear,
      hip: (200, 360),
      leadKnee: (130, 410),
      leadAnkle: (120, 540),
      trailKnee: (250, 470),
    );

Map<PoseLandmarkType, PoseLandmark> _bottom(bool leftNear,
        {(double, double) trailKnee = (260, 520),
        (double, double) leadKnee = (110, 400)}) =>
    _pose(
      leftNear: leftNear,
      hip: (200, 400),
      leadKnee: leadKnee,
      leadAnkle: (110, 540),
      trailKnee: trailKnee,
    );

Lunge _lunge(bool leftNear) => Lunge(maxRep: 10)
  ..cameraFacing = leftNear ? CameraFacing.left : CameraFacing.right
  ..scaleFactor = 200
  ..exerciseState = ExerciseState.activated;

int _t = 0;

void _pump(Lunge lunge, Map<PoseLandmarkType, PoseLandmark> pose) {
  _t += 33;
  lunge.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(_t);
  lunge.checkingPose(pose);
}

/// Stand, lunge down, hold [bottomFrames] at the bottom, stand back up.
void _rep(Lunge lunge, bool leftNear,
    {Map<PoseLandmarkType, PoseLandmark>? bottom, int bottomFrames = 10}) {
  for (var i = 0; i < 6; i++) {
    _pump(lunge, _standing(leftNear));
  }
  _pump(lunge, _halfway(leftNear));
  for (var i = 0; i < bottomFrames; i++) {
    _pump(lunge, bottom ?? _bottom(leftNear));
  }
  _pump(lunge, _halfway(leftNear));
  _pump(lunge, _standing(leftNear));
  _pump(lunge, _standing(leftNear));
}

List<String> _faultTypes(Lunge lunge) =>
    (lunge.logger.repLogs.last.data['fault_types'] as List).cast<String>();

LungeRepContext _ctx({
  double leadKneeAngle = 90,
  double trunkLean = 0,
  double shAngle = 160,
  LungeState state = LungeState.bottom,
}) =>
    LungeRepContext(
      leadKneeAngle: leadKneeAngle,
      trailKneeAngle: 120,
      trunkLean: trunkLean,
      shoulderHipTrailKneeAngle: shAngle,
      lungeState: state,
      isLeftLegLead: true,
      frameTimestamp: 0,
      scaleFactor: 1.0,
      leadKneeY: 0,
      leadHipY: 0,
      resultIssues: ResultIssues(),
    );

final _english = RegExp(r'^[A-Za-z !\x27.,]+$');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final leftNear in [true, false]) {
    final side = leftNear ? 'left' : 'right';

    test('a clean lunge counts once with good form (facing $side)', () {
      final lunge = _lunge(leftNear);
      _rep(lunge, leftNear);
      expect(lunge.repCount, 1);
      expect(lunge.logger.repLogs, hasLength(1));
      expect(_faultTypes(lunge), isEmpty);
      expect(lunge.logger.repLogs.single.correctForm, isTrue);
    });

    test('trail knee far behind an upright trunk logs lumbar (facing $side)',
        () {
      final lunge = _lunge(leftNear);
      _rep(lunge, leftNear,
          bottom: _bottom(leftNear, trailKnee: (360, 480)));
      expect(lunge.repCount, 1);
      expect(_faultTypes(lunge), contains('lumbar'));
    });

    test('start gate refuses an upright trunk over a hip flexed 40 deg '
        '(facing $side)', () {
      // Shoulder straight above the hip; the near thigh 40 deg forward of
      // vertical, so shoulder-hip-knee is 140 deg, below the 155 limit.
      final pose = _pose(
        leftNear: leftNear,
        hip: (200, 300),
        leadKnee: (123, 392),
        leadAnkle: (123, 540),
        trailKnee: (240, 420),
      );
      expect(_lunge(leftNear).isInStartPosition(pose), isFalse);
      expect(_lunge(leftNear).isInStartPosition(_standing(leftNear)), isTrue);
    });

    test('a clean lunge counts once when the view turns angled after the '
        'start (lead leg settled facing $side)', () {
      final lunge = _lunge(leftNear);
      // The start gate needs a side view, so the lead leg is settled there.
      for (var i = 0; i < 6; i++) {
        _pump(lunge, _standing(leftNear));
      }
      lunge.cameraFacing = CameraFacing.angled;
      _rep(lunge, leftNear);
      expect(lunge.repCount, 1);
    });
  }

  test('logged fault messages and result text are Vietnamese', () {
    final lunge = _lunge(true);
    _rep(lunge, true, bottom: _bottom(true, trailKnee: (360, 480)));
    expect(lunge.repCount, 1);
    expect(lunge.resultIssues.feedback['Result'], isNot(matches(_english)));
    final messages = <String>[
      for (final rep in lunge.setFeedback)
        for (final byPhase in rep.values)
          for (final byType in byPhase.values) ...byType.values,
    ];
    expect(messages, isNotEmpty);

    final forward = LungeTrunkLeanMetric();
    final backward = LungeTrunkLeanMetric();
    final lumbar = LungeLumbarProxyMetric();
    for (var i = 0; i < 12; i++) {
      forward.update(_ctx(trunkLean: 70));
      backward.update(_ctx(trunkLean: -20));
      lumbar.update(_ctx(shAngle: 100));
    }
    for (final metric in [forward, backward, lumbar]) {
      expect(metric.faults, isNotEmpty, reason: metric.name);
      messages.addAll(metric.faults.map((f) => f.message));
    }
    for (final message in messages) {
      expect(message, isNot(matches(_english)), reason: message);
    }
  });

  test('forward lean of 20 deg held 5 frames is a trunk fault, 11 deg is not',
      () {
    final upright = LungeTrunkLeanMetric();
    final leaning = LungeTrunkLeanMetric();
    final brief = LungeTrunkLeanMetric();
    for (var i = 0; i < 5; i++) {
      upright.update(_ctx(trunkLean: 11));
      leaning.update(_ctx(trunkLean: 20));
    }
    for (var i = 0; i < 4; i++) {
      brief.update(_ctx(trunkLean: 46));
    }
    brief.update(_ctx(trunkLean: 0));
    expect(upright.faults, isEmpty);
    expect(leaning.faults.map((f) => f.type), ['trunk']);
    expect(brief.faults, isEmpty);
  });

  test('a knee-to-floor lunge is never faulted or told to go lower', () {
    final depth = LungeDepthMetric();
    for (final angle in [90.0, 60.0, 43.0, 30.0]) {
      final ctx = _ctx(leadKneeAngle: angle);
      depth.update(ctx);
      expect(ctx.resultIssues.feedback['Depth'], 'Độ sâu tốt!',
          reason: '$angle');
    }
    expect(depth.faults, isEmpty);
    expect(depth.minKneeAngle, 30.0);
  });

  test('a rep logs no depth or heel fault and keeps both set-log keys', () {
    final lunge = _lunge(true);
    _rep(lunge, true);
    lunge.onSetComplete();
    expect(_faultTypes(lunge), isNot(contains('depth')));
    expect(_faultTypes(lunge), isNot(contains('heel')));
    expect(lunge.logger.setLogs['depth_fails_count'], 0);
    expect(lunge.logger.setLogs['heel_lift_fails_count'], 0);
  });
}
