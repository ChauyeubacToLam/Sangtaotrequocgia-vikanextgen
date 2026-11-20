import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vika/models/exercise_lookup.dart';
import 'package:vika/models/kept_exercises.dart';
import 'package:vika/screens/onboarding/quick_start/quick_start_goal_screen.dart';
import 'package:vika/screens/onboarding/quick_start/quick_start_navigator.dart';
import 'package:vika/screens/onboarding/quick_start/quick_start_programs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('quick start programs', () {
    test('every exercise is kept, in the catalog and launchable', () {
      final rows = jsonDecode(
        File('assets/data/exercise_catalog.json').readAsStringSync(),
      ) as List;
      final catalogIds = {for (final row in rows) (row as Map)['catalogId']};

      for (final program in quickPrograms) {
        expect(program.exerciseIds, isNotEmpty, reason: program.id);
        for (final id in program.exerciseIds) {
          final where = '${program.id}: $id';
          expect(keptExerciseIds, contains(id), reason: '$where is hidden');
          expect(catalogIds, contains(id), reason: '$where not in catalog');
          expect(
            lookupExerciseDefinition(id),
            isNotNull,
            reason: '$where has no exercise definition',
          );
        }
      }
      expect(
        {for (final program in quickPrograms) program.id}.length,
        quickPrograms.length,
        reason: 'program ids must be unique',
      );
      for (final goal in QuickGoal.values) {
        expect(programsFor(goal), isNotEmpty, reason: goal.name);
      }
    });

    test('recommended level follows age and goal', () {
      String level(int age, QuickGoal goal) =>
          recommendedLevel(age: age, goal: goal);

      expect(level(16, QuickGoal.muscle), 'beginner');
      expect(level(17, QuickGoal.famous), 'beginner');
      expect(level(18, QuickGoal.muscle), 'intermediate');
      expect(level(49, QuickGoal.famous), 'intermediate');
      expect(level(50, QuickGoal.muscle), 'beginner');
      expect(level(80, QuickGoal.famous), 'beginner');
      // The pain branch starts light at any age.
      expect(level(30, QuickGoal.pain), 'beginner');
      // The hardest level is never suggested.
      for (var age = quickMinAge; age <= quickMaxAge; age++) {
        for (final goal in QuickGoal.values) {
          expect(level(age, goal), isNot('advanced'));
        }
      }
    });

    test('sets grow with the level', () {
      expect(quickLevels.map(setsForLevel), [1, 2, 3]);
    });
  });

  for (final size in const [Size(390, 844), Size(320, 568)]) {
    testWidgets('B2 goes from goal cards to an enabled CTA at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      QuickGoal? goal;
      QuickProgram? program;
      String? level;
      var age = quickDefaultAge;
      var continued = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => QuickStartGoalScreen(
                goal: goal,
                program: program,
                age: age,
                level: level,
                onGoal: (g) => setState(() {
                  goal = g;
                  program = null;
                }),
                onProgram: (p) => setState(() => program = p),
                onAge: (a) => setState(() => age = a),
                onLevel: (l) => setState(() => level = l),
                onNext: () => continued++,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1600));

      // Three goal cards, no CTA yet.
      expect(find.text('Đau mỏi, giãn cơ'), findsOneWidget);
      expect(find.text('Bài tập nổi tiếng'), findsOneWidget);
      expect(find.text('Tiếp tục'), findsNothing);

      await tester.tap(find.text('Tăng cơ, giảm mỡ'));
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('Giảm mỡ toàn thân'), findsOneWidget);
      expect(find.text('Chọn một bài để tiếp'), findsOneWidget);
      // Age 28, muscle goal: "Vừa sức" is suggested and preselected.
      expect(find.text('Gợi ý'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Giảm mỡ toàn thân'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Tiếp tục'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(continued, 1);

      // Switching goal drops the program picked under the old goal.
      await tester.tap(find.text('Nổi tiếng'));
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('Herschel Walker'), findsOneWidget);
      expect(find.text('Chọn một bài để tiếp'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1600));
    });
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // Dummy project: nothing in these tests reaches the network.
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  for (final size in const [Size(390, 844), Size(320, 568)]) {
    testWidgets('B1 renders, toggles and validates at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var tookOverAuth = false;
      await tester.pumpWidget(
        MaterialApp(
          home: QuickStartNavigator(onTakeOverAuth: () => tookOverAuth = true),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1600));

      expect(tester.takeException(), isNull);
      expect(tookOverAuth, isTrue);
      expect(find.text('Tạo tài khoản'), findsNWidgets(2)); // tab + button
      expect(find.textContaining('16 tuổi'), findsOneWidget);

      await tester.tap(find.text('Đăng nhập').first);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('Chào mừng'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsNWidgets(2));

      await tester.tap(find.text('Đăng nhập').last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Email chưa đúng định dạng.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1600));
    });
  }
}
