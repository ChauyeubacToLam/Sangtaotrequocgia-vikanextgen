import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

// depth_fails_count is not used here: a push-up only counts after reaching
// bottom, so that key is always 0 and would show a permanent perfect score.
// Shallow attempts are rejected live instead ("Xuống thấp hơn nhé").
class PushUpReportBuilder extends ExerciseReportBuilder {
  @override
  Map<String, List<String>> painToFaultMap() => {
        'lower_back': ['trunk_alignment_fails_count'],
        'shoulder_neck': ['tempo_fails_count'],
        'wrist': ['tempo_fails_count'],
      };

  @override
  Map<String, FaultTipCopy> faultToTipMap() => {
        'trunk_alignment_fails_count': (
          watch: 'Trong Push Up: thân người có lúc võng hoặc chổng hông.',
          next:
              'Đẩy sàn ra xa, kéo khóa quần về rốn và giữ vai-hông-gót trên một đường.',
        ),
        'tempo_fails_count': (
          watch: 'Trong Push Up: nhịp hạ có lúc hơi vội.',
          next: 'Đi xuống như thang máy chậm, đếm một-nhẹ-hai rồi mới đẩy lên.',
        ),
      };

  @override
  Map<String, String> praiseMetricNames() => {
        'trunk_alignment_fails_count': 'Thân người',
        'tempo_fails_count': 'Nhịp hạ',
      };

  @override
  Map<String, String Function(int count, int total)> praiseSentenceMap() => {
        'Thân người': (c, t) =>
            'Thân người giữ thẳng $c/$t rep - lực đẩy sạch hơn hẳn.',
        'Nhịp hạ': (c, t) =>
            'Nhịp hạ kiểm soát $c/$t rep - vai và cổ tay được chăm tốt.',
      };

  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) => null;
}
