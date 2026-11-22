import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/tricep_dip/tricep_dip.dart';
import 'package:vika/exercise/tricep_dip/tricep_dip_report_builder.dart';
import 'package:vika/models/exercise_definition.dart';

PoseLandmark _lm(PoseLandmarkType type, double x, double y) =>
    PoseLandmark(type: type, x: x, y: y, z: 0, likelihood: 0.99);

Map<PoseLandmarkType, PoseLandmark> _pose({required bool bent}) => {
      PoseLandmarkType.leftEar: _lm(PoseLandmarkType.leftEar, 180, 160),
      PoseLandmarkType.leftShoulder: _lm(PoseLandmarkType.leftShoulder, 200, 200),
      PoseLandmarkType.leftElbow: bent
          ? _lm(PoseLandmarkType.leftElbow, 150, 350)
          : _lm(PoseLandmarkType.leftElbow, 250, 300),
      PoseLandmarkType.leftWrist: _lm(PoseLandmarkType.leftWrist, 300, 400),
      PoseLandmarkType.leftHip: _lm(PoseLandmarkType.leftHip, 400, 350),
      PoseLandmarkType.leftAnkle: _lm(PoseLandmarkType.leftAnkle, 600, 400),
    };

TricepDip _oneRep() {
  final e = TricepDip(maxRep: 10)
    ..cameraFacing = CameraFacing.left
    ..exerciseState = ExerciseState.activated;
  expect(e.isInStartPosition(_pose(bent: false)), isTrue);
  for (var i = 1; i <= 8; i++) {
    e.frameTimestamp = DateTime.fromMillisecondsSinceEpoch(i * 100);
    e.checkingPose(_pose(bent: i <= 4));
  }
  expect(e.repCount, 1);
  return e;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog marks tricep_dip as not form-checked', () {
    final catalog = jsonDecode(
            File('assets/data/exercise_catalog.json').readAsStringSync())
        as List<dynamic>;
    final entry = catalog.cast<Map<String, dynamic>>().singleWhere(
        (e) => e['catalogId'] == 'tricep_dip');
    expect(entry['isFormChecked'], isFalse);
  });

  test('seed marks tricep_dip as not form-checked', () {
    final seed = File('supabase/seed.sql').readAsStringSync();
    final start = seed.indexOf('( -- tricep_dip');
    expect(start, greaterThanOrEqualTo(0));
    final row = seed.substring(start, seed.indexOf('),', start));
    // Columns: ..., pain_safe, pain_contraindicated, is_form_checked, ...
    final values = row
        .split('\n')
        .skip(1)
        .map((l) => l.trim().replaceAll(RegExp(r',$'), ''))
        .where((l) => l.isNotEmpty)
        .toList();
    expect(values[10], 'false', reason: 'is_form_checked is column 11');
  });

  test('no report card or praise presents the unwired checks', () {
    final e = _oneRep()..onSetComplete();
    final builder = TricepDipReportBuilder();
    expect(builder.buildDetailCards([e.logger]), isEmpty);
    expect(builder.praiseMetricNames(), isEmpty);
    expect(e.logger.setLogs.keys.where((k) => k.endsWith('_fails_count')),
        isEmpty);
  });

  test('result text is Vietnamese', () {
    final e = _oneRep();
    expect(e.resultIssues.feedback['Result'], 'Tốt lắm!');
  });

  test('setup copy asks for the side view checkSafety requires', () {
    final def =
        exerciseDefinitions.firstWhere((d) => d.id == 'tricep__dip_(_floor)');
    expect(def.cameraHint, isNot(contains('đối diện')));
    expect(def.cameraHint, contains('nghiêng'));
  });
}
