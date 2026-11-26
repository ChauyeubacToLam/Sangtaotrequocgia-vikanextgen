import '../models/post_exercise_data.dart';
import '../models/exercise_lookup.dart';
import '../utils/exercise_logger.dart';

abstract class ExerciseCalorieEstimator {
  const ExerciseCalorieEstimator();

  int estimateCalories({
    required List<ExerciseLogger> setLoggers,
    required PostExerciseData report,
    required double userWeightKg,
    required Duration totalDuration,
  });
}

class GenericMetCalorieEstimator extends ExerciseCalorieEstimator {
  const GenericMetCalorieEstimator();

  @override
  int estimateCalories({
    required List<ExerciseLogger> setLoggers,
    required PostExerciseData report,
    required double userWeightKg,
    required Duration totalDuration,
  }) {
    final hours = totalDuration.inSeconds <= 0
        ? 0.0
        : totalDuration.inSeconds / Duration.secondsPerHour;
    final netMet = report.metValue > 1 ? report.metValue - 1 : 0.0;
    return (netMet * userWeightKg * hours).round();
  }
}

class SquatDepthCalorieEstimator extends ExerciseCalorieEstimator {
  const SquatDepthCalorieEstimator();

  static const double _standingKneeAngle = 170.0;
  static const double _deepSquatKneeAngle = 70.0;
  static const double _referenceDisplacementMeters = 0.30;
  static const double _minDisplacementMeters = 0.16;
  static const double _maxDisplacementMeters = 0.38;

  @override
  int estimateCalories({
    required List<ExerciseLogger> setLoggers,
    required PostExerciseData report,
    required double userWeightKg,
    required Duration totalDuration,
  }) {
    final baseline = const GenericMetCalorieEstimator().estimateCalories(
      setLoggers: setLoggers,
      report: report,
      userWeightKg: userWeightKg,
      totalDuration: totalDuration,
    );

    final peakAngles = setLoggers
        .expand((logger) => logger.repLogs)
        .map((rep) => (rep.data['peak_knee_angle'] as num?)?.toDouble())
        .whereType<double>()
        .where((value) => value > 0)
        .toList();

    if (peakAngles.isEmpty || baseline <= 0) return baseline;

    final avgDisplacement =
        peakAngles.map(_estimateDisplacementMeters).reduce((a, b) => a + b) /
            peakAngles.length;
    final depthFactor =
        (avgDisplacement / _referenceDisplacementMeters).clamp(0.78, 1.22);

    return (baseline * depthFactor).round();
  }

  double _estimateDisplacementMeters(double peakKneeAngle) {
    final normalizedDepth = ((_standingKneeAngle - peakKneeAngle) /
            (_standingKneeAngle - _deepSquatKneeAngle))
        .clamp(0.0, 1.0);
    return _minDisplacementMeters +
        ((_maxDisplacementMeters - _minDisplacementMeters) * normalizedDepth);
  }
}

final Map<String, ExerciseCalorieEstimator> calorieEstimators = {
  'squat': const SquatDepthCalorieEstimator(),
  'squat_assessment': const SquatDepthCalorieEstimator(),
};

ExerciseCalorieEstimator? resolveCalorieEstimator(String exerciseId) {
  final direct = calorieEstimators[exerciseId];
  if (direct != null) return direct;

  final normalizedId = normalizeExerciseKey(exerciseId);
  for (final entry in calorieEstimators.entries) {
    if (normalizeExerciseKey(entry.key) == normalizedId) {
      return entry.value;
    }
  }
  return null;
}
