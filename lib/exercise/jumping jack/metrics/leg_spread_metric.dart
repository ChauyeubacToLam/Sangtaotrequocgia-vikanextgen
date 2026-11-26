/* =========================================================================
   Metric 2: Leg Spread
   Priority: IMPORTANT — Ship Day 2
   
   Measures foot separation in the OPEN position, normalized to
   shoulder width. Ensures user is performing a complete jumping jack
   rather than just waving arms.
   
   Detection strategy:
   - ankleSpreadNorm = distance(leftAnkle, rightAnkle) / shoulderWidth
   - The open gate already needs spread > 0.85, so a rep always opened at
     least that wide; the fault is the per-rep peak below 1.4 (rep end).
   - Live text only while the frame still meets the open gate (not during
     the closing movement, when the feet pass through narrow spreads).
   
   Thresholds (normalized to shoulder width):
     Good:     peak spread >= 1.4× shoulder width
     Fault:    peak spread 0.85–1.4× (logged at rep end)
   
   Vietnamese context:
   - Small apartment tile floors can be slippery
   - Bare feet common at home — may limit willingness to jump wide
   - Frame as encouragement, not criticism
   ========================================================================= */

import 'jumping_jack_metric_base.dart';
import '../jumping_jack.dart';

class LegSpreadConfig {
  /// Good: feet clearly spread wider than shoulders
  // ignore: constant_identifier_names
  static const double SPREAD_GOOD = 1.4;
}

class LegSpreadMetric extends JJMetricBase {
  @override
  String get name => 'LegSpread';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  /// Track peak spread this rep
  double _peakSpread = 0.0;

  /// Prevent instruction spam
  bool _instructionSet = false;

  double get peakSpread => _peakSpread;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(RepContext ctx) {
    // Track peak spread
    if (ctx.ankleSpreadNorm > _peakSpread) {
      _peakSpread = ctx.ankleSpreadNorm;
    }

    _debugData['ankleSpread'] = ctx.ankleSpreadNorm.toStringAsFixed(2);
    _debugData['peakSpread'] = _peakSpread.toStringAsFixed(2);

    // Only the open position itself: not in CLOSED, and not once the
    // closing movement has begun (frame no longer meets the open gate).
    if (ctx.jjState != JJState.open || !ctx.meetsOpenGate) {
      if (ctx.resultIssues.feedback['Legs'] == null) {
        ctx.resultIssues.feedback['Legs'] = 'Chuẩn bị';
      }
      return;
    }

    bool mediumStance = ctx.ankleSpreadNorm < LegSpreadConfig.SPREAD_GOOD;

    if (mediumStance) {
      ctx.resultIssues.feedback['Legs'] = 'Rộng hơn chút!';
      if (!_instructionSet) {
        // Legacy UI instruction copy: Cố gắng mở rộng chân hơn lần sau!
        _instructionSet = true;
      }
    } else {
      ctx.resultIssues.feedback['Legs'] = 'Chân tốt!';
    }

    _debugData['legStatus'] = ctx.resultIssues.feedback['Legs'] ?? '';
  }

  /// Called by JumpingJack when rep completes.
  void evaluateRep(RepContext ctx) {
    if (_peakSpread < LegSpreadConfig.SPREAD_GOOD) {
      _logFault('REP_COMPLETE',
          'Chân chưa đủ rộng (${_peakSpread.toStringAsFixed(1)}×)',
          voiceMessage: 'Mở chân rộng hơn');
    }
  }

  void _logFault(String phase, String message, {String? voiceMessage}) {
    if (!_faults.any((f) => f.phase == phase && f.type == 'legs')) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'legs',
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
    _peakSpread = 0.0;
    _instructionSet = false;
  }
}
