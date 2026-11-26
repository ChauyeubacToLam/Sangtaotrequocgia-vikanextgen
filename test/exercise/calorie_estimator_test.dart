import 'package:flutter_test/flutter_test.dart';
import 'package:vika/exercise/calorie_estimator_registry.dart';
import 'package:vika/models/post_exercise_data.dart';

PostExerciseData _report(double met) => PostExerciseData(
      exerciseName: 'test',
      metValue: met,
      sets: const [],
      formScore: 0,
      coachText: '',
    );

int _kcal(double met, Duration d) => const GenericMetCalorieEstimator()
    .estimateCalories(
        setLoggers: const [],
        report: _report(met),
        userWeightKg: 60,
        totalDuration: d);

void main() {
  test('counts only energy above rest: (MET - 1) x kg x hours', () {
    expect(_kcal(5.0, const Duration(minutes: 30)), 120);
  });

  test('an activity at or below resting MET burns nothing extra', () {
    expect(_kcal(1.0, const Duration(minutes: 30)), 0);
    expect(_kcal(0.5, const Duration(minutes: 30)), 0);
  });
}
