/* =========================================================================
   Metric 1: Arm Extension
   Priority: CRITICAL — Ship Day 1
   
   Detects whether arms fully extend overhead during the OPEN phase.
   This is the primary quality indicator — lazy jumping jacks with
   bent arms or low reach are the #1 form error.
   
   Detection strategy:
   - Arm height is enforced by the open gate (both wrists above the nose,
     average hip-shoulder-wrist angle > 90°): an attempt without it is not
     a rep, so no elevation fault is logged here.
   - Elbow straightness: shoulder→elbow→wrist angle (180° = straight),
     checked only while the frame still meets the open gate.
   
   Thresholds:
     Good:     elbows >= 135°
     Warning:  elbows 105°-135° (live text only)
     Error:    elbows < 105° for 3 frames
   
   Vietnamese desk worker context:
   - Tight shoulders from hunching over laptops limit overhead reach
   - Start lenient for beginners, tighten as users progress
   - Encouraging feedback, never harsh
   ========================================================================= */

import 'jumping_jack_metric_base.dart';
import '../jumping_jack.dart';
import '../../../utils/debouncer.dart';

class ArmExtensionConfig {
  // -- Elbow straightness thresholds (shoulder→elbow→wrist angle) --
  /// Good: arms nearly straight
  // ignore: constant_identifier_names
  static const double ELBOW_GOOD = 135.0;

  /// Warning: noticeably bent
  // ignore: constant_identifier_names
  static const double ELBOW_WARNING = 105.0;

  // Below ELBOW_WARNING = error
}

class ArmExtensionMetric extends JJMetricBase {
  @override
  String get name => 'ArmExtension';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  // Fast movement → low debounce frames
  final Debouncer _elbowDebouncer = Debouncer(requiredFrames: 3);

  /// Track peak elevation this rep (for post-rep analysis)
  double _peakLeftElevation = 0.0;
  double _peakRightElevation = 0.0;

  /// Prevent instruction spam — only set coaching once per rep.
  bool _elbowInstructionSet = false;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    // Track peak elevation
    if (ctx.leftArmElevation > _peakLeftElevation) {
      _peakLeftElevation = ctx.leftArmElevation;
    }
    if (ctx.rightArmElevation > _peakRightElevation) {
      _peakRightElevation = ctx.rightArmElevation;
    }

    _debugData['leftElev'] = ctx.leftArmElevation.toStringAsFixed(1);
    _debugData['rightElev'] = ctx.rightArmElevation.toStringAsFixed(1);
    _debugData['leftElbow'] = ctx.leftArmAngle.toStringAsFixed(1);
    _debugData['rightElbow'] = ctx.rightArmAngle.toStringAsFixed(1);
    _debugData['peakElev'] =
        '${_peakLeftElevation.toStringAsFixed(0)}° / ${_peakRightElevation.toStringAsFixed(0)}°';

    // Only evaluate the open position itself: not in CLOSED, and not once
    // the closing movement has begun (frame no longer meets the open gate).
    if (ctx.jjState != JJState.open || !ctx.meetsOpenGate) {
      // During CLOSED phase, show neutral status
      if (ctx.resultIssues.feedback['Arms'] == null) {
        ctx.resultIssues.feedback['Arms'] = 'Chuẩn bị';
      }
      return;
    }

    {
      // Elevation is guaranteed by the open gate — check elbow straightness
      final minElbow = ctx.leftArmAngle < ctx.rightArmAngle
          ? ctx.leftArmAngle
          : ctx.rightArmAngle;

      bool bentElbow = minElbow < ArmExtensionConfig.ELBOW_WARNING;
      bool softElbow = minElbow >= ArmExtensionConfig.ELBOW_WARNING &&
          minElbow < ArmExtensionConfig.ELBOW_GOOD;

      if (_elbowDebouncer.update(bentElbow)) {
        ctx.resultIssues.feedback['Arms'] = 'Duỗi thẳng tay!';
        if (!_elbowInstructionSet) {
          // Legacy UI instruction copy: Duỗi thẳng khuỷu tay lần sau!
          _elbowInstructionSet = true;
        }
        _logFault('OPEN', 'Khuỷu tay gập nhiều');
      } else if (softElbow) {
        ctx.resultIssues.feedback['Arms'] = 'Duỗi tay thêm!';
      } else {
        ctx.resultIssues.feedback['Arms'] = 'Tay tốt!';
      }
    }

    _debugData['armStatus'] = ctx.resultIssues.feedback['Arms'] ?? '';
  }

  void _logFault(String phase, String message) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'arms')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'arms',
        message: message,
        affectsForm: true,
      ));
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _elbowDebouncer.reset();
    _peakLeftElevation = 0.0;
    _peakRightElevation = 0.0;
    _elbowInstructionSet = false;
  }
}
