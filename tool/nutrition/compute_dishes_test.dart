import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vika/nutrition/food_db.dart';

void main() {
  test('compute missing dish foods in the staged catalog', () {
    final file = File('assets/data/vn_nutrition.json.family.tmp');
    final catalog = jsonDecode(file.readAsStringSync()) as Map;
    final db = FoodDb.parse(catalog);
    for (final recipe in db.recipes.where((r) => !db.foods.containsKey(r.id))) {
      final ingredients = [
        for (final i in recipe.ingredients) (db.foods[i.foodId]!, i.grams)
      ];
      expect(ingredients.every((i) => i.$1.isRaw && i.$2 > 0), isTrue,
          reason: recipe.id);
      final food = dishFromIngredients(
          id: recipe.id,
          name: recipe.name,
          serving: recipe.serving,
          ingredients: ingredients,
          region: recipe.region);
      food['aka'] = <String>[];
      food['src'] = 'recipe:nin2007';
      (catalog['foods'] as List).add(food);
    }
    file.writeAsStringSync(jsonEncode(catalog), flush: true);
  });
}
