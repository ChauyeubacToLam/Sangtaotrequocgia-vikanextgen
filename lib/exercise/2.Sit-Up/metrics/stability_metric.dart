import 'dart:math' as math;

import 'sit_up_metric_base.dart';

class StabilityMetric extends SitUpMetricBase {
  static const double liftTorsoRatio = 0.10;
  static const int liftFrames = 3;

  @override
  String get name => 'LowerBodyStability';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  double? _floorAnkleY;
  int _framesLifted = 0;
  double maxLift = 0;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  void observeLying(double ankleY) {
    final floor = _floorAnkleY;
    _floorAnkleY = floor == null ? ankleY : floor * 0.8 + ankleY * 0.2;
  }

  @override
  void update(SitUpRepContext ctx) {
    final floor = _floorAnkleY;
    final scale = ctx.scaleFactor;
    if (ctx.state == SitUpState.lying ||
        floor == null ||
        scale == null ||
        scale <= 0) {
      return;
    }
    final lift = (floor - ctx.ankleY) / scale;
    maxLift = math.max(maxLift, lift);
    _debugData['ankleLift'] = lift;
    _framesLifted = lift > liftTorsoRatio ? _framesLifted + 1 : 0;
    ctx.resultIssues.feedback['Chân'] =
        _framesLifted > 0 ? 'Giữ chân trên sàn' : 'Chân tốt';
    if (_framesLifted >= liftFrames &&
        !_faults.any((f) => f.type == 'stability')) {
      _faults.add(FaultRecord(
        phase: ctx.state.name,
        type: 'stability',
        message: 'Nhấc chân khỏi sàn',
        voiceMessage: 'Hạ chân xuống',
        affectsForm: true,
        priority: SitUpFaultPriority.heelLift,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _framesLifted = 0;
    maxLift = 0;
  }
}
