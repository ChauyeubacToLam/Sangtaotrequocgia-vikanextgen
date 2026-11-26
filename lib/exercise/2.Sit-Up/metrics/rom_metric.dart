import 'sit_up_metric_base.dart';

class RomMetric extends SitUpMetricBase {
  static const double fullTrunkAngle = 60.0;

  @override
  String get name => 'ROM';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  double? minKneeHipShoulder;
  double? peakTrunk;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(SitUpRepContext ctx) {
    if (ctx.state == SitUpState.lying) return;
    if (minKneeHipShoulder == null ||
        ctx.kneeHipShoulderAngle < minKneeHipShoulder!) {
      minKneeHipShoulder = ctx.kneeHipShoulderAngle;
    }
    if (peakTrunk == null || ctx.trunkHorizontalAngle > peakTrunk!) {
      peakTrunk = ctx.trunkHorizontalAngle;
    }
    ctx.resultIssues.feedback['Lên'] = (peakTrunk ?? 0) >= fullTrunkAngle
        ? 'Đã lên đủ cao'
        : 'Cuộn người lên cao hơn';
  }

  void evaluateRep() {
    final peak = peakTrunk;
    if (peak == null || peak >= fullTrunkAngle) return;
    _faults.add(FaultRecord(
      phase: 'REP_COMPLETE',
      type: 'rom',
      message: 'Chưa ngồi lên hết: thân mới lên ${peak.toStringAsFixed(0)}°',
      voiceMessage: 'Cố gắng cuộn người cao hơn nữa',
      affectsForm: true,
      priority: SitUpFaultPriority.rom,
    ));
  }

  @override
  void reset() {
    _faults.clear();
    minKneeHipShoulder = null;
    peakTrunk = null;
  }
}
