import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vika/screens/exercise/exercise_intro_page.dart';
import 'package:vika/screens/exercise/widgets/exercise_guide_video.dart';

Widget _intro() => MaterialApp(
      home: ExerciseIntroPage(
        title: 'Squat',
        exerciseId: 'squat',
        difficulty: 'Cơ bản',
        totalSets: 2,
        repsPerSet: 10,
        muscles: const [],
        tips: const [],
        badges: const [],
        callouts: const [],
        coachNote: '',
        videoAsset: 'assets/video/squat.mp4',
        onStart: () {},
        onBack: () {},
      ),
    );

void main() {
  testWidgets('first visit opens the guide video, skip marks it seen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_intro());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ExerciseGuideVideoPage), findsOneWidget);
    await tester.tap(find.text('Bỏ qua'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ExerciseGuideVideoPage), findsNothing);
    expect(find.text('BẮT ĐẦU TẬP'), findsOneWidget);
    expect(await guideVideoSeen('squat'), isTrue);
  });

  testWidgets('later visits go straight to the intro', (tester) async {
    SharedPreferences.setMockInitialValues({'${kGuideVideoSeenPrefix}squat': true});
    await tester.pumpWidget(_intro());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ExerciseGuideVideoPage), findsNothing);
    expect(find.text('Xem video mẫu'), findsOneWidget);
  });
}
