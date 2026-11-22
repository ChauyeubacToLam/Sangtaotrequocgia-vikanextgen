import '../services/user_profile_service.dart';
import 'food_db.dart';
import 'nutrition_store.dart';
import 'nutrition_targets.dart';

class NutritionContext {
  const NutritionContext({
    required this.db,
    required this.body,
    required this.bodyFromProfile,
    required this.settings,
    required this.daily,
    required this.postWorkout,
  });

  final FoodDb db;
  final BodyInfo body;
  final bool bodyFromProfile;
  final NutritionSettings settings;
  final DailyTargets daily;
  final PostWorkoutTarget postWorkout;

  static Future<BodyInfo?> _bodyFromProfile() async {
    try {
      final p = await UserProfileService().fetchCurrentProfile();
      final w = p?.weightKg;
      final h = p?.heightCm;
      if (w == null || h == null || w <= 0 || h <= 0) return null;
      return BodyInfo(
        weightKg: w.toDouble(),
        heightCm: h.toDouble(),
        age: p?.age ?? BodyInfo.fallback.age,
        male: p?.gender != 'female',
      );
    } catch (_) {
      return null;
    }
  }

  static Future<NutritionContext> load() async {
    final db = await FoodDb.load();
    final settings = await NutritionStore.instance.settings();
    final fromProfile = await _bodyFromProfile();
    final weights = await NutritionStore.instance.weights();
    var body = fromProfile ?? BodyInfo.fallback;
    if (weights.isNotEmpty) {
      body = BodyInfo(
        weightKg: weights.last.kg,
        heightCm: body.heightCm,
        age: body.age,
        male: body.male,
      );
    }
    final daily = NutritionTargets.daily(body, settings.goal, settings.mode);
    return NutritionContext(
      db: db,
      body: body,
      bodyFromProfile: fromProfile != null,
      settings: settings,
      daily: daily,
      postWorkout: NutritionTargets.postWorkout(body, daily),
    );
  }
}
