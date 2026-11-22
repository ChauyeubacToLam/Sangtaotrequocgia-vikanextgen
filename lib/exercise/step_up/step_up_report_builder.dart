import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class StepUpReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['trunk_fails_count'],
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'trunk_fails_count': 'Thân thẳng trên ghế',
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'trunk_fails_count': (
          watch: 'Trong Step-Up: có lúc bạn đổ người ra trước khi đứng trên ghế.',
          next: 'Đứng thẳng người trên ghế, vai ngay trên hông rồi mới bước xuống.',
        ),
        'alternate_fails_count': (
          watch: 'Trong Step-Up: có lúc bạn bước lên bằng cùng một chân hai lần liền.',
          next: 'Đổi chân bước lên sau mỗi rep để hai chân làm việc đều nhau.',
        ),
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
