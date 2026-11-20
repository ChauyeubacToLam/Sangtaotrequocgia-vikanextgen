import 'package:flutter/material.dart';

import '../../models/exercise_definition.dart';
import '../../theme/app_colors.dart';
import 'exercise_experience_screen.dart';
import 'exercise_launch_args.dart';

/// Resolves route arguments for `/exercise` and refuses any hidden or malformed
/// exercise launch request before [ExerciseExperienceScreen] is constructed.
///
/// Lives one level above `exercise_experience_screen.dart` and
/// `active_exercise_page.dart` so those files need no edits.
ExerciseLaunchArgs? resolveAllowedExerciseLaunchArgs(Object? rawArgs) {
  final ExerciseLaunchArgs candidate;
  if (rawArgs is ExerciseLaunchArgs) {
    candidate = rawArgs;
  } else if (rawArgs is ExerciseDefinition) {
    candidate = ExerciseLaunchArgs(definition: rawArgs);
  } else {
    return null;
  }

  if (!isAllowedExerciseLaunchArgs(candidate)) {
    return null;
  }

  if (candidate.sequence.isEmpty) {
    return candidate.sequenceIndex == 0
        ? candidate
        : ExerciseLaunchArgs(
            definition: candidate.definition,
            workoutSessionId: candidate.workoutSessionId,
            catalogExerciseId: candidate.catalogExerciseId,
            catalogInfo: candidate.catalogInfo,
            prescription: candidate.prescription,
            recommendationId: candidate.recommendationId,
            weekNumber: candidate.weekNumber,
            sessionIndex: candidate.sessionIndex,
            slotName: candidate.slotName,
            sequence: const [],
            sequenceIndex: 0,
            priorReports: candidate.priorReports,
          );
  }

  final keptItems = <ExerciseSequenceItem>[];
  var keptBefore = 0;
  for (var i = 0; i < candidate.sequence.length; i++) {
    final item = candidate.sequence[i];
    if (isAllowedExerciseSequenceItem(item)) {
      if (i < candidate.sequenceIndex) {
        keptBefore++;
      }
      keptItems.add(item);
    }
  }

  final mappedIndex =
      keptItems.isEmpty ? 0 : keptBefore.clamp(0, keptItems.length - 1);
  if (keptItems.length == candidate.sequence.length &&
      mappedIndex == candidate.sequenceIndex) {
    return candidate;
  }

  return ExerciseLaunchArgs(
    definition: candidate.definition,
    workoutSessionId: candidate.workoutSessionId,
    catalogExerciseId: candidate.catalogExerciseId,
    catalogInfo: candidate.catalogInfo,
    prescription: candidate.prescription,
    recommendationId: candidate.recommendationId,
    weekNumber: candidate.weekNumber,
    sessionIndex: candidate.sessionIndex,
    slotName: candidate.slotName,
    sequence: List<ExerciseSequenceItem>.unmodifiable(keptItems),
    sequenceIndex: mappedIndex,
    priorReports: candidate.priorReports,
  );
}

/// Builds the `/exercise` route, refusing hidden exercises without crashing.
Route<dynamic> buildGuardedExerciseRoute(RouteSettings settings) {
  final launchArgs = resolveAllowedExerciseLaunchArgs(settings.arguments);
  if (launchArgs == null) {
    debugPrint(
      '[ExerciseLaunchGuard] Refused hidden or invalid launch: '
      '${settings.arguments}',
    );
    return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) => const BlockedExerciseLaunchScreen(),
    );
  }

  return MaterialPageRoute<dynamic>(
    settings: RouteSettings(name: settings.name, arguments: launchArgs),
    builder: (_) => ExerciseExperienceScreen(
      workoutSessionId: launchArgs.workoutSessionId,
      definition: launchArgs.definition,
      catalogExerciseId: launchArgs.catalogExerciseId,
      catalogInfo: launchArgs.catalogInfo,
      prescription: launchArgs.prescription,
      recommendationId: launchArgs.recommendationId,
      weekNumber: launchArgs.weekNumber,
      sessionIndex: launchArgs.sessionIndex,
      slotName: launchArgs.slotName,
      sequence: launchArgs.sequence,
      sequenceIndex: launchArgs.sequenceIndex,
      priorReports: launchArgs.priorReports,
    ),
  );
}

/// Safe backstop screen mounted if a hidden exercise is ever pushed onto
/// `/exercise`. When pushed on top of an existing route, it pops immediately on
/// the next frame with a quiet Vietnamese SnackBar; when used as a root/replaced
/// route, it renders a quiet fallback with a button back to `/`.
class BlockedExerciseLaunchScreen extends StatefulWidget {
  const BlockedExerciseLaunchScreen({super.key});

  @override
  State<BlockedExerciseLaunchScreen> createState() =>
      _BlockedExerciseLaunchScreenState();
}

class _BlockedExerciseLaunchScreenState
    extends State<BlockedExerciseLaunchScreen> {
  static const String _refusedMessage =
      'Bài tập này tạm ẩn trong phiên bản hiện tại.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text(_refusedMessage)));
        navigator.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = VikaColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _refusedMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.inkSoft,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    if (navigator.canPop()) {
                      navigator.pop();
                    } else {
                      navigator.pushReplacementNamed('/');
                    }
                  },
                  child: Text(
                    'Quay lại',
                    style: TextStyle(
                      fontFamily: 'BeVietnamPro',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
