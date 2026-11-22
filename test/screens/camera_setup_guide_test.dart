import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/plank/plank.dart';
import 'package:vika/exercise/presence_gate.dart';
import 'package:vika/exercise/squat/squat.dart';
import 'package:vika/models/exercise_definition.dart';
import 'package:vika/models/exercise_lookup.dart';
import 'package:vika/models/kept_exercises.dart';
import 'package:vika/pose/vika_pose_landmark.dart';
import 'package:vika/screens/exercise/active_exercise_page.dart';
import 'package:vika/screens/exercise/exercise_experience_screen.dart';
import 'package:vika/screens/exercise/exercise_intro_page.dart';
import 'package:vika/screens/exercise/exercise_launch_args.dart';
import 'package:vika/screens/exercise/widgets/camera_placement_card.dart';
import 'package:vika/screens/exercise/widgets/form_score_arc.dart';
import 'package:vika/screens/exercise/widgets/guidance_signage.dart';
import 'package:vika/screens/exercise/widgets/ivory_chrome.dart';
import 'package:vika/screens/exercise/widgets/readiness_checklist.dart';
import 'package:vika/services/catalog/catalog_source.dart';
import 'package:vika/utils/person_detector.dart';

Future<void> _loadBeVietnamProFont() async {
  const fontFiles = [
    'assets/fonts/be_vietnam_pro/BeVietnamPro-Regular.ttf',
    'assets/fonts/be_vietnam_pro/BeVietnamPro-Italic.ttf',
    'assets/fonts/be_vietnam_pro/BeVietnamPro-Medium.ttf',
    'assets/fonts/be_vietnam_pro/BeVietnamPro-MediumItalic.ttf',
    'assets/fonts/be_vietnam_pro/BeVietnamPro-SemiBold.ttf',
    'assets/fonts/be_vietnam_pro/BeVietnamPro-SemiBoldItalic.ttf',
    'assets/fonts/be_vietnam_pro/BeVietnamPro-Bold.ttf',
    'assets/fonts/be_vietnam_pro/BeVietnamPro-BoldItalic.ttf',
    'assets/fonts/be_vietnam_pro/BeVietnamPro-ExtraBold.ttf',
    'assets/fonts/be_vietnam_pro/BeVietnamPro-ExtraBoldItalic.ttf',
  ];
  final loader = FontLoader('BeVietnamPro');
  for (final path in fontFiles) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

Map<PoseLandmarkType, PoseLandmark> _syntheticLandmarks() {
  return <PoseLandmarkType, PoseLandmark>{
    for (final type in PoseLandmarkType.values)
      type: poseLandmarkWithVikaConfidence(
        type: type,
        x: 100,
        y: 200,
        z: 0,
        visibility: 0.95,
        presence: 0.95,
      ),
  };
}

class _FakePresenceSource implements PosePresenceSource {
  @override
  bool personDetected = true;

  @override
  double presenceScore = 1.0;

  @override
  Future<bool> detect([Object? _]) async => personDetected;

  @override
  Future<void> triggerCheck({String reason = 'unknown'}) async {}

  @override
  Future<void> useActivatedCadence() async {}

  @override
  Future<void> usePausedCadence() async {}

  @override
  Future<void> close() async {}
}

class _ControllableSquat extends Squat {
  _ControllableSquat({super.maxRep = 5});

  double? overrideActivationProgress;
  bool? overridePaused;

  @override
  bool get isPaused => overridePaused ?? super.isPaused;

  @override
  double? get activationProgress =>
      overrideActivationProgress ?? super.activationProgress;
}

class _GateControllablePlank extends Plank {
  _GateControllablePlank({
    required super.maxRep,
    required this.presenceSource,
  }) : _customGate = PresenceGate(detector: presenceSource);

  final _FakePresenceSource presenceSource;
  final PresenceGate _customGate;
  double? overrideActivationProgress;

  @override
  bool get isPaused => _customGate.isPaused;

  @override
  double? get activationProgress =>
      overrideActivationProgress ?? super.activationProgress;

  void drivePresence({required DateTime now, required bool hasPose}) {
    final phase = switch (exerciseState) {
      ExerciseState.notActivated => GatePhase.seeking,
      ExerciseState.activated => GatePhase.active,
      ExerciseState.completed => GatePhase.done,
    };
    final verdict = hasPose
        ? _customGate.onPose(
            now: now,
            phase: phase,
            landmarks: _syntheticLandmarks(),
          )
        : _customGate.onNoPose(now: now, phase: phase);
    if (verdict.resumedNow && exerciseState == ExerciseState.activated) {
      exerciseState = ExerciseState.notActivated;
      onPauseReactivationStarted();
    }
    if (!verdict.proceed) {
      publishGuidanceSignal(
        verdict.block == GateBlock.paused
            ? const GuidanceSignal.paused()
            : const GuidanceSignal.searching(),
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const audioGlobalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const audioPlayersChannel = MethodChannel('xyz.luan/audioplayers');
  const audioEventsChannel = MethodChannel(
    'xyz.luan/audioplayers.global/events',
  );

  setUpAll(() async {
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
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await _loadBeVietnamProFont();
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
    await CatalogSource.instance.ensureLoaded();
  });

  tearDownAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(audioGlobalChannel, null);
    messenger.setMockMethodCallHandler(audioPlayersChannel, null);
    messenger.setMockMethodCallHandler(audioEventsChannel, null);
  });

  group('Placement constant table vs exercise code', () {
    test(
      'every kept exercise has an entry whose orientation and view agree with the exercise class',
      () async {
        expect(keptExerciseIds, hasLength(24));
        expect(kExercisePlacementByCatalogId.keys.toSet(), keptExerciseIds);

        final landmarks = _syntheticLandmarks();

        for (final id in keptExerciseIds) {
          final spec = kExercisePlacementByCatalogId[id];
          expect(spec, isNotNull, reason: 'Missing placement entry for $id');

          final def = lookupExerciseDefinition(id);
          expect(def, isNotNull, reason: 'Missing ExerciseDefinition for $id');

          final exercise = def!.createExercise(reps: 1, seconds: 1);
          try {
            expect(
              spec!.orientation.supportedOrientations,
              exercise.supportedOrientations,
              reason:
                  '$id placement orientation (${spec.orientation}) disagrees with ${exercise.runtimeType}.supportedOrientations (${exercise.supportedOrientations})',
            );

            // Check camera-facing safety gate agreement where checkSafety enforces view.
            if (spec.view == UserCameraView.facingCamera) {
              exercise.cameraFacing = CameraFacing.left;
              final sideSignal = exercise.checkSafety(landmarks);
              expect(
                sideSignal?.kind,
                GuidanceClass.faceCamera,
                reason: '$id is marked facingCamera so side view must emit faceCamera',
              );
            } else if (id != 'vup') {
              // VUp.checkSafety returns null (reported gate omission); all other 18
              // side-on exercises reject CameraFacing.front with turnSide.
              exercise.cameraFacing = CameraFacing.front;
              final frontSignal = exercise.checkSafety(landmarks);
              expect(
                frontSignal?.kind,
                GuidanceClass.turnSide,
                reason: '$id is marked sideOn so front view must emit turnSide',
              );
            }
          } finally {
            await exercise.disposeDetectors();
          }
        }
      },
    );

    test(
      'lookupExercisePlacement resolves catalog ids, definition ids, and assessment variants',
      () {
        for (final id in keptExerciseIds) {
          final spec = lookupExercisePlacement(id);
          expect(spec, isNotNull, reason: id);
          final def = lookupExerciseDefinition(id)!;
          expect(lookupExercisePlacement(def.id), same(spec), reason: def.id);
        }
        expect(
          lookupExercisePlacement('squat_assessment'),
          same(kExercisePlacementByCatalogId['squat']),
        );
        expect(
          lookupExercisePlacement('wall_pushup_assessment'),
          same(kExercisePlacementByCatalogId['wall_pushup']),
        );
        expect(
          lookupExercisePlacement('seated_forward_fold_assessment'),
          same(kExercisePlacementByCatalogId['seated_forward_fold']),
        );
        // Catalog Vietnamese and English display names via CatalogSource
        expect(
          lookupExercisePlacement('Tư thế con bướm'),
          same(kExercisePlacementByCatalogId['butterfly']),
        );
        expect(
          lookupExercisePlacement('Cầu mông'),
          same(kExercisePlacementByCatalogId['glute_bridge']),
        );
        expect(
          lookupExercisePlacement('Butterfly'),
          same(kExercisePlacementByCatalogId['butterfly']),
        );
        expect(lookupExercisePlacement('cobra'), isNull);
        expect(lookupExercisePlacement('warrior_one'), isNull);
        expect(lookupExercisePlacement(''), isNull);
        expect(lookupExercisePlacement(null), isNull);
      },
    );

    test(
      'one landscape placement serves every kept exercise, so no transition asks to move the phone',
      () {
        final ids = keptExerciseIds.toList(growable: false);
        for (final id in ids) {
          final spec = kExercisePlacementByCatalogId[id]!;
          expect(
            spec.orientation,
            PhonePlacementOrientation.landscape,
            reason: id,
          );
          expect(
            spec.placementWhere,
            const {'jumping_jack', 'jump_squat'}.contains(id)
                ? kJumpPlacementWhere
                : kOnePlacementWhere,
            reason: id,
          );
        }
        for (final previous in ids) {
          for (final current in ids) {
            if (previous == current) continue;
            final notice = computePlacementTransition(
              current: kExercisePlacementByCatalogId[current]!,
              previousExerciseId: previous,
            )!;
            expect(notice.phoneRotated, isFalse, reason: '$previous -> $current');
            expect(
              notice.message,
              startsWith('Giữ nguyên vị trí máy'),
              reason: '$previous -> $current',
            );
          }
        }
      },
    );

    test(
      'computePlacementTransition still names the body turn between views',
      () {
        final unchanged = computePlacementTransition(
          current: kExercisePlacementByCatalogId['lunge']!,
          sequenceExerciseIds: const ['squat', 'lunge'],
          sequenceIndex: 1,
        )!;
        expect(unchanged.message, 'Giữ nguyên vị trí máy');
        expect(unchanged.requiresAction, isFalse);
        expect(unchanged.phoneRotated, isFalse);

        final bodyTurnToSide = computePlacementTransition(
          current: kExercisePlacementByCatalogId['squat']!,
          sequenceExerciseIds: const ['jumping_jack', 'squat'],
          sequenceIndex: 1,
        )!;
        expect(
          bodyTurnToSide.message,
          'Giữ nguyên vị trí máy · Quay nghiêng người',
        );
        expect(bodyTurnToSide.requiresAction, isTrue);
        expect(bodyTurnToSide.phoneRotated, isFalse);

        const stretchSeq = ['seated_forward_fold', 'butterfly', 'sphinx'];
        final toButterfly = computePlacementTransition(
          current: kExercisePlacementByCatalogId['butterfly']!,
          sequenceExerciseIds: stretchSeq,
          sequenceIndex: 1,
        )!;
        expect(
          toButterfly.message,
          'Giữ nguyên vị trí máy · Quay mặt về camera',
        );
        expect(toButterfly.phoneRotated, isFalse);

        final toSphinx = computePlacementTransition(
          current: kExercisePlacementByCatalogId['sphinx']!,
          sequenceExerciseIds: stretchSeq,
          sequenceIndex: 2,
        )!;
        expect(
          toSphinx.message,
          'Giữ nguyên vị trí máy · Quay nghiêng người',
        );
        expect(toSphinx.phoneRotated, isFalse);

        final acrossSkipped = computePlacementTransition(
          current: kExercisePlacementByCatalogId['push_up']!,
          sequenceExerciseIds: const ['squat', 'cobra', 'push_up'],
          sequenceIndex: 2,
        )!;
        expect(acrossSkipped.message, 'Giữ nguyên vị trí máy');
        expect(acrossSkipped.phoneRotated, isFalse);
      },
    );
  });

  group('CameraPlacementCard and ExerciseIntroPage at 320pt width', () {
    testWidgets(
      'renders CameraPlacementCard and ExerciseIntroPage for all 24 kept exercises at 320pt without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final orderedIds = keptExerciseIds.toList(growable: false);
        for (var i = 0; i < orderedIds.length; i++) {
          final id = orderedIds[i];
          final def = lookupExerciseDefinition(id)!;
          final spec = kExercisePlacementByCatalogId[id]!;
          final prevId = i > 0 ? orderedIds[i - 1] : null;

          await tester.pumpWidget(
            MaterialApp(
              home: ExerciseIntroPage(
                title: def.displayName,
                exerciseId: id,
                safetyWarning: def.safetyWarning,
                previousExerciseId: prevId,
                sequenceExerciseIds: orderedIds,
                sequenceIndex: i,
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
            ),
          );
          await tester.pump(const Duration(milliseconds: 80));

          expect(
            tester.takeException(),
            isNull,
            reason: '$id overflowed at 320x568',
          );
          expect(find.byType(CameraPlacementCard), findsOneWidget, reason: id);
          expect(
            find.text(spec.view.vietnameseLabel),
            findsOneWidget,
            reason: '$id missing view label',
          );
          if (spec.placementWhere != null) {
            expect(
              find.text(spec.placementWhere!),
              findsOneWidget,
              reason: '$id missing placementWhere',
            );
          }
          if (def.safetyWarning != null) {
            expect(
              find.text(def.safetyWarning!),
              findsOneWidget,
              reason: '$id missing safetyWarning on card',
            );
          }
          if (i > 0) {
            final expectedNotice = computePlacementTransition(
              current: spec,
              sequenceExerciseIds: orderedIds,
              sequenceIndex: i,
            )!;
            expect(
              find.text(expectedNotice.message),
              expectedNotice.requiresAction ? findsOneWidget : findsNothing,
              reason: '$id transition callout',
            );
          }
        }

        // Also verify CameraPlacementCard still renders in controlCondition: true,
        // dark brightness, and large 1.5x system font scale at 320pt width.
        final sphinxDef = lookupExerciseDefinition('sphinx')!;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              platformBrightness: Brightness.dark,
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.5),
            ),
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  platformBrightness: Brightness.dark,
                  textScaler: const TextScaler.linear(1.5),
                ),
                child: child!,
              ),
              home: ExerciseIntroPage(
                title: sphinxDef.displayName,
                exerciseId: 'sphinx',
                safetyWarning: sphinxDef.safetyWarning,
                previousExerciseId: 'squat',
                difficulty: sphinxDef.difficulty,
                totalSets: 2,
                repsPerSet: 30,
                muscles: sphinxDef.targetMuscles,
                tips: sphinxDef.setupTips,
                badges: const <ExerciseIntroBadge>[],
                callouts: const [],
                coachNote: '',
                controlCondition: true,
                onStart: () {},
                onBack: () {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.takeException(), isNull);
        expect(find.byType(CameraPlacementCard), findsOneWidget);
        expect(find.text('Giữ nguyên vị trí máy'), findsNothing);
        expect(find.text(sphinxDef.safetyWarning!), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'ExerciseExperienceScreen threads sequence transition and safetyWarning into ExerciseIntroPage',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final squatDef = lookupExerciseDefinition('squat')!;
        final mcDef = lookupExerciseDefinition('mountain_climber')!;

        await tester.pumpWidget(
          MaterialApp(
            home: ExerciseExperienceScreen(
              definition: mcDef,
              catalogExerciseId: 'mountain_climber',
              catalogInfo: CatalogSource.instance.lookup('mountain_climber'),
              sequenceIndex: 1,
              sequence: [
                ExerciseSequenceItem(
                  definition: squatDef,
                  catalogExerciseId: 'squat',
                ),
                ExerciseSequenceItem(
                  definition: mcDef,
                  catalogExerciseId: 'mountain_climber',
                ),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 80));

        expect(tester.takeException(), isNull);
        expect(find.byType(CameraPlacementCard), findsOneWidget);
        expect(find.text('Giữ nguyên vị trí máy'), findsNothing);
        expect(find.text(mcDef.safetyWarning!), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('ReadinessChecklist signal-to-line mapping and lifecycle', () {
    ReadinessCheckRow rowFor(WidgetTester tester, ReadinessCheckLine line) {
      return tester.widget<ReadinessCheckRow>(
        find.byKey(ValueKey<ReadinessCheckLine>(line)),
      );
    }

    testWidgets(
      'every GuidanceClass kind ticks and unticks the expected checklist lines',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        GuidanceSignal? currentSignal;
        var hasPose = true;
        late StateSetter setHostState;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    setHostState = setState;
                    return ReadinessChecklist(
                      signal: currentSignal,
                      hasPose: hasPose,
                    );
                  },
                ),
              ),
            ),
          ),
        );

        Future<void> setSignal(
          GuidanceSignal? signal, {
          bool pose = true,
        }) async {
          setHostState(() {
            currentSignal = signal;
            hasPose = pose;
          });
          await tester.pump();
          expect(tester.takeException(), isNull);
        }

        // Initial null signal -> all pending / unticked.
        expect(rowFor(tester, ReadinessCheckLine.bodyInFrame).isMet, isFalse);
        expect(
          rowFor(tester, ReadinessCheckLine.viewAndOrientation).isMet,
          isFalse,
        );
        expect(rowFor(tester, ReadinessCheckLine.lighting).isMet, isFalse);
        expect(rowFor(tester, ReadinessCheckLine.startPosition).isMet, isFalse);

        // View & orientation blockers: phoneLandscape, phonePortrait, turnSide, faceCamera
        for (final signal in const <GuidanceSignal>[
          GuidanceSignal.phoneLandscape(),
          GuidanceSignal.phonePortrait(),
          GuidanceSignal.turnSide(),
          GuidanceSignal.faceCamera(),
        ]) {
          await setSignal(signal);
          expect(
            rowFor(tester, ReadinessCheckLine.viewAndOrientation).status,
            ReadinessCheckStatus.blocker,
            reason: signal.kind.name,
          );
          expect(rowFor(tester, ReadinessCheckLine.bodyInFrame).isMet, isFalse);
          expect(rowFor(tester, ReadinessCheckLine.lighting).isMet, isFalse);
          expect(
            rowFor(tester, ReadinessCheckLine.startPosition).isMet,
            isFalse,
          );
        }

        // Presence blockers before view check: searching, paused, no-pose bodyInFrame
        for (final (signal, pose) in const <(GuidanceSignal, bool)>[
          (GuidanceSignal.searching(), false),
          (GuidanceSignal.paused(), false),
          (GuidanceSignal.bodyInFrame(), false),
        ]) {
          await setSignal(signal, pose: pose);
          expect(
            rowFor(tester, ReadinessCheckLine.bodyInFrame).status,
            ReadinessCheckStatus.blocker,
            reason: '${signal.kind.name} pose=$pose',
          );
          expect(
            rowFor(tester, ReadinessCheckLine.viewAndOrientation).isMet,
            isFalse,
          );
          expect(rowFor(tester, ReadinessCheckLine.lighting).isMet, isFalse);
          expect(
            rowFor(tester, ReadinessCheckLine.startPosition).isMet,
            isFalse,
          );
        }

        // bodyInFrame with pose -> view & orientation met, bodyInFrame blocked
        await setSignal(const GuidanceSignal.bodyInFrame(), pose: true);
        expect(
          rowFor(tester, ReadinessCheckLine.viewAndOrientation).isMet,
          isTrue,
        );
        expect(
          rowFor(tester, ReadinessCheckLine.bodyInFrame).status,
          ReadinessCheckStatus.blocker,
        );
        expect(rowFor(tester, ReadinessCheckLine.lighting).isMet, isFalse);
        expect(rowFor(tester, ReadinessCheckLine.startPosition).isMet, isFalse);

        // lighting -> bodyInFrame & viewAndOrientation met, lighting blocked
        await setSignal(const GuidanceSignal.lighting());
        expect(rowFor(tester, ReadinessCheckLine.bodyInFrame).isMet, isTrue);
        expect(
          rowFor(tester, ReadinessCheckLine.viewAndOrientation).isMet,
          isTrue,
        );
        expect(
          rowFor(tester, ReadinessCheckLine.lighting).status,
          ReadinessCheckStatus.blocker,
        );
        expect(rowFor(tester, ReadinessCheckLine.startPosition).isMet, isFalse);

        // setupPosition and resume -> first 3 lines met, startPosition blocked
        for (final signal in const <GuidanceSignal>[
          GuidanceSignal.setupPosition(),
          GuidanceSignal.resume(),
        ]) {
          await setSignal(signal);
          expect(rowFor(tester, ReadinessCheckLine.bodyInFrame).isMet, isTrue);
          expect(
            rowFor(tester, ReadinessCheckLine.viewAndOrientation).isMet,
            isTrue,
          );
          expect(rowFor(tester, ReadinessCheckLine.lighting).isMet, isTrue);
          expect(
            rowFor(tester, ReadinessCheckLine.startPosition).status,
            ReadinessCheckStatus.blocker,
            reason: signal.kind.name,
          );
        }

        // holdStill -> all 4 lines ticked!
        await setSignal(const GuidanceSignal.holdStill());
        for (final line in ReadinessCheckLine.values) {
          expect(rowFor(tester, line).isMet, isTrue, reason: line.name);
        }

        // Stepping out of start position unticks startPosition; stepping out of
        // frame unticks lighting and bodyInFrame too.
        await setSignal(const GuidanceSignal.setupPosition());
        expect(rowFor(tester, ReadinessCheckLine.startPosition).isMet, isFalse);
        expect(rowFor(tester, ReadinessCheckLine.lighting).isMet, isTrue);

        await setSignal(const GuidanceSignal.bodyInFrame(), pose: true);
        expect(rowFor(tester, ReadinessCheckLine.bodyInFrame).isMet, isFalse);
        expect(rowFor(tester, ReadinessCheckLine.lighting).isMet, isFalse);
        expect(
          rowFor(tester, ReadinessCheckLine.viewAndOrientation).isMet,
          isTrue,
        );

        // Exhaustiveness sanity check: every GuidanceClass value was covered.
        expect(GuidanceClass.values, hasLength(11));

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('ActiveExercisePage live checklist & "Chưa đủ căn cứ để chấm"', () {
    const permChannel = MethodChannel(
      'flutter.baseflow.com/permissions/methods',
    );
    const poseMethodChannel = MethodChannel('com.vikavn.app/pose_landmarker');
    const poseStreamMethodChannel = MethodChannel(
      'com.vikavn.app/pose_landmarker_stream',
    );
    const orientMethodChannel = MethodChannel('native_device_orientation');
    const orientEventsChannel = MethodChannel(
      'native_device_orientation_events',
    );

    String mockOrientation = 'PortraitUp';

    setUp(() {
      mockOrientation = 'PortraitUp';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(permChannel, (call) async {
        if (call.method == 'requestPermissions') {
          final requested = call.arguments as List<Object?>;
          return <int, int>{for (final p in requested) p! as int: 1};
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
      messenger.setMockMethodCallHandler(orientMethodChannel, (call) async {
        if (call.method == 'getOrientation') return mockOrientation;
        return null;
      });
      messenger.setMockMethodCallHandler(
        orientEventsChannel,
        (call) async => null,
      );
    });

    tearDown(() {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(permChannel, null);
      messenger.setMockMethodCallHandler(poseMethodChannel, null);
      messenger.setMockMethodCallHandler(poseStreamMethodChannel, null);
      messenger.setMockMethodCallHandler(orientMethodChannel, null);
      messenger.setMockMethodCallHandler(orientEventsChannel, null);
    });

    testWidgets(
      'shows checklist while notActivated, hides on activation, returns on post-pause re-hold, and renders "Chưa đủ căn cứ để chấm" above signal instructions when activated (including control condition)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final squat = _ControllableSquat(maxRep: 5);
        addTearDown(squat.disposeDetectors);
        final squatDef = lookupExerciseDefinition('squat')!;
        var controlCondition = false;
        late StateSetter updateHost;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                updateHost = setState;
                return ActiveExercisePage(
                  definition: squatDef,
                  exercise: squat,
                  currentSet: 1,
                  totalSets: 2,
                  totalReps: 5,
                  controlCondition: controlCondition,
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

        // 1. Pre-activation: checklist is visible; "Chưa đủ căn cứ để chấm" is NOT shown,
        // and ReadinessChecklist never overlaps GuidanceSignage or top chrome.
        squat.publishGuidanceSignal(const GuidanceSignal.turnSide());
        updateHost(() {});
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(ReadinessChecklist), findsOneWidget);
        expect(find.text('Đứng nghiêng người'), findsOneWidget);
        expect(find.text('Chưa đủ căn cứ để chấm'), findsNothing);
        expect(
          tester
              .getRect(find.byType(ReadinessChecklist))
              .overlaps(tester.getRect(find.byType(GuidanceSignage))),
          isFalse,
        );

        // Pre-activation holdStill countdown ring also stays disjoint from checklist.
        squat
          ..overrideActivationProgress = 0.4
          ..publishGuidanceSignal(const GuidanceSignal.holdStill());
        updateHost(() {});
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(FormScoreArc), findsOneWidget);
        expect(
          tester
              .getRect(find.byType(ReadinessChecklist))
              .overlaps(tester.getRect(find.byType(FormScoreArc))),
          isFalse,
        );
        squat.overrideActivationProgress = null;

        // 2. Activate exercise: checklist disappears.
        squat
          ..exerciseState = ExerciseState.activated
          ..clearGuidanceSignal();
        updateHost(() {});
        await tester.pump();
        expect(find.byType(ReadinessChecklist), findsNothing);
        expect(find.text('Chưa đủ căn cứ để chấm'), findsNothing);

        // 3. During activated exercise, each stop-evaluation signal shows
        // "Chưa đủ căn cứ để chấm" ABOVE the existing instruction text.
        const activeSignals = <(GuidanceSignal, String)>[
          (GuidanceSignal.bodyInFrame(), 'Lùi lại'),
          (GuidanceSignal.turnSide(), 'Đứng nghiêng người'),
          (GuidanceSignal.faceCamera(), 'Hướng về camera'),
          (GuidanceSignal.lighting(), 'Thêm ánh sáng'),
          (GuidanceSignal.phoneLandscape(), 'Xoay ngang máy'),
          (GuidanceSignal.phonePortrait(), 'Xoay dọc máy'),
          (GuidanceSignal.searching(), 'Đang tìm người'),
          (GuidanceSignal.paused(), 'Tạm dừng'),
        ];

        for (final (signal, expectedTitle) in activeSignals) {
          squat.publishGuidanceSignal(signal);
          updateHost(() {});
          await tester.pump();
          expect(tester.takeException(), isNull, reason: signal.kind.name);
          expect(
            find.text('Chưa đủ căn cứ để chấm'),
            findsOneWidget,
            reason: 'Missing not-judging line for ${signal.kind.name}',
          );
          expect(
            find.text(expectedTitle),
            findsOneWidget,
            reason: 'Existing instruction changed for ${signal.kind.name}',
          );
          final statusTop =
              tester.getTopLeft(find.text('Chưa đủ căn cứ để chấm')).dy;
          final titleTop = tester.getTopLeft(find.text(expectedTitle)).dy;
          expect(
            statusTop,
            lessThan(titleTop),
            reason:
                '"Chưa đủ căn cứ để chấm" must sit above "$expectedTitle"',
          );
        }

        // 4. Auto-pause (IvoryPauseOverlay with isManualPause == false):
        // renders "Chưa đủ căn cứ để chấm" ABOVE "MẤT TÍN HIỆU" / "Bạn ở đâu rồi?".
        squat
          ..overridePaused = true
          ..publishGuidanceSignal(const GuidanceSignal.paused());
        updateHost(() {});
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(IvoryPauseOverlay), findsOneWidget);
        expect(find.text('Chưa đủ căn cứ để chấm'), findsOneWidget);
        expect(find.text('MẤT TÍN HIỆU'), findsOneWidget);
        expect(find.text('Bạn ở đâu rồi?'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('Chưa đủ căn cứ để chấm')).dy,
          lessThan(tester.getTopLeft(find.text('MẤT TÍN HIỆU')).dy),
        );
        squat.overridePaused = null;

        // 5. Signal clears -> "Chưa đủ căn cứ để chấm" goes away immediately.
        squat.clearGuidanceSignal();
        updateHost(() {});
        await tester.pump();
        expect(find.text('Chưa đủ căn cứ để chấm'), findsNothing);

        // 6. Control condition: "Chưa đủ căn cứ để chấm" still shows when activated,
        // does not overlap "Đang ghi nhận buổi tập", and ReadinessChecklist still
        // returns on post-pause re-hold without overlapping either!
        controlCondition = true;
        squat.publishGuidanceSignal(const GuidanceSignal.bodyInFrame());
        updateHost(() {});
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Chưa đủ căn cứ để chấm'), findsOneWidget);
        expect(find.text('Lùi lại'), findsOneWidget);
        expect(
          tester
              .getRect(find.byType(GuidanceSignage))
              .overlaps(tester.getRect(find.text('Đang ghi nhận buổi tập'))),
          isFalse,
        );

        // Manual pause button -> shows manual pause overlay without not-judging line.
        await tester.tap(find.byIcon(Icons.pause_rounded));
        await tester.pump();
        expect(find.text('Tạm nghỉ một chút?'), findsOneWidget);
        expect(find.text('Chưa đủ căn cứ để chấm'), findsNothing);

        // Simulate a throttled 1fps frame arriving while paused (publishes paused signal),
        // then tap resume -> must NOT flash stale "Tạm dừng" signage or false bodyInFrame blocker!
        squat.publishGuidanceSignal(const GuidanceSignal.paused());
        await tester.tap(find.text('Tiếp tục tập'));
        await tester.pump();
        expect(squat.exerciseState, ExerciseState.notActivated);
        expect(find.text('Tạm dừng'), findsNothing);
        expect(find.byType(ReadinessChecklist), findsOneWidget);
        expect(
          tester
              .widget<ReadinessCheckRow>(
                find.byKey(
                  const ValueKey<ReadinessCheckLine>(
                    ReadinessCheckLine.bodyInFrame,
                  ),
                ),
              )
              .status,
          ReadinessCheckStatus.pending,
        );

        // Next post-resume frame arrives -> checklist updates & stays disjoint
        // from GuidanceSignage and control pill.
        squat.publishGuidanceSignal(const GuidanceSignal.setupPosition());
        updateHost(() {});
        await tester.pump();
        expect(find.byType(ReadinessChecklist), findsOneWidget);
        expect(find.text('Chưa đủ căn cứ để chấm'), findsNothing);
        expect(
          tester
              .getRect(find.byType(ReadinessChecklist))
              .overlaps(tester.getRect(find.byType(GuidanceSignage))),
          isFalse,
        );
        expect(
          tester
              .getRect(find.byType(ReadinessChecklist))
              .overlaps(tester.getRect(find.text('Đang ghi nhận buổi tập'))),
          isFalse,
        );
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'real portrait-locked 568x320 RotatedBox landscape (Plank) keeps ReadinessChecklist, GuidanceSignage, countdown ring, control pill, and ExerciseDemoPage disjoint across 1.5x font scale and live pose stream',
      (tester) async {
        // Real device configuration: OS window is locked to portrait (320x568)
        // while sensor reports LandscapeLeft, so RotatedBox(quarterTurns: 1)
        // gives _buildActiveLayout genuine 568x320 landscape constraints.
        mockOrientation = 'LandscapeLeft';
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final presenceSource = _FakePresenceSource();
        final plank = _GateControllablePlank(
          maxRep: 3,
          presenceSource: presenceSource,
        );
        addTearDown(plank.disposeDetectors);
        final plankDef = lookupExerciseDefinition('plank')!;
        var controlCondition = true;
        var textScale = 1.5;
        late StateSetter updateHost;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                updateHost = setState;
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: ActiveExercisePage(
                    definition: plankDef,
                    exercise: plank,
                    currentSet: 1,
                    totalSets: 2,
                    totalReps: 3,
                    isTimeBased: true,
                    controlCondition: controlCondition,
                    onSetComplete: (_) {},
                    onBack: () {},
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1700));
        await tester.pump();

        // Confirm RotatedBox actually laid out the inner PageView at 568x320
        // and enabled compact landscape mode on ReadinessChecklist & GuidanceSignage!
        expect(
          tester.renderObject<RenderBox>(find.byType(PageView)).size,
          const Size(568, 320),
        );

        // 1. Pre-activation in 568x320 landscape + controlCondition + 1.5x text scale:
        // ReadinessChecklist, GuidanceSignage, and "Đang ghi nhận buổi tập" never overlap.
        plank.publishGuidanceSignal(const GuidanceSignal.turnSide());
        updateHost(() {});
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(ReadinessChecklist), findsOneWidget);
        expect(
          tester.widget<ReadinessChecklist>(find.byType(ReadinessChecklist)).compact,
          isTrue,
        );
        expect(find.byType(GuidanceSignage), findsOneWidget);
        expect(
          tester.widget<GuidanceSignage>(find.byType(GuidanceSignage)).landscape,
          isTrue,
        );
        expect(find.text('Chưa đủ căn cứ để chấm'), findsNothing);

        final checklistRect = tester.getRect(find.byType(ReadinessChecklist));
        final signageRect = tester.getRect(find.byType(GuidanceSignage));
        final controlLabelRect =
            tester.getRect(find.text('Đang ghi nhận buổi tập'));
        expect(checklistRect.overlaps(signageRect), isFalse);
        expect(checklistRect.overlaps(controlLabelRect), isFalse);
        expect(signageRect.overlaps(controlLabelRect), isFalse);

        // 2. HoldStill 3-2-1 countdown in 568x320 landscape + swipe to ExerciseDemoPage:
        // FormScoreArc and "HLV MẪU" header stay disjoint from ReadinessChecklist.
        plank
          ..overrideActivationProgress = 0.5
          ..publishGuidanceSignal(const GuidanceSignal.holdStill());
        updateHost(() {});
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(FormScoreArc), findsOneWidget);
        expect(
          tester
              .getRect(find.byType(ReadinessChecklist))
              .overlaps(tester.getRect(find.byType(FormScoreArc))),
          isFalse,
        );

        // Navigate PageView to Page 1 (ExerciseDemoPage) while checklist is up.
        final pageView = tester.widget<PageView>(find.byType(PageView));
        pageView.controller!.jumpToPage(1);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('HLV MẪU'), findsOneWidget);
        expect(
          tester
              .getRect(find.byType(ReadinessChecklist))
              .overlaps(tester.getRect(find.text('HLV MẪU'))),
          isFalse,
        );
        pageView.controller!.jumpToPage(0);
        await tester.pump();
        plank.overrideActivationProgress = null;

        // 3. Push a real no-pose frame over com.vikavn.app/pose_landmarker_stream
        // while activated -> triggers bodyInFrame / searching + "Chưa đủ căn cứ để chấm".
        controlCondition = false;
        textScale = 1.0;
        plank
          ..exerciseState = ExerciseState.activated
          ..clearGuidanceSignal();
        updateHost(() {});
        await tester.pump();

        final messenger = tester.binding.defaultBinaryMessenger;
        await messenger.handlePlatformMessage(
          'com.vikavn.app/pose_landmarker_stream',
          const StandardMethodCodec().encodeSuccessEnvelope(<String, Object?>{
            'imageWidth': 640,
            'imageHeight': 480,
            'rotationDegrees': 0,
            'isFrontCamera': true,
            'landmarks': const <Object>[],
          }),
          (_) {},
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(ReadinessChecklist), findsNothing);
        expect(find.text('Chưa đủ căn cứ để chấm'), findsOneWidget);

        // 4. Drive PresenceGate auto-pause (>400ms person lost) in 568x320 landscape:
        // IvoryPauseOverlay renders "Chưa đủ căn cứ để chấm" without overflow, then
        // auto-resume restores notActivated + ReadinessChecklist.
        final t0 = DateTime(2026, 11, 18, 12, 0, 0);
        presenceSource.personDetected = false;
        plank.drivePresence(now: t0, hasPose: false);
        plank.drivePresence(
          now: t0.add(const Duration(milliseconds: 500)),
          hasPose: false,
        );
        updateHost(() {});
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(plank.isPaused, isTrue);
        expect(find.byType(IvoryPauseOverlay), findsOneWidget);
        expect(find.text('Chưa đủ căn cứ để chấm'), findsOneWidget);
        expect(find.text('MẤT TÍN HIỆU'), findsOneWidget);

        // Rotating upright and back to landscape while still auto-paused (before
        // the next 1fps pose event) must NOT drop "Chưa đủ căn cứ để chấm".
        await messenger.handlePlatformMessage(
          'native_device_orientation_events',
          const StandardMethodCodec().encodeSuccessEnvelope('PortraitUp'),
          (_) {},
        );
        await tester.pump();
        await messenger.handlePlatformMessage(
          'native_device_orientation_events',
          const StandardMethodCodec().encodeSuccessEnvelope('LandscapeLeft'),
          (_) {},
        );
        await tester.pump();
        expect(plank.isPaused, isTrue);
        expect(find.byType(IvoryPauseOverlay), findsOneWidget);
        expect(find.text('Chưa đủ căn cứ để chấm'), findsOneWidget);

        presenceSource.personDetected = true;
        plank.drivePresence(
          now: t0.add(const Duration(milliseconds: 600)),
          hasPose: true,
        );
        plank.drivePresence(
          now: t0.add(const Duration(milliseconds: 1000)),
          hasPose: true,
        );
        plank.publishGuidanceSignal(const GuidanceSignal.setupPosition());
        updateHost(() {});
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(plank.isPaused, isFalse);
        expect(plank.exerciseState, ExerciseState.notActivated);
        expect(find.byType(ReadinessChecklist), findsOneWidget);
        expect(find.text('Chưa đủ căn cứ để chấm'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'notched portrait safe-area insets in RotatedBox landscape clear hardware cutout and keep ReadinessChecklist disjoint from top chrome, countdown ring, and control pill',
      (tester) async {
        mockOrientation = 'LandscapeLeft';
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final plank = _GateControllablePlank(
          maxRep: 3,
          presenceSource: _FakePresenceSource(),
        );
        addTearDown(plank.disposeDetectors);
        final plankDef = lookupExerciseDefinition('plank')!;
        late StateSetter updateHost;

        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                updateHost = setState;
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 59, bottom: 34),
                    viewPadding: const EdgeInsets.only(top: 59, bottom: 34),
                    textScaler: const TextScaler.linear(1.5),
                  ),
                  child: ActiveExercisePage(
                    definition: plankDef,
                    exercise: plank,
                    currentSet: 1,
                    totalSets: 2,
                    totalReps: 3,
                    isTimeBased: true,
                    controlCondition: true,
                    onSetComplete: (_) {},
                    onBack: () {},
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1700));
        await tester.pump();

        plank.publishGuidanceSignal(const GuidanceSignal.turnSide());
        updateHost(() {});
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Under RotatedBox(quarterTurns: 1), portrait top=59 (notch) is screen y=0..59.
        final checklistScreenRect =
            tester.getRect(find.byType(ReadinessChecklist));
        final topChromeRect =
            tester.getRect(find.byType(IvoryTopChromeLeft));
        final signageRect = tester.getRect(find.byType(GuidanceSignage));
        final controlRect =
            tester.getRect(find.text('Đang ghi nhận buổi tập'));

        expect(checklistScreenRect.top, greaterThanOrEqualTo(59.0));
        expect(checklistScreenRect.overlaps(topChromeRect), isFalse);
        expect(checklistScreenRect.overlaps(signageRect), isFalse);
        expect(checklistScreenRect.overlaps(controlRect), isFalse);

        // HoldStill countdown ring also stays disjoint and unclipped under notched insets.
        plank
          ..overrideActivationProgress = 0.5
          ..publishGuidanceSignal(const GuidanceSignal.holdStill());
        updateHost(() {});
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(FormScoreArc), findsOneWidget);
        expect(
          tester
              .getRect(find.byType(ReadinessChecklist))
              .overlaps(tester.getRect(find.byType(FormScoreArc))),
          isFalse,
        );

        // Rotate to LandscapeRight (quarterTurns: 3): portrait bottom=34 (home bar)
        // sits at screen y=0..34, and portrait top=59 (notch) sits at screen y=509..568.
        plank
          ..overrideActivationProgress = null
          ..publishGuidanceSignal(const GuidanceSignal.turnSide());
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'native_device_orientation_events',
          const StandardMethodCodec().encodeSuccessEnvelope('LandscapeRight'),
          (_) {},
        );
        updateHost(() {});
        await tester.pump();
        expect(tester.takeException(), isNull);

        final rightChecklistRect =
            tester.getRect(find.byType(ReadinessChecklist));
        final rightSignageRect = tester.getRect(find.byType(GuidanceSignage));
        expect(rightChecklistRect.bottom, lessThanOrEqualTo(568.0 - 34.0));
        expect(rightSignageRect.top, greaterThanOrEqualTo(59.0));
        expect(rightChecklistRect.overlaps(rightSignageRect), isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });
}
