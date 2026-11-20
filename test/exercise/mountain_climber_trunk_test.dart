import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/4.Mountain Climber/metrics/mountain_climber_metric_base.dart';
import 'package:vika/exercise/4.Mountain Climber/metrics/trunk_stability_metric.dart';
import 'package:vika/exercise/exercise_base.dart';

RepContext _ctx(double hipY) => RepContext(
      state: ClimberState.knee_driving_in,
      frameTimestamp: 0,
      scaleFactor: 100,
      armAngle: 175,
      trunkAngle: 170,
      hipY: hipY,
      shoulderX: 100,
      hipX: 200,
      leftKneeDistNorm: 1,
      rightKneeDistNorm: 1,
      leftKneeAngle: 170,
      rightKneeAngle: 170,
      resultIssues: ResultIssues(),
    );

/// One rep's worth of frames at a steady hip height, then the rep closes.
void _rep(TrunkStabilityMetric m, double hipY) {
  for (var i = 0; i < 10; i++) {
    m.update(_ctx(hipY));
  }
  m.resetAndCountFault();
}

void main() {
  test('a one-time shift in hip height is not a bounce on every later rep',
      () {
    final m = TrunkStabilityMetric();
    _rep(m, 300); // first rep sets the old baseline
    // The user re-sets the plank 0.3 torso lower and then holds steady.
    for (var r = 0; r < 5; r++) {
      _rep(m, 330);
    }
    // At most the rep in which the shift happened may carry a bounce.
    expect(m.faultsCount, lessThanOrEqualTo(1));
  });

  test('a bounce within a rep is still logged', () {
    final m = TrunkStabilityMetric();
    m.update(_ctx(300));
    for (var i = 0; i < 6; i++) {
      m.update(_ctx(330));
    }
    expect(m.faults.map((f) => f.type), contains('trunk_bounce'));
  });
}
