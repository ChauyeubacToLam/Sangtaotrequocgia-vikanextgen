import 'package:vika/utils/debouncer.dart';

import 'squat_metric_base.dart';
import '../squat.dart';

class HipShoulderSyncConfig {
  static const double LEAN_RISE_WARNING = 6.0;
  static const double LEAN_RISE_FAULT = 10.0;
  static const int CONFIRM_FRAMES = 3;
}

class HipShoulderSyncMetric extends SquatMetricBase {
  @override
  String get name => 'HipShoulderSync';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _faultDebouncer =
      Debouncer(requiredFrames: HipShoulderSyncConfig.CONFIRM_FRAMES);

  double? _ascentStartLean;
  double? _leanRise;
  double _peakLeanRise = 0.0;
  bool _faultLogged = false;
  MetricStatus _status = MetricStatus.pass;

  double get peakLeanRise => _peakLeanRise;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  double? get value => _leanRise;

  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningAbove: HipShoulderSyncConfig.LEAN_RISE_WARNING,
        faultAbove: HipShoulderSyncConfig.LEAN_RISE_FAULT,
      );

  @override
  MetricStatus get status => _status;

  @override
  void update(RepContext ctx) {
    if (ctx.squatState != SquatState.ascending || !ctx.trunkMeasured) {
      _ascentStartLean = ctx.trunkMeasured ? ctx.trunkLean : null;
      _faultDebouncer.reset();
      _status = MetricStatus.pass;
      return;
    }

    final start = _ascentStartLean ??= ctx.trunkLean;
    final rise = ctx.trunkLean - start;
    _leanRise = rise;
    if (rise > _peakLeanRise) _peakLeanRise = rise;
    _debugData['syncLeanRise'] = rise;
    _debugData['peakSyncLeanRise'] = _peakLeanRise;

    if (_faultDebouncer.update(rise > HipShoulderSyncConfig.LEAN_RISE_FAULT)) {
      _status = MetricStatus.fault;
      ctx.resultIssues.feedback['Sync'] = 'Đẩy ngực lên!';
      if (!_faultLogged) {
        _faultLogged = true;
        _faults.add(FaultRecord(
          phase: ctx.squatState.toString().split('.').last.toUpperCase(),
          type: 'sync',
          message:
              'Hông lên trước vai, thân đổ thêm ${rise.toStringAsFixed(0)}°',
          affectsForm: true,
          voiceMessage: null,
          priority: SquatFaultVoicePriority.hipShoulderSync,
        ));
      }
      return;
    }

    _status = rise > HipShoulderSyncConfig.LEAN_RISE_WARNING
        ? MetricStatus.near
        : MetricStatus.pass;
    ctx.resultIssues.feedback['Sync'] = 'Hông và vai đồng đều';
  }

  @override
  void reset() {
    _faultDebouncer.reset();
    _ascentStartLean = null;
    _leanRise = null;
    _peakLeanRise = 0.0;
    _faultLogged = false;
    _status = MetricStatus.pass;
    _faults.clear();
    _debugData.clear();
  }
}
