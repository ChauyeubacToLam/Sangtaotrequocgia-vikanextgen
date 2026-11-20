import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vika/data/library_mock.dart';
import 'package:vika/models/exercise_definition.dart';
import 'package:vika/models/exercise_lookup.dart';
import 'package:vika/models/kept_exercises.dart';
import 'package:vika/screens/exercise/exercise_experience_screen.dart';
import 'package:vika/screens/exercise/exercise_intro_page.dart';
import 'package:vika/screens/exercise/exercise_launch_args.dart';
import 'package:vika/screens/exercise/exercise_launch_guard.dart';
import 'package:vika/screens/library_browse_screen.dart';
import 'package:vika/screens/library_catalog_screen.dart';
import 'package:vika/screens/library_screen.dart';
import 'package:vika/screens/plan_retest_screen.dart';
import 'package:vika/screens/reviewer/reviewer_plan_screen.dart';
import 'package:vika/services/catalog/catalog_source.dart';
import 'package:vika/services/recommendation/fitness_retest_service.dart';
import 'package:vika/services/recommendation/models/plan.dart';
import 'package:vika/services/recommendation/recommendation_service.dart';
import 'package:vika/theme/typography.dart';
import 'package:vika/widgets/library/library_card.dart';
import 'package:vika/widgets/library/library_rail.dart';

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
    loader.addFont(
      Future<ByteData>.value(
        ByteData.sublistView(bytes),
      ),
    );
  }
  await loader.load();
}

List<Map<String, dynamic>> _loadCatalogRows() {
  final raw = File('assets/data/exercise_catalog.json').readAsStringSync();
  return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
}

Widget _guardedNavHost({
  required GlobalKey<NavigatorState> navKey,
  Widget? home,
}) {
  return MaterialApp(
    navigatorKey: navKey,
    onGenerateRoute: (settings) {
      if (settings.name == '/exercise') {
        return buildGuardedExerciseRoute(settings);
      }
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) =>
            home ??
            const Scaffold(
              body: Center(child: Text('Home')),
            ),
      );
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> catalogRows;
  late List<String> hiddenIds;
  late List<String> keptIds;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _loadBeVietnamProFont();
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
    await CatalogSource.instance.ensureLoaded();
    catalogRows = _loadCatalogRows();
    hiddenIds = [
      for (final row in catalogRows)
        if (!keptExerciseIds.contains(row['catalogId'] as String))
          row['catalogId'] as String,
    ];
    keptIds = [
      for (final row in catalogRows)
        if (keptExerciseIds.contains(row['catalogId'] as String))
          row['catalogId'] as String,
    ];
  });

  group('Launch guard (/exercise)', () {
    testWidgets(
      'refuses all 19 hidden exercises, warrior_one_assessment, and invalid args without crashing',
      (tester) async {
        expect(hiddenIds, hasLength(19));
        final navKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(_guardedNavHost(navKey: navKey));
        await tester.pump();

        for (final hiddenId in hiddenIds) {
          final def = lookupExerciseDefinition(hiddenId);
          expect(def, isNotNull, reason: hiddenId);

          // 1. Pushed as bare ExerciseDefinition: auto-pops on first frame with
          // refusal SnackBar and never mounts ExerciseExperienceScreen.
          final futureDef = navKey.currentState!.pushNamed(
            '/exercise',
            arguments: def,
          );
          await tester.pump();
          expect(
            find.byType(ExerciseExperienceScreen),
            findsNothing,
            reason:
                'Hidden $hiddenId (def) must not mount ExerciseExperienceScreen',
          );
          await tester.pump(const Duration(milliseconds: 350));
          expect(await futureDef, isNull);
          expect(
            find.text('Bài tập này tạm ẩn trong phiên bản hiện tại.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          // 2. Pushed as ExerciseLaunchArgs.
          final futureArgs = navKey.currentState!.pushNamed(
            '/exercise',
            arguments: ExerciseLaunchArgs(
              definition: def!,
              catalogExerciseId: hiddenId,
            ),
          );
          await tester.pump();
          expect(
            find.byType(ExerciseExperienceScreen),
            findsNothing,
            reason:
                'Hidden $hiddenId (args) must not mount ExerciseExperienceScreen',
          );
          await tester.pump(const Duration(milliseconds: 350));
          expect(await futureArgs, isNull);
          expect(tester.takeException(), isNull);
        }

        // Assessment variant of hidden warrior_one + malformed/null args.
        for (final extra in <Object?>[
          warriorOneAssessmentDefinition,
          null,
          'not_launch_args',
        ]) {
          final f = navKey.currentState!.pushNamed(
            '/exercise',
            arguments: extra,
          );
          await tester.pump();
          expect(find.byType(ExerciseExperienceScreen), findsNothing);
          await tester.pump(const Duration(milliseconds: 350));
          expect(await f, isNull);
          expect(tester.takeException(), isNull);
        }

        // 3. Root / replaced route (`canPop() == false`): stays on
        // BlockedExerciseLaunchScreen with a 'Quay lại' button to '/'.
        unawaited(
          navKey.currentState!.pushReplacementNamed(
            '/exercise',
            arguments: lookupExerciseDefinition('cobra'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(BlockedExerciseLaunchScreen), findsOneWidget);
        expect(find.byType(ExerciseExperienceScreen), findsNothing);
        expect(find.text('Quay lại'), findsOneWidget);

        await tester.tap(find.text('Quay lại'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Home'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    test(
      'sanitizes mixed sequences in resolveAllowedExerciseLaunchArgs and ExerciseLaunchArgs.nextInSequence',
      () {
        final squatDef = lookupExerciseDefinition('squat')!;
        final cobraDef = lookupExerciseDefinition('cobra')!;
        final plankDef = lookupExerciseDefinition('plank')!;

        final raw = ExerciseLaunchArgs(
          definition: squatDef,
          catalogExerciseId: 'squat',
          sequenceIndex: 0,
          sequence: [
            ExerciseSequenceItem(
              definition: squatDef,
              catalogExerciseId: 'squat',
            ),
            ExerciseSequenceItem(
              definition: cobraDef,
              catalogExerciseId: 'cobra',
            ),
            ExerciseSequenceItem(
              definition: plankDef,
              catalogExerciseId: 'plank',
            ),
          ],
        );

        // nextInSequence skips hidden cobra directly to plank.
        final next = raw.nextInSequence();
        expect(next, isNotNull);
        expect(next!.definition.id, plankDef.id);
        expect(next.nextInSequence(), isNull);

        // resolveAllowedExerciseLaunchArgs strips hidden items from sequence.
        final sanitized = resolveAllowedExerciseLaunchArgs(raw)!;
        expect(
          sanitized.sequence.map((i) => i.catalogExerciseId),
          ['squat', 'plank'],
        );
        expect(sanitized.sequenceIndex, 0);

        // When sequenceIndex points at a hidden slot after 1 kept slot,
        // mappedIndex advances to the next kept slot (1) rather than rewinding to 0.
        final midHidden = ExerciseLaunchArgs(
          definition: squatDef,
          catalogExerciseId: 'squat',
          sequenceIndex: 1,
          sequence: [
            ExerciseSequenceItem(
              definition: plankDef,
              catalogExerciseId: 'plank',
            ),
            ExerciseSequenceItem(
              definition: cobraDef,
              catalogExerciseId: 'cobra',
            ),
            ExerciseSequenceItem(
              definition: squatDef,
              catalogExerciseId: 'squat',
            ),
          ],
        );
        final sanitizedMid = resolveAllowedExerciseLaunchArgs(midHidden)!;
        expect(
          sanitizedMid.sequence.map((i) => i.catalogExerciseId),
          ['plank', 'squat'],
        );
        expect(sanitizedMid.sequenceIndex, 1);

        // Out-of-bounds sequenceIndex is clamped safely.
        final outOfBounds = ExerciseLaunchArgs(
          definition: squatDef,
          catalogExerciseId: 'squat',
          sequenceIndex: 99,
          sequence: [
            ExerciseSequenceItem(
              definition: plankDef,
              catalogExerciseId: 'plank',
            ),
            ExerciseSequenceItem(
              definition: squatDef,
              catalogExerciseId: 'squat',
            ),
          ],
        );
        expect(
          resolveAllowedExerciseLaunchArgs(outOfBounds)!.sequenceIndex,
          1,
        );

        // Hidden catalogInfo.id is refused even if definition.id is kept and
        // catalogExerciseId is omitted.
        final poisonedCatalogInfo = ExerciseLaunchArgs(
          definition: squatDef,
          catalogInfo: CatalogSource.instance.lookup('cobra'),
        );
        expect(resolveAllowedExerciseLaunchArgs(poisonedCatalogInfo), isNull);
      },
    );

    test('all 21 kept exercises build ExerciseExperienceSpec cleanly', () {
      expect(keptIds, hasLength(21));
      for (final keptId in keptIds) {
        final def = lookupExerciseDefinition(keptId);
        final info = CatalogSource.instance.lookup(keptId);
        expect(def, isNotNull, reason: keptId);
        expect(info, isNotNull, reason: keptId);

        final spec = debugBuildExerciseExperienceSpec(
          def!,
          catalogInfo: info,
        );
        expect(spec.targetPerSet, greaterThan(0), reason: keptId);
      }
    });

    testWidgets(
      'all 21 kept exercises launch onto ExerciseIntroPage and show the right status label',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        expect(keptIds, hasLength(21));
        final navKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(_guardedNavHost(navKey: navKey));
        await tester.pump();

        for (final keptId in keptIds) {
          final def = lookupExerciseDefinition(keptId)!;
          final info = CatalogSource.instance.lookup(keptId)!;

          unawaited(
            navKey.currentState!.pushNamed(
              '/exercise',
              arguments: ExerciseLaunchArgs(
                definition: def,
                catalogExerciseId: keptId,
                catalogInfo: info,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(
            find.byType(ExerciseExperienceScreen),
            findsOneWidget,
            reason: '$keptId should launch ExerciseExperienceScreen',
          );
          expect(find.byType(ExerciseIntroPage), findsOneWidget, reason: keptId);
          expect(find.byType(BlockedExerciseLaunchScreen), findsNothing);

          final expectedLabel = validatedExerciseIds.contains(keptId)
              ? 'Đã kiểm chứng'
              : 'Chỉ đếm, chưa kiểm chứng';
          final unexpectedLabel = validatedExerciseIds.contains(keptId)
              ? 'Chỉ đếm, chưa kiểm chứng'
              : 'Đã kiểm chứng';
          expect(
            find.text(expectedLabel),
            findsOneWidget,
            reason: '$keptId detail page missing "$expectedLabel"',
          );
          expect(
            find.text(unexpectedLabel),
            findsNothing,
            reason: '$keptId detail page showed wrong label "$unexpectedLabel"',
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$keptId threw layout exception',
          );

          navKey.currentState!.pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
        }

        // Blank/whitespace catalogExerciseId falls back to catalogInfo/definition
        // without dropping the validation label.
        for (final blankId in ['', '   ']) {
          unawaited(
            navKey.currentState!.pushNamed(
              '/exercise',
              arguments: ExerciseLaunchArgs(
                definition: lookupExerciseDefinition('squat')!,
                catalogExerciseId: blankId,
                catalogInfo: CatalogSource.instance.lookup('squat'),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          expect(find.byType(ExerciseIntroPage), findsOneWidget);
          expect(find.text('Đã kiểm chứng'), findsOneWidget);
          navKey.currentState!.pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
        }

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('Library, Catalog, Browse, and ReviewerPlan UI', () {
    for (final size in const [Size(390, 844), Size(430, 932)]) {
      testWidgets(
        'LibraryScreen renders only kept exercises and shows quiet validation labels at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LibraryScreen(
                  bottomPadding: 80,
                  onSelectExercise: (_) {},
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull);
          // Featured card in LibraryCatalogEntry is Squat -> validated.
          expect(find.text('Đã kiểm chứng'), findsWidgets);

          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    for (final size in const [Size(390, 844), Size(320, 568)]) {
      testWidgets(
        'LibraryCatalogScreen renders only kept exercises, shows validation labels, and hides unkept search queries at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              home: LibraryCatalogScreen(
                rows: libraryMockAllExercises,
                onSelectByName: (_) {},
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull);
          // First tab ('CHÂN · MÔNG') has Squat & Glute Bridge (validated) plus
          // Lunge & Jump Squat (counts-only).
          expect(find.text('Đã kiểm chứng'), findsWidgets);
          expect(find.text('Chỉ đếm, chưa kiểm chứng'), findsWidgets);

          // Searching for hidden exercises yields no results.
          for (final hiddenQuery in [
            'rắn hổ mang',
            'chiến binh',
            'burpee',
            'cossack',
          ]) {
            await tester.enterText(find.byType(TextField), hiddenQuery);
            await tester.pump(const Duration(milliseconds: 100));
            expect(
              find.textContaining('Không tìm thấy'),
              findsOneWidget,
              reason: 'Hidden query "$hiddenQuery" should find nothing',
            );
            expect(tester.takeException(), isNull);
          }

          // Every muscle-group tab renders cleanly without overflow at $size.
          for (final group in orderedCatalogGroups(libraryMockAllExercises)) {
            await tester.pumpWidget(
              MaterialApp(
                home: LibraryCatalogScreen(
                  rows: libraryMockAllExercises,
                  initialGroup: group,
                  onSelectByName: (_) {},
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 200));
            expect(
              tester.takeException(),
              isNull,
              reason: 'LibraryCatalogScreen group "$group" overflowed at $size',
            );
          }

          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets(
      'LibraryRail fits at VikaType.maxScale (1.3x) without overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Two-line exercise card title inside LibraryRail at 1.3x text scale.
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: MaterialApp(
              builder: (context, child) =>
                  VikaType.clampTextScaler(context, child),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: LibraryRail(
                    eyebrow: 'CÓ CAMERA AI',
                    cards: const [
                      LibraryCardData(
                        kind: LibraryCardKind.exercise,
                        title: 'Tư thế ngồi gập người',
                        detail: 'Gân kheo · lưng',
                        hasAi: true,
                        exerciseName: 'seated_forward_fold',
                      ),
                    ],
                    onSelectCard: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        expect(find.text('Chỉ đếm, chưa kiểm chứng'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'PlanRetestScreen launches kept squat assessment and resolveRetestFirstSessionLaunchArgs skips hidden slots',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        const mixedFirstSessionPlan = Plan(
          recommendationId: 'retest-rec-1',
          userId: 'user-1',
          templateKey: 'yoga_flexible',
          planScope: kPlanScopeFull,
          weeks: [
            WeekPlan(
              weekNumber: 1,
              phaseNumber: 1,
              phaseName: 'Nền tảng',
              isDeloadWeek: false,
              sessions: [
                SessionPlan(
                  sessionIndex: 0,
                  slots: [
                    SlotAssignment(
                      slotName: 's1',
                      exerciseId: 'warrior_one',
                      volume: VolumePrescription(
                        sets: 1,
                        reps: 2,
                        restSeconds: 30,
                      ),
                      score: 0.8,
                      topKCandidates: [],
                    ),
                    SlotAssignment(
                      slotName: 's2',
                      exerciseId: 'cobra',
                      volume: VolumePrescription(
                        sets: 1,
                        reps: 3,
                        restSeconds: 30,
                      ),
                      score: 0.8,
                      topKCandidates: [],
                    ),
                    SlotAssignment(
                      slotName: 's3',
                      exerciseId: 'sphinx',
                      volume: VolumePrescription(
                        sets: 1,
                        reps: 1,
                        seconds: 30,
                        restSeconds: 30,
                      ),
                      score: 0.9,
                      topKCandidates: [],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        final resolved =
            resolveRetestFirstSessionLaunchArgs(mixedFirstSessionPlan);
        expect(resolved, isNotNull);
        expect(resolved!.catalogExerciseId, 'sphinx');
        expect(resolved.slotName, 's3');

        const hiddenOnlyFirstSessionPlan = Plan(
          recommendationId: 'retest-rec-2',
          userId: 'user-1',
          templateKey: 'yoga_flexible',
          planScope: kPlanScopeFull,
          weeks: [
            WeekPlan(
              weekNumber: 1,
              phaseNumber: 1,
              phaseName: 'Nền tảng',
              isDeloadWeek: false,
              sessions: [
                SessionPlan(
                  sessionIndex: 0,
                  slots: [
                    SlotAssignment(
                      slotName: 's1',
                      exerciseId: 'warrior_one',
                      volume: VolumePrescription(
                        sets: 1,
                        reps: 2,
                        restSeconds: 30,
                      ),
                      score: 0.8,
                      topKCandidates: [],
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
        expect(
          resolveRetestFirstSessionLaunchArgs(hiddenOnlyFirstSessionPlan),
          isNull,
        );

        final navKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          _guardedNavHost(
            navKey: navKey,
            home: PlanRetestScreen(
              args: const PlanRetestLaunchArgs(
                pending: PendingFitnessRetest(
                  recommendationId: 'retest-rec-1',
                  plan: mixedFirstSessionPlan,
                  weekNumber: 7,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Bắt đầu kiểm tra'), findsOneWidget);

        await tester.tap(find.text('Bắt đầu kiểm tra'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(ExerciseIntroPage), findsOneWidget);
        expect(find.text('Đã kiểm chứng'), findsOneWidget);
        expect(tester.takeException(), isNull);

        navKey.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'LibraryBrowseScreen renders all 6 facet tiles (including back) without crashing or leaking hidden exercises',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final tileGrid = librarySections
            .whereType<LibrarySectionTileGrid>()
            .single;
        for (final tile in tileGrid.tiles) {
          await tester.pumpWidget(
            MaterialApp(
              home: LibraryBrowseScreen(
                tile: tile,
                onSelectExercise: (_) {},
                onSelectCard: (_) {},
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 150));
          expect(
            tester.takeException(),
            isNull,
            reason: 'Tile ${tile.id} threw',
          );
          expect(find.text('Tư thế rắn hổ mang'), findsNothing);
          expect(find.text('Tư thế cánh cung'), findsNothing);
          expect(find.text('Tư thế chiến binh I'), findsNothing);
        }

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'ReviewerPlanScreen skips hidden slots in a stored plan snapshot',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final snapshot = PlanSnapshot(
          plan: const Plan(
            recommendationId: 'rev-1',
            userId: 'demo-user',
            templateKey: 'yoga_health',
            planScope: kPlanScopeFull,
            weeks: [
              WeekPlan(
                weekNumber: 1,
                phaseNumber: 1,
                phaseName: 'Nền tảng',
                isDeloadWeek: false,
                sessions: [
                  SessionPlan(
                    sessionIndex: 0,
                    slots: [
                      SlotAssignment(
                        slotName: 's1',
                        exerciseId: 'cobra',
                        volume: VolumePrescription(
                          sets: 1,
                          reps: 3,
                          restSeconds: 30,
                        ),
                        score: 0.8,
                        topKCandidates: [],
                      ),
                      SlotAssignment(
                        slotName: 's2',
                        exerciseId: 'sphinx',
                        volume: VolumePrescription(
                          sets: 1,
                          reps: 1,
                          seconds: 30,
                          restSeconds: 30,
                        ),
                        score: 0.9,
                        topKCandidates: [],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ReviewerPlanScreen(
              planFutureOverride: () async => snapshot,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
        expect(find.text('Tư thế nhân sư'), findsOneWidget);
        expect(find.text('Tư thế rắn hổ mang'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
