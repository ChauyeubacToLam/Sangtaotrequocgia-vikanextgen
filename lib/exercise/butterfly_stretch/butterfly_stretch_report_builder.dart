import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/interpreter/interpreter_base.dart';

class ButterflyReportBuilder extends ExerciseReportBuilder {
  @override
  bool get isSecondBased => true;

  @override
  Map<String, List<String>> painToFaultMap() => {
        'hip': ['knee_seconds', 'foot_placement_seconds'],
        'lower_back': ['posture_seconds'],
        'knee': ['knee_seconds'],
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'knee_seconds': 'Gối cân bằng',
        'posture_seconds': 'Lưng thẳng',
        'foot_placement_seconds': 'Vị trí chân',
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'knee_seconds': (
          watch: 'Trong Butterfly: có lúc một gối cao hơn gối kia.',
          next: 'Thả lỏng cả hai bên hông để hai gối hạ ngang nhau, đừng ép một bên bằng tay.',
        ),
        'posture_seconds': (
          watch: 'Trong Butterfly: lưng có lúc bị gù xuống.',
          next: 'Ngồi cao như có sợi dây kéo đỉnh đầu lên, mở ngực.',
        ),
        'foot_placement_seconds': (
          watch: 'Trong Butterfly: gót chân để hơi xa hông.',
          next: 'Kéo hai gót chân lại gần hông để tăng độ giãn ở háng.',
        ),
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Gối cân bằng': (c, t) =>
            'Hai gối giữ ngang nhau, không bên cao bên thấp!',
        'Lưng thẳng': (c, t) => 'Lưng giữ thẳng suốt bài - tư thế rất đẹp!',
        'Vị trí chân': (c, t) => 'Gót chân đặt sát hông - độ giãn đạt tối đa!',
      };

  // No detail cards. A "Thời gian Hold" ring read 100% for every set that
  // reaches the summary (only completed holds add time, and the summary is
  // built after every hold completes). max_knee_separation is in raw pixels
  // and has no camera-independent scale to show it against.

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }
}
