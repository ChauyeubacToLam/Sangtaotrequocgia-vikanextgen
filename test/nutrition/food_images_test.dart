import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vika/nutrition/food_db.dart';

const iconOnlyFoods = {'nin_7008', 'nin_7009'};

void main() {
  test('every food has an image except the icon-only ones', () {
    final db = FoodDb.parse(
      jsonDecode(File('assets/data/vn_nutrition.json').readAsStringSync()) as Map,
    );
    for (final food in db.foods.values) {
      expect(File(food.image).existsSync(), !iconOnlyFoods.contains(food.id),
          reason: food.id);
    }
  });
}
