import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vika/data/library_mock.dart';
import 'package:vika/data/program_mock.dart';
import 'package:vika/data/vika_albums.dart';
import 'package:vika/interpreter/intepreting_map.dart';
import 'package:vika/models/exercise_definition.dart';
import 'package:vika/models/exercise_lookup.dart';
import 'package:vika/models/kept_exercises.dart';
import 'package:vika/models/pain_regions.dart';
import 'package:vika/services/catalog/catalog_source.dart';
import 'package:vika/services/recommendation/models/exercise_catalog_entry.dart';
import 'package:vika/services/recommendation/models/plan.dart';
import 'package:vika/services/recommendation/program_plan_mapper.dart';
import 'package:vika/services/recommendation/progression_service.dart';
import 'package:vika/services/recommendation/recommendation_engine.dart';
import 'package:vika/services/recommendation/recommendation_service.dart';
import 'package:vika/services/recommendation/templates.dart';
import 'package:vika/services/user_program_service.dart';
import 'package:vika/services/workout_launch_service.dart';

class _OfflineRecommendationService extends RecommendationService {
  _OfflineRecommendationService() : super(client: null);
}

List<Map<String, dynamic>> _loadBundledCatalogRows() {
  final raw = File('assets/data/exercise_catalog.json').readAsStringSync();
  return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
}

List<ExerciseCatalogEntry> _loadSeedCatalogEntries() {
  final sql = File('supabase/seed.sql').readAsStringSync();
  final blockPattern = RegExp(
    r'\(\s*--\s*([a-z0-9_]+)\s*\r?\n([\s\S]*?)\r?\n\s*\)',
  );

  List<String> parseSqlTextArray(String expr) {
    final trimmed = expr.trim();
    if (trimmed.startsWith("'{}'")) return const [];
    return [
      for (final m in RegExp(r"'([^']*)'").allMatches(trimmed)) m.group(1)!,
    ];
  }

  String? parseNullableString(String expr) {
    final trimmed = expr.trim();
    if (trimmed == 'null') return null;
    return RegExp(r"^'(.*)'$").firstMatch(trimmed)!.group(1);
  }

  int? parseNullableInt(String expr) {
    final trimmed = expr.trim();
    if (trimmed == 'null') return null;
    return int.parse(trimmed);
  }

  Map<String, dynamic> parseJsonb(String expr) {
    final jsonText =
        RegExp(r"^'(.*)'::jsonb$").firstMatch(expr.trim())!.group(1)!;
    return (jsonDecode(jsonText) as Map).cast<String, dynamic>();
  }

  final entries = <ExerciseCatalogEntry>[];
  for (final match in blockPattern.allMatches(sql)) {
    final lines = match
        .group(2)!
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.endsWith(',')
            ? line.substring(0, line.length - 1).trim()
            : line)
        .toList();
    expect(lines.length, 27, reason: 'Unexpected column count for ${match.group(1)}');

    entries.add(
      ExerciseCatalogEntry.fromSupabase({
        'id': parseNullableString(lines[0]),
        'vietnamese_name': parseNullableString(lines[1]),
        'english_name': parseNullableString(lines[2]),
        'fork': parseNullableString(lines[3]),
        'body_regions': parseSqlTextArray(lines[4]),
        'muscle_groups': parseSqlTextArray(lines[5]),
        'difficulty_tier': int.parse(lines[6]),
        'goal_fit': parseJsonb(lines[7]),
        'pain_safe': parseSqlTextArray(lines[8]),
        'pain_contraindicated': parseSqlTextArray(lines[9]),
        'is_form_checked': lines[10] == 'true',
        'is_corrective': lines[11] == 'true',
        'corrective_for': parseSqlTextArray(lines[12]),
        'class_key': parseNullableString(lines[13]),
        'video_url': parseNullableString(lines[14]),
        'base_sets': parseNullableInt(lines[15]),
        'base_reps': parseNullableInt(lines[16]),
        'base_seconds': parseNullableInt(lines[17]),
        'progression_from': parseNullableString(lines[18]),
        'progression_to': parseNullableString(lines[19]),
        'metadata': parseJsonb(lines[20]),
        'max_reps_beginner': parseNullableInt(lines[21]),
        'max_reps_intermediate': parseNullableInt(lines[22]),
        'max_reps_advanced': parseNullableInt(lines[23]),
        'max_seconds_beginner': parseNullableInt(lines[24]),
        'max_seconds_intermediate': parseNullableInt(lines[25]),
        'max_seconds_advanced': parseNullableInt(lines[26]),
      }),
    );
  }
  return entries;
}

/// Dart class-name / report-builder key forms for exercises where class/builder
/// keys differ from `catalogId` or `definitionId`.
const Map<String, List<String>> _extraClassKeyForms = {
  'squat': ['Squat', 'squat_bw', 'SQUAT'],
  'push_up': ['PushUp', 'pushup'],
  'glute_bridge': ['GluteBridge', 'glute_bridge_bw'],
  'plank': ['Plank', 'forearm_plank'],
  'lunge': ['Lunge', 'reverse_lunge'],
  'jump_squat': ['JumpSquat'],
  'jumping_jack': ['JumpingJack', 'Nhảy Dạng'],
  'wall_pushup': ['WallPushUp', 'wall_push_up', 'WALL_PUSHUP'],
  'situp': ['SitUp', 'sit_up'],
  'leg_raises': ['LegRaise', 'leg_raise'],
  'vup': ['VUp', 'v_up', 'VUP'],
  'mcgill_curlup': [
    'CurlUp',
    'curl_up',
    'mcgill_curl_up',
    'mcgill_curlup_bw',
    'MCGILL_CURLUP',
  ],
  'dead_bug': ['DeadBug'],
  'bird_dog': ['BirdDog'],
  'mountain_climber': ['MountainClimber'],
  'superman': ['Superman'],
  'tricep_dip': ['TricepDip', 'TRICEP_DIP'],
  'side_plank_dip': ['SidePlankDip', 'SIDE_PLANK_DIP'],
  'seated_forward_fold': ['SeatedForwardFold'],
  'butterfly': ['ButterflyStretch', 'butterfly_stretch'],
  'sphinx': ['SphinxStretch', 'sphinx_stretch', 'SPHINX'],
  'step_up': ['StepUp', 'step_ups', 'Chair Step-Up'],
  'neck_side_stretch': ['NeckSideStretch', 'neck_stretch'],
  'pushup_rotation': ['PushUpRotation', 'push_up_rotation', 'T Push-Up'],
};

const Map<String, List<String>> _extraHiddenClassForms = {
  'ashtanga_namaskara': ['AshtangaNamaskara'],
  'bear_plank': ['BearPlank'],
  'bow_pose': ['BowPose'],
  'cobra': ['Cobra', 'Cobra Pose'],
  'cossack_squat': ['CossackSquat'],
  'downward_dog': ['DownwardDog'],
  'high_plank': ['HighPlank'],
  'low_lunge': ['LowLunge'],
  'plank_shoulder_tap': ['PlankShoulderTap'],
  'plank_up_down': ['PlankUpDown'],
  'prayer_pose': ['PrayerPose'],
  'raised_arms': ['RaisedArms', 'Raised Arms Pose'],
  'reverse_crunch': ['ReverseCrunch'],
  'russian_twist': ['RussianTwist'],
  'standing_knee_to_elbow': ['StandingKneeToElbow'],
  'step_back_burpee': ['StepBackBurpee'],
  'surya_namaskar': ['SuryaNamaskarExercise'],
  'walking_lunge': ['WalkingLunge'],
  'warrior_one': ['WarriorOne', 'warrior_i'],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> catalogRows;
  late Set<String> allCatalogIds;
  late Set<String> hiddenCatalogIds;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
    catalogRows = _loadBundledCatalogRows();
    allCatalogIds = {
      for (final row in catalogRows) row['catalogId'] as String,
    };
    hiddenCatalogIds = allCatalogIds.difference(keptExerciseIds);
    await CatalogSource.instance.ensureLoaded();
  });

  group('single source of truth (kept_exercises.dart)', () {
    test('partitions the 43-exercise catalog into 21 kept (4 validated + 17 counts-only) and 22 hidden', () {
      expect(catalogRows, hasLength(43));
      expect(keptExerciseIds, hasLength(21));
      expect(validatedExerciseIds, hasLength(4));
      expect(keptExerciseIds.containsAll(validatedExerciseIds), isTrue);
      expect(allCatalogIds.containsAll(keptExerciseIds), isTrue);
      expect(hiddenCatalogIds, hasLength(22));
    });

    test('resolves isKeptExercise and exerciseValidationStatus for all 21 kept exercises across catalogId, definitionId, and classKey forms', () {
      for (final row in catalogRows) {
        final catalogId = row['catalogId'] as String;
        if (!keptExerciseIds.contains(catalogId)) continue;

        final definitionId = row['definitionId'] as String;
        final classKey = row['classKey'] as String;
        final expectedStatus = validatedExerciseIds.contains(catalogId)
            ? ExerciseValidationStatus.validated
            : ExerciseValidationStatus.countsOnly;
        final expectedLabel = validatedExerciseIds.contains(catalogId)
            ? 'Đã kiểm chứng'
            : 'Chỉ đếm, chưa kiểm chứng';

        final instance = lookupExerciseDefinition(catalogId)!
            .createExercise(reps: 5, seconds: 15);
        final forms = <String>{
          catalogId,
          definitionId,
          classKey,
          instance.exerciseName,
          ...?_extraClassKeyForms[catalogId],
        };

        for (final form in forms) {
          expect(
            isKeptExercise(form),
            isTrue,
            reason: 'Expected "$form" ($catalogId) to be kept',
          );
          final status = exerciseValidationStatus(form);
          expect(
            status,
            expectedStatus,
            reason: 'Wrong status for "$form" ($catalogId)',
          );
          expect(
            status?.vietnameseLabel,
            expectedLabel,
            reason: 'Wrong label for "$form" ($catalogId)',
          );
        }
      }
    });

    test('rejects all 22 hidden exercises across catalogId, definitionId, and classKey forms, plus edge inputs', () {
      for (final row in catalogRows) {
        final catalogId = row['catalogId'] as String;
        if (keptExerciseIds.contains(catalogId)) continue;

        final instance = lookupExerciseDefinition(catalogId)!
            .createExercise(reps: 5, seconds: 15);
        final forms = <String>{
          catalogId,
          row['definitionId'] as String,
          row['classKey'] as String,
          instance.exerciseName,
          ...?_extraHiddenClassForms[catalogId],
        };
        for (final form in forms) {
          expect(
            isKeptExercise(form),
            isFalse,
            reason: 'Hidden exercise "$form" ($catalogId) must not be kept',
          );
          expect(
            exerciseValidationStatus(form),
            isNull,
            reason: 'Hidden exercise "$form" ($catalogId) must have null status',
          );
        }
      }

      for (final edge in [
        '',
        '   ',
        '_assessment',
        '   assessment',
        'warrior_one_assessment',
        'Warrior I Assessment',
        'unknown_xyz',
      ]) {
        expect(isKeptExercise(edge), isFalse, reason: 'Edge "$edge"');
        expect(exerciseValidationStatus(edge), isNull, reason: 'Edge "$edge"');
      }

      for (final squatForm in ['squat_assessment', 'Squat Assessment']) {
        expect(isKeptExercise(squatForm), isTrue, reason: squatForm);
        expect(
          exerciseValidationStatus(squatForm)?.vietnameseLabel,
          'Đã kiểm chứng',
          reason: squatForm,
        );
      }
      for (final countsOnlyForm in [
        'wall_pushup_assessment',
        'Wall Pushup Assessment',
        'seated_forward_fold_assessment',
        'Seated Forward Fold Assessment',
      ]) {
        expect(isKeptExercise(countsOnlyForm), isTrue, reason: countsOnlyForm);
        expect(
          exerciseValidationStatus(countsOnlyForm)?.vietnameseLabel,
          'Chỉ đếm, chưa kiểm chứng',
          reason: countsOnlyForm,
        );
      }
    });
  });

  group('Library & album routes', () {
    test('libraryMockAllExercises exposes exactly the 21 kept exercises and zero hidden exercises', () {
      final exposedIds = {
        for (final row in libraryMockAllExercises) row.definitionName!,
      };
      expect(libraryMockAllExercises, hasLength(21));
      expect(exposedIds, equals(keptExerciseIds));
      for (final hidden in hiddenCatalogIds) {
        expect(exposedIds, isNot(contains(hidden)));
      }
      expect(
        [for (final row in libraryMockAllExercises) row.idx],
        List<int>.generate(21, (i) => i + 1),
      );
    });

    test('libraryAiExerciseCards, vikaAlbums, vikaAlbumCards, and libraryFilters contain only kept exercises and matching counts', () {
      for (final card in libraryAiExerciseCards) {
        if (card.exerciseName != null) {
          expect(isKeptExercise(card.exerciseName!), isTrue);
        }
      }

      expect(vikaAlbums, isNotEmpty);
      for (final album in vikaAlbums) {
        expect(album.exerciseIds, isNotEmpty, reason: album.id);
        for (final id in album.exerciseIds) {
          expect(
            isKeptExercise(id),
            isTrue,
            reason: 'Album ${album.id} leaked hidden exercise $id',
          );
        }
      }

      for (final card in vikaAlbumCards) {
        for (final id in card.sequenceExerciseIds ?? const <String>[]) {
          expect(isKeptExercise(id), isTrue, reason: card.title);
        }
      }

      final byId = {for (final f in libraryFilters) f.id: f.count};
      expect(byId['exercise'], 21);
      expect(byId['album'], vikaAlbumCards.length);
      expect(byId['all'], 21 + vikaAlbumCards.length);
      expect(byId['yoga'], 3);
    });

    test('loadMockProgramPlan filters out hidden exercises', () {
      final plan = loadMockProgramPlan();
      for (final block in plan.blocks) {
        for (final session in block.sessions) {
          for (final ex in session.exercises) {
            expect(
              isKeptExercise(ex.exerciseId ?? ex.name),
              isTrue,
              reason: 'Mock plan leaked ${ex.exerciseId ?? ex.name}',
            );
          }
        }
      }
    });
  });

  group('RecommendationEngine, ProgressionService, and stored plans/history', () {
    test('RecommendationEngine never selects a hidden exercise across all 8 templates, 3 levels, single pains, and unlocked hidden variants', () {
      final fullSeedCatalog = _loadSeedCatalogEntries();
      expect(fullSeedCatalog, hasLength(43));
      final formCheckedSeed =
          fullSeedCatalog.where((e) => e.isFormChecked && !e.isCorrective).toList();
      expect(formCheckedSeed, hasLength(29));
      expect(
        formCheckedSeed.where((e) => isKeptExercise(e.id)),
        hasLength(19),
      );
      expect(
        formCheckedSeed.where((e) => !isKeptExercise(e.id)),
        hasLength(10),
      );

      List<ExerciseCatalogEntry> safePool(String fork, List<String> pains) {
        return formCheckedSeed
            .where((e) =>
                isKeptExercise(e.id) &&
                (e.fork == fork || e.fork == 'both') &&
                !e.painContraindicated.any(pains.contains))
            .toList();
      }

      // Unfiltered vs filtered fork pools (3 'both' rows: bird_dog, dead_bug, glute_bridge).
      expect(
        formCheckedSeed.where((e) => e.fork == 'home' || e.fork == 'both'),
        hasLength(24),
      );
      expect(safePool('home', const []), hasLength(17));
      expect(
        formCheckedSeed.where((e) => e.fork == 'yoga' || e.fork == 'both'),
        hasLength(8),
      );
      expect(safePool('yoga', const []), hasLength(5));

      const expectedHomeByPain = {
        'shoulder_neck': 9,
        'lower_back': 11,
        'hip': 12,
        'knee': 12,
        'wrist': 13,
        'ankle': 14,
        'back': 17,
      };
      for (final entry in expectedHomeByPain.entries) {
        expect(
          safePool('home', [entry.key]),
          hasLength(entry.value),
          reason: 'home pool for pain=${entry.key}',
        );
      }

      final allPainIds = [for (final region in painRegions) region.id];
      expect(
        safePool('home', allPainIds).map((e) => e.id).toSet(),
        {'dead_bug', 'glute_bridge'},
      );
      expect(
        safePool('yoga', allPainIds).map((e) => e.id).toSet(),
        {'dead_bug', 'glute_bridge'},
      );

      const engine = RecommendationEngine();
      const levels = ['beginner', 'intermediate', 'advanced'];
      final painCases = <List<String>>[
        const [],
        for (final region in painRegions) [region.id],
        const ['wrist', 'shoulder_neck', 'knee'],
        const ['lower_back', 'knee', 'hip'],
        [for (final region in painRegions) region.id],
      ];

      // Even if user_exercise_capacity had stale unlocks pointing to hidden
      // exercises, the engine must ignore them.
      const poisonedUnlocks = {
        'lunge': 'walking_lunge',
        'sphinx': 'cobra',
        'wall_pushup': 'push_up',
      };

      for (final template in launchTemplates.values) {
        for (final level in levels) {
          for (final pains in painCases) {
            final result = engine.generatePlan(
              RecommendationRequest(
                recommendationId: 'rec-${template.key}-$level',
                userId: 'user-test',
                template: template,
                catalog: fullSeedCatalog,
                fitnessLevel: level,
                goalKey: template.goal,
                activePainAreas: pains,
                recentExerciseIds: const ['cobra', 'warrior_one'],
                rngSeed: 'seed-${template.key}-$level-${pains.join(",")}',
                unlockedVariantByExerciseId: poisonedUnlocks,
              ),
            );

            expect(result.algorithmVersion, kRecommendationAlgorithmVersion);
            for (final week in result.plan.weeks) {
              for (final session in week.sessions) {
                expect(
                  session.slots,
                  hasLength(template.slots.length),
                  reason: '${template.key} $level pains=$pains',
                );
                for (final slot in session.slots) {
                  expect(
                    keptExerciseIds,
                    contains(slot.exerciseId),
                    reason:
                        '${template.key} $level pains=$pains picked hidden ${slot.exerciseId}',
                  );
                }
              }
            }
          }
        }
      }
    });

    test('ProgressionService blocks unlocking hidden progression_to targets while keeping kept progressions', () {
      final seedById = {
        for (final entry in _loadSeedCatalogEntries()) entry.id: entry,
      };

      // lunge -> walking_lunge (hidden): must NOT unlock even at streak >= 2.
      expect(
        resolveKeptProgressionTarget(
          exercise: seedById['lunge']!,
          nextStreak: 3,
          alreadyUnlocked: 'walking_lunge',
        ),
        isNull,
      );

      // sphinx -> cobra (hidden): must NOT unlock even at streak >= 2.
      expect(
        resolveKeptProgressionTarget(
          exercise: seedById['sphinx']!,
          nextStreak: 3,
          alreadyUnlocked: 'cobra',
        ),
        isNull,
      );

      // wall_pushup -> push_up (kept): unlocks at streak >= 3.
      expect(
        resolveKeptProgressionTarget(
          exercise: seedById['wall_pushup']!,
          nextStreak: 2,
        ),
        isNull,
      );
      expect(
        resolveKeptProgressionTarget(
          exercise: seedById['wall_pushup']!,
          nextStreak: 3,
        ),
        'push_up',
      );

      // situp -> vup (kept): unlocks at streak >= 3.
      expect(
        resolveKeptProgressionTarget(
          exercise: seedById['situp']!,
          nextStreak: 3,
        ),
        'vup',
      );

      final filteredNotices = filterKeptUnlockRows([
        {'exercise_id': 'lunge', 'unlocked_next_id': 'walking_lunge'},
        {'exercise_id': 'sphinx', 'unlocked_next_id': 'cobra'},
        {'exercise_id': 'high_plank', 'unlocked_next_id': 'plank'},
        {'exercise_id': 'wall_pushup', 'unlocked_next_id': 'push_up'},
      ]);
      expect(filteredNotices, [
        {'exercise_id': 'wall_pushup', 'unlocked_next_id': 'push_up'},
      ]);
    });

    test('saved plans skip hidden exercises in Plan.fromSupabase, ProgramPlanMapper, and WorkoutLaunchService without crashing', () async {
      // 1. Deserialization from stored recommendations_log JSON.
      final deserialized = Plan.fromSupabase(
        recommendationId: 'stored-rec-1',
        userId: 'user-1',
        templateKey: 'yoga_flexible',
        planStructure: const {
          'schema_version': '4.4',
          'plan_scope': 'full',
          'end_retest': {
            'after_week_number': 7,
            'exercises': [
              {
                'exercise_id': 'warrior_one_assessment',
                'vietnamese_name': 'Chiến binh I',
                'duration_seconds': 30,
              },
              {
                'exercise_id': 'squat_assessment',
                'vietnamese_name': 'Squat 5 rep',
                'duration_seconds': 60,
              },
            ],
          },
          'weeks': [
            {
              'week_number': 1,
              'phase_number': 1,
              'phase_name': 'Nền tảng',
              'is_deload_week': false,
              'sessions': [
                {
                  'session_index': 0,
                  'slots': [
                    {
                      'slot_name': 's1',
                      'exercise_id': 'warrior_one',
                      'volume': {'sets': 1, 'reps': 2, 'rest_seconds': 30},
                      'score': 0.8,
                    },
                    {
                      'slot_name': 's2',
                      'exercise_id': 'sphinx',
                      'volume': {
                        'sets': 1,
                        'reps': 1,
                        'seconds': 30,
                        'rest_seconds': 30,
                      },
                      'score': 0.85,
                    },
                    {
                      'slot_name': 's3',
                      'exercise_id': 'cobra',
                      'volume': {'sets': 1, 'reps': 3, 'rest_seconds': 30},
                      'score': 0.75,
                    },
                  ],
                },
                {
                  'session_index': 1,
                  'slots': [
                    {
                      'slot_name': 's1',
                      'exercise_id': 'bow_pose',
                      'volume': {'sets': 1, 'reps': 3, 'rest_seconds': 30},
                      'score': 0.7,
                    },
                  ],
                },
              ],
            },
          ],
        },
      );

      expect(
        deserialized.weeks.single.sessions[0].slots.map((s) => s.exerciseId),
        ['sphinx'],
      );
      expect(deserialized.weeks.single.sessions[1].slots, isEmpty);
      expect(
        deserialized.endOfPlanRetest!.exercises.map((e) => e.exerciseId),
        ['squat_assessment'],
      );

      // 2. Direct in-memory PlanSnapshot with hidden exercises passed to
      // ProgramPlanMapper and WorkoutLaunchService.
      final manualPlan = Plan(
        recommendationId: 'manual-rec',
        userId: 'user-1',
        templateKey: 'home_health',
        planScope: kPlanScopeFull,
        weeks: const [
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
                    slotName: 'lower',
                    exerciseId: 'walking_lunge',
                    volume: VolumePrescription(sets: 3, reps: 10, restSeconds: 60),
                    score: 0.8,
                    topKCandidates: [],
                  ),
                  SlotAssignment(
                    slotName: 'core',
                    exerciseId: 'bird_dog',
                    volume: VolumePrescription(sets: 3, reps: 8, restSeconds: 60),
                    score: 0.9,
                    topKCandidates: [],
                  ),
                ],
              ),
              SessionPlan(
                sessionIndex: 1,
                slots: [
                  SlotAssignment(
                    slotName: 'only_hidden',
                    exerciseId: 'step_back_burpee',
                    volume: VolumePrescription(sets: 3, reps: 8, restSeconds: 60),
                    score: 0.8,
                    topKCandidates: [],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final catalogInfo = CatalogSource.instance.lookupMany([
        'walking_lunge',
        'bird_dog',
        'step_back_burpee',
      ]);
      final mapped = ProgramPlanMapper.fromSnapshot(
        PlanSnapshot(plan: manualPlan),
        catalogById: catalogInfo,
      );
      expect(
        mapped.blocks.single.sessions[0].exercises.map((e) => e.exerciseId),
        ['bird_dog'],
      );
      expect(mapped.blocks.single.sessions[1].exercises, isEmpty);

      final launches = WorkoutLaunchService(
        recommendations: _OfflineRecommendationService(),
      );
      final target0 = await launches.resolveFromSnapshot(
        PlanSnapshot(plan: manualPlan),
      );
      expect(target0, isNotNull);
      expect(target0!.sequence.map((i) => i.catalogExerciseId), ['bird_dog']);

      // When session 0 is done, session 1 has only a hidden exercise -> empty
      // launchable sequence, firstLaunchArgs() is null, no crash.
      final target1 = await launches.resolveFromSnapshot(
        PlanSnapshot(
          plan: manualPlan,
          completionMap: const {
            1: {0},
          },
        ),
      );
      expect(target1, isNotNull);
      expect(target1!.hasLaunchableSlots, isFalse);
      expect(target1.firstLaunchArgs(), isNull);

      // resolveFromSnapshot skips all 22 hidden ids in a plan session.
      final allHiddenPlan = Plan(
        recommendationId: 'all-hidden-rec',
        userId: 'user-1',
        templateKey: 'home_health',
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
                  for (final id in hiddenCatalogIds)
                    SlotAssignment(
                      slotName: id,
                      exerciseId: id,
                      volume: const VolumePrescription(
                        sets: 1,
                        reps: 5,
                        restSeconds: 30,
                      ),
                      score: 0.8,
                      topKCandidates: const [],
                    ),
                ],
              ),
            ],
          ),
        ],
      );
      final allHiddenTarget = await launches.resolveFromSnapshot(
        PlanSnapshot(plan: allHiddenPlan),
      );
      expect(allHiddenTarget, isNotNull);
      expect(allHiddenTarget!.sequence, isEmpty);
      expect(allHiddenTarget.firstLaunchArgs(), isNull);

      final keptSeq = await launches.buildSequenceFromCatalogIds(
        keptExerciseIds.toList(),
      );
      expect(keptSeq, hasLength(21));

      // buildSequenceFromCatalogIds filters out hidden ids at the service boundary.
      final mixedSeq = await launches.buildSequenceFromCatalogIds([
        ...hiddenCatalogIds,
        'squat',
        'sphinx',
      ]);
      expect(
        mixedSeq.map((i) => i.catalogExerciseId),
        ['squat', 'sphinx'],
      );
      final hiddenOnlySeq = await launches.buildSequenceFromCatalogIds(
        hiddenCatalogIds.toList(),
      );
      expect(hiddenOnlySeq, isEmpty);
    });

    test('UserProgramService never emits unkept exercises (cat_cow or non-kept correctives)', () async {
      const goals = [
        null,
        'health',
        'Sức khỏe',
        'body',
        'Vóc dáng',
        'strength',
        'Sức mạnh',
        'flexible',
        'Linh hoạt',
      ];
      final issueCases = <List<String>>[
        const [],
        for (final issueId in interpretingMap.keys) [issueId],
      ];

      for (final goal in goals) {
        for (final issues in issueCases) {
          final program = UserProgramService.buildProgram(
            userName: 'Nam',
            level: 'beginner',
            goal: goal,
            workoutDays: const [0, 1, 2, 3, 4],
            detectedIssues: issues,
            isPro: true,
          );
          expect(program.workouts, isNotEmpty);
          for (final workout in program.workouts) {
            expect(workout.exercises, isNotEmpty);
            for (final ex in workout.exercises) {
              expect(
                isKeptExercise(ex.name),
                isTrue,
                reason:
                    'UserProgramService(goal=$goal, issues=$issues) emitted unkept "${ex.name}"',
              );
            }
          }
        }
      }
    });

    test('past history still resolves display names for all 22 hidden exercises without crashing', () {
      for (final hiddenId in hiddenCatalogIds) {
        final def = lookupExerciseDefinition(hiddenId);
        final catalog = CatalogSource.instance.lookup(hiddenId);
        expect(def, isNotNull, reason: 'Definition missing for $hiddenId');
        expect(catalog, isNotNull, reason: 'Catalog entry missing for $hiddenId');
        expect(def!.displayName, isNotEmpty, reason: hiddenId);
        expect(catalog!.vietnameseName, isNotEmpty, reason: hiddenId);
      }
    });
  });
}
