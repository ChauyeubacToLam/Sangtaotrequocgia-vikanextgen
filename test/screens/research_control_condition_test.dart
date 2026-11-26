import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vika/exercise/bow_pose/bow_pose.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/plank/plank.dart';
import 'package:vika/exercise/squat/squat.dart';
import 'package:vika/models/exercise_definition.dart';
import 'package:vika/models/exercise_lookup.dart';
import 'package:vika/models/post_exercise_data.dart';
import 'package:vika/models/workout_session_report.dart';
import 'package:vika/screens/exercise/active_exercise_page.dart';
import 'package:vika/screens/exercise/exercise_experience_screen.dart';
import 'package:vika/screens/exercise/exercise_intro_page.dart';
import 'package:vika/screens/exercise/exercise_transition_moment.dart';
import 'package:vika/screens/exercise/rest_screen.dart';
import 'package:vika/screens/exercise/widgets/form_score_arc.dart';
import 'package:vika/screens/exercise/widgets/pose_overlay_painter.dart';
import 'package:vika/screens/exercise/widgets/rep_hero.dart';
import 'package:vika/screens/exercise/widgets/rep_reward_layer.dart';
import 'package:vika/screens/exercise/widgets/skeleton_annotation.dart';
import 'package:vika/screens/exercise/workout_summary_screen.dart';
import 'package:vika/screens/research_settings_screen.dart';
import 'package:vika/services/bow_pose_voice_coach.dart';
import 'package:vika/services/catalog/catalog_source.dart';
import 'package:vika/services/plank_voice_coach.dart';
import 'package:vika/services/recommendation/recommendation_service.dart'
    show ExerciseLaunchCatalogInfo;
import 'package:vika/services/research/research_log_storage.dart';
import 'package:vika/services/research/research_preferences.dart';
import 'package:vika/services/research/research_voice_sink.dart';
import 'package:vika/services/research/set_recorder.dart';
import 'package:vika/services/session_coach_builder.dart';
import 'package:vika/services/session_summary_builder.dart';
import 'package:vika/services/session_trophy_picker.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/voice/voice_sink.dart';
import 'package:vika/screens/exercise/widgets/exercise_guide_video.dart';
import 'package:vika/widgets/exercise/session_satisfaction_dialog.dart';

class _FakeResearchLogStorage extends ResearchLogStorage {
  _FakeResearchLogStorage(this._files);
  final List<File> _files;

  @override
  Future<List<File>> listStoredLogFiles() async => _files;
}

class _SpyAssetVoiceSink extends AssetVoiceSink {
  _SpyAssetVoiceSink(this._delegate) : super(voiceSet: _delegate.voiceSet);
  final AssetVoiceSink _delegate;
  final List<String> forwardedKeys = <String>[];
  int clearPendingCount = 0;

  @override
  bool get isBusy => _delegate.isBusy;

  @override
  Future<void> playKey(
    String logicalKey, {
    bool Function()? isStillRelevant,
  }) {
    forwardedKeys.add(logicalKey);
    return _delegate.playKey(logicalKey, isStillRelevant: isStillRelevant);
  }

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) =>
      _delegate.waitUntilIdle(timeout: timeout);

  @override
  void clearPending() {
    clearPendingCount++;
    _delegate.clearPending();
  }

  @override
  Future<void> stop() => _delegate.stop();

  @override
  void dispose() => _delegate.dispose();
}

class _ControllableActivationSquat extends Squat {
  _ControllableActivationSquat({super.maxRep});
  double? overrideActivationProgress;

  @override
  double? get activationProgress =>
      overrideActivationProgress ?? super.activationProgress;
}

class _GatedCatalogSource implements CatalogSource {
  _GatedCatalogSource(this._entries, this._gate);
  final Map<String, ExerciseLaunchCatalogInfo> _entries;
  final Completer<void> _gate;
  bool _loaded = false;

  @override
  Future<void> ensureLoaded() async {
    await _gate.future;
    _loaded = true;
  }

  @override
  ExerciseLaunchCatalogInfo? lookup(String id) {
    if (!_loaded) return null;
    return _entries[id];
  }

  @override
  Map<String, ExerciseLaunchCatalogInfo> lookupMany(Iterable<String> ids) {
    if (!_loaded) return const <String, ExerciseLaunchCatalogInfo>{};
    return <String, ExerciseLaunchCatalogInfo>{
      for (final id in ids)
        if (_entries[id] != null) id: _entries[id]!,
    };
  }
}

void main() {
  group('ResearchSettingsScreen & ResearchPreferences', () {
    testWidgets(
        'defaults to anon and ai, persists P07 + control, and shows stored file count',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final storage = _FakeResearchLogStorage(<File>[
        File('vika_20261120T091500Z-P07_01_squat_set1.json'),
        File('vika_20261120T091500Z-P07_session.json'),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: ResearchSettingsScreen(storage: storage),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cài đặt nghiên cứu'), findsOneWidget);
      expect(find.text('Mã đang ghi vào tệp: anon'), findsOneWidget);
      expect(find.text('Số tệp nhật ký đang lưu: 2'), findsOneWidget);
      expect(find.text('CHIA SẺ TẤT CẢ TỆP NHẬT KÝ'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'P07');
      await tester.pump();
      expect(find.text('Mã đang ghi vào tệp: P07'), findsOneWidget);

      await tester.tap(find.text('Đối chứng — không phản hồi (control)'));
      await tester.pump();

      final saved = await ResearchPreferences.load();
      expect(saved.participantId, 'P07');
      expect(saved.hasParticipantId, isTrue);
      expect(saved.isControl, isTrue);
    });
  });

  group('Session satisfaction dialog', () {
    testWidgets('returns 1..5 when selected and null when skipped',
        (tester) async {
      int? result = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showSessionSatisfactionDialog(context);
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bạn hài lòng thế nào với buổi tập hôm nay?'),
        findsOneWidget,
      );

      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      expect(result, 4);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bỏ qua'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });

  group('Control condition post-set & summary screens', () {
    testWidgets('RestScreen hides score, praise, coach tip, and fault list',
        (tester) async {
      final logger = ExerciseLogger()
        ..addRepLog(
          RepLog(
            repNumber: 1,
            correctForm: false,
            data: <String, dynamic>{
              'fault_types': <String>['depth'],
              'faults': <String>['Xuống sâu hơn chút nữa'],
            },
          ),
        );
      const setReport = SetReportData(
        setIndex: 0,
        score: 62,
        totalReps: 10,
        goodReps: 6,
        repResults: <bool>[true, false, true, true, false],
        praiseSentence: 'Tốt lắm! Cứ giữ form đẹp như vậy.',
        coachTip: 'Dồn lực qua gót chân.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RestScreen(
            setReport: setReport,
            setIndex: 0,
            totalSets: 3,
            currentReps: 10,
            baseRestSeconds: 45,
            isLastSet: false,
            exerciseName: 'Squat',
            setLogger: logger,
            controlCondition: false,
            onNext: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('REP CHUẨN FORM'), findsOneWidget);
      expect(
        find.textContaining('Tốt lắm! Cứ giữ form đẹp như vậy.'),
        findsOneWidget,
      );
      expect(find.textContaining('Dồn lực qua gót chân.'), findsOneWidget);
      expect(find.text('CẦN CHÚ Ý (1)'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: RestScreen(
            setReport: setReport,
            setIndex: 0,
            totalSets: 3,
            currentReps: 10,
            baseRestSeconds: 45,
            isLastSet: false,
            exerciseName: 'Squat',
            setLogger: logger,
            controlCondition: true,
            onNext: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Đã hoàn thành hiệp 1'), findsOneWidget);
      expect(
        find.text('Nghỉ ngơi một chút trước khi sang hiệp tiếp theo.'),
        findsOneWidget,
      );
      expect(find.text('REP CHUẨN FORM'), findsNothing);
      expect(
        find.textContaining('Tốt lắm! Cứ giữ form đẹp như vậy.'),
        findsNothing,
      );
      expect(find.textContaining('Dồn lực qua gót chân.'), findsNothing);
      expect(find.textContaining('Cần chú ý'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'RestScreen shows AI visibility and Báo sai toggle only in ai condition',
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
      const setReport = SetReportData(
        setIndex: 0,
        score: 62,
        totalReps: 10,
        goodReps: 6,
        repResults: <bool>[true, false],
      );
      final reports = <String>[];

      Widget build({required bool control, double ratio = 0.92}) =>
          MaterialApp(
            home: RestScreen(
              setReport: setReport,
              setIndex: 0,
              totalSets: 3,
              currentReps: 10,
              baseRestSeconds: 45,
              isLastSet: false,
              exerciseName: 'Squat',
              setLogger: logger,
              controlCondition: control,
              aiVisibleRatio: control ? null : ratio,
              onReportFault: control
                  ? null
                  : (fault, reported) => reports.add('$fault:$reported'),
              onNext: () {},
            ),
          );

      await tester.pumpWidget(build(control: false));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('AI nhìn rõ 92% thời gian tập'), findsOneWidget);

      await tester.ensureVisible(find.text('Báo sai'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Báo sai'));
      await tester.pump();
      expect(find.text('Đã báo sai'), findsOneWidget);
      await tester.ensureVisible(find.text('Đã báo sai'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Đã báo sai'));
      await tester.pump();
      expect(reports, ['depth:true', 'depth:false']);

      await tester.pumpWidget(build(control: false, ratio: 0.55));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('AI nhìn rõ 55% thời gian · kiểm tra lại vị trí máy'),
        findsOneWidget,
      );

      await tester.pumpWidget(build(control: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('AI nhìn rõ'), findsNothing);
      expect(find.text('Báo sai'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'ExerciseTransitionMoment hides numeric score monument in control condition',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseTransitionMoment(
            exerciseName: 'Squat',
            formScore: 84,
            setResults: const <SetReportData>[
              SetReportData(
                setIndex: 0,
                score: 84,
                totalReps: 10,
                goodReps: 8,
                repResults: <bool>[true, true, false],
              ),
            ],
            nextExerciseName: 'Tổng kết buổi tập',
            controlCondition: true,
            onComplete: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.text('Hoàn thành bài tập'), findsOneWidget);
      expect(find.text('Đã ghi nhận kết quả các hiệp tập.'), findsOneWidget);
      expect(find.text('/ 100'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'WorkoutSummaryScreen hides form scores/coach feedback in control and gates export button by participant id',
        (tester) async {
      tester.view.physicalSize = const Size(520, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final report = _buildExerciseReport(name: 'Squat', setScores: [85, 90]);
      report.userDifficulty = 'medium';
      final reports = <ExerciseSessionReport>[report];
      final summary = SessionSummaryBuilder.build(reports, 0);
      final trophy = SessionTrophyPicker.pick(
        reports: reports,
        sessionRawFormScore: summary.rawFormScore,
        streakWeeks: 0,
        priorSessionForms: const [],
        priorExerciseForms: const {},
      );
      final coach = SessionCoachBuilder.build(
        candidates: const [],
        trophy: trophy,
        lowestFormScore: report.formScore,
      );

      var exportTapped = false;
      var exportResult = true;
      var exportThrows = false;
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutSummaryScreen(
            reports: reports,
            sessionSummary: summary,
            totalDuration: const Duration(minutes: 4),
            totalCalories: 45,
            trophy: trophy,
            coach: coach,
            controlCondition: true,
            onExportSessionLogs: (_) async {
              exportTapped = true;
              if (exportThrows) {
                throw StateError('share failed');
              }
              return exportResult;
            },
            onDone: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1800));

      expect(find.text('Hoàn thành buổi tập.'), findsOneWidget);
      expect(find.text('Phiên tập đã được ghi nhận hoàn tất.'), findsOneWidget);
      expect(find.text('SỐ HIỆP'), findsOneWidget);
      expect(find.text('HÀNH TRÌNH FORM'), findsNothing);
      expect(find.text('ĐÚNG FORM'), findsNothing);
      expect(find.text('HLV AI'), findsNothing);
      expect(find.text('${report.formScore}'), findsNothing);
      expect(find.text('Chia sẻ tệp nhật ký phiên này'), findsOneWidget);

      await tester.ensureVisible(find.text('Chia sẻ tệp nhật ký phiên này'));
      await tester.tap(find.text('Chia sẻ tệp nhật ký phiên này'));
      await tester.pump();
      expect(exportTapped, isTrue);
      expect(
        find.text(
          'Chưa có tệp nhật ký nào để chia sẻ hoặc chia sẻ không thành công.',
        ),
        findsNothing,
      );

      // Returning false surfaces Vietnamese SnackBar feedback.
      exportResult = false;
      await tester.tap(find.text('Chia sẻ tệp nhật ký phiên này'));
      await tester.pump();
      expect(
        find.text(
          'Chưa có tệp nhật ký nào để chia sẻ hoặc chia sẻ không thành công.',
        ),
        findsOneWidget,
      );

      // Throwing surfaces Vietnamese error SnackBar feedback.
      exportThrows = true;
      await tester.tap(find.text('Chia sẻ tệp nhật ký phiên này'));
      await tester.pump();
      expect(
        find.text('Không thể chia sẻ tệp nhật ký. Vui lòng thử lại.'),
        findsOneWidget,
      );

      // Without participant id (onExportSessionLogs == null), export button is hidden.
      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutSummaryScreen(
            reports: reports,
            sessionSummary: summary,
            totalDuration: const Duration(minutes: 4),
            totalCalories: 45,
            trophy: trophy,
            coach: coach,
            controlCondition: true,
            onDone: () {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1800));
      expect(find.text('Chia sẻ tệp nhật ký phiên này'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'ExerciseIntroPage hides AI metric gallery and ExerciseValidationLabel in control condition while showing both in AI condition',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseIntroPage(
            title: 'Squat',
            exerciseId: 'squat',
            difficulty: 'Cơ bản',
            totalSets: 3,
            repsPerSet: 10,
            muscles: const <String>['Đùi trước'],
            tips: const <String>['Đặt điện thoại cách 2m'],
            badges: const <ExerciseIntroBadge>[
              ExerciseIntroBadge(
                title: 'Nhịp xuống',
                value: '≥ 1.0s',
                color: Colors.blue,
              ),
            ],
            callouts: const <SkeletonCallout>[
              SkeletonCallout(
                title: 'Độ sâu gối',
                value: '75° — 100°',
                color: Colors.green,
                alignment: Alignment.centerRight,
                anchor: Offset(0.5, 0.5),
              ),
            ],
            coachNote: '',
            controlCondition: false,
            onStart: () {},
            onBack: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('AI chấm form'), findsOneWidget);
      expect(find.text('Đã kiểm chứng'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: ExerciseIntroPage(
            title: 'Squat',
            exerciseId: 'squat',
            difficulty: 'Cơ bản',
            totalSets: 3,
            repsPerSet: 10,
            muscles: const <String>['Đùi trước'],
            tips: const <String>['Đặt điện thoại cách 2m'],
            badges: const <ExerciseIntroBadge>[
              ExerciseIntroBadge(
                title: 'Nhịp xuống',
                value: '≥ 1.0s',
                color: Colors.blue,
              ),
            ],
            callouts: const <SkeletonCallout>[
              SkeletonCallout(
                title: 'Độ sâu gối',
                value: '75° — 100°',
                color: Colors.green,
                alignment: Alignment.centerRight,
                anchor: Offset(0.5, 0.5),
              ),
            ],
            coachNote: '',
            controlCondition: true,
            onStart: () {},
            onBack: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('AI chấm form'), findsNothing);
      expect(find.text('Đã kiểm chứng'), findsNothing);
      expect(find.text('Chỉ đếm, chưa kiểm chứng'), findsNothing);
      expect(find.textContaining('Video hướng dẫn'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('Custom voice coaches & live ActiveExercisePage integration', () {
    const audioGlobalChannel = MethodChannel('xyz.luan/audioplayers.global');
    const audioPlayersChannel = MethodChannel('xyz.luan/audioplayers');
    const audioEventsChannel = MethodChannel(
      'xyz.luan/audioplayers.global/events',
    );

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'test-anon-key',
      );
    });

    setUp(() {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        audioGlobalChannel,
        (call) async => null,
      );
      messenger.setMockMethodCallHandler(
        audioPlayersChannel,
        (call) async => null,
      );
      messenger.setMockMethodCallHandler(
        audioEventsChannel,
        (call) async => null,
      );
    });

    tearDown(() {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(audioGlobalChannel, null);
      messenger.setMockMethodCallHandler(audioPlayersChannel, null);
      messenger.setMockMethodCallHandler(audioEventsChannel, null);
    });

    test(
      'BowPoseVoiceCoach and PlankVoiceCoach emit canonical exercise fault IDs, respect control muting, and do not clear pending setup audio on muted cues',
      () {
        final bowRecorder = SetRecorder(
          sessionId: '20261120T091500Z-P07',
          participantId: 'P07',
          condition: 'control',
          exerciseId: 'bow_pose',
          setIndex: 1,
          appVersion: '1.0.3+155',
          platform: 'android',
          osVersion: '13',
        );
        final bowCoach = BowPoseVoiceCoach();
        addTearDown(bowCoach.dispose);
        late _SpyAssetVoiceSink bowSpy;
        bowCoach.wrapSink(
          (inner) => bowSpy = _SpyAssetVoiceSink(inner as AssetVoiceSink),
        );
        wrapExerciseVoiceCoach(
          bowCoach,
          recorder: bowRecorder,
          controlCondition: true,
        );
        final bowExercise = BowPose(maxRep: 5)
          ..exerciseState = ExerciseState.activated
          ..lastRepWasClean = false
          ..lastRepTopVoiceMessage = 'Mở ngực thêm một chút';

        bowCoach.processFrame(
          exercise: bowExercise,
          repCount: 1,
          hasPose: true,
          feedback: const {},
        );

        bowExercise.lastRepTopVoiceMessage = 'Nắm chân chắc hơn';
        bowCoach.processFrame(
          exercise: bowExercise,
          repCount: 2,
          hasPose: true,
          feedback: const {},
        );

        // Allowed 'Sẵn sàng' was forwarded, and muted rep/fault cues did NOT clear pending!
        expect(bowSpy.forwardedKeys, ['Sẵn sàng']);
        expect(bowSpy.clearPendingCount, 0);

        final bowCues = bowRecorder.events
            .where((e) => e['type'] == 'cue')
            .toList();
        expect(
          bowCues,
          containsAll([
            {'t_ms': 0, 'type': 'cue', 'key': 'Sẵn sàng', 'played': true},
            {'t_ms': 0, 'type': 'cue', 'key': '1', 'played': false},
            {
              't_ms': 0,
              'type': 'cue',
              'key': 'Mở ngực thêm một chút',
              'played': false,
              'fault': 'LiftForm',
            },
            {'t_ms': 0, 'type': 'cue', 'key': '2', 'played': false},
            {
              't_ms': 0,
              'type': 'cue',
              'key': 'Nắm chân chắc hơn',
              'played': false,
              'fault': 'Connection',
            },
          ]),
        );

        final plankRecorder = SetRecorder(
          sessionId: '20261120T091500Z-P07',
          participantId: 'P07',
          condition: 'control',
          exerciseId: 'plank',
          setIndex: 1,
          appVersion: '1.0.3+155',
          platform: 'android',
          osVersion: '13',
        );
        final plankCoach = PlankVoiceCoach();
        addTearDown(plankCoach.dispose);
        late _SpyAssetVoiceSink plankSpy;
        plankCoach.wrapSink(
          (inner) => plankSpy = _SpyAssetVoiceSink(inner as AssetVoiceSink),
        );
        wrapExerciseVoiceCoach(
          plankCoach,
          recorder: plankRecorder,
          controlCondition: true,
        );
        final plankExercise = Plank(maxRep: 3)
          ..exerciseState = ExerciseState.activated
          ..previousPlankState = PlankState.holding
          ..plankState = PlankState.paused
          ..lastHoldFaultVoiceMessage = 'Gồng cơ bụng, nâng hông lên';

        plankCoach.processFrame(
          exercise: plankExercise,
          repCount: 0,
          hasPose: true,
          feedback: const {},
        );

        // Muted hold-completed praise also must NOT clear pending setup/'Sẵn sàng' audio.
        plankCoach.processFrame(
          exercise: plankExercise,
          repCount: 1,
          hasPose: true,
          feedback: const {},
        );

        expect(plankSpy.forwardedKeys, ['Sẵn sàng']);
        expect(plankSpy.clearPendingCount, 0);

        // Allowed safety framing cue DOES clear pending and play in control mode.
        plankExercise.lastHoldFaultVoiceMessage =
            'Giữ cả người trong khung hình';
        plankCoach.processFrame(
          exercise: plankExercise,
          repCount: 1,
          hasPose: true,
          feedback: const {},
        );
        expect(plankSpy.clearPendingCount, 1);
        expect(
          plankSpy.forwardedKeys,
          ['Sẵn sàng', 'Giữ cả người trong khung hình'],
        );

        expect(plankRecorder.events, [
          {'t_ms': 0, 'type': 'cue', 'key': 'Sẵn sàng', 'played': true},
          {
            't_ms': 0,
            'type': 'cue',
            'key': 'Gồng cơ bụng, nâng hông lên',
            'played': false,
            'fault': 'Back',
          },
          {'t_ms': 0, 'type': 'cue', 'key': 'common.correct', 'played': false},
          {
            't_ms': 0,
            'type': 'cue',
            'key': 'Giữ cả người trong khung hình',
            'played': true,
          },
        ]);
      },
    );

    test(
      'ResearchVoiceSink.warmUpAssetManifest checks real AssetManifest for bundled vs missing mp3 files',
      () async {
        addTearDown(() => ResearchVoiceSink.resetAssetCacheForTesting());
        ResearchVoiceSink.resetAssetCacheForTesting();
        await ResearchVoiceSink.warmUpAssetManifest();

        final recorded = <Map<String, Object?>>[];
        final sink = ResearchVoiceSink(
          inner: AssetVoiceSink(),
          controlCondition: false,
          onCue: ({required key, required played, fault}) {
            recorded.add({'key': key, 'played': played});
          },
        );
        addTearDown(sink.dispose);

        await sink.playKey('squat.depth'); // exists: assets/audio/squat/depth.mp3
        await sink.playKey('push_up.pike'); // missing in assets/audio/push_up/
        expect(recorded, [
          {'key': 'squat.depth', 'played': true},
          {'key': 'push_up.pike', 'played': false},
        ]);
      },
    );

    testWidgets(
      'ActiveExercisePage masks AI overlays in control condition, records live landmark stream frames, and flushes on mid-set exit',
      (tester) async {
        final messenger = tester.binding.defaultBinaryMessenger;
        const permChannel = MethodChannel(
          'flutter.baseflow.com/permissions/methods',
        );
        const poseMethodChannel = MethodChannel(
          'com.vikavn.app/pose_landmarker',
        );
        const poseStreamMethodChannel = MethodChannel(
          'com.vikavn.app/pose_landmarker_stream',
        );
        const orientMethodChannel = MethodChannel(
          'com.github.rmtmckenzie/flutter_native_device_orientation/orientation',
        );

        messenger.setMockMethodCallHandler(permChannel, (call) async {
          if (call.method == 'requestPermissions') {
            final requested = call.arguments as List<Object?>;
            return <int, int>{
              for (final p in requested) p! as int: 1,
            };
          }
          return 1;
        });
        messenger.setMockMethodCallHandler(poseMethodChannel, (call) async {
          if (call.method == 'initialize') return 1;
          return null;
        });
        messenger.setMockMethodCallHandler(
          poseStreamMethodChannel,
          (call) async => null,
        );
        messenger.setMockMethodCallHandler(
          orientMethodChannel,
          (call) async => 'PortraitUp',
        );
        addTearDown(() {
          messenger.setMockMethodCallHandler(permChannel, null);
          messenger.setMockMethodCallHandler(poseMethodChannel, null);
          messenger.setMockMethodCallHandler(poseStreamMethodChannel, null);
          messenger.setMockMethodCallHandler(orientMethodChannel, null);
        });

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final squat = _ControllableActivationSquat(maxRep: 5);
        final recorder = SetRecorder(
          sessionId: '20261120T091500Z-P07',
          participantId: 'P07',
          condition: 'control',
          exerciseId: 'squat',
          setIndex: 1,
          appVersion: '1.0.3+155',
          platform: 'android',
          osVersion: '13',
        );
        final squatDef = ExerciseDefinition(
          id: 'squat',
          name: 'Squat',
          subtitle: '',
          description: '',
          icon: Icons.fitness_center,
          primaryColor: Colors.black,
          secondaryColor: Colors.white,
          difficulty: '',
          targetMuscles: const [],
          duration: '',
          cameraHint: '',
          framingHint: '',
          setupTips: const [],
          createExercise: ({int? reps, int? seconds}) => squat,
          phaseColors: const {},
        );

        var flushCount = 0;
        var controlEnabled = false;
        late StateSetter updateHost;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setHostState) {
                updateHost = setHostState;
                return ActiveExercisePage(
                  definition: squatDef,
                  exercise: squat,
                  currentSet: 1,
                  totalSets: 2,
                  totalReps: 5,
                  controlCondition: controlEnabled,
                  setRecorder: recorder,
                  onFlushSetRecording: () => flushCount++,
                  onSetComplete: (_) {},
                  onBack: () {},
                );
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1700));
        await tester.pump();

        // Flip to controlCondition=true via didUpdateWidget (simulates async config load)
        updateHost(() => controlEnabled = true);
        await tester.pump();

        expect(find.text('Đang ghi nhận buổi tập'), findsOneWidget);
        expect(find.byType(RepRewardLayer), findsNothing);
        expect(find.byType(IvoryRepHero), findsNothing);

        // Push a pose landmark frame over the native EventChannel
        final landmarks = <Map<String, Object>>[
          for (var i = 0; i < PoseLandmarkType.values.length; i++)
            <String, Object>{
              'type': i,
              'x': 0.5,
              'y': 0.5,
              'z': 0.0,
              'visibility': 0.95,
              'presence': 0.95,
            },
        ];
        final frameEnvelope = const StandardMethodCodec().encodeSuccessEnvelope(
          <String, Object?>{
            'imageWidth': 480,
            'imageHeight': 640,
            'rotationDegrees': 0,
            'isFrontCamera': true,
            'landmarks': landmarks,
          },
        );
        await messenger.handlePlatformMessage(
          'com.vikavn.app/pose_landmarker_stream',
          frameEnvelope,
          (_) {},
        );
        await tester.pump();

        expect(recorder.totalFrames, greaterThanOrEqualTo(1));
        expect(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is PoseOverlayPainter,
          ),
          findsNothing,
        );

        // Activate squat and verify IvoryRepHero stays hidden in control mode
        squat
          ..exerciseState = ExerciseState.activated
          ..clearGuidanceSignal();
        await messenger.handlePlatformMessage(
          'com.vikavn.app/pose_landmarker_stream',
          const StandardMethodCodec().encodeSuccessEnvelope(<String, Object?>{
            'imageWidth': 480,
            'imageHeight': 640,
            'rotationDegrees': 0,
            'isFrontCamera': true,
            'landmarks': const <Object>[],
          }),
          (_) {},
        );
        await tester.pump();
        expect(find.byType(IvoryRepHero), findsNothing);
        expect(find.text('Đang ghi nhận buổi tập'), findsOneWidget);

        // Simulate bottom release cue followed immediately by pause/resume re-hold:
        // in controlCondition, bottomHoldCue is gated off so the 3s activation
        // countdown (FormScoreArc) renders cleanly without lingering suppression.
        squat
          ..squatState = SquatState.bottom
          ..resultIssues.phaseStatus['bottom'] = 'Đứng lên';
        updateHost(() {});
        await tester.pump();

        squat
          ..squatState = SquatState.standing
          ..exerciseState = ExerciseState.notActivated
          ..clearGuidanceSignal()
          ..overrideActivationProgress = 0.5;
        updateHost(() {});
        await tester.pump();
        expect(find.byType(FormScoreArc), findsOneWidget);
        expect(find.text('2'), findsOneWidget);

        // Unmount mid-set -> flushes partial set without set_complete
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(flushCount, greaterThanOrEqualTo(1));
        expect(
          recorder.events.map((e) => e['type']),
          isNot(contains('set_complete')),
        );
      },
    );

    testWidgets(
      'ExerciseExperienceScreen launched with bare ExerciseDefinition loads CatalogSource and records canonical catalog exercise_id',
      (tester) async {
        final messenger = tester.binding.defaultBinaryMessenger;
        const permChannel = MethodChannel(
          'flutter.baseflow.com/permissions/methods',
        );
        const poseMethodChannel = MethodChannel(
          'com.vikavn.app/pose_landmarker',
        );
        const poseStreamMethodChannel = MethodChannel(
          'com.vikavn.app/pose_landmarker_stream',
        );
        const orientMethodChannel = MethodChannel(
          'com.github.rmtmckenzie/flutter_native_device_orientation/orientation',
        );
        const orientEventsChannel = MethodChannel(
          'native_device_orientation_events',
        );
        const mlkitChannel = MethodChannel('google_mlkit_pose_detector');
        const segStreamChannel = MethodChannel(
          'com.vikavn.app/segmentation_stream',
        );

        messenger.setMockMethodCallHandler(permChannel, (call) async {
          if (call.method == 'requestPermissions') {
            final requested = call.arguments as List<Object?>;
            return <int, int>{
              for (final p in requested) p! as int: 1,
            };
          }
          return 1;
        });
        messenger.setMockMethodCallHandler(poseMethodChannel, (call) async {
          if (call.method == 'initialize') return 1;
          return null;
        });
        messenger.setMockMethodCallHandler(
          poseStreamMethodChannel,
          (call) async => null,
        );
        messenger.setMockMethodCallHandler(
          orientMethodChannel,
          (call) async => 'PortraitUp',
        );
        messenger.setMockMethodCallHandler(
          orientEventsChannel,
          (call) async => null,
        );
        messenger.setMockMethodCallHandler(mlkitChannel, (call) async => null);
        messenger.setMockMethodCallHandler(
          segStreamChannel,
          (call) async => null,
        );

        final tempDir = await tester.runAsync(
          () => Directory.systemTemp.createTemp('vika_bare_def_test_'),
        );
        ResearchLogStorage.setDirectoryProviderForTesting(() async => tempDir!);
        final prevCatalog = CatalogSource.instance;
        final catalogGate =
            (await tester.runAsync(() async => Completer<void>()))!;
        // Gated unloaded CatalogSource: lookup('wall_push_up') stays null even
        // while the user starts and exits the set, completing only after unmount.
        CatalogSource.instance = _GatedCatalogSource(
          const <String, ExerciseLaunchCatalogInfo>{
            'wall_push_up': ExerciseLaunchCatalogInfo(
              id: 'wall_pushup',
              isFormChecked: true,
              baseSets: 2,
              baseReps: 8,
            ),
          },
          catalogGate,
        );
        expect(CatalogSource.instance.lookup('wall_push_up'), isNull);

        addTearDown(() async {
          if (!catalogGate.isCompleted) catalogGate.complete();
          ResearchLogStorage.setDirectoryProviderForTesting(null);
          CatalogSource.instance = prevCatalog;
          messenger.setMockMethodCallHandler(permChannel, null);
          messenger.setMockMethodCallHandler(poseMethodChannel, null);
          messenger.setMockMethodCallHandler(poseStreamMethodChannel, null);
          messenger.setMockMethodCallHandler(orientMethodChannel, null);
          messenger.setMockMethodCallHandler(orientEventsChannel, null);
          messenger.setMockMethodCallHandler(mlkitChannel, null);
          messenger.setMockMethodCallHandler(segStreamChannel, null);
          await tester.runAsync(() async {
            if (tempDir != null && await tempDir.exists()) {
              await tempDir.delete(recursive: true);
            }
          });
        });

        SharedPreferences.setMockInitialValues(<String, Object>{
          ResearchPreferences.participantIdKey: 'P07',
          ResearchPreferences.conditionKey: 'control',
          '${kGuideVideoSeenPrefix}wall_push_up': true,
          '${kGuideVideoSeenPrefix}wall_pushup': true,
        });
        ResearchPreferences.resetCacheForTesting();

        final wallPushDef = lookupExerciseDefinition('wall_push_up')!;
        expect(
          wallPushDef.id,
          'wall_push_up',
        ); // definition id differs from catalog 'wall_pushup'

        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: ExerciseExperienceScreen(definition: wallPushDef),
            ),
          );
        });
        await tester.pump();

        // Catalog is STILL loading in flight when the user starts the set!
        expect(CatalogSource.instance.lookup('wall_push_up'), isNull);

        // Start set from ExerciseIntroPage immediately (no sleep workaround)
        await tester.tap(find.text('BẮT ĐẦU TẬP'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1700));
        await tester.pump();

        // Feed one camera frame while catalog is STILL uncompleted, then unmount
        await messenger.handlePlatformMessage(
          'com.vikavn.app/pose_landmarker_stream',
          const StandardMethodCodec().encodeSuccessEnvelope(<String, Object?>{
            'imageWidth': 480,
            'imageHeight': 640,
            'rotationDegrees': 0,
            'isFrontCamera': true,
            'landmarks': const <Object>[],
          }),
          (_) {},
        );
        await tester.pump();

        final parsed = await tester.runAsync(() async {
          // Unmount while catalog load is STILL in flight!
          await tester.pumpWidget(const SizedBox.shrink());
          // Release the catalog load AFTER unmount: off-frame flush awaits it
          // before writing the set and session files to disk.
          catalogGate.complete();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          final files = await ResearchLogStorage.instance.listStoredLogFiles();
          final setFile = files.firstWhere(
            (f) => !f.path.endsWith('_session.json'),
          );
          final sessionFile = files.firstWhere(
            (f) => f.path.endsWith('_session.json'),
          );
          return (
            fileName: setFile.uri.pathSegments.last,
            json:
                jsonDecode(await setFile.readAsString()) as Map<String, dynamic>,
            sessionJson: jsonDecode(await sessionFile.readAsString())
                as Map<String, dynamic>,
          );
        });
        expect(
          parsed!.fileName,
          contains('-P07_01_wall_pushup_set1.json'),
        );
        expect(parsed.json['exercise_id'], 'wall_pushup');
        expect(parsed.json['participant_id'], 'P07');
        expect(parsed.json['condition'], 'control');
        expect(parsed.sessionJson['files'], [parsed.fileName]);
      },
    );
  });
}

ExerciseSessionReport _buildExerciseReport({
  required String name,
  required List<int> setScores,
}) {
  final sets = <SetReportData>[
    for (var i = 0; i < setScores.length; i++)
      SetReportData(
        setIndex: i,
        score: setScores[i],
        totalReps: 10,
        goodReps: 8,
        repResults: List<bool>.filled(10, true),
      ),
  ];
  return ExerciseSessionReport(
    definition: ExerciseDefinition(
      id: name.toLowerCase(),
      name: name,
      subtitle: '',
      description: '',
      icon: Icons.fitness_center,
      primaryColor: Colors.black,
      secondaryColor: Colors.white,
      difficulty: '',
      targetMuscles: const [],
      duration: '',
      cameraHint: '',
      framingHint: '',
      setupTips: const [],
      createExercise: ({int? reps, int? seconds}) =>
          throw UnimplementedError(),
      phaseColors: const {},
    ),
    exerciseKey: name.toLowerCase(),
    report: PostExerciseData(
      exerciseName: name,
      metValue: 5.0,
      sets: sets,
      formScore: 88,
      coachText: 'Form rất chắc!',
      isSecondBased: false,
    ),
    duration: const Duration(minutes: 2),
    calories: 30,
  );
}
