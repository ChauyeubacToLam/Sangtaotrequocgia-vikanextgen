import 'seated_forward_metric_base.dart';
import '../../../utils/debouncer.dart';

class SpinalAlignmentMetric extends SeatedForwardMetricBase {
  @override
  String get name => 'SpinalAlignment';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  final Debouncer _spineRoundDebouncer = Debouncer(requiredFrames: 6);
  bool _instructionSet = false;
  bool _isFaultingNow = false;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  bool get isFaultingNow => _isFaultingNow;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(SeatedForwardContext ctx) {
    _isFaultingNow = false;
    if (ctx.state == SeatedForwardState.setup) return;

    _debugData['spineAngle'] = ctx.spineAngle.toStringAsFixed(1);

    bool isRounding = ctx.spineAngle < SeatedForwardConfig.As_Fault_Spine_Angle;

    if (_spineRoundDebouncer.update(isRounding)) {
      _isFaultingNow = true;
      ctx.resultIssues.feedback['Spine'] = 'Nâng đầu lên, giữ cổ thẳng!';
      if (!_instructionSet) {
        // Legacy UI instruction copy: Lưng đang bị gù. Hãy kê cao mông (ngồi lên đệm), ưu tiên co nhẹ gối để bụng chạm đùi thay vì cố vươn tay chạm chân.
        _instructionSet = true;
      }
      _logFault(ctx.state.name, 'Giữ đầu thẳng hàng, đừng gục cổ');
    } else {
      ctx.resultIssues.feedback['Spine'] = 'Đầu cổ thẳng hàng tốt';
    }
  }

  void _logFault(String phase, String voiceMessage) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'SpineRound')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'SpineRound',
        // Ear-shoulder-hip angle: this measures the head/neck, not the back.
        message: 'Lỗi cúi đầu quá sâu',
        voiceMessage: voiceMessage,
        affectsForm: true,
        priority: SeatedForwardFaultVoicePriority.spineRound,
      ));
    }
  }

  @override
  void reset() {
    super.reset();
    _instructionSet = false;
    _spineRoundDebouncer.reset();
    _isFaultingNow = false;
  }
}
