import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/fault_record.dart';
import 'package:vika/services/research/json_sanitizer.dart';
import 'package:vika/services/research/research_log_exporter.dart';
import 'package:vika/services/research/research_log_storage.dart';
import 'package:vika/services/research/research_preferences.dart';
import 'package:vika/services/research/research_session_tracker.dart';
import 'package:vika/services/research/research_voice_sink.dart';
import 'package:vika/services/research/set_recorder.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/voice/voice_coach.dart';
import 'package:vika/voice/voice_content.dart';
import 'package:vika/voice/voice_policy.dart';
import 'package:vika/voice/voice_sink.dart';

class _StateRig {
  final ExerciseLogger logger = ExerciseLogger();
  ExerciseState exerciseState = ExerciseState.notActivated;
  GuidanceSignal? guidanceSignal;
  bool isPaused = false;
  List<FaultRecord> liveFaults = const [];
  int repCount = 0;

  void feed(
    SetRecorder recorder, {
    required int timestampMs,
    required bool hasPose,
  }) {
    recorder.onState(
      frameTimestampMs: timestampMs,
      hasPose: hasPose,
      exerciseState: exerciseState,
      guidanceSignal: guidanceSignal,
      isPaused: isPaused,
      liveFaults: liveFaults,
      logger: logger,
      repCount: repCount,
    );
  }
}

class _FakeVoiceSink implements VoiceSink {
  final List<String> forwardedKeys = <String>[];
  int clearPendingCount = 0;
  bool busy = false;
  bool disposed = false;

  @override
  bool get isBusy => busy;

  @override
  Future<void> playKey(
    String logicalKey, {
    bool Function()? isStillRelevant,
  }) async {
    forwardedKeys.add(logicalKey);
  }

  @override
  Future<void> waitUntilIdle({
    Duration timeout = const Duration(seconds: 4),
  }) async {}

  @override
  void clearPending() {
    clearPendingCount++;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {
    disposed = true;
  }
}

class _CustomNonJsonValue {
  const _CustomNonJsonValue(this.label);
  final String label;

  @override
  String toString() => 'custom:$label';
}

class _ThrowingToStringValue {
  @override
  String toString() => throw StateError('cannot stringify');
}

void main() {
  final baseEpochMs = DateTime.utc(2026, 11, 20, 9, 15, 2, 123)
      .millisecondsSinceEpoch;

  SetRecorder makeRecorder({
    String sessionId = '20261120T091500Z-P07',
    String participantId = 'P07',
    String condition = 'ai',
    String exerciseId = 'squat',
    int setIndex = 1,
    void Function()? onFirstActivationBeep,
  }) {
    return SetRecorder(
      sessionId: sessionId,
      participantId: participantId,
      condition: condition,
      exerciseId: exerciseId,
      setIndex: setIndex,
      appVersion: '1.0.3+155',
      platform: 'android',
      osVersion: '13',
      clockUtc: () => DateTime.utc(2026, 11, 20, 9, 15, 2, 123),
      onFirstActivationBeep: onFirstActivationBeep,
    );
  }

  // Note: NO TestWidgetsFlutterBinding.ensureInitialized() — proves SetRecorder
  // runs in plain Dart without Flutter widget/channel bindings.
  group('SetRecorder event transitions', () {
    test('each event type is emitted on the right change and only then', () {
      var beepCount = 0;
      final recorder = makeRecorder(onFirstActivationBeep: () => beepCount++);
      final rig = _StateRig();

      // Frame 0: setup guidance searching -> unseen_start(setup, searching)
      rig.guidanceSignal = const GuidanceSignal.searching();
      rig.feed(recorder, timestampMs: baseEpochMs, hasPose: false);
      expect(recorder.events, [
        {
          't_ms': 0,
          'type': 'unseen_start',
          'phase': 'setup',
          'reason': 'searching',
        },
      ]);

      // Unchanged guidance kind does not re-emit unseen_start
      rig.feed(recorder, timestampMs: baseEpochMs + 100, hasPose: false);
      expect(recorder.events, hasLength(1));

      // Changing guidance kind emits unseen_end then unseen_start at same t_ms
      rig.guidanceSignal = const GuidanceSignal.holdStill();
      rig.feed(recorder, timestampMs: baseEpochMs + 200, hasPose: true);
      expect(recorder.events.sublist(1), [
        {'t_ms': 200, 'type': 'unseen_end'},
        {
          't_ms': 200,
          'type': 'unseen_start',
          'phase': 'setup',
          'reason': 'holdStill',
        },
      ]);

      // Clearing guidance and activating emits unseen_end, activated, and plays beep once
      rig.guidanceSignal = null;
      rig.exerciseState = ExerciseState.activated;
      rig.feed(recorder, timestampMs: baseEpochMs + 3200, hasPose: true);
      expect(beepCount, 1);
      expect(recorder.syncBeepTMs, 3200);
      expect(recorder.events.sublist(3), [
        {'t_ms': 3200, 'type': 'unseen_end'},
        {'t_ms': 3200, 'type': 'activated'},
      ]);

      // Live fault enters -> fault_start; stays -> no new event; leaves -> fault_end
      rig.liveFaults = [
        FaultRecord(phase: 'holding', type: 'Back', message: 'Hông hơi chùng'),
        FaultRecord(phase: 'holding', type: 'Back', message: 'Hông hơi chùng'),
      ];
      rig.feed(recorder, timestampMs: baseEpochMs + 4000, hasPose: true);
      expect(recorder.events.last, {
        't_ms': 4000,
        'type': 'fault_start',
        'fault': 'Back',
        'message': 'Hông hơi chùng',
      });

      rig.feed(recorder, timestampMs: baseEpochMs + 4100, hasPose: true);
      expect(recorder.events.last['type'], 'fault_start');
      expect(recorder.events.last['t_ms'], 4000);

      rig.liveFaults = const [];
      rig.feed(recorder, timestampMs: baseEpochMs + 4500, hasPose: true);
      expect(recorder.events.last, {
        't_ms': 4500,
        'type': 'fault_end',
        'fault': 'Back',
        'message': 'Hông hơi chùng',
      });

      // RepLog added: fault_types list vs non-list fallback
      rig.repCount = 1;
      rig.logger.addRepLog(
        RepLog(
          repNumber: 1,
          correctForm: false,
          data: {
            'fault_types': ['depth'],
            'peak_knee_angle': 102.5,
          },
        ),
      );
      rig.feed(recorder, timestampMs: baseEpochMs + 5000, hasPose: true);
      recorder.recordCue(key: 'squat.depth', played: true, fault: 'depth');
      expect(recorder.events.sublist(recorder.events.length - 2), [
        {
          't_ms': 5000,
          'type': 'rep',
          'n': 1,
          'correct': false,
          'faults': ['depth'],
          'data': {
            'fault_types': ['depth'],
            'peak_knee_angle': 102.5,
          },
        },
        {
          't_ms': 5000,
          'type': 'cue',
          'key': 'squat.depth',
          'played': true,
          'fault': 'depth',
        },
      ]);

      // RepLog without fault_types list -> faults: []
      rig.repCount = 2;
      rig.logger.addRepLog(
        RepLog(
          repNumber: 2,
          correctForm: true,
          data: {'fault_types': 'not_a_list'},
        ),
      );
      rig.feed(recorder, timestampMs: baseEpochMs + 6000, hasPose: true);
      expect(recorder.events.last['faults'], const <Object?>[]);

      // Active-phase unseen_start -> pause_start closes unseen and does not re-open on paused signal
      rig.guidanceSignal = const GuidanceSignal.bodyInFrame();
      rig.feed(recorder, timestampMs: baseEpochMs + 7000, hasPose: true);
      expect(recorder.events.last, {
        't_ms': 7000,
        'type': 'unseen_start',
        'phase': 'active',
        'reason': 'bodyInFrame',
      });

      rig.isPaused = true;
      rig.guidanceSignal = const GuidanceSignal.paused();
      rig.feed(recorder, timestampMs: baseEpochMs + 7400, hasPose: false);
      expect(recorder.events.sublist(recorder.events.length - 2), [
        {'t_ms': 7400, 'type': 'unseen_end'},
        {'t_ms': 7400, 'type': 'pause_start'},
      ]);

      // Resume -> pause_end, re-hold in notActivated -> second activated does NOT re-fire sync beep
      rig.isPaused = false;
      rig.exerciseState = ExerciseState.notActivated;
      rig.guidanceSignal = const GuidanceSignal.holdStill();
      rig.feed(recorder, timestampMs: baseEpochMs + 9400, hasPose: true);
      expect(recorder.events.sublist(recorder.events.length - 2), [
        {'t_ms': 9400, 'type': 'pause_end'},
        {
          't_ms': 9400,
          'type': 'unseen_start',
          'phase': 'setup',
          'reason': 'holdStill',
        },
      ]);

      rig.guidanceSignal = null;
      rig.exerciseState = ExerciseState.activated;
      rig.feed(recorder, timestampMs: baseEpochMs + 12400, hasPose: true);
      expect(beepCount, 1);
      expect(recorder.syncBeepTMs, 3200);
      expect(recorder.events.last, {'t_ms': 12400, 'type': 'activated'});

      // Completion frame: cue spoken on completion frame still precedes set_complete
      rig.exerciseState = ExerciseState.completed;
      rig.feed(recorder, timestampMs: baseEpochMs + 15000, hasPose: true);
      recorder.recordCue(key: 'common.exercise_complete', played: true);
      expect(recorder.events.sublist(recorder.events.length - 2), [
        {
          't_ms': 15000,
          'type': 'cue',
          'key': 'common.exercise_complete',
          'played': true,
        },
        {'t_ms': 15000, 'type': 'set_complete'},
      ]);
    });

    test('ten thousand unchanged frames add no event', () {
      final recorder = makeRecorder(onFirstActivationBeep: () {});
      final rig = _StateRig()
        ..exerciseState = ExerciseState.activated
        ..liveFaults = [
          FaultRecord(phase: 'holding', type: 'sag', message: 'Siết bụng'),
        ];

      rig.feed(recorder, timestampMs: baseEpochMs, hasPose: true);
      final initialEventCount = recorder.events.length;
      expect(initialEventCount, 2); // activated + fault_start

      for (var i = 1; i <= 10000; i++) {
        rig.feed(recorder, timestampMs: baseEpochMs + i * 40, hasPose: true);
      }

      expect(recorder.events, hasLength(initialEventCount));
      final json = recorder.buildSetJson(setLogs: rig.logger.setLogs);
      final frames = json['frames']! as Map<String, Object?>;
      expect(frames['total'], 10001);
      expect(frames['with_pose'], 10001);
      expect(frames['duration_ms'], 400000);
      expect(frames['max_gap_ms'], 40);
      expect(frames['min_fps_1s'], 25);
    });

    test('mid-set quit writes recorded events without set_complete', () {
      final recorder = makeRecorder();
      final rig = _StateRig()..exerciseState = ExerciseState.activated;

      rig.feed(recorder, timestampMs: baseEpochMs, hasPose: true);
      rig.repCount = 1;
      rig.logger.addRepLog(
        RepLog(repNumber: 1, correctForm: true, data: const {'fault_types': []}),
      );
      rig.feed(recorder, timestampMs: baseEpochMs + 2000, hasPose: true);

      final json = recorder.buildSetJson(setLogs: rig.logger.setLogs);
      final events = json['events']! as List<Object?>;
      expect(
        events.map((e) => (e! as Map<String, Object?>)['type']),
        isNot(contains('set_complete')),
      );
      final summary = json['summary']! as Map<String, Object?>;
      expect(summary['reps'], 1);
      expect(summary['good_reps'], 1);
      expect(summary['active_ms'], 2000);
    });

    test(
      'active liveFaults close with fault_end on pause_start and on set_complete',
      () {
        final recorder = makeRecorder();
        final rig = _StateRig()
          ..exerciseState = ExerciseState.activated
          ..liveFaults = [
            FaultRecord(phase: 'bottom', type: 'trunk', message: 'Thẳng lưng'),
          ];

        rig.feed(recorder, timestampMs: baseEpochMs, hasPose: true);
        expect(recorder.events.last['type'], 'fault_start');

        //Exercise pauses while subclass metric.faults remains populated:
        //SetRecorder must close fault_start at pause_start instead of spanning the pause.
        rig.isPaused = true;
        rig.guidanceSignal = const GuidanceSignal.paused();
        rig.feed(recorder, timestampMs: baseEpochMs + 1000, hasPose: false);
        expect(recorder.events.sublist(recorder.events.length - 2), [
          {
            't_ms': 1000,
            'type': 'fault_end',
            'fault': 'trunk',
            'message': 'Thẳng lưng',
          },
          {'t_ms': 1000, 'type': 'pause_start'},
        ]);

        // Resume into re-hold (notActivated) still ignores stale metric.faults
        rig.isPaused = false;
        rig.exerciseState = ExerciseState.notActivated;
        rig.guidanceSignal = const GuidanceSignal.holdStill();
        rig.feed(recorder, timestampMs: baseEpochMs + 5000, hasPose: true);
        expect(
          recorder.events.where((e) => e['type'] == 'fault_start'),
          hasLength(1),
        );

        // Re-activate with fault active, then complete set -> fault_end precedes set_complete
        rig.guidanceSignal = null;
        rig.exerciseState = ExerciseState.activated;
        rig.feed(recorder, timestampMs: baseEpochMs + 8000, hasPose: true);
        expect(recorder.events.last['type'], 'fault_start');

        rig.exerciseState = ExerciseState.completed;
        rig.feed(recorder, timestampMs: baseEpochMs + 9000, hasPose: true);
        expect(recorder.events.sublist(recorder.events.length - 2), [
          {
            't_ms': 9000,
            'type': 'fault_end',
            'fault': 'trunk',
            'message': 'Thẳng lưng',
          },
          {'t_ms': 9000, 'type': 'set_complete'},
        ]);
      },
    );

    test(
      'min_fps_1s records slow or frozen unpaused 1s window even when pause_start lands on the boundary frame',
      () {
        final recorder = makeRecorder();
        final rig = _StateRig()..exerciseState = ExerciseState.activated;

        // First second [0, 1000): 20 frames (50ms apart)
        for (var t = 0; t < 1000; t += 50) {
          rig.feed(recorder, timestampMs: baseEpochMs + t, hasPose: true);
        }
        // Second [1000, 2000): 6 frames, then freeze across [2000, 3000),
        // then auto-pause triggers on frame at t=3100ms!
        for (var i = 0; i < 6; i++) {
          rig.feed(
            recorder,
            timestampMs: baseEpochMs + 1000 + i * 100,
            hasPose: true,
          );
        }
        rig.isPaused = true;
        rig.guidanceSignal = const GuidanceSignal.paused();
        rig.feed(recorder, timestampMs: baseEpochMs + 3100, hasPose: false);

        final json = recorder.buildSetJson(setLogs: rig.logger.setLogs);
        final frames = json['frames']! as Map<String, Object?>;
        expect(frames['min_fps_1s'], 0);
      },
    );

    test(
      'orientation-gate frames with frozen frameTimestampMs do not corrupt min_fps_1s or max_gap_ms when phone rotates into supported orientation',
      () {
        final recorder = makeRecorder(exerciseId: 'plank');
        final rig = _StateRig()
          ..guidanceSignal = const GuidanceSignal.phoneLandscape();

        // 60 portrait frames short-circuited by _syncOrientationGate():
        // ExerciseBase.frameTimestampMs stays pinned at baseEpochMs.
        for (var i = 0; i < 60; i++) {
          rig.feed(recorder, timestampMs: baseEpochMs, hasPose: false);
        }

        // User rotates phone to landscape 3000ms later; steady 20 fps frames follow.
        rig.guidanceSignal = const GuidanceSignal.holdStill();
        for (var t = 3000; t < 6000; t += 50) {
          rig.feed(recorder, timestampMs: baseEpochMs + t, hasPose: true);
        }
        rig.guidanceSignal = null;
        rig.exerciseState = ExerciseState.activated;
        for (var t = 6000; t <= 8000; t += 50) {
          rig.feed(recorder, timestampMs: baseEpochMs + t, hasPose: true);
        }

        // Mid-set accidental portrait tilt for 2500ms (50 frames pinned at +8050ms),
        // then rotate back to landscape at +10550ms and finish at +12000ms.
        rig.guidanceSignal = const GuidanceSignal.phoneLandscape();
        for (var i = 0; i < 50; i++) {
          rig.feed(recorder, timestampMs: baseEpochMs + 8050, hasPose: false);
        }
        rig.guidanceSignal = null;
        for (var t = 10550; t < 12000; t += 50) {
          rig.feed(recorder, timestampMs: baseEpochMs + t, hasPose: true);
        }
        rig.exerciseState = ExerciseState.completed;
        rig.feed(recorder, timestampMs: baseEpochMs + 12000, hasPose: true);

        final json = recorder.buildSetJson(setLogs: rig.logger.setLogs);
        final frames = json['frames']! as Map<String, Object?>;
        expect(frames['max_gap_ms'], 50);
        expect(frames['min_fps_1s'], 20);

        final summary = json['summary']! as Map<String, Object?>;
        expect(summary['active_ms'], 6000);
        expect(summary['unseen_ms'], 2500);
        expect(recorder.visibleRatio, closeTo(1 - 2500 / 6000, 1e-9));
      },
    );
  });

  group('Full schema integration & storage', () {
    test(
      'full sequence through guidance, activation, reps, pause and completion produces schema-valid set and session files',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('vika_rec_test_');
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final storage = ResearchLogStorage(
          directoryProvider: () async => tempDir,
        );
        final tracker = ResearchSessionTracker(storage: storage);
        final session = tracker.beginOrContinueSession(
          config: const ResearchConfig(
            rawParticipantId: 'P07',
            condition: ResearchCondition.ai,
          ),
          isContinuation: false,
          nowUtc: DateTime.utc(2026, 11, 20, 9, 15, 0),
        );
        expect(session.sessionId, '20261120T091500Z-P07');

        final slot = tracker.nextSetSlot('squat');
        expect(slot.fileName, 'vika_20261120T091500Z-P07_01_squat_set1.json');

        var beepPlayed = false;
        final recorder = SetRecorder(
          sessionId: session.sessionId,
          participantId: session.config.participantId,
          condition: session.config.condition.storageValue,
          exerciseId: slot.exerciseId,
          setIndex: slot.setIndex,
          appVersion: '1.0.3+155',
          platform: 'android',
          osVersion: '13',
          clockUtc: () => DateTime.utc(2026, 11, 20, 9, 15, 2, 123),
          onFirstActivationBeep: () => beepPlayed = true,
        );
        final rig = _StateRig();

        // Setup holdStill from 0..3000ms (at 50ms steps = 20 fps)
        rig.guidanceSignal = const GuidanceSignal.holdStill();
        for (var t = 0; t < 3000; t += 50) {
          rig.feed(recorder, timestampMs: baseEpochMs + t, hasPose: true);
        }

        // Activate at 3000ms
        rig.guidanceSignal = null;
        rig.exerciseState = ExerciseState.activated;
        rig.feed(recorder, timestampMs: baseEpochMs + 3000, hasPose: true);
        recorder.recordCue(key: 'common.ready', played: true);
        expect(beepPlayed, isTrue);

        // Active frames 3050..6000ms, Rep 1 clean at 6000ms
        for (var t = 3050; t < 6000; t += 50) {
          rig.feed(recorder, timestampMs: baseEpochMs + t, hasPose: true);
        }
        rig.repCount = 1;
        rig.logger.addRepLog(
          RepLog(
            repNumber: 1,
            correctForm: true,
            data: const {'fault_types': <String>[], 'peak_knee_angle': 92.0},
          ),
        );
        rig.feed(recorder, timestampMs: baseEpochMs + 6000, hasPose: true);
        recorder.recordCue(key: '1', played: true);

        // Unseen active (bodyInFrame) from 7000..8500ms (1500ms unseen)
        for (var t = 6050; t < 7000; t += 50) {
          rig.feed(recorder, timestampMs: baseEpochMs + t, hasPose: true);
        }
        rig.guidanceSignal = const GuidanceSignal.bodyInFrame();
        for (var t = 7000; t < 8500; t += 50) {
          rig.feed(recorder, timestampMs: baseEpochMs + t, hasPose: false);
        }
        rig.guidanceSignal = null;
        rig.feed(recorder, timestampMs: baseEpochMs + 8500, hasPose: true);

        // Pause from 9000..11000ms (2000ms paused, 1fps while paused)
        for (var t = 8550; t < 9000; t += 50) {
          rig.feed(recorder, timestampMs: baseEpochMs + t, hasPose: true);
        }
        rig.isPaused = true;
        rig.guidanceSignal = const GuidanceSignal.paused();
        rig.feed(recorder, timestampMs: baseEpochMs + 9000, hasPose: false);
        rig.feed(recorder, timestampMs: baseEpochMs + 10000, hasPose: false);

        rig.isPaused = false;
        rig.exerciseState = ExerciseState.notActivated;
        rig.guidanceSignal = const GuidanceSignal.holdStill();
        rig.feed(recorder, timestampMs: baseEpochMs + 11000, hasPose: true);

        // Re-hold 11050..14000ms, re-activate at 14000ms
        for (var t = 11050; t < 14000; t += 50) {
          rig.feed(recorder, timestampMs: baseEpochMs + t, hasPose: true);
        }
        rig.guidanceSignal = null;
        rig.exerciseState = ExerciseState.activated;
        rig.feed(recorder, timestampMs: baseEpochMs + 14000, hasPose: true);

        // Rep 2 faulted + set completion at 17000ms
        for (var t = 14050; t < 17000; t += 50) {
          rig.feed(recorder, timestampMs: baseEpochMs + t, hasPose: true);
        }
        rig.repCount = 2;
        rig.logger.addRepLog(
          RepLog(
            repNumber: 2,
            correctForm: false,
            data: const {
              'fault_types': <String>['depth'],
              'peak_knee_angle': 112.0,
            },
          ),
        );
        rig.logger.pushGoodRepCount();
        rig.exerciseState = ExerciseState.completed;
        rig.feed(recorder, timestampMs: baseEpochMs + 17000, hasPose: true);
        recorder.recordCue(key: '2', played: true);
        recorder.recordCue(key: 'squat.depth', played: true, fault: 'depth');

        final setFile = await tracker.finishSet(
          slot: slot,
          recorder: recorder,
          setLogs: rig.logger.setLogs,
        );
        expect(setFile, isNotNull);

        final rawSetJson = await setFile!.readAsString();
        final parsedSet = jsonDecode(rawSetJson) as Map<String, dynamic>;
        expect(parsedSet['schema'], 1);
        expect(parsedSet['kind'], 'exercise_set');
        expect(parsedSet['session_id'], '20261120T091500Z-P07');
        expect(parsedSet['participant_id'], 'P07');
        expect(parsedSet['condition'], 'ai');
        expect(parsedSet['app_version'], '1.0.3+155');
        expect(parsedSet['platform'], 'android');
        expect(parsedSet['os_version'], '13');
        expect(parsedSet['exercise_id'], 'squat');
        expect(parsedSet['set_index'], 1);
        expect(parsedSet['started_at_utc'], '2026-11-20T09:15:02.123Z');
        expect(parsedSet['sync_beep_t_ms'], 3000);

        final frames = parsedSet['frames'] as Map<String, dynamic>;
        expect(frames['duration_ms'], 17000);
        expect(frames['max_gap_ms'], 50);
        expect(frames['min_fps_1s'], 20);

        final events = (parsedSet['events'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        for (var i = 1; i < events.length; i++) {
          expect(
            events[i]['t_ms'] as int,
            greaterThanOrEqualTo(events[i - 1]['t_ms'] as int),
          );
        }
        expect(events.last, {'t_ms': 17000, 'type': 'set_complete'});

        final summary = parsedSet['summary'] as Map<String, dynamic>;
        expect(summary['reps'], 2);
        expect(summary['good_reps'], 1);
        expect(summary['active_ms'], 9000);
        expect(summary['unseen_ms'], 1500);
        expect(summary['paused_ms'], 2000);

        session.setFaultReported(slot, 'depth', reported: true);
        session.setFaultReported(slot, 'heel', reported: true);
        session.setFaultReported(slot, 'depth', reported: false);

        final sessionFile = await tracker.endSession(
          satisfaction: 4,
          endedAtUtc: DateTime.utc(2026, 11, 20, 9, 31, 40),
        );
        expect(sessionFile, isNotNull);
        expect(
          sessionFile!.uri.pathSegments.last,
          'vika_20261120T091500Z-P07_session.json',
        );
        final parsedSession = jsonDecode(await sessionFile.readAsString())
            as Map<String, dynamic>;
        expect(parsedSession, {
          'schema': 1,
          'kind': 'session',
          'session_id': '20261120T091500Z-P07',
          'participant_id': 'P07',
          'condition': 'ai',
          'started_at_utc': '2026-11-20T09:15:00.000Z',
          'ended_at_utc': '2026-11-20T09:31:40.000Z',
          'satisfaction': 4,
          'fault_reports': [
            {
              'exercise_id': 'squat',
              'set_index': 1,
              'file': 'vika_20261120T091500Z-P07_01_squat_set1.json',
              'fault': 'heel',
            },
          ],
          'files': ['vika_20261120T091500Z-P07_01_squat_set1.json'],
        });
      },
    );

    test('moveLogFiles moves only log files and keeps existing targets',
        () async {
      final root = await Directory.systemTemp.createTemp('vika_move_test_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final from = Directory('${root.path}/old');
      final to = Directory('${root.path}/new');
      await from.create();
      await File('${from.path}/vika_a_session.json').writeAsString('old-a');
      await File('${from.path}/vika_b_session.json').writeAsString('old-b');
      await File('${from.path}/notes.txt').writeAsString('keep');
      await to.create();
      await File('${to.path}/vika_b_session.json').writeAsString('new-b');

      await ResearchLogStorage.moveLogFiles(from: from, to: to);

      expect(await File('${to.path}/vika_a_session.json').readAsString(),
          'old-a');
      expect(await File('${to.path}/vika_b_session.json').readAsString(),
          'new-b');
      expect(await File('${from.path}/vika_a_session.json').exists(), isFalse);
      expect(await File('${from.path}/vika_b_session.json').exists(), isFalse);
      expect(await File('${from.path}/notes.txt').exists(), isTrue);
      await ResearchLogStorage.moveLogFiles(
        from: Directory('${root.path}/missing'),
        to: to,
      );
    });

    test(
      'session snapshot keeps the session open and the final end overwrites it',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('vika_snap_test_');
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });
        final tracker = ResearchSessionTracker(
          storage: ResearchLogStorage(directoryProvider: () async => tempDir),
        );
        final session = tracker.beginOrContinueSession(
          config: const ResearchConfig(rawParticipantId: 'P00'),
          isContinuation: false,
          nowUtc: DateTime.utc(2026, 11, 20, 20, 0, 0),
        );
        expect(await tracker.writeSessionSnapshot(session), isNull);

        final slot = tracker.nextSetSlot('squat');
        session.setFiles.add(slot.fileName);
        session.setFaultReported(slot, 'depth', reported: true);

        final snapshot = await tracker.writeSessionSnapshot(session);
        expect(snapshot, isNotNull);
        expect(
          snapshot!.uri.pathSegments.last,
          'vika_20261120T200000Z-P00_session.json',
        );
        final parsed =
            jsonDecode(await snapshot.readAsString()) as Map<String, dynamic>;
        expect(parsed['ended_at_utc'], isNull);
        expect(parsed['files'], [slot.fileName]);
        expect(parsed['fault_reports'], [
          {
            'exercise_id': 'squat',
            'set_index': 1,
            'file': slot.fileName,
            'fault': 'depth',
          },
        ]);
        expect(session.isEnded, isFalse);
        expect(tracker.activeSession, same(session));

        final ended = await tracker.endSession(
          endedAtUtc: DateTime.utc(2026, 11, 20, 20, 10, 0),
        );
        final finalJson =
            jsonDecode(await ended!.readAsString()) as Map<String, dynamic>;
        expect(ended.path, snapshot.path);
        expect(finalJson['ended_at_utc'], '2026-11-20T20:10:00.000Z');
        expect(await tracker.writeSessionSnapshot(session), isNull);
      },
    );

    test(
      'retention keeps at most 300 newest log files and write errors never throw',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('vika_cap_test_');
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final storage = ResearchLogStorage(
          directoryProvider: () async => tempDir,
        );

        for (var i = 1; i <= 305; i++) {
          final ts =
              DateTime.utc(2026, 11, 20, 9, 0, 0).add(Duration(seconds: i));
          final sid = '${formatSessionTimestampUtc(ts)}-P01';
          await storage.writeJsonFile(
            fileName: 'vika_${sid}_01_squat_set1.json',
            payload: {'schema': 1, 'seq': i},
          );
        }

        final remaining = await storage.listStoredLogFiles();
        expect(remaining, hasLength(300));
        expect(
          remaining.first.uri.pathSegments.last,
          'vika_20261120T090006Z-P01_01_squat_set1.json',
        );
        expect(
          remaining.last.uri.pathSegments.last,
          'vika_20261120T090505Z-P01_01_squat_set1.json',
        );

        final brokenStorage = ResearchLogStorage(
          directoryProvider: () async =>
              throw const FileSystemException('disk full'),
        );
        final result = await brokenStorage.writeJsonFile(
          fileName: 'vika_20261120T100000Z-anon_01_squat_set1.json',
          payload: {'schema': 1},
        );
        expect(result, isNull);
      },
    );

    test(
      'participant IDs with spaces/underscores sanitize without underscore delimiter collision and legacy underscore filenames sort accurately',
      () async {
        expect(
          const ResearchConfig(rawParticipantId: 'P_07').participantId,
          'P-07',
        );
        expect(
          const ResearchConfig(rawParticipantId: 'P 07').participantId,
          'P-07',
        );

        final tempDir =
            await Directory.systemTemp.createTemp('vika_sort_test_');
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final storage = ResearchLogStorage(
          directoryProvider: () async => tempDir,
        );
        // Write out of order using legacy underscore participant IDs + snake_case exercises
        await storage.writeJsonFile(
          fileName: 'vika_20261120T091500Z-P_07_session.json',
          payload: {'schema': 1},
        );
        await storage.writeJsonFile(
          fileName: 'vika_20261120T091500Z-P_07_02_push_up_set1.json',
          payload: {'schema': 1},
        );
        await storage.writeJsonFile(
          fileName: 'vika_20261120T091500Z-P_07_01_glute_bridge_set1.json',
          payload: {'schema': 1},
        );

        final sorted = await storage.listStoredLogFiles();
        expect(
          sorted.map((f) => f.uri.pathSegments.last).toList(),
          [
            'vika_20261120T091500Z-P_07_01_glute_bridge_set1.json',
            'vika_20261120T091500Z-P_07_02_push_up_set1.json',
            'vika_20261120T091500Z-P_07_session.json',
          ],
        );
      },
    );

    test(
      'discarding unrecorded 0-frame slot leaves no gap in seq or set_index and config can update before first set',
      () {
        final tracker = ResearchSessionTracker();
        final session = tracker.beginOrContinueSession(
          config: const ResearchConfig(),
          isContinuation: false,
          nowUtc: DateTime.utc(2026, 11, 20, 9, 15, 0),
        );
        final abortedSlot = session.allocateSetSlot('squat');
        expect(abortedSlot.seq, 1);
        expect(abortedSlot.setIndex, 1);

        // Late async config resolution before any set is recorded
        session.updateConfigBeforeFirstSet(
          const ResearchConfig(
            rawParticipantId: 'P07',
            condition: ResearchCondition.control,
          ),
          pendingSlot: abortedSlot,
        );
        expect(session.sessionId, '20261120T091500Z-P07');
        expect(
          abortedSlot.fileName,
          'vika_20261120T091500Z-P07_01_squat_set1.json',
        );

        // User aborts before camera frame 1 -> rollback seq & setIndex
        session.discardUnrecordedSlot(abortedSlot);
        final realSlot = session.allocateSetSlot('squat');
        expect(realSlot.seq, 1);
        expect(realSlot.setIndex, 1);
        expect(
          realSlot.fileName,
          'vika_20261120T091500Z-P07_01_squat_set1.json',
        );

        tracker.discardSessionIfEmpty(session);
        expect(tracker.activeSession, isNull);
      },
    );
  });

  group('JSON sanitization', () {
    test(
      'encoding survives non-finite numbers, custom objects, sets, non-string keys, and cycles',
      () {
        final cyclicList = <Object?>[];
        cyclicList.add(cyclicList);
        final cyclicMap = <String, Object?>{};
        cyclicMap['self'] = cyclicMap;

        final recorder = makeRecorder();
        final rig = _StateRig()..exerciseState = ExerciseState.activated;
        rig.repCount = 1;
        rig.logger.addRepLog(
          RepLog(
            repNumber: 1,
            correctForm: false,
            data: {
              'nan_val': double.nan,
              'pos_inf': double.infinity,
              'neg_inf': double.negativeInfinity,
              'valid_num': 42.5,
              'set_val': <String>{'depth', 'heel'},
              'enum_val': GuidanceClass.turnSide,
              'custom_obj': const _CustomNonJsonValue('ok'),
              'throwing_obj': _ThrowingToStringValue(),
              'non_string_map': <Object, Object?>{1: 'one', true: double.nan},
              'cyclic_list': cyclicList,
              'cyclic_map': cyclicMap,
            },
          ),
        );
        rig.logger.pushKey('ratio', 0.0 / 0.0);
        rig.logger.pushKey('timestamp', DateTime.utc(2026, 11, 20, 10, 0));
        rig.feed(recorder, timestampMs: baseEpochMs, hasPose: true);

        final payload = recorder.buildSetJson(setLogs: rig.logger.setLogs);
        final encoded = encodeSafeJson(payload);
        final decoded = jsonDecode(encoded) as Map<String, dynamic>;

        final repEvent = (decoded['events'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .firstWhere((e) => e['type'] == 'rep');
        final repData = repEvent['data'] as Map<String, dynamic>;
        expect(repData['nan_val'], isNull);
        expect(repData['pos_inf'], isNull);
        expect(repData['neg_inf'], isNull);
        expect(repData['valid_num'], 42.5);
        expect(repData['set_val'], ['depth', 'heel']);
        expect(repData['enum_val'], 'turnSide');
        expect(repData['custom_obj'], 'custom:ok');
        expect(repData['throwing_obj'], isNull);
        expect(repData['non_string_map'], {'1': 'one', 'true': null});

        final setLog = decoded['set_log'] as Map<String, dynamic>;
        expect(setLog['ratio'], isNull);
        expect(setLog['timestamp'], '2026-11-20T10:00:00.000Z');
      },
    );
  });

  group('ResearchVoiceSink & Control Condition', () {
    test(
      'control sink records without forwarding muted keys and forwards setup/guidance keys',
      () async {
        final inner = _FakeVoiceSink();
        final recorded = <Map<String, Object?>>[];
        final controlSink = ResearchVoiceSink(
          inner: inner,
          controlCondition: true,
          onCue: ({required key, required played, fault}) {
            recorded.add({
              'key': key,
              'played': played,
              if (fault != null) 'fault': fault,
            });
          },
        );

        final coach = VoiceCoach(
          sink: controlSink,
          policy: VoicePolicy(
            random: Random(1),
            clockMs: () => 1000,
            tuning: {
              ...kDefaultTuning,
              CueType.praise:
                  const CueTuning(CueMode.variableRatio, base: 1.0, cap: 1.0),
              CueType.softFault:
                  const CueTuning(CueMode.variableRatio, base: 1.0, cap: 1.0),
              CueType.hustle:
                  const CueTuning(CueMode.perishable, base: 1.0, cap: 1.0),
              CueType.phase:
                  const CueTuning(CueMode.perishable, base: 1.0, cap: 1.0),
            },
          ),
          random: Random(1),
        );

        coach.say(
          CueType.setup,
          VoiceContent.key('squat.setup_position'),
          const CueContext(repNumber: 0, contentKey: 'setup_position'),
        );
        coach.say(
          CueType.setup,
          VoiceContent.key('3'),
          const CueContext(repNumber: 0, contentKey: 'count_3'),
        );
        coach.say(
          CueType.safety,
          VoiceContent.key('common.body_in_frame'),
          const CueContext(repNumber: 0, contentKey: 'common.body_in_frame'),
        );

        coach.say(
          CueType.count,
          VoiceContent.key('1'),
          const CueContext(repNumber: 1),
        );
        coach.say(
          CueType.criticalFault,
          VoiceContent.key('squat.depth'),
          const CueContext(repNumber: 1, contentKey: 'depth'),
        );
        coach.beginSet();
        coach.say(
          CueType.praise,
          VoiceContent.key('common.good_1'),
          const CueContext(repNumber: 2, clean: true),
        );
        coach.beginSet();
        coach.say(
          CueType.hustle,
          VoiceContent.key('common.push'),
          const CueContext(repNumber: 3),
        );

        await controlSink.playKey('common.rotate_landscape');
        await controlSink.playKey('plank.hold_good');
        await controlSink.playKey('common.nonexistent_audio');

        expect(inner.forwardedKeys, [
          'squat.setup_position',
          '3',
          'common.body_in_frame',
          'common.rotate_landscape',
        ]);

        expect(recorded, [
          {'key': 'squat.setup_position', 'played': true},
          {'key': '3', 'played': true},
          {'key': 'common.body_in_frame', 'played': true},
          {'key': '1', 'played': false},
          {'key': 'squat.depth', 'played': false, 'fault': 'depth'},
          {'key': 'common.good_1', 'played': false},
          {'key': 'common.push', 'played': false},
          {'key': 'common.rotate_landscape', 'played': true},
          {'key': 'plank.hold_good', 'played': false},
          {'key': 'common.nonexistent_audio', 'played': false},
        ]);
      },
    );

    test(
      'ai condition sink forwards valid cues with fault id and marks missing audio played:false',
      () async {
        final inner = _FakeVoiceSink();
        final recorded = <Map<String, Object?>>[];
        final aiSink = ResearchVoiceSink(
          inner: inner,
          controlCondition: false,
          onCue: ({required key, required played, fault}) {
            recorded.add({
              'key': key,
              'played': played,
              if (fault != null) 'fault': fault,
            });
          },
        );

        final coach = VoiceCoach(sink: aiSink, random: Random(1));
        coach.say(
          CueType.criticalFault,
          VoiceContent.key('squat.depth'),
          const CueContext(repNumber: 2, contentKey: 'depth'),
        );
        await aiSink.playKey('side_plank_dip.amplitude');

        expect(inner.forwardedKeys, [
          'squat.depth',
          'side_plank_dip.amplitude',
        ]);
        expect(recorded, [
          {'key': 'squat.depth', 'played': true, 'fault': 'depth'},
          {'key': 'side_plank_dip.amplitude', 'played': false},
        ]);
      },
    );

    test(
      'wrapExerciseVoiceCoach safely handles null coach and ResearchVoiceSink unwraps nested sinks + checks bundled manifest cache',
      () async {
        addTearDown(() => ResearchVoiceSink.resetAssetCacheForTesting());
        final recorder = makeRecorder();
        expect(
          () => wrapExerciseVoiceCoach(
            null,
            recorder: recorder,
            controlCondition: true,
          ),
          returnsNormally,
        );

        final baseInner = _FakeVoiceSink();
        var cueCount = 0;
        final firstWrap = ResearchVoiceSink(
          inner: baseInner,
          controlCondition: false,
          onCue: ({required key, required played, fault}) => cueCount++,
        );
        final recorded = <Map<String, Object?>>[];
        final secondWrap = ResearchVoiceSink(
          inner: firstWrap,
          controlCondition: true,
          onCue: ({required key, required played, fault}) {
            recorded.add({'key': key, 'played': played});
          },
        );
        expect(identical(secondWrap.unwrapInner, baseInner), isTrue);

        ResearchVoiceSink.resetAssetCacheForTesting(<String>{
          'assets/audio/common/ready.mp3',
        });
        await secondWrap.playKey('common.ready');
        await secondWrap.playKey('squat.setup_position'); // unbundled in mock set
        expect(cueCount, 0); // firstWrap was unwrapped, not double-invoked
        expect(recorded, [
          {'key': 'common.ready', 'played': true},
          {'key': 'squat.setup_position', 'played': false},
        ]);
      },
    );

    test(
      'suppressed cues with clearPendingBeforePlay do not clear pending audio on inner sink',
      () async {
        final inner = _FakeVoiceSink();
        final controlSink = ResearchVoiceSink(
          inner: inner,
          controlCondition: true,
          onCue: ({required key, required played, fault}) {},
        );
        await controlSink.playKeyWithContext(
          'common.correct',
          cueType: CueType.praise,
          clearPendingBeforePlay: true,
        );
        expect(inner.clearPendingCount, 0);
        expect(inner.forwardedKeys, isEmpty);

        await controlSink.playKeyWithContext(
          'Giữ cả người trong khung hình',
          cueType: CueType.safety,
          clearPendingBeforePlay: true,
        );
        expect(inner.clearPendingCount, 1);
        expect(inner.forwardedKeys, ['Giữ cả người trong khung hình']);
      },
    );

    test(
      'rekeyPendingSlotExerciseId and SetRecorder.updateExerciseId canonicalize exercise_id before set flush, and lib/services/research has no Flutter widget imports',
      () {
        final tracker = ResearchSessionTracker();
        final session = tracker.beginOrContinueSession(
          config: const ResearchConfig(rawParticipantId: 'P07'),
          isContinuation: false,
          nowUtc: DateTime.utc(2026, 11, 20, 9, 15, 0),
        );
        final slot = session.allocateSetSlot('v__up');
        final recorder = makeRecorder(
          sessionId: session.sessionId,
          exerciseId: slot.exerciseId,
          setIndex: slot.setIndex,
        );
        expect(slot.fileName, 'vika_20261120T091500Z-P07_01_v__up_set1.json');

        session.rekeyPendingSlotExerciseId(slot, 'vup');
        recorder.updateExerciseId(slot.exerciseId, setIndex: slot.setIndex);
        expect(slot.exerciseId, 'vup');
        expect(slot.setIndex, 1);
        expect(slot.fileName, 'vika_20261120T091500Z-P07_01_vup_set1.json');
        expect(recorder.exerciseId, 'vup');
        expect(
          recorder.buildSetJson(setLogs: const {})['exercise_id'],
          'vup',
        );

        final nextVup = session.allocateSetSlot('vup');
        expect(nextVup.setIndex, 2);

        final researchDir = Directory('lib/services/research');
        final researchFiles = researchDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();
        expect(researchFiles, isNotEmpty);
        for (final file in researchFiles) {
          final src = file.readAsStringSync();
          expect(
            src,
            isNot(contains("package:flutter/widgets.dart")),
            reason: '${file.path} must not depend on flutter/widgets.dart',
          );
          expect(
            src,
            isNot(contains("package:flutter/material.dart")),
            reason: '${file.path} must not depend on flutter/material.dart',
          );
          expect(
            src,
            isNot(contains("package:flutter/cupertino.dart")),
            reason: '${file.path} must not depend on flutter/cupertino.dart',
          );
          expect(
            src,
            isNot(contains("package:flutter/rendering.dart")),
            reason: '${file.path} must not depend on flutter/rendering.dart',
          );
        }
      },
    );

    test(
      'ResearchLogExporter returns false cleanly for empty lists and caught platform failures',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('vika_exp_test_');
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });
        final storage = ResearchLogStorage(
          directoryProvider: () async => tempDir,
        );

        expect(await ResearchLogExporter.shareFiles(const <File>[]), isFalse);
        expect(
          await ResearchLogExporter.shareAllStoredLogs(storage: storage),
          isFalse,
        );
        expect(
          await ResearchLogExporter.shareSessionLogs(
            const <String>['missing.json'],
            storage: storage,
          ),
          isFalse,
        );

        final written = await storage.writeJsonFile(
          fileName: 'vika_20261120T091500Z-P07_session.json',
          payload: const {'schema': 1},
        );
        expect(written, isNotNull);
        // Without a Flutter platform channel binding, Share.shareXFiles throws
        // and all three exporter entry points catch and return false safely.
        expect(await ResearchLogExporter.shareFiles(<File>[written!]), isFalse);
        expect(
          await ResearchLogExporter.shareAllStoredLogs(storage: storage),
          isFalse,
        );
        expect(
          await ResearchLogExporter.shareSessionLogs(
            const <String>['vika_20261120T091500Z-P07_session.json'],
            storage: storage,
          ),
          isFalse,
        );
      },
    );
  });
}
