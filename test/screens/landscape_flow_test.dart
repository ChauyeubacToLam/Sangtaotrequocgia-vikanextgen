import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/models/exercise_definition.dart';
import 'package:vika/models/exercise_lookup.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/screens/exercise/exercise_intro_page.dart';
import 'package:vika/screens/exercise/exercise_transition_moment.dart';
import 'package:vika/screens/exercise/rest_screen.dart';
import 'package:vika/screens/exercise/widgets/sensor_rotated_box.dart';
import 'package:vika/utils/exercise_logger.dart';

Future<void> _loadFonts() async {
  final vietnam = FontLoader('BeVietnamPro');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/be_vietnam_pro/BeVietnamPro-$weight.ttf')
        .readAsBytesSync();
    vietnam.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
  }
  await vietnam.load();
}

Future<void> _pumpLandscape(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final stream = StreamController<VikaImageOrientation>();
  addTearDown(stream.close);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SensorRotatedBox(
          orientationStream: stream.stream,
          initialOrientation: Future<VikaImageOrientation>.value(
            VikaImageOrientation.landscapeLeft,
          ),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets(
      'SensorRotatedBox follows the sensor between portrait and landscape',
      (tester) async {
    final stream = StreamController<VikaImageOrientation>();
    addTearDown(stream.close);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SensorRotatedBox(
          orientationStream: stream.stream,
          initialOrientation: Future<VikaImageOrientation>.value(
            VikaImageOrientation.portrait,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    RotatedBox box() => tester.widget<RotatedBox>(find.byType(RotatedBox));
    expect(box().quarterTurns, 0);

    stream.add(VikaImageOrientation.landscapeLeft);
    await tester.pump();
    await tester.pump();
    expect(
      box().quarterTurns,
      VikaImageOrientation.landscapeLeft.uiQuarterTurns,
    );

    stream.add(VikaImageOrientation.landscapeRight);
    await tester.pump();
    await tester.pump();
    expect(
      box().quarterTurns,
      VikaImageOrientation.landscapeRight.uiQuarterTurns,
    );

    stream.add(VikaImageOrientation.portraitUpsideDown);
    await tester.pump();
    await tester.pump();
    expect(box().quarterTurns, 0);
  });

  test('Android preview texture cancels the landscape page rotation', () {
    for (final orientation in VikaImageOrientation.values) {
      final page = orientation.uiQuarterTurns;
      final texture = orientation.androidPreviewTextureQuarterTurns;
      if (orientation.isLandscape) {
        expect((page + texture) % 4, 0, reason: orientation.name);
        expect(texture, isNot(0), reason: orientation.name);
      } else {
        expect(texture, 0, reason: orientation.name);
      }
    }
  });

  testWidgets('RestScreen lays out without overflow when the phone is landscape',
      (tester) async {
    final logger = ExerciseLogger()
      ..addRepLog(
        RepLog(
          repNumber: 1,
          correctForm: false,
          data: <String, dynamic>{
            'fault_types': <String>['depth'],
          },
        ),
      );
    await _pumpLandscape(
      tester,
      RestScreen(
        setReport: const SetReportData(
          setIndex: 0,
          score: 62,
          totalReps: 10,
          goodReps: 6,
          repResults: <bool>[true, false, true, true, false],
          praiseSentence: 'Tốt lắm! Cứ giữ form đẹp như vậy.',
          coachTip: 'Dồn lực qua gót chân.',
        ),
        setIndex: 0,
        totalSets: 2,
        currentReps: 10,
        baseRestSeconds: 45,
        isLastSet: false,
        exerciseName: 'Squat',
        setLogger: logger,
        aiVisibleRatio: 0.9,
        onReportFault: (_, __) {},
        onNext: () {},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('AI nhìn rõ 90% thời gian tập'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('RestScreen export button pauses the rest timer while sharing',
      (tester) async {
    final completer = Completer<bool>();
    var calls = 0;
    var advanced = false;
    await _pumpLandscape(
      tester,
      RestScreen(
        setReport: const SetReportData(
          setIndex: 0,
          score: 80,
          totalReps: 2,
          goodReps: 2,
          repResults: <bool>[true, true],
        ),
        setIndex: 0,
        totalSets: 2,
        currentReps: 2,
        baseRestSeconds: 3,
        isLastSet: false,
        exerciseName: 'Squat',
        onExportLogs: (_) {
          calls += 1;
          return completer.future;
        },
        onNext: () => advanced = true,
      ),
    );
    final button = find.text('XUẤT TỆP NHẬT KÝ');
    await tester.ensureVisible(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    expect(advanced, isFalse);

    completer.complete(true);
    await tester.pump();
    await tester.pump();
    expect(find.text('XUẤT TỆP NHẬT KÝ'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(advanced, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'ExerciseIntroPage lays out without overflow when the phone is landscape',
      (tester) async {
    final def = lookupExerciseDefinition('squat')!;
    await _pumpLandscape(
      tester,
      ExerciseIntroPage(
        title: def.displayName,
        exerciseId: 'squat',
        safetyWarning: def.safetyWarning,
        previousExerciseId: 'plank',
        difficulty: def.difficulty,
        totalSets: 2,
        repsPerSet: 10,
        muscles: def.targetMuscles,
        tips: def.setupTips,
        badges: const <ExerciseIntroBadge>[],
        callouts: const [],
        coachNote: '',
        onStart: () {},
        onBack: () {},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Giữ nguyên vị trí máy'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'ExerciseTransitionMoment lays out without overflow when the phone is landscape',
      (tester) async {
    await _pumpLandscape(
      tester,
      ExerciseTransitionMoment(
        exerciseName: 'Squat',
        formScore: 72,
        setResults: const <SetReportData>[
          SetReportData(
            setIndex: 0,
            score: 72,
            totalReps: 8,
            goodReps: 6,
            repResults: <bool>[true, true, false, true, true, false, true, true],
          ),
        ],
        nextExerciseName: 'Bài tiếp theo · Chống đẩy',
        onComplete: () {},
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
