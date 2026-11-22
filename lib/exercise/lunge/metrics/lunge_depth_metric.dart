// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'lunge_metric_base.dart';
import '../lunge.dart';

class LungeDepthConfig {
  static const int GOOD_DEPTH_MAX = 125;
  static const int SHALLOW_WARN_THRESHOLD = 150;
}

class LungeDepthMetric extends LungeMetricBase {
  @override
  String get name => 'Depth';

  final Map<String, dynamic> _debugData = {};

  double? minKneeAngle;

  @override
  List<FaultRecord> get faults => const <FaultRecord>[];

  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  void update(LungeRepContext ctx) {
    if (minKneeAngle == null || ctx.leadKneeAngle < minKneeAngle!) {
      minKneeAngle = ctx.leadKneeAngle;
    }

    _debugData['minLeadKneeAngle'] = minKneeAngle?.toStringAsFixed(1) ?? 'N/A';

    if (ctx.leadKneeAngle <= LungeDepthConfig.GOOD_DEPTH_MAX) {
      ctx.resultIssues.feedback['Depth'] = 'Độ sâu tốt!';
    } else if (ctx.leadKneeAngle > LungeDepthConfig.SHALLOW_WARN_THRESHOLD) {
      ctx.resultIssues.feedback['Depth'] = 'Chưa đủ sâu';
    } else if (ctx.lungeState == LungeState.descending) {
      ctx.resultIssues.feedback['Depth'] = 'Xuống thấp hơn';
    } else {
      ctx.resultIssues.feedback['Depth'] = 'Độ sâu tốt!';
    }
  }

  @override
  void reset() {
    _debugData.clear();
    minKneeAngle = null;
  }
}
