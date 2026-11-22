import 'bird_dog_metric_base.dart';

class AlignmentMetric extends BirdDogMetricBase {
  static const double limbFaultAbove = 35.0;
  static const double limbWarningAbove = 25.0;
  static const double headDropFaultAbove = 0.15;

  @override
  String get name => 'Alignment';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};
  double? _limbDeviation;
  MetricStatus _status = MetricStatus.pass;
  double? _bestArm;
  double? _bestLeg;
  double? _bestHeadDrop;

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;
  @override
  double? get value => _limbDeviation;
  @override
  ThresholdBand? get threshold => const ThresholdBand(
        warningAbove: limbWarningAbove,
        faultAbove: limbFaultAbove,
      );
  @override
  MetricStatus get status => _status;

  @override
  void update(BirdDogRepContext ctx) {
    final arm = ctx.activeArmHorizontalAngle;
    final leg = ctx.activeLegHorizontalAngle;
    final limbBad = arm > limbFaultAbove || leg > limbFaultAbove;

    _limbDeviation = arm > leg ? arm : leg;
    _status = limbBad
        ? MetricStatus.fault
        : _limbDeviation! > limbWarningAbove
            ? MetricStatus.near
            : MetricStatus.pass;
    _debugData['armHorizontal'] = arm;
    _debugData['legHorizontal'] = leg;
    _debugData['limbDeviation'] = _limbDeviation;

    final scale = ctx.scaleFactor;
    final headDrop =
        scale == null || scale <= 0 ? null : (ctx.earY - ctx.shoulderY) / scale;
    if (headDrop != null) {
      _debugData['headDrop'] = headDrop;
      if (headDrop > headDropFaultAbove) _status = MetricStatus.fault;
    }

    if (ctx.state != BirdDogState.hold_extended) return;
    _bestArm = _min(_bestArm, arm);
    _bestLeg = _min(_bestLeg, leg);
    if (headDrop != null) _bestHeadDrop = _min(_bestHeadDrop, headDrop);
    _debugData['holdBestArm'] = _bestArm;
    _debugData['holdBestLeg'] = _bestLeg;
  }

  @override
  void onStateTransition(BirdDogState from, BirdDogState to, int timestampMs) {
    if (from != BirdDogState.hold_extended) return;
    final arm = _bestArm;
    final leg = _bestLeg;
    if (arm != null &&
        leg != null &&
        (arm > limbFaultAbove || leg > limbFaultAbove)) {
      _addFault(
        type: 'alignment',
        message: 'Tay/Chân duỗi chưa thẳng với mặt đất',
        voiceMessage: 'Vươn dài tay và chân.',
      );
    }
    final head = _bestHeadDrop;
    if (head != null && head > headDropFaultAbove) {
      _addFault(
        type: 'head',
        message: 'Đầu cúi quá thấp',
        voiceMessage: 'Nâng đầu nhẹ, mắt nhìn xuống thảm.',
      );
    }
  }

  static double _min(double? current, double value) =>
      current == null || value < current ? value : current;

  void _addFault({
    required String type,
    required String message,
    required String voiceMessage,
  }) {
    if (_faults.any((f) => f.type == type)) return;
    _faults.add(FaultRecord(
      phase: BirdDogState.hold_extended.name,
      type: type,
      message: message,
      voiceMessage: voiceMessage,
      affectsForm: true,
      priority: BirdDogFaultPriority.alignment,
    ));
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _limbDeviation = null;
    _status = MetricStatus.pass;
    _bestArm = null;
    _bestLeg = null;
    _bestHeadDrop = null;
  }
}
