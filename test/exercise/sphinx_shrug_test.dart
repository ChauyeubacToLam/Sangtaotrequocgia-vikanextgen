import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/Sphinx_Pose/Metrics/neck_shoulder_metric.dart';
import 'package:vika/exercise/Sphinx_Pose/Metrics/sphinx_metric_base.dart';

SphinxContext _ctx(double earShoulderDist) => SphinxContext(
      bodyAngle: 170,
      elbowAngle: 85,
      spineAngle: 20,
      forearmAngle: 0,
      upperArmAngle: 90,
      hipY: 300,
      ankleY: 300,
      earShoulderDist: earShoulderDist,
      neckAngle: 160,
      scaleFactor: 100,
      state: SphinxState.isometricHold,
      frameTimestampMs: 0,
      resultIssues: ResultIssues(),
    );

void main() {
  test('shoulders pulled toward the ears (distance 35 -> 22) is a shrug', () {
    final metric = NeckShoulderMetric();
    for (var i = 0; i < 20; i++) {
      metric.update(_ctx(35));
    }
    expect(metric.isShrugFaultingNow, isFalse);
    for (var i = 0; i < 8; i++) {
      metric.update(_ctx(22));
    }
    expect(metric.isShrugFaultingNow, isTrue);
  });

  test('small wobble around the relaxed distance is not a shrug', () {
    final metric = NeckShoulderMetric();
    for (var i = 0; i < 30; i++) {
      metric.update(_ctx(i.isEven ? 35 : 31));
    }
    expect(metric.isShrugFaultingNow, isFalse);
  });
}
