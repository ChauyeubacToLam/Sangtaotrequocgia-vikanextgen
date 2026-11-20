import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class SidePlankDipReportBuilderV2 extends ExerciseReportBuilder {
  @override
  Map<String, String> praiseMetricNames() => {
        'shoulder_align_fails_count': 'Vai an toàn',
        'dip_depth_fails_count': 'Đường thẳng thân người',
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'shoulder_align_fails_count': (
          watch: 'Trong Side Plank: khuỷu tay có lúc lệch khỏi trục dưới vai.',
          next: 'Đặt khuỷu tay thẳng ngay dưới vai trước khi nâng hông lên.',
        ),
        'dip_depth_fails_count': (
          watch:
              'Trong Side Plank: vai, hông và cổ chân có lúc không còn thẳng hàng.',
          next: 'Nâng hông để vai, hông và cổ chân nằm trên một đường thẳng.',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Vai an toàn': (c, t) =>
            'Khuỷu tay thẳng trục $c/$t lần giữ - khớp vai an toàn!',
        'Đường thẳng thân người': (c, t) =>
            'Giữ thân thẳng ổn định trong $c/$t lần giữ!',
      };

  @override
  Map<String, List<String>> painToFaultMap() => {
        'shoulder_neck': ['shoulder_align_fails_count'],
        'hip': ['dip_depth_fails_count'],
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
