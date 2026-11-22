import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';

class NeckSideStretchReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'shoulder_neck': ['shrug_fails_count', 'shoulder_fails_count'],
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'shrug_fails_count': 'Vai thả lỏng',
        'shoulder_fails_count': 'Vai giữ ngang',
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'shrug_fails_count': (
          watch: 'Trong giãn cổ nghiêng: vai có lúc nhún lên khi nghiêng đầu.',
          next: 'Thả hai vai xuống xa tai trước, rồi mới nghiêng đầu.',
        ),
        'shoulder_fails_count': (
          watch: 'Trong giãn cổ nghiêng: vai có lúc nghiêng theo đầu.',
          next: 'Giữ hai vai ngang, chỉ đưa tai về phía vai.',
        ),
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
