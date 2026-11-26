import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/glute bridge/glute_bridge.dart';
import 'package:vika/utils/exercise_logger.dart';
import 'package:vika/voice/policy_voice_coach.dart';
import 'package:vika/voice/voice_coach.dart';
import 'package:vika/voice/voice_content.dart';
import 'package:vika/voice/voice_policy.dart';
import 'package:vika/voice/voice_sink.dart';

class _QueuedSink implements VoiceSink {
  final List<(String, bool Function()?)> queued = [];

  @override
  bool get isBusy => false;

  @override
  Future<void> playKey(String logicalKey,
      {bool Function()? isStillRelevant}) async {
    queued.add((logicalKey, isStillRelevant));
  }

  List<String> playedNow() => [
        for (final (key, relevant) in queued)
          if (relevant?.call() ?? true) key,
      ];

  @override
  Future<void> waitUntilIdle(
      {Duration timeout = const Duration(seconds: 4)}) async {}

  @override
  void clearPending() {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a rep count still queued 0.8 s after the rep is dropped, the last is kept',
      () async {
    final sink = _QueuedSink();
    final exercise = GluteBridge(maxRep: 2)
      ..exerciseState = ExerciseState.activated;
    final coach = PolicyVoiceCoach(
      script: VoiceScript.from(
        VoiceDefaults.repBased,
        slug: 'glute_bridge',
        faultIds: const ['hip_extension'],
      ),
      targetReps: 2,
      coach: VoiceCoach(
        sink: sink,
        policy: VoicePolicy(
          random: Random(1),
          tuning: {
            ...kDefaultTuning,
            CueType.count: const CueTuning(CueMode.always, base: 1.0),
            CueType.praise: const CueTuning(CueMode.variableRatio, base: 0.0),
            CueType.hustle: const CueTuning(CueMode.perishable, base: 0.0),
            CueType.phase: const CueTuning(CueMode.perishable, base: 0.0),
            CueType.setup: const CueTuning(CueMode.base, base: 0.0),
          },
        ),
        random: Random(1),
      ),
    );
    addTearDown(coach.dispose);

    coach.processFrame(
        exercise: exercise, repCount: 0, hasPose: true, feedback: const {});
    for (var rep = 1; rep <= 2; rep++) {
      exercise.logger
          .addRepLog(RepLog(repNumber: rep, correctForm: true, data: const {}));
      coach.processFrame(
          exercise: exercise, repCount: rep, hasPose: true, feedback: const {});
    }
    expect(sink.playedNow(), containsAllInOrder(['1', '2']));

    await Future<void>.delayed(const Duration(
        milliseconds: PolicyVoiceCoach.maxCountDelayMs + 150));
    final late = sink.playedNow();
    expect(late, isNot(contains('1')));
    expect(late, contains('2'));
  });
}
