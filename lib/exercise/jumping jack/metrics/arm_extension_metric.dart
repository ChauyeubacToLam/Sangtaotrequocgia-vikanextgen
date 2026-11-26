import 'jumping_jack_metric_base.dart';
import '../jumping_jack.dart';

class ArmExtensionConfig {
  // ignore: constant_identifier_names
  static const double OVERHEAD_ELEVATION_MIN = 150.0;
}

class ArmExtensionMetric extends JJMetricBase {
  @override
  String get name => 'ArmExtension';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  double _peakLeftElevation = 0.0;
  double _peakRightElevation = 0.0;

  double get peakElevation => _peakLeftElevation < _peakRightElevation
      ? _peakLeftElevation
      : _peakRightElevation;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    if (ctx.leftArmElevation > _peakLeftElevation) {
      _peakLeftElevation = ctx.leftArmElevation;
    }
    if (ctx.rightArmElevation > _peakRightElevation) {
      _peakRightElevation = ctx.rightArmElevation;
    }

    _debugData['leftElev'] = ctx.leftArmElevation.toStringAsFixed(1);
    _debugData['rightElev'] = ctx.rightArmElevation.toStringAsFixed(1);
    _debugData['peakElev'] = peakElevation.toStringAsFixed(0);

    if (ctx.jjState != JJState.open || !ctx.meetsOpenGate) {
      if (ctx.resultIssues.feedback['Arms'] == null) {
        ctx.resultIssues.feedback['Arms'] = 'Chuẩn bị';
      }
      return;
    }

    final lowerArm = ctx.leftArmElevation < ctx.rightArmElevation
        ? ctx.leftArmElevation
        : ctx.rightArmElevation;
    ctx.resultIssues.feedback['Arms'] =
        lowerArm < ArmExtensionConfig.OVERHEAD_ELEVATION_MIN
            ? 'Vung tay cao qua đầu!'
            : 'Tay tốt!';
    _debugData['armStatus'] = ctx.resultIssues.feedback['Arms'] ?? '';
  }

  void evaluateRep() {
    if (peakElevation >= ArmExtensionConfig.OVERHEAD_ELEVATION_MIN) return;
    if (_faults.any((f) => f.type == 'arms')) return;
    _faults.add(FaultRecord(
      phase: 'REP_COMPLETE',
      type: 'arms',
      message: 'Tay chưa vươn cao qua đầu (${peakElevation.toStringAsFixed(0)}°)',
      voiceMessage: 'Vung tay lên cao qua đầu',
      affectsForm: true,
    ));
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _peakLeftElevation = 0.0;
    _peakRightElevation = 0.0;
  }
}
