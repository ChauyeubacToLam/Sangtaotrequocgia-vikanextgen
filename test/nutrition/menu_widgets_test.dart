import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vika/nutrition/food_db.dart';
import 'package:vika/nutrition/nutrition_store.dart';
import 'package:vika/screens/nutrition/food_visuals.dart';
import 'package:vika/screens/nutrition/nutrition_screen.dart';
import 'package:vika/screens/nutrition/post_workout_card.dart';
import 'package:vika/widgets/tk/tk.dart';

void main() {
  testWidgets(
      'compact card swaps one or all, keeps regional decks and logged state',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = (await tester.runAsync(() => FoodDb.load()))!;
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body:
              SingleChildScrollView(child: PostWorkoutMealCard(compact: true))),
    ));
    await tester.pumpAndSettle();
    List<String> visible() => tester
        .widgetList<FadeSlideIn>(find.byType(FadeSlideIn))
        .map((w) => (w.key! as ValueKey<String>).value)
        .toList();
    Future<void> tap(Finder control) async {
      await tester.ensureVisible(control);
      await tester.tap(control);
      await tester.pumpAndSettle();
    }

    final initial = visible();
    expect(initial, hasLength(2));
    final single = find.text('Đổi thực đơn');
    final all = find.text('Xem thực đơn khác');
    await tap(find.byTooltip('Ghi vào nhật ký').last);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    await tap(single.first);
    final changed = visible();
    expect(initial, isNot(contains(changed.first)));
    expect(changed.last, initial.last);
    await tap(find.text('Nam'));
    final south = visible();
    await tap(all);
    final newSouth = visible();
    expect(south.toSet().intersection(newSouth.toSet()), isEmpty);
    await tap(find.text('Bắc'));
    expect(visible(), changed);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    await tap(find.text('Nam'));
    expect(visible(), newSouth);
    await tap(find.text('Bắc'));
    final slot = mealSlotForHour(DateTime.now().hour);
    final count = db.menus
        .where((m) =>
            (m.region == null || m.region == Region.bac) &&
            m.servesAt(slot.name))
        .length;
    final message = find.text('Đã xem hết $count thực đơn, quay lại từ đầu.');
    var seenCount = 3;
    while (seenCount <= count) {
      expect(message, findsNothing);
      final previous = visible();
      await tap(all);
      expect(visible().toSet().intersection(previous.toSet()), isEmpty);
      seenCount += 2;
    }
    expect(message, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
      'sample menus filter by meal and region, page by six and keep custom menus',
      (tester) async {
    const customName = 'Thực đơn riêng để kiểm tra';
    SharedPreferences.setMockInitialValues({
      'nutri_menus': jsonEncode([
        {
          'id': 'custom_test',
          'region': 'bac',
          'name': customName,
          'src': 'user',
          'items': [
            {'food': 'com_te', 'g': 158}
          ],
        }
      ]),
    });
    final db = (await tester.runAsync(() => FoodDb.load()))!;
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: NutritionScreen())));
    await tester.pumpAndSettle();
    final scroll = find.byType(Scrollable).first;
    final chips = find.byWidgetPredicate(
        (w) => w is TkSegmented && w.labels.contains('Ăn khuya'));
    Future<void> reveal(Finder control, double delta) async {
      for (var i = 0;
          i < 100 && control.hitTestable().evaluate().isEmpty;
          i++) {
        await tester.drag(scroll, Offset(0, -delta));
        await tester.pumpAndSettle();
      }
      expect(control.hitTestable(), findsOneWidget);
    }

    await reveal(chips, 300);
    final meal = mealSlotForHour(DateTime.now().hour);
    expect(tester.widget<TkSegmented>(chips).selected, meal.index);

    Future<void> select(Finder control, {double delta = 300}) async {
      await reveal(control, delta);
      await tester.tap(control.hitTestable());
      await tester.pumpAndSettle();
    }

    await select(find.descendant(of: chips, matching: find.text('Trưa')));
    final bac = db.menus
        .where(
            (m) => !m.custom && m.region == Region.bac && m.servesAt('lunch'))
        .toList();
    Finder page(Region r, MealSlot m) => find.byKey(ValueKey((r.index, m)));
    final lunch = page(Region.bac, MealSlot.lunch);
    Finder inPage(Finder p, String name) =>
        find.descendant(of: p, matching: find.text(name));
    expect(inPage(lunch, bac[5].name), findsOneWidget);
    expect(inPage(lunch, bac[6].name), findsNothing);
    await select(inPage(lunch, 'Xem thêm'));
    expect(inPage(lunch, bac[11].name), findsOneWidget);
    expect(inPage(lunch, bac[12].name), findsNothing);
    await select(inPage(lunch, 'Xem thêm'));
    expect(inPage(lunch, bac[17].name), findsOneWidget);
    final regions = find
        .byWidgetPredicate((w) => w is TkSegmented && w.labels.contains('Nam'));
    await select(find.descendant(of: regions, matching: find.text('Nam')),
        delta: -200);
    final south = db.menus
        .where(
            (m) => !m.custom && m.region == Region.nam && m.servesAt('lunch'))
        .toList();
    expect(inPage(page(Region.nam, MealSlot.lunch), south[5].name),
        findsOneWidget);
    expect(
        inPage(page(Region.nam, MealSlot.lunch), south[6].name), findsNothing);
    await select(find.descendant(of: chips, matching: find.text('Ăn khuya')));
    final snacks =
        db.menus.where((m) => !m.custom && m.servesAt('snack')).toList();
    final night = page(Region.nam, MealSlot.snack);
    expect(inPage(night, snacks.first.name), findsOneWidget);
    expect(inPage(night, snacks[6].name), findsNothing);
    await reveal(find.text(customName), 300);
    expect(find.text(customName), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
