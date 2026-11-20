import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/butterfly_stretch/butterfly_stretch_report_builder.dart';
import 'package:vika/utils/exercise_logger.dart';

ExerciseLogger _logger({required double held, required double target}) =>
    ExerciseLogger()
      ..pushKey('total_seconds', target)
      ..pushKey('good_seconds', held)
      ..pushKey('total_hold_time', held)
      ..pushKey('max_knee_separation', 412.0)
      ..pushKey('knee_seconds', 0.0)
      ..pushKey('posture_seconds', 0.0)
      ..pushKey('foot_placement_seconds', 0.0);

void main() {
  test('no hold-time card: it could only ever read 100%', () {
    final cards = ButterflyReportBuilder()
        .buildDetailCards([_logger(held: 30, target: 30)]);
    expect(cards.map((c) => c.label), isNot(contains('Thời gian Hold')));
  });

  test('no card shows the raw-pixel knee separation', () {
    final cards = ButterflyReportBuilder()
        .buildDetailCards([_logger(held: 30, target: 30)]);
    expect(cards.map((c) => c.label), isNot(contains('Độ mở gối tối đa')));
    expect(cards.map((c) => c.value), isNot(contains('412')));
  });

  test('knee copy describes left/right asymmetry, not knee opening', () {
    final b = ButterflyReportBuilder();
    final label = b.praiseMetricNames()['knee_seconds']!;
    final praise = b.praiseSentenceMap()[label]!(1, 1);
    final tip = b.faultToTipMap()['knee_seconds']!;
    for (final text in [label, praise, tip.watch, tip.next]) {
      expect(text, isNot(contains('mở')), reason: text);
      expect(text, isNot(contains('sàn')), reason: text);
    }
    expect(tip.watch, contains('cao hơn'));
  });

  test('butterfly is still not form-checked in catalog and seed', () {
    final catalog = (jsonDecode(
                File('assets/data/exercise_catalog.json').readAsStringSync())
            as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(
      catalog.singleWhere((e) => e['catalogId'] == 'butterfly')['isFormChecked'],
      isFalse,
    );

    final seed = File('supabase/seed.sql').readAsStringSync();
    final start = seed.indexOf('( -- butterfly');
    expect(start, greaterThanOrEqualTo(0));
    final values = seed
        .substring(start, seed.indexOf('),', start))
        .split('\n')
        .skip(1)
        .map((l) => l.trim().replaceAll(RegExp(r',$'), ''))
        .where((l) => l.isNotEmpty)
        .toList();
    expect(values[10], 'false', reason: 'is_form_checked is column 11');
  });
}
