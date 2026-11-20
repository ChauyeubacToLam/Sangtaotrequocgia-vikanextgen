import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/2.Sit-Up/sit_up_report_builder.dart';
import 'package:vika/utils/exercise_logger.dart';

ExerciseLogger _logger(List<List<String>> faultTypesPerRep) {
  final logger = ExerciseLogger();
  var n = 0;
  for (final types in faultTypesPerRep) {
    n++;
    logger.addRepLog(RepLog(
      correctForm: types.isEmpty,
      repNumber: n,
      data: {'fault_types': types, 'lowering_time': 1.0},
    ));
  }
  return logger;
}

void main() {
  test('movement card counts the real lowercase jerking fault type', () {
    final cards = SitUpReportBuilder().buildDetailCards([
      _logger([
        ['jerking'],
        [],
        [],
        [],
      ])
    ]);
    final movement = cards.singleWhere((c) => c.label == 'Mượt (An toàn)');
    expect(movement.value, '75%');
  });

  test('no card presents a check the code cannot fail or does not enforce',
      () {
    final cards = SitUpReportBuilder().buildDetailCards([
      _logger([[], []])
    ]);
    // rom can never fire on a counted rep (threshold == counting gate 142).
    expect(cards.where((c) => c.label == 'Full ROM'), isEmpty);
    // Lowering speed is deliberately unrestricted: no target is shown.
    for (final card in cards) {
      expect(card.subLabel ?? '', isNot(contains('Mục tiêu')),
          reason: card.label);
    }
  });

  test('praise does not cite the never-faulted lowering tempo', () {
    expect(SitUpReportBuilder().praiseMetricNames().keys,
        isNot(contains('tempo_fails_count')));
  });
}
