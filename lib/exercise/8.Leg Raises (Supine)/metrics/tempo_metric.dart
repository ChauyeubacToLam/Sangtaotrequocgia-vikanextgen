import 'leg_raise_metric_base.dart';

class TempoMetric extends LegRaiseMetricBase {
  @override
  String get name => 'Tempo';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  int? _loweringStartMs;
  double? loweringDuration;
  // The rep's smallest hip angle and when it was seen: the legs leave the top
  // of the raise there, so the lowering clock starts there.
  double? _minHipAngle;
  int? _minHipMs;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;
  @override
  double? get value {
    final liveDuration = _debugData['loweringSeconds'];
    return loweringDuration ??
        (liveDuration is num ? liveDuration.toDouble() : null);
  }

  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningBelow: LegRaiseConfig.TEMPO_TARGET_THRESHOLD,
        faultBelow: LegRaiseConfig.TEMPO_FAULT_THRESHOLD,
      );

  @override
  void onStateTransition(
      LegRaiseState from, LegRaiseState to, int timestampMs) {
    if (to == LegRaiseState.raising) {
      _minHipAngle = null;
      _minHipMs = null;
    } else if (to == LegRaiseState.lowering) {
      _loweringStartMs = _minHipMs ?? timestampMs;
    } else if (to == LegRaiseState.lying && _loweringStartMs != null) {
      loweringDuration = (timestampMs - _loweringStartMs!) / 1000.0;
    }
  }

  @override
  void update(LegRaiseRepContext ctx) {
    if ((ctx.state == LegRaiseState.raising ||
            ctx.state == LegRaiseState.top) &&
        (_minHipAngle == null || ctx.hipFlexionAngle <= _minHipAngle!)) {
      _minHipAngle = ctx.hipFlexionAngle;
      _minHipMs = ctx.frameTimestampMs;
    }
    if (_loweringStartMs != null &&
        (ctx.state == LegRaiseState.lowering ||
            ctx.state == LegRaiseState.lying)) {
      _debugData['loweringSeconds'] =
          (ctx.frameTimestampMs - _loweringStartMs!) / 1000.0;
    }
  }

  void evaluateRep(LegRaiseRepContext ctx) {
    // Nếu rớt tự do < TEMPO_FAULT_THRESHOLD (0.8s)
    if (loweringDuration != null &&
        loweringDuration! < LegRaiseConfig.TEMPO_FAULT_THRESHOLD) {
      _faults.add(FaultRecord(
        phase: 'REP_COMPLETE',
        type: 'tempo',
        message:
            'Thả rơi chân quá nhanh (${loweringDuration!.toStringAsFixed(1)}s)',
        voiceMessage:
            'Từ từ thôi! Hạ chân chậm lại để giữ an toàn cho thắt lưng!',
        affectsForm: true,
        priority: LegRaiseFaultPriority.tempo,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _loweringStartMs = null;
    loweringDuration = null;
    _minHipAngle = null;
    _minHipMs = null;
  }
}
