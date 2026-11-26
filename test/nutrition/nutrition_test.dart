import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/nutrition/food_db.dart';
import 'package:vika/nutrition/nutrition_sync.dart';
import 'package:vika/nutrition/nutrition_targets.dart';
import 'package:vika/nutrition/post_workout.dart';
import 'package:vika/screens/nutrition/create_food_screen.dart';
import 'package:vika/screens/nutrition/food_visuals.dart';

void main() {
  final db = FoodDb.parse(
    jsonDecode(File('assets/data/vn_nutrition.json').readAsStringSync()) as Map,
  );

  test('Mifflin-St Jeor BMR and daily targets', () {
    const man = BodyInfo(weightKg: 70, heightCm: 175, age: 25, male: true);
    expect(NutritionTargets.bmr(man), closeTo(1673.75, 0.01));
    final keep = NutritionTargets.daily(man, NutritionGoal.maintain, DietMode.balanced);
    expect(keep.macros.kcal, closeTo(1673.75 * 1.4, 0.01));
    expect(keep.macros.protein, closeTo(112, 0.01));
    expect(keep.macros.fat * 9 / keep.macros.kcal, closeTo(0.25, 0.001));
    const woman = BodyInfo(weightKg: 45, heightCm: 150, age: 60, male: false);
    final lose = NutritionTargets.daily(woman, NutritionGoal.lose, DietMode.balanced);
    expect(lose.macros.kcal, 1200);
  });

  test('post-workout protein follows 0.25-0.40 g/kg within 20-40 g', () {
    const b = BodyInfo(weightKg: 60, heightCm: 165, age: 25, male: true);
    final t = NutritionTargets.postWorkout(
        b, NutritionTargets.daily(b, NutritionGoal.maintain, DietMode.balanced));
    expect(t.proteinLow, 20);
    expect(t.proteinHigh, 24);
    expect(t.protein, 20);
  });

  test('recipe filters match region, macros and protein source', () {
    Recipe r(String id) => db.recipes.firstWhere((x) => x.id == id);
    expect(db.recipeMatches(r('pho_bo'), 'Miền Bắc'), isTrue);
    expect(db.recipeMatches(r('pho_bo'), 'Miền Nam'), isFalse);
    expect(db.recipeMatches(r('pho_bo'), 'Bò'), isTrue);
    expect(db.recipeMatches(r('pho_bo'), 'Gà'), isFalse);
    expect(db.recipeMatches(r('com_tam_suon'), 'Lợn'), isTrue);
    expect(db.recipeMatches(r('com_tam_suon'), 'Trứng'), isTrue);
    expect(db.recipeMatches(r('canh_chua_ca'), 'Cá, tôm, cua'), isTrue);
    expect(db.recipeMatches(r('dau_sot_ca'), 'Đậu phụ'), isTrue);
    expect(db.recipeMatches(r('chao_ga'), 'Gà'), isTrue);
    for (final f in FoodDb.recipeFilters) {
      expect(db.recipes.any((x) => db.recipeMatches(x, f)), isTrue, reason: f);
    }
  });

  test('piece counts show next to grams with a known source', () {
    expect(db.foods['nin_7069']!.amountLabel(75), '75 g ≈ 3 lát');
    expect(db.foods['nin_7073']!.amountLabel(60), '60 g ≈ 3 cái');
    expect(db.foods['nin_9004']!.amountLabel(105), '105 g ≈ 1,5 quả');
    expect(db.foods['com_te']!.amountLabel(158), '158 g');
    for (final f in db.foods.values) {
      final p = f.piece;
      if (p == null) continue;
      expect(db.sources.containsKey(p.source.split(':').first), isTrue,
          reason: f.id);
    }
    for (final id in ['bac_xoi_gio', 'bac_com_gio', 'trung_nem_chua', 'nam_thit_kho']) {
      expect(db.menus.any((m) => m.id == id), isTrue, reason: id);
    }
  });

  testWidgets('menu collage builds at full width without errors', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 300,
          child: MenuCollage(foods: [
            db.foods['com_te']!,
            db.foods['ga_luoc']!,
            db.foods['rau_lang']!,
          ]),
        ),
      ),
    ));
    expect(t.takeException(), isNull);
  });

  test('every cooked staple has cooking steps', () {
    for (final id in ['com_te', 'ga_luoc', 'trung_op_la', 'dau_phu_ran', 'tom_hap', 'rau_lang', 'uc_ga']) {
      expect(db.foods[id]!.howto.length, greaterThanOrEqualTo(2), reason: id);
    }
    for (final r in db.recipes) {
      expect(r.steps, isNotEmpty, reason: r.id);
      expect(r.ingredients, isNotEmpty, reason: r.id);
    }
  });

  test('only nutrition keys sync, device step baselines stay local', () {
    expect(NutritionSync.syncable('nutri_day_2026-11-22'), isTrue);
    expect(NutritionSync.syncable('nutri_fav'), isTrue);
    expect(NutritionSync.syncable('nutri_steps_2026-11-22'), isTrue);
    expect(NutritionSync.syncable('nutri_steps_base_2026-11-22'), isFalse);
    expect(NutritionSync.syncable('nutri_steps_last'), isFalse);
    expect(NutritionSync.syncable(NutritionSync.ownerKey), isFalse);
    expect(NutritionSync.syncable('onboarding_done'), isFalse);
  });

  test('every food and menu item points at a known source', () {
    bool known(String src) {
      final parts = src.split(':');
      if (parts.first == 'recipe') {
        return parts.length == 1 || db.sources.containsKey(parts[1]);
      }
      return db.sources.containsKey(parts.first);
    }

    for (final f in db.foods.values) {
      expect(known(f.source), isTrue, reason: f.id);
      for (final p in f.portions) {
        expect(known(p.source), isTrue, reason: '${f.id} ${p.label}');
      }
    }
    for (final m in db.menus) {
      expect(m.items, isNotEmpty, reason: m.id);
    }
    expect(Region.values.every((r) => db.menus.any((m) => m.region == r)), isTrue);
  });

  test('search ignores Vietnamese diacritics and voice text matches foods', () {
    expect(db.search('ga luoc').map((f) => f.id), contains('ga_luoc'));
    expect(db.search('dau phu').length, greaterThanOrEqualTo(2));
    final hits = db.matchSpoken('hôm nay ăn cơm tẻ với gà luộc và rau khoai lang luộc');
    expect(hits.map((h) => h.$1.id), containsAll(['com_te', 'ga_luoc', 'rau_lang']));
  });

  test('meal cap adds workout burn and never exceeds what is left today', () {
    const b = BodyInfo(weightKg: 60, heightCm: 165, age: 25, male: true);
    final daily = NutritionTargets.daily(b, NutritionGoal.maintain, DietMode.balanced);
    final k = daily.macros.kcal;
    expect(NutritionTargets.postWorkout(b, daily).kcalCap, closeTo(k / 3, 0.01));
    expect(NutritionTargets.postWorkout(b, daily, burnedKcal: 200).kcalCap,
        closeTo(k / 3 + 200, 0.01));
    expect(NutritionTargets.postWorkout(b, daily, eatenKcal: k - 100).kcalCap,
        closeTo(100, 0.01));
    expect(NutritionTargets.postWorkout(b, daily, eatenKcal: k + 500).kcalCap, 0);
  });

  test('suggestions follow the time of day and grow with the workout burn', () {
    const b = BodyInfo(weightKg: 60, heightCm: 165, age: 25, male: true);
    final daily = NutritionTargets.daily(b, NutritionGoal.maintain, DietMode.balanced);
    final rest = NutritionTargets.postWorkout(b, daily);
    final trained = NutritionTargets.postWorkout(b, daily, burnedKcal: 300);
    for (final meal in ['breakfast', 'lunch', 'dinner', 'snack']) {
      final all = PostWorkoutPlanner.forAllRegions(db, rest, meal: meal);
      for (final r in Region.values) {
        expect(all[r], isNotEmpty, reason: '$meal ${r.name}');
        for (final s in all[r]!) {
          expect(s.menu.servesAt(meal), isTrue, reason: '$meal ${s.menu.id}');
        }
      }
    }
    final breakfast = PostWorkoutPlanner.forAllRegions(db, rest, meal: 'breakfast');
    final ids = breakfast[Region.bac]!.map((s) => s.menu.id);
    expect(ids, contains('bac_pho'));
    expect(ids, isNot(contains('bac_com_gio')));
    final snack = PostWorkoutPlanner.forAllRegions(db, rest, meal: 'snack');
    for (final r in Region.values) {
      expect(snack[r]!.every((s) => s.menu.id.startsWith('toi_')), isTrue);
    }
    for (final menu in db.menus) {
      final a = PostWorkoutPlanner.plan(db, menu, rest)!;
      final c = PostWorkoutPlanner.plan(db, menu, trained)!;
      expect(c.total.kcal, greaterThanOrEqualTo(a.total.kcal), reason: menu.id);
    }
    final com = db.menus.firstWhere((m) => m.id == 'bac_ga_rau_lang');
    final small = NutritionTargets.postWorkout(b, daily, eatenKcal: daily.macros.kcal - 450);
    expect(PostWorkoutPlanner.plan(db, com, trained)!.total.kcal,
        greaterThan(PostWorkoutPlanner.plan(db, com, small)!.total.kcal));
  });

  test('planner returns a portion within the known sizes', () {
    const b = BodyInfo(weightKg: 60, heightCm: 165, age: 25, male: true);
    final daily = NutritionTargets.daily(b, NutritionGoal.maintain, DietMode.balanced);
    final target = NutritionTargets.postWorkout(b, daily);
    final all = PostWorkoutPlanner.forAllRegions(db, target);
    for (final r in Region.values) {
      expect(all[r], isNotEmpty, reason: r.name);
    }
    for (final list in all.values) {
      for (final s in list) {
        expect(s.total.kcal, greaterThan(0));
        if (s.meetsProtein) {
          final i = PostWorkoutPlanner.sizes.indexOf(s.sizeLabel);
          expect(i, greaterThanOrEqualTo(0));
        }
      }
    }
  });

  test('recipes resolve to NIN ingredients and a dish food per serving', () {
    expect(db.recipes.length, greaterThanOrEqualTo(15));
    for (final r in db.recipes) {
      final dish = db.foods[r.id];
      expect(dish, isNotNull, reason: r.id);
      expect(dish!.isDish, isTrue);
      expect(dish.defaultPortion?.grams, closeTo(r.grams, 0.01));
      for (final i in r.ingredients) {
        expect(db.foods[i.foodId]?.isRaw, isTrue, reason: '${r.id} ${i.foodId}');
      }
      expect(r.steps, isNotEmpty);
    }
    final gio = db.search('gio lua').first;
    expect(gio.per100.kcal, 136);
    expect(gio.source, 'nin2007:7069');
  });

  test('dishFromIngredients sums ingredient nutrients', () {
    final rice = db.foods['nin_1004']!;
    final pork = db.foods['nin_7017']!;
    final dish = Food.fromJson(dishFromIngredients(
      id: 'x',
      name: 'Thử',
      serving: '1 bát',
      ingredients: [(rice, 50), (pork, 50)],
    ));
    expect(dish.forGrams(100).kcal, closeTo(344 / 2 + 139 / 2, 0.01));
    expect(dish.forGrams(100).protein, closeTo(7.9 / 2 + 19 / 2, 0.01));
  });

  test('nutrition label parser reads common Vietnamese label lines', () {
    final v = parseNutritionLabel('''
THÔNG TIN DINH DƯỠNG / 100g
Năng lượng 452 kcal
Chất đạm 6,5 g
Chất béo 21 g
Carbohydrate 59 g
Chất xơ 2 g''');
    expect(v['kcal'], 452);
    expect(v['p'], 6.5);
    expect(v['f'], 21);
    expect(v['c'], 59);
    expect(v['fib'], 2);
  });
}
