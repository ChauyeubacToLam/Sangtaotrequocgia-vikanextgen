// ignore_for_file: constant_identifier_names, non_constant_identifier_names

/* =========================================================================
   Lunge Metric: Depth

   Lead knee angle — how deep the user lunges.

   Landmarks: HIP (#23/#24), KNEE (#25/#26), ANKLE (#27/#28) — lead leg
   Calculation: 3-point angle at the lead knee (hip-knee-ankle)

   When to check: Continuously during descending and bottom phases.
   Per-rep evaluation at rep completion (checkRepCompletion) to verify
   the user reached sufficient depth without going too deep.
   ========================================================================= */

import 'lunge_metric_base.dart';
import '../lunge.dart';

class LungeDepthConfig {
  /// Lead knee angle range considered good depth.
  static const List<int> GOOD_DEPTH_RANGE = [55, 125];

  /// Below this = too deep
  static const int TOO_DEEP_THRESHOLD = 55;

  /// Live-text shallow zone: 125° – 150° while descending.
  static const int SHALLOW_WARN_THRESHOLD = 150;
}

class LungeDepthMetric extends LungeMetricBase {
  @override
  String get name => 'Depth';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  /// Tracks minimum lead knee angle this rep (for post-rep analysis)
  double? minKneeAngle;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(LungeRepContext ctx) {
    // Track minimum lead knee angle across the rep
    if (minKneeAngle == null || ctx.leadKneeAngle < minKneeAngle!) {
      minKneeAngle = ctx.leadKneeAngle;
    }

    _debugData['minLeadKneeAngle'] = minKneeAngle?.toStringAsFixed(1) ?? 'N/A';

    final phase = ctx.lungeState.toString().split('.').last.toUpperCase();

    if (ctx.leadKneeAngle < LungeDepthConfig.TOO_DEEP_THRESHOLD) {
      // Too deep
      ctx.resultIssues.feedback['Depth'] = 'Quá sâu! Đứng lên một chút';
      _logFault(phase, 'Quá sâu! Đứng lên một chút');
    } else if (ctx.leadKneeAngle >= LungeDepthConfig.GOOD_DEPTH_RANGE[0] &&
        ctx.leadKneeAngle <= LungeDepthConfig.GOOD_DEPTH_RANGE[1]) {
      // Good depth
      ctx.resultIssues.feedback['Depth'] = 'Độ sâu tốt!';
    } else if (ctx.lungeState == LungeState.descending &&
        ctx.leadKneeAngle > LungeDepthConfig.GOOD_DEPTH_RANGE[1] &&
        ctx.leadKneeAngle <= LungeDepthConfig.SHALLOW_WARN_THRESHOLD) {
      // Shallow — still descending, encourage going lower
      ctx.resultIssues.feedback['Depth'] = 'Xuống thấp hơn';
    } else if (ctx.leadKneeAngle > LungeDepthConfig.SHALLOW_WARN_THRESHOLD) {
      // Too shallow
      ctx.resultIssues.feedback['Depth'] = 'Chưa đủ sâu';
    } else {
      ctx.resultIssues.feedback['Depth'] = 'Độ sâu tốt!';
    }
  }

  // Called by Lunge when a rep completes. A counted rep always entered
  // `bottom` (lead knee <= 125), so only "too deep" can apply here; shallow
  // attempts are rejected by Lunge (rejected_shallow_attempts_count).
  void checkRepCompletion(LungeState finalState, LungeRepContext ctx) {
    final phase = finalState.toString().split('.').last.toUpperCase();

    if (minKneeAngle == null) return;

    if (minKneeAngle! < LungeDepthConfig.TOO_DEEP_THRESHOLD) {
      _logFault(phase, 'Quá sâu! Đứng lên một chút');
    }
  }

  void _logFault(String phase, String message, {String? voiceMessage}) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'depth')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'depth',
        message: message,
        voiceMessage: voiceMessage,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    minKneeAngle = null;
  }
}
