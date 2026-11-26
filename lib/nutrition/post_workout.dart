import 'dart:math';

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
      final candidate = MealSuggestion(
        menu: menu,
        items: items,
        sizeLabel: size,
        total: total,
        meetsProtein: total.protein >= target.protein,
      );
      if (total.kcal > target.kcalCap) return best ?? candidate;
      best = candidate;
    }
    return best;
  }

  static Map<Region, List<MealSuggestion>> forAllRegions(
    FoodDb db,
    PostWorkoutTarget target, {
    String? meal,
    DateTime? date,
  }) {
    final out = {for (final r in Region.values) r: <MealSuggestion>[]};
    for (final menu in db.menus) {
      if (meal != null && !menu.servesAt(meal)) continue;
      final s = plan(db, menu, target);
      if (s == null) continue;
      for (final r in Region.values) {
        if (menu.region == null || menu.region == r) out[r]!.add(s);
      }
    }
    final day = date ?? DateTime.now();
    final dayNumber = DateTime.utc(day.year, day.month, day.day)
        .difference(DateTime.utc(1970))
        .inDays;
    bool fits(MealSuggestion s) =>
        s.meetsProtein && s.total.kcal <= target.kcalCap;
    for (final region in Region.values) {
      var seed = region.index;
      for (final unit in (meal ?? '').codeUnits) {
        seed = (seed * 31 + unit) & 0x7fffffff;
      }
      final list = out[region]!..shuffle(Random(seed));
      final dailyRandom = Random(dayNumber ^ seed);
      List<MealSuggestion> rotate(List<MealSuggestion> group) {
        if (group.isEmpty) return group;
        final first = group.removeAt(dayNumber % group.length);
        group.shuffle(dailyRandom);
        return [first, ...group];
      }

      out[region] = [
        ...rotate(list.where(fits).toList()),
        ...rotate(list.where((s) => !fits(s)).toList()),
      ];
    }
    return out;
  }
}

class MenuDeck {
  MenuDeck(List<MealSuggestion> pool, int slots)
      : _pool = List.unmodifiable(pool),
        _visible = pool.take(slots).toList(),
        _remaining = pool.skip(slots).toList();

  final List<MealSuggestion> _pool;
  final List<MealSuggestion> _visible;
  final List<MealSuggestion> _remaining;
  List<MealSuggestion> get visible => List.unmodifiable(_visible);
  int get length => _pool.length;
  bool get canSwap => _pool.length > _visible.length && _visible.isNotEmpty;
  bool wrapped = false;

  void swap(int slot) => _replace([slot]);

  void swapAll() => _replace(
      List.generate(min(_visible.length, length - _visible.length), (i) => i));

  void _replace(List<int> slots) {
    wrapped = false;
    if (!canSwap) return;
    final previous = _visible.toSet();
    for (var i = 0; i < slots.length; i++) {
      if (_remaining.isEmpty) {
        final staying = _visible.toSet()
          ..removeAll(slots.skip(i).map((slot) => _visible[slot]));
        _remaining.addAll(_pool.where((s) => !staying.contains(s)));
        wrapped = true;
      }
      final next = _remaining.indexWhere((s) => !previous.contains(s));
      _visible[slots[i]] = _remaining.removeAt(next);
    }
  }
}
