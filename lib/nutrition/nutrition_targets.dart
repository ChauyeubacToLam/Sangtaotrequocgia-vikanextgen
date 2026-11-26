import 'dart:math' as math;

enum NutritionGoal { lose, maintain, gain }

enum DietMode { balanced, highProtein }

class Macros {
  const Macros({
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
    this.fiber = 0,
  });

  static const zero = Macros(kcal: 0, protein: 0, fat: 0, carb: 0);

  final double kcal;
  final double protein;
  final double fat;
  final double carb;
  final double fiber;

  Macros operator +(Macros o) => Macros(
        kcal: kcal + o.kcal,
        protein: protein + o.protein,
        fat: fat + o.fat,
        carb: carb + o.carb,
        fiber: fiber + o.fiber,
      );

  Macros scale(double f) => Macros(
        kcal: kcal * f,
        protein: protein * f,
        fat: fat * f,
        carb: carb * f,
        fiber: fiber * f,
      );
}

class BodyInfo {
  const BodyInfo({
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.male,
  });

  static const fallback =
      BodyInfo(weightKg: 60, heightCm: 165, age: 25, male: true);

  final double weightKg;
  final double heightCm;
  final int age;
  final bool male;
}

class DailyTargets {
  const DailyTargets({
    required this.bmr,
    required this.tdee,
    required this.macros,
  });

  final double bmr;
  final double tdee;
  final Macros macros;
}

class PostWorkoutTarget {
  const PostWorkoutTarget({
    required this.protein,
    required this.proteinLow,
    required this.proteinHigh,
    required this.kcalCap,
  });

  final double protein;
  final double proteinLow;
  final double proteinHigh;
  final double kcalCap;
}

class NutritionTargets {
  const NutritionTargets._();

  static const pal = 1.4;
  static const deficit = 500.0;
  static const surplusShare = 0.10;
  static const fatShare = 0.25;
  static const fiberGrams = 25.0;

  static double bmr(BodyInfo b) =>
      10 * b.weightKg + 6.25 * b.heightCm - 5 * b.age + (b.male ? 5 : -161);

  static double minKcal(BodyInfo b) => b.male ? 1500 : 1200;

  static DailyTargets daily(BodyInfo b, NutritionGoal goal, DietMode mode) {
    final base = bmr(b);
    final tdee = base * pal;
    final kcal = switch (goal) {
      NutritionGoal.lose => math.max(tdee - deficit, minKcal(b)),
      NutritionGoal.maintain => tdee,
      NutritionGoal.gain => tdee * (1 + surplusShare),
    };
    final proteinPerKg = mode == DietMode.highProtein ? 2.0 : 1.6;
    final protein = b.weightKg * proteinPerKg;
    final fat = kcal * fatShare / 9;
    final carb = math.max(0.0, (kcal - protein * 4 - fat * 9) / 4);
    return DailyTargets(
      bmr: base,
      tdee: tdee,
      macros: Macros(
        kcal: kcal,
        protein: protein,
        fat: fat,
        carb: carb,
        fiber: fiberGrams,
      ),
    );
  }

  static PostWorkoutTarget postWorkout(
    BodyInfo b,
    DailyTargets daily, {
    double eatenKcal = 0,
    double burnedKcal = 0,
  }) {
    final perMeal = daily.macros.kcal / 3 + burnedKcal;
    final left = daily.macros.kcal + burnedKcal - eatenKcal;
    return PostWorkoutTarget(
      protein: (b.weightKg * 0.30).clamp(20.0, 40.0),
      proteinLow: (b.weightKg * 0.25).clamp(20.0, 40.0),
      proteinHigh: (b.weightKg * 0.40).clamp(20.0, 40.0),
      kcalCap: math.max(0, math.min(perMeal, left)),
    );
  }
}
