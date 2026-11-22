import 'food_db.dart';
import 'nutrition_targets.dart';

class SuggestedItem {
  const SuggestedItem(this.food, this.grams);

  final Food food;
  final double grams;

  Macros get macros => food.forGrams(grams);
}

class MealSuggestion {
  const MealSuggestion({
    required this.menu,
    required this.items,
    required this.sizeLabel,
    required this.total,
    required this.meetsProtein,
  });

  final RegionalMenu menu;
  final List<SuggestedItem> items;
  final String sizeLabel;
  final Macros total;
  final bool meetsProtein;
}

class PostWorkoutPlanner {
  const PostWorkoutPlanner._();

  static const sizes = ['Nhỏ', 'Vừa', 'Lớn', 'Rất lớn'];

  static double _gramsFor(Food food, MenuItem item, String size) {
    for (final p in food.portions) {
      if (p.label == size) return p.grams;
    }
    return item.grams;
  }

  static MealSuggestion? plan(
    FoodDb db,
    RegionalMenu menu,
    PostWorkoutTarget target,
  ) {
    MealSuggestion? best;
    for (final size in sizes) {
      final items = <SuggestedItem>[];
      for (final it in menu.items) {
        final food = db.foods[it.foodId];
        if (food == null) continue;
        items.add(SuggestedItem(food, _gramsFor(food, it, size)));
      }
      if (items.isEmpty) return null;
      final total = items.fold(Macros.zero, (a, b) => a + b.macros);
      final meets = total.protein >= target.protein;
      final fits = total.kcal <= target.kcalCap;
      final candidate = MealSuggestion(
        menu: menu,
        items: items,
        sizeLabel: size,
        total: total,
        meetsProtein: meets,
      );
      if (!fits) return best ?? candidate;
      best = candidate;
      if (meets) return candidate;
    }
    return best;
  }

  static Map<Region, List<MealSuggestion>> forAllRegions(
    FoodDb db,
    PostWorkoutTarget target,
  ) {
    final out = {for (final r in Region.values) r: <MealSuggestion>[]};
    for (final menu in db.menus) {
      final s = plan(db, menu, target);
      if (s != null) out[menu.region]!.add(s);
    }
    for (final list in out.values) {
      list.sort((a, b) {
        if (a.meetsProtein != b.meetsProtein) return a.meetsProtein ? -1 : 1;
        return a.total.kcal.compareTo(b.total.kcal);
      });
    }
    return out;
  }
}
