import 'glute_bridge_metric_base.dart';
import '../../../utils/debouncer.dart';

class NeckHeadConfig {
  static const double HEAD_LIFT_THRESHOLD = 0.14;
  static const double HEAD_LIFT_PIXELS = 20.0;
  static const int DEBOUNCE_FRAMES = 10;
}

class NeckHeadMetric extends GluteBridgeMetricBase {
  @override
  String get name => 'NeckHead';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _liftDebouncer =
      Debouncer(requiredFrames: NeckHeadConfig.DEBOUNCE_FRAMES);

  bool _faultAdded = false;
  bool _resting = false;
  double? _restingDiff;
  double? _restingScale;
  double? _peakLift;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  double? get restingLift => _restingDiff == null || _restingScale == null
      ? null
      : _restingDiff! / _restingScale!;

  double? get peakLift => _peakLift;

  @override
  void onBottomFrame(RepContext ctx) {
    _liftDebouncer.reset();
    final headY = ctx.headY;
    if (headY == null) return;
    final diff = ctx.shoulderY - headY;
    final resting = _restingDiff;
    _restingDiff =
        !_resting || resting == null || diff < resting ? diff : resting;
    _resting = true;
    _restingScale = ctx.scaleFactor;
    _debugData['headRest'] = restingLift?.toStringAsFixed(3);
  }

  @override
  void update(RepContext ctx) {
    _resting = false;
    final headY = ctx.headY;
    final resting = _restingDiff;
    if (headY == null || resting == null) return;

    final scale = ctx.scaleFactor;
    final lift = ctx.shoulderY - headY - resting;
    final threshold = scale != null
        ? scale * NeckHeadConfig.HEAD_LIFT_THRESHOLD
        : NeckHeadConfig.HEAD_LIFT_PIXELS;
    final normalized = scale != null ? lift / scale : null;
    if (normalized != null && (_peakLift == null || normalized > _peakLift!)) {
      _peakLift = normalized;
    }
    _debugData['headLift'] = normalized?.toStringAsFixed(3);

    if (_liftDebouncer.update(lift > threshold) && !_faultAdded) {
      _faults.add(FaultRecord(
        phase: ctx.state.toString().split('.').last,
        type: 'neck_head',
        message: 'Giữ đầu và cổ trên sàn khi thực hiện bài tập',
        affectsForm: true,
      ));
      _faultAdded = true;
    }
  }

  @override
  void reset() {
    _faults.clear();
    _liftDebouncer.reset();
    _faultAdded = false;
    _peakLift = null;
  }
}
