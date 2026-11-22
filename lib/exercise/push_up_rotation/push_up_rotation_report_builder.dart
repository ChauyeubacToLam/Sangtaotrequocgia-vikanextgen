import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class PushUpRotationReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['body_line_fails_count'],
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'body_line_fails_count': 'Thân thẳng khi chống đẩy',
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'body_line_fails_count': (
          watch:
              'Trong chống đẩy xoay người: hông có lúc võng hoặc nhô khi chống đẩy.',
          next: 'Siết bụng để vai, hông và cổ chân thành một đường thẳng.',
        ),
        'alternate_fails_count': (
          watch: 'Trong chống đẩy xoay người: có lúc bạn mở cùng một tay hai lần liền.',
          next: 'Đổi tay mở lên trần sau mỗi rep.',
        ),
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
