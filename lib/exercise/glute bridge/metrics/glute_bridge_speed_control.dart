import 'glute_bridge_metric_base.dart';
import '../glute_bridge.dart';
import '../../../utils/debouncer.dart';

class SpeedControlConfig {
  static const double RAPID_VELOCITY_WARNING = 0.08;
  static const double RAPID_VELOCITY_ERROR = 0.15;
  static const int RAPID_DEBOUNCE_FRAMES = 5;
}

class SpeedControlMetric extends GluteBridgeMetricBase {
  @override
  String get name => 'SpeedControl';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _rapidDebouncer =
      Debouncer(requiredFrames: SpeedControlConfig.RAPID_DEBOUNCE_FRAMES);

  bool _liveInstructionShown = false;
  double _peakDescentVelocity = 0.0;
  int? _descentStartMs;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.state != GluteBridgeState.descending) return;

    final scale = ctx.scaleFactor;
    if (scale == null || scale <= 1e-6) return;
    final double vel = ctx.hipVelocity / scale;

    if (vel > _peakDescentVelocity) _peakDescentVelocity = vel;

    _debugData['descentVel'] = '+${vel.toStringAsFixed(2)}';
    _debugData['peakDescentVel'] =
        '+${_peakDescentVelocity.toStringAsFixed(2)}';

    final bool isRapid = vel >= SpeedControlConfig.RAPID_VELOCITY_WARNING;
    if (_rapidDebouncer.update(isRapid)) _liveInstructionShown = true;
  }

  @override
  void onStateTransition(
      GluteBridgeState from, GluteBridgeState to, int timestampMs) {
    switch (to) {
      case GluteBridgeState.ascending:
        _rapidDebouncer.reset();
        _liveInstructionShown = false;
        _peakDescentVelocity = 0.0;
        break;
      case GluteBridgeState.descending:
        _descentStartMs = timestampMs;
        break;
      case GluteBridgeState.topHold:
      case GluteBridgeState.bottom:
        break;
    }
  }

  void checkRepCompletion(int timestampMs) {
    if (_descentStartMs == null) return;
    _debugData['eccentricDur'] =
        ((timestampMs - _descentStartMs!) / 1000.0).toStringAsFixed(2);

    if (_peakDescentVelocity >= SpeedControlConfig.RAPID_VELOCITY_ERROR) {
      _faults.add(FaultRecord(
        phase: 'descending',
        type: 'speed_control',
        message: 'Hạ hông quá nhanh — siết cơ lõi để kiểm soát',
        affectsForm: true,
      ));
    } else if (_liveInstructionShown) {
      _faults.add(FaultRecord(
        phase: 'descending',
        type: 'speed_control',
        message: 'Kiểm soát tốc độ hạ hông để bảo vệ lưng',
        affectsForm: false,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _rapidDebouncer.reset();
    _liveInstructionShown = false;
    _peakDescentVelocity = 0.0;
    _descentStartMs = null;
  }
}
