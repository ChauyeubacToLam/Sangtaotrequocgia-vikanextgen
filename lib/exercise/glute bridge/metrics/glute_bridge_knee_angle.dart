import 'glute_bridge_metric_base.dart';
import '../glute_bridge.dart';

class KneeAngleConfig {
  static const double GOOD_MIN = 80.0;
  static const double GOOD_MAX = 135.0;
  static const double ACCEPTABLE_UPPER_MAX = 145.0;
  static const double WARNING_MIN = 55.0;
}

class KneeAngleMetric extends GluteBridgeMetricBase {
  @override
  String get name => 'KneeAngle';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  bool _setupInstructionShown = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void onBottomFrame(RepContext ctx) {
    if (_setupInstructionShown || ctx.kneeAngle == null) return;

    final double angle = ctx.kneeAngle!;
    _debugData['kneeAngle'] = angle.toStringAsFixed(1);

    if (angle >= KneeAngleConfig.WARNING_MIN) _setupInstructionShown = true;
  }

  @override
  void update(RepContext ctx) {
    if (ctx.kneeAngle == null) return;
    if (ctx.state == GluteBridgeState.topHold) {
      _debugData['kneeAngle'] = ctx.kneeAngle!.toStringAsFixed(1);
    }
  }

  void checkRepCompletion(double? kneeAngle) {
    if (kneeAngle == null) return;

    _debugData['repKneeAngle'] = '${kneeAngle.toStringAsFixed(1)}°';

    if (kneeAngle < KneeAngleConfig.WARNING_MIN) {
      _faults.add(FaultRecord(
        phase: 'topHold',
        type: 'knee_angle',
        message: 'Di chân ra xa hông hơn — duỗi gối nhiều hơn',
        affectsForm: true,
      ));
    } else if (kneeAngle < KneeAngleConfig.GOOD_MIN) {
      _faults.add(FaultRecord(
        phase: 'topHold',
        type: 'knee_angle',
        message: 'Di chân ra xa hông thêm để giảm áp lực hamstring',
        affectsForm: false,
      ));
    } else if (kneeAngle > KneeAngleConfig.ACCEPTABLE_UPPER_MAX) {
      _faults.add(FaultRecord(
        phase: 'topHold',
        type: 'knee_angle',
        message: 'Di chân lại gần hông một chút',
        affectsForm: false,
      ));
    }
  }

  @override
  void onStateTransition(
      GluteBridgeState from, GluteBridgeState to, int timestampMs) {}

  @override
  void reset() {
    _faults.clear();
    _setupInstructionShown = false;
  }
}
