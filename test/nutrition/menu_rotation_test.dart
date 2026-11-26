import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vika/nutrition/food_db.dart';
import 'package:vika/nutrition/nutrition_store.dart';
import 'package:vika/nutrition/nutrition_targets.dart';
import 'package:vika/nutrition/post_workout.dart';

void main() {
  final db =
      FoodDb.parse(jsonDecode(File(FoodDb.asset).readAsStringSync()) as Map);
  const body = BodyInfo.fallback;
  final target = NutritionTargets.postWorkout(body,
      NutritionTargets.daily(body, NutritionGoal.maintain, DietMode.balanced));
  final date = DateTime(2026, 11, 25);
  final pool = PostWorkoutPlanner.forAllRegions(db, target,
      meal: 'lunch', date: date)[Region.bac]!;

  test('ordering repeats within a day and varies during the week', () {
    for (final slot in MealSlot.values) {
      final firsts = {for (final r in Region.values) r: <String>{}};
      for (var i = 0; i < 7; i++) {
        final day = DateTime(date.year, date.month, date.day + i);
        final morning = PostWorkoutPlanner.forAllRegions(db, target,
            meal: slot.name, date: day);
        final evening = PostWorkoutPlanner.forAllRegions(db, target,
            meal: slot.name,
            date: DateTime(day.year, day.month, day.day, 23, 59));
        for (final r in Region.values) {
          expect(morning[r]!.map((s) => s.menu.id),
              evening[r]!.map((s) => s.menu.id));
          firsts[r]!.add(morning[r]!.first.menu.id);
        }
      }
      for (final entry in firsts.entries) {
        expect(entry.value.length, greaterThanOrEqualTo(3),
            reason: '${entry.key} $slot');
      }
    }
  });

  test('protein and calorie cap jointly determine the priority group', () {
    const tight = PostWorkoutTarget(
        protein: 27, proteinLow: 20, proteinHigh: 40, kcalCap: 405);
    final menus =
        PostWorkoutPlanner.forAllRegions(db, tight, date: date)[Region.bac]!;
    bool fits(MealSuggestion s) =>
        s.meetsProtein && s.total.kcal <= tight.kcalCap;
    expect(menus.where(fits), isNotEmpty);
    expect(menus.where((s) => s.meetsProtein && s.total.kcal > tight.kcalCap),
        isNotEmpty);
    expect(menus.where((s) => !s.meetsProtein && s.total.kcal <= tight.kcalCap),
        isNotEmpty);
    expect(menus.takeWhile(fits).length, menus.where(fits).length);
  });

  test('one slot wraps exactly every pool length swaps indefinitely', () {
    final deck = MenuDeck(pool, 1);
    for (var i = 1; i <= pool.length * 4; i++) {
      deck.swap(0);
      expect(deck.wrapped, i % pool.length == 0, reason: 'swap $i');
      expect(deck.visible.single, pool[i % pool.length]);
    }
  });

  test('mixed swaps exhaust unseen menus before crossing a page boundary', () {
    final ten = pool.take(10).toList();
    final deck = MenuDeck(ten, 4);
    final seen = deck.visible.toSet();
    expect(deck.visible, ten.take(4));
    deck.swap(2);
    expect(deck.visible, [ten[0], ten[1], ten[4], ten[3]]);
    expect(seen.add(deck.visible[2]), isTrue);
    deck.swapAll();
    expect(deck.wrapped, isFalse);
    for (final s in deck.visible) {
      expect(seen.add(s), isTrue);
    }
    expect(seen, hasLength(9));
    final before = deck.visible.toSet();
    deck.swapAll();
    expect(deck.visible, [ten[9], ten[0], ten[1], ten[2]]);
    expect(deck.visible.toSet().intersection(before), isEmpty);
    expect(deck.wrapped, isTrue);
    expect(seen..add(deck.visible.first), ten.toSet());
    final secondCycle = deck.visible.toSet();
    for (var i = 0; i < 6; i++) {
      final previous = deck.visible;
      deck.swap(i % 4);
      final next = deck.visible[i % 4];
      expect(previous, isNot(contains(next)));
      expect(secondCycle.add(next), isTrue);
      expect(deck.wrapped, isFalse);
    }
    expect(secondCycle, ten.toSet());
    deck.swapAll();
    expect(deck.wrapped, isTrue);
  });

  test('unlimited swaps preserve untouched tiles and handle short pools', () {
    for (var length = 0; length <= 14; length++) {
      for (final slots in [1, 2, 4]) {
        final deck = MenuDeck(pool.take(length).toList(), slots);
        for (var i = 0; i < 100; i++) {
          final before = deck.visible;
          if (i % 3 == 0 || before.isEmpty) {
            deck.swapAll();
            if (length >= slots * 2) {
              expect(
                  deck.visible.toSet().intersection(before.toSet()), isEmpty);
            }
          } else {
            final slot = i % before.length;
            deck.swap(slot);
            for (var j = 0; j < before.length; j++) {
              if (deck.canSwap && j == slot) {
                expect(before, isNot(contains(deck.visible[j])));
              } else {
                expect(deck.visible[j], before[j]);
              }
            }
          }
          expect(deck.visible.toSet(), hasLength(before.length));
        }
      }
    }
  });
}
