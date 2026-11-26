// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Lunge Metric: Trunk Lean

   Angle of the torso from vertical (shoulder-hip line).

   Landmarks: HIP (#23/#24) — pivot, SHOULDER (#11/#12) — point
   Calculation: calculateVerticalAngle(Hip, Shoulder) then
                convertClockAngleToTrunkLean(clockAngle, cameraFacing)

   When to check: Bottom phase primarily (when lever arm on lumbar is longest).
                  Continuous monitoring for live feedback.
   Per-rep evaluation at point of maximum depth.
   ========================================================================= */

import 'lunge_metric_base.dart';
import '../../../utils/debouncer.dart';

class LungeTrunkLeanConfig {
  static const List<int> GOOD_LEAN_RANGE = [-5, 14];

  static const int WARN_LEAN_LIMIT = 19;

  static const int FORWARD_CONFIRM_FRAMES = 5;

  /// Backward lean threshold (degrees). Below 0 = leaning back.
  static const double BACKWARD_LIMIT = -10.0;
}

class LungeTrunkLeanMetric extends LungeMetricBase {
  @override
  String get name => 'TrunkLean';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Separate debouncers for forward/backward
  final Debouncer _forwardDebouncer =
      Debouncer(requiredFrames: LungeTrunkLeanConfig.FORWARD_CONFIRM_FRAMES);
  // 8 frames for backward lean
  final Debouncer _backwardDebouncer = Debouncer(requiredFrames: 8);

  /// Track maximum trunk lean this rep (for post-rep analysis)
  double? maxTrunkLean;

  /// Prevent instruction spam — only set coaching once per rep.
  bool _instructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(LungeRepContext ctx) {
    // Track max lean per rep
    if (maxTrunkLean == null || ctx.trunkLean > maxTrunkLean!) {
      maxTrunkLean = ctx.trunkLean;
    }

    _debugData['maxTrunkLean'] = maxTrunkLean?.toStringAsFixed(1) ?? 'N/A';

    final phase = ctx.lungeState.toString().split('.').last.toUpperCase();

    bool leanForwardBad =
        ctx.trunkLean >= (LungeTrunkLeanConfig.WARN_LEAN_LIMIT + 1);
    bool leanForwardWarn =
        ctx.trunkLean > LungeTrunkLeanConfig.GOOD_LEAN_RANGE[1] &&
            ctx.trunkLean <= LungeTrunkLeanConfig.WARN_LEAN_LIMIT;
    // Backward lean: < -10°
    bool leanBackward = ctx.trunkLean < LungeTrunkLeanConfig.BACKWARD_LIMIT;

    bool forwardBadConfirmed = _forwardDebouncer.update(leanForwardBad);
    bool backwardConfirmed = _backwardDebouncer.update(leanBackward);

    if (forwardBadConfirmed) {
      ctx.resultIssues.feedback['Back'] = 'Nâng ngực lên!';
      if (!_instructionSet) {
        // Legacy UI instruction copy: Giữ thân trên thẳng, siết cơ core khi bước lùi.
        _instructionSet = true;
      }
      _logFault(phase, 'Nâng ngực lên! Thân trên đổ quá nhiều');
    } else if (backwardConfirmed) {
      // < -10° — Leaning backward
      ctx.resultIssues.feedback['Back'] = 'Đừng ngả ra sau!';
      if (!_instructionSet) {
        // Legacy UI instruction copy: Đừng ngả ra sau! Giữ thân trên thẳng.
        _instructionSet = true;
      }
      _logFault(phase, 'Đừng ngả ra sau!');
    } else if (leanForwardWarn) {
      ctx.resultIssues.feedback['Back'] = 'Hơi gập người, giữ lưng thẳng';
    } else {
      ctx.resultIssues.feedback['Back'] = 'Lưng tốt!';
    }
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'trunk')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'trunk',
        message: message,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _forwardDebouncer.reset();
    _backwardDebouncer.reset();
    maxTrunkLean = null;
    _instructionSet = false;
  }
}
