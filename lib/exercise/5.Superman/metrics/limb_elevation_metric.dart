import 'superman_metric_base.dart';

class LimbElevationMetric extends SupermanMetricBase {
  @override
  String get name => 'LimbElevation';

  // Elevation below the lift line in `hold` is also the hold's exit condition
  // (3 frames at <= 0.03). A dip is only a fault if the hold then continues;
  // if the state leaves `hold`, the dip was the normal lowering.
  bool _armDipped = false;
  bool _legDipped = false;

  @override
  void onStateTransition(
      SupermanState from, SupermanState to, int timestampMs) {
    if (from == SupermanState.hold) {
      _armDipped = false;
      _legDipped = false;
    }
  }

  @override
  void reset() {
    super.reset();
    _armDipped = false;
    _legDipped = false;
  }

  @override
  void update(SupermanRepContext ctx) {
    debugData['arm_elevation'] = ctx.armElevation.toStringAsFixed(3);
    debugData['leg_elevation'] = ctx.legElevation.toStringAsFixed(3);

    if (ctx.currentState != SupermanState.hold) return;

    final armLow = ctx.armElevation < SupermanConfig.LIFT_THRESHOLD;
    final legLow = ctx.legElevation < SupermanConfig.LIFT_THRESHOLD;
    final armRecovered = _armDipped && !armLow;
    final legRecovered = _legDipped && !legLow;
    _armDipped = armLow || (_armDipped && !armRecovered);
    _legDipped = legLow || (_legDipped && !legRecovered);

    if (armRecovered) {
      if (!faults.any((f) => f.type == 'elevation_arm')) {
        addFault(FaultRecord(
          phase: ctx.currentState.name,
          type: 'elevation_arm',
          message: 'Nâng tay cao hơn!',
          voiceMessage: 'Nâng tay lên cao hơn',
          affectsForm: true,
          priority: SupermanVoicePriority
              .limbElevation, // Fix #6: Sử dụng priority riêng
        ));
      }
    }
    if (legRecovered) {
      if (!faults.any((f) => f.type == 'elevation_leg')) {
        addFault(FaultRecord(
          phase: ctx.currentState.name,
          type: 'elevation_leg',
          message: 'Nâng chân cao hơn!',
          voiceMessage: 'Nâng chân lên cao hơn',
          affectsForm: true,
          priority: SupermanVoicePriority
              .limbElevation, // Fix #6: Sử dụng priority riêng
        ));
      }
    }
  }
}
