import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vika/nutrition/food_db.dart';
import 'package:vika/nutrition/nutrition_store.dart';
import 'package:vika/nutrition/nutrition_targets.dart';
import 'package:vika/nutrition/post_workout.dart';

const _proteins = {'gà', 'lợn', 'bò', 'cá', 'hải sản', 'trứng', 'đậu'};
const _staples = {'com_te', 'gao_lut'};
const _plainProteins = {
  'ga_luoc': 'gà',
  'ga_xe': 'gà',
  'thit_nac_luoc': 'lợn',
  'thit_nuong': 'lợn',
  'nin_7069': 'lợn',
  'tom_hap': 'hải sản',
  'dau_phu_ran': 'đậu',
  'dau_phu_luoc': 'đậu',
  'trung_op_la': 'trứng',
  'trung_luoc': 'trứng',
};

const _methods = {
  'luộc',
  'nướng',
  'hấp',
  'rán',
  'trộn',
  'kho',
  'rim',
  'rang',
  'xào',
  'sốt',
  'om'
};
const _plainMethods = {
  'ga_luoc': 'luộc',
  'ga_xe': 'trộn',
  'thit_nac_luoc': 'luộc',
  'thit_nuong': 'nướng',
  'nin_7069': 'hấp',
  'tom_hap': 'hấp',
  'dau_phu_ran': 'rán',
  'dau_phu_luoc': 'luộc',
  'trung_op_la': 'rán',
  'trung_luoc': 'luộc',
};

void main() {
  const catalog =
      String.fromEnvironment('NUTRITION_CATALOG', defaultValue: FoodDb.asset);
  final raw = jsonDecode(File(catalog).readAsStringSync()) as Map;
  final db = FoodDb.parse(raw);
  final recipes = {for (final r in db.recipes) r.id: r};
  const body = BodyInfo(weightKg: 60, heightCm: 165, age: 25, male: true);
  final target = NutritionTargets.postWorkout(body,
      NutritionTargets.daily(body, NutritionGoal.maintain, DietMode.balanced));

  test('catalog identifiers, references, meal slots and portion provenance',
      () {
    expect(db.menus.length, greaterThanOrEqualTo(318));
    final ids = <String, Set<String>>{};
    for (final table in ['foods', 'recipes', 'menus']) {
      final rows = raw[table] as List;
      ids[table] = {for (final row in rows) row['id'] as String};
      expect(ids[table], hasLength(rows.length), reason: table);
      for (final id in ids[table]!) {
        expect(id, matches(RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$')));
      }
    }
    expect(ids['menus']!.intersection(ids['foods']!), isEmpty);
    expect(ids['recipes'],
        db.foods.values.where((f) => f.isDish).map((f) => f.id).toSet());
    expect(db.foods.values.where((f) => f.isRaw), hasLength(515));
    expect(db.foods.values.where((f) => f.source.startsWith('usda:')),
        hasLength(33));
    expect(
        ids['menus'],
        containsAll([
          'bac_ga_rau_lang',
          'bac_dau_trung',
          'bac_thit_luoc',
          'bac_tom',
          'trung_com_ga',
          'trung_bun_tom',
          'trung_dau_luoc',
          'nam_bun_thit_nuong',
          'nam_ga_ca_rot',
          'bac_pho',
          'bac_bun_cha',
          'bac_dau_rau',
          'trung_bun_bo',
          'trung_mi_quang',
          'nam_com_tam_ct',
          'nam_hu_tieu',
          'nam_ca_kho',
          'bac_xoi_gio',
          'bac_com_gio',
          'trung_nem_chua',
          'nam_thit_kho',
          'toi_sua_trung',
          'toi_dau_nanh_trung',
          'toi_yen_mach_sua',
        ]));
    for (final row in raw['menus']) {
      final id = row['id'] as String;
      final slots = (row['meals'] as List).cast<String>();
      expect(slots, isNotEmpty, reason: id);
      expect(slots.toSet(), hasLength(slots.length), reason: id);
      expect(slots, everyElement(isIn(MealSlot.values.map((s) => s.name))),
          reason: id);
      final snack = slots.contains('snack');
      if (snack) {
        expect(slots, ['snack'], reason: id);
        expect(row['region'], isNull, reason: id);
        expect(id, startsWith('toi_'));
      } else {
        expect(Region.values.map((r) => r.name), contains(row['region']),
            reason: id);
        expect(id, startsWith('${row['region']}_'));
      }
      final items = row['items'] as List;
      expect(items, isNotEmpty, reason: id);
      expect(items.map((it) => it['food']).toSet(), hasLength(items.length),
          reason: id);
      var allWeighed = true;
      for (final item in items) {
        final food = db.foods[item['food']];
        expect(food, isNotNull, reason: '$id ${item['food']}');
        expect(item['g'], greaterThan(0), reason: id);
        final weighed =
            food!.portions.where((p) => p.source.startsWith('ifpri2021:'));
        if (weighed.isEmpty) {
          allWeighed = false;
        } else {
          expect(weighed.map((p) => p.grams), contains(item['g']),
              reason: '$id ${food.id}');
        }
      }
      expect(
          row['src'],
          snack
              ? 'issn_timing'
              : allWeighed
                  ? 'ifpri2021'
                  : 'nin2007',
          reason: id);
    }
  });

  test('every dish matches its NIN recipe including micronutrients', () {
    for (final r in db.recipes) {
      final dish = db.foods[r.id]!;
      expect(r.ingredients, isNotEmpty, reason: r.id);
      expect(r.steps, hasLength(greaterThanOrEqualTo(3)), reason: r.id);
      expect(r.steps.every((step) => step.trim().isNotEmpty), isTrue,
          reason: r.id);
      expect(dish.source, 'recipe:nin2007', reason: r.id);
      expect(dish.name, r.name);
      expect(dish.defaultPortion?.label, r.serving, reason: r.id);
      expect(dish.defaultPortion?.grams, r.grams, reason: r.id);
      expect(r.grams,
          closeTo(r.ingredients.fold<double>(0, (n, i) => n + i.grams), 1e-7),
          reason: r.id);
      for (final i in r.ingredients) {
        expect(db.foods[i.foodId]?.isRaw, isTrue,
            reason: '${r.id} ${i.foodId}');
        expect(i.grams, greaterThan(0), reason: r.id);
      }
      if (r.tags.contains('canh')) {
        expect(r.tags, contains('món rau'), reason: r.id);
      }
      if (r.tags.contains('món rau')) {
        expect(r.tags, isNot(contains('món chính')), reason: r.id);
        expect(
            r.ingredients.any(
                (i) => i.grams >= 30 && db.foods[i.foodId]!.group == 'rau'),
            isTrue,
            reason: r.id);
      }
      final expected = dishFromIngredients(
          id: r.id,
          name: r.name,
          serving: r.serving,
          ingredients: [
            for (final i in r.ingredients) (db.foods[i.foodId]!, i.grams)
          ]);
      for (final field in ['per100', 'micro']) {
        final wanted = expected[field] as Map;
        final actual = dish.toJson()[field] as Map;
        expect(actual.keys.toSet(), wanted.keys.toSet(), reason: r.id);
        for (final key in wanted.keys) {
          final value = wanted[key] as double;
          expect(actual[key], closeTo(value, value.abs() * 0.005 + 1e-8),
              reason: '${r.id} $key');
        }
      }
    }
  });

  for (final region in Region.values) {
    for (final slot in MealSlot.values) {
      test('${region.name} ${slot.name} portions, balance and variety', () {
        final menus = db.menus.where((m) =>
            (m.region == null || m.region == region) && m.servesAt(slot.name));
        final mainMeal = slot == MealSlot.lunch || slot == MealSlot.dinner;
        expect(
            menus.length,
            greaterThanOrEqualTo(mainMeal
                ? 70
                : slot == MealSlot.snack
                    ? 28
                    : 26));
        final frequency = <String, int>{};
        final proteins = <String, int>{};
        final combinations = <String>{};
        var withSoup = 0;
        var bowls = 0;
        for (final m in menus) {
          final ids = m.items.map((i) => i.foodId).toList();
          final signature = [...ids]..sort();
          expect(combinations.add(signature.join('|')), isTrue, reason: m.id);
          final t = PostWorkoutPlanner.plan(db, m, target)!.total;
          if (slot == MealSlot.snack) {
            expect(t.kcal, inInclusiveRange(100, 350), reason: m.id);
            expect(t.protein, greaterThanOrEqualTo(10), reason: m.id);
            continue;
          }
          expect(t.fat * 9 / t.kcal, lessThanOrEqualTo(.35), reason: m.id);
          if (!mainMeal) {
            expect(t.kcal, inInclusiveRange(300, 700), reason: m.id);
            expect(t.protein, greaterThanOrEqualTo(15), reason: m.id);
            continue;
          }
          final family = slot == MealSlot.dinner || ids.any(_staples.contains);
          expect(t.kcal, inInclusiveRange(family ? 500 : 350, target.kcalCap),
              reason: m.id);
          expect(t.protein, greaterThanOrEqualTo(family ? 25 : 20),
              reason: m.id);
          expect(t.fiber, greaterThanOrEqualTo(family ? 4 : 3), reason: m.id);
          for (final id in ids.where((id) => !_staples.contains(id))) {
            frequency.update(id, (n) => n + 1, ifAbsent: () => 1);
          }
          bool tagged(String id, String tag) =>
              recipes[id]?.tags.contains(tag) ?? false;
          bool vegetable(String id) =>
              db.foods[id]!.group == 'rau' || tagged(id, 'món rau');
          if (!family) {
            bowls++;
            expect(tagged(ids.first, 'món sợi hoặc bánh mì'), isTrue,
                reason: m.id);
            for (final id in ids.skip(1)) {
              expect(
                  vegetable(id) &&
                      !tagged(id, 'canh') &&
                      !tagged(id, 'món chính'),
                  isTrue,
                  reason: m.id);
            }
            continue;
          }
          expect(ids, hasLength(4), reason: m.id);
          expect(ids.where(_staples.contains), hasLength(1), reason: m.id);
          expect(_staples, contains(ids.first), reason: m.id);
          expect(ids.where(vegetable), hasLength(1), reason: m.id);
          expect(vegetable(ids.last), isTrue, reason: m.id);
          if (tagged(ids.last, 'canh')) {
            expect(tagged(ids.last, 'món rau'), isTrue, reason: m.id);
            withSoup++;
          }
          final pair = <String>{};
          final methods = <String>{};
          for (final id in ids.sublist(1, 3)) {
            final tags = recipes[id]?.tags ?? [];
            expect(
                !vegetable(id) &&
                    !tags.contains('canh') &&
                    !tags.contains('tinh bột'),
                isTrue,
                reason: m.id);
            expect(_plainProteins.containsKey(id) || tags.contains('món chính'),
                isTrue,
                reason: m.id);
            final kinds = _plainProteins.containsKey(id)
                ? [_plainProteins[id]!]
                : tags.where(_proteins.contains);
            final cooks = _plainMethods.containsKey(id)
                ? [_plainMethods[id]!]
                : tags.where(_methods.contains);
            expect(kinds, hasLength(1), reason: m.id);
            expect(cooks, hasLength(1), reason: m.id);
            expect(pair.add(kinds.single), isTrue, reason: m.id);
            expect(methods.add(cooks.single), isTrue, reason: m.id);
            proteins.update(kinds.single, (n) => n + 1, ifAbsent: () => 1);
          }
        }
        if (slot == MealSlot.dinner) {
          expect(withSoup / menus.length, inInclusiveRange(.40, .70));
        }
        if (slot == MealSlot.lunch) {
          expect(bowls / menus.length, lessThanOrEqualTo(.30));
        }
        if (mainMeal) {
          for (final protein in _proteins) {
            expect(proteins[protein] ?? 0, greaterThanOrEqualTo(4),
                reason: protein);
          }
          for (final entry in frequency.entries) {
            expect(entry.value / menus.length, lessThanOrEqualTo(.15),
                reason: entry.key);
          }
        }
      });
    }
  }
}
