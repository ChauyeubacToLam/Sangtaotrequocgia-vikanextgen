import 'dart:math';

import '../wall_push_up.dart';
import 'package:vika/utils/debouncer.dart';

class WallContactConfig {
  static const double MAX_HAND_DRIFT_RATIO = 0.14;
}

class WallContactMetric extends WallPushUpMetricBase {
  @override
  String get name => 'WallContact';

  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _anchorErrorDebouncer = Debouncer(requiredFrames: 8);

  double? _baselineScaleFactor;
  double? _repAnchorX;
  double? _repAnchorY;
  bool? _repAnchorUsesFoot;
  double _repMaxDriftRatio = 0;

  @override
  List<FaultRecord> get faults => _faults;

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void captureBaseline(double? value) {
    if (value != null && value > 0) _baselineScaleFactor = value;
  }

  @override
  void update(RepContext ctx) {
    final scale = _baselineScaleFactor ?? ctx.scaleFactor;
    if (scale == null || scale <= 0) {
      return;
    }

    final usesFoot = ctx.footAnchorX != null && ctx.footAnchorY != null;
    final anchorX =
        usesFoot ? ctx.wristAnchorX - ctx.footAnchorX! : ctx.wristAnchorX;
    final anchorY =
        usesFoot ? ctx.wristAnchorY - ctx.footAnchorY! : ctx.wristAnchorY;

    if (_repAnchorUsesFoot == null) {
      _repAnchorUsesFoot = usesFoot;
      _repAnchorX = anchorX;
      _repAnchorY = anchorY;
    }
    if (_repAnchorUsesFoot != usesFoot) {
      return;
    }

    final dx = anchorX - _repAnchorX!;
    final dy = anchorY - _repAnchorY!;
    final anchorDriftRatio = sqrt(dx * dx + dy * dy) / scale;
    if (anchorDriftRatio > _repMaxDriftRatio) {
      _repMaxDriftRatio = anchorDriftRatio;
    }

    _debugData['handAnchorDrift'] = anchorDriftRatio;
    _debugData['handAnchorDriftMax'] = _repMaxDriftRatio;
    _debugData['handAnchorDriftSource'] = usesFoot ? 'wrist-foot' : 'image';

    final phase = ctx.state.toString().split('.').last.toUpperCase();
    final anchorErrorConfirmed = _anchorErrorDebouncer
        .update(anchorDriftRatio > WallContactConfig.MAX_HAND_DRIFT_RATIO);

    if (anchorErrorConfirmed) {
      const message = 'Tay bị di chuyển — giữ tay cố định trên tường.';
      ctx.resultIssues.feedback['Wall'] = message;
      _logFault(phase, message, voiceMessage: 'Chống tay vào tường');
    } else {
      ctx.resultIssues.feedback['Wall'] = 'Tay giữ cố định tốt!';
    }
  }

  void _logFault(String phase, String message, {String? voiceMessage}) {
    if (!_faults.any((f) => f.phase == phase && f.message == message)) {
      _faults.add(FaultRecord(
        phase: phase,
        type: 'hand',
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
    _anchorErrorDebouncer.reset();
    _repAnchorX = null;
    _repAnchorY = null;
    _repAnchorUsesFoot = null;
    _repMaxDriftRatio = 0;
  }
}
