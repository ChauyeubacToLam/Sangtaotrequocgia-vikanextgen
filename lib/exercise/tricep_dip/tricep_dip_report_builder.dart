import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/interpreter/interpreter_base.dart';
import 'package:vika/utils/exercise_logger.dart';

/// Tricep Dip (floor) counts hip lifts only; its four form metrics are not
/// wired (they assume a bar-dip state machine). So this builder shows no
/// detail cards, praise, tips or pain mapping: none of them could ever show a
/// value other than perfect. The catalog marks it `isFormChecked: false`.
class TricepDipReportBuilder extends ExerciseReportBuilder {
  @override
  DetectedEvidence? detectIssue(List<ExerciseLogger> setLoggers) {
    return null;
  }
}
