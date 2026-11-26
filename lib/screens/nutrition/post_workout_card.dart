import 'dart:async';

import 'package:flutter/material.dart';

import '../../nutrition/food_db.dart';
import '../../nutrition/nutrition_context.dart';
import '../../nutrition/nutrition_store.dart';
import '../../nutrition/nutrition_targets.dart';
import '../../nutrition/post_workout.dart';
import '../../widgets/tk/tk.dart';
import 'food_visuals.dart';
import 'nutrition_screen.dart' show entriesTotal;
import 'nutrition_sources_sheet.dart';

class PostWorkoutMealCard extends StatefulWidget {
  const PostWorkoutMealCard({
    super.key,
    this.onLogged,
    this.compact = false,
    this.justTrained = false,
  });

  final VoidCallback? onLogged;
  final bool compact;
  final bool justTrained;

  @override
  State<PostWorkoutMealCard> createState() => _PostWorkoutMealCardState();
}

class _PostWorkoutMealCardState extends State<PostWorkoutMealCard>
    with WidgetsBindingObserver {
  NutritionContext? _ctx;
  PostWorkoutTarget? _target;
  MealSlot _slot = mealSlotForHour(DateTime.now().hour);
  double _burned = 0;
  Map<Region, MenuDeck> _decks = const {};
  DateTime? _loadedDay;
  Timer? _mealTimer;
  int _region = 0;
  final Set<String> _logged = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mealTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = DateTime.now();
    if (state == AppLifecycleState.resumed &&
        (!DateUtils.isSameDay(_loadedDay, now) ||
            mealSlotForHour(now.hour) != _slot)) {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      final ctx = await NutritionContext.load();
      final day = await NutritionStore.instance.loadDay(now);
      final target = NutritionTargets.postWorkout(
        ctx.body,
        ctx.daily,
        eatenKcal: entriesTotal(ctx.db, day.entries).kcal,
        burnedKcal: day.burnedKcal,
      );
      final slot = mealSlotForHour(now.hour);
      if (!mounted) return;
      final nextHour = [10, 15, 21, 24].firstWhere((h) => h > now.hour);
      final nextMeal = DateTime(now.year, now.month, now.day, nextHour);
      _mealTimer?.cancel();
      _mealTimer = Timer(nextMeal.difference(DateTime.now()), _load);
      setState(() {
        if (!DateUtils.isSameDay(_loadedDay, now)) _logged.clear();
        _loadedDay = now;
        _ctx = ctx;
        _target = target;
        _slot = slot;
        _burned = day.burnedKcal;
        _decks = PostWorkoutPlanner.forAllRegions(ctx.db, target,
                meal: slot.name, date: now)
            .map((region, pool) =>
                MapEntry(region, MenuDeck(pool, widget.compact ? 2 : 4)));
      });
    } catch (_) {}
  }

  String get _title => switch (_slot) {
        MealSlot.breakfast => 'Bữa sáng nay ăn gì?',
        MealSlot.lunch => 'Bữa trưa nay ăn gì?',
        MealSlot.dinner => 'Bữa tối nay ăn gì?',
        MealSlot.snack => 'Tối muộn ăn nhẹ gì?',
      };

  String _advice(PostWorkoutTarget t) {
    final burned = _burned.round();
    final head = widget.justTrained && burned > 0
        ? 'Bạn vừa tập xong, hôm nay đã đốt khoảng $burned kcal. '
        : burned > 0
            ? 'Hôm nay bạn đã đốt khoảng $burned kcal khi tập. '
            : '';
    if (t.kcalCap <= 0) {
      return '${head}Hôm nay bạn đã ăn đủ năng lượng. Nếu đói, chọn phần nhỏ nhất.';
    }
    if (_slot == MealSlot.snack) {
      return '${head}Tối muộn nên ăn nhẹ, ưu tiên sữa và trứng: đạm trước khi ngủ '
          'giúp cơ phục hồi qua đêm.';
    }
    return '${head}Bữa này không nên vượt quá khoảng ${t.kcalCap.round()} kcal, có '
        '${t.proteinLow.round()}–${t.proteinHigh.round()} g đạm '
        '(0,25–0,4 g cho mỗi kg cân nặng).';
  }

  Future<void> _log(MealSuggestion s) async {
    final now = DateTime.now();
    final meal = mealSlotForHour(now.hour);
    for (var i = 0; i < s.items.length; i++) {
      await NutritionStore.instance.addEntry(
        now,
        DiaryEntry(
          foodId: s.items[i].food.id,
          grams: s.items[i].grams,
          meal: meal,
          at: now.add(Duration(milliseconds: i)),
        ),
      );
    }
    if (!mounted) return;
    setState(() => _logged.add(s.menu.id));
    widget.onLogged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = _ctx;
    final target = _target;
    if (ctx == null || target == null) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(color: Tk.primary)),
      );
    }
    final region = Region.values[_region];
    final deck = _decks[region]!;
    final list = deck.visible;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEDF8F0), Color(0xFFF6F7FC)],
        ),
        border: Border.all(color: const Color(0xFFD5EFDC), width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Tk.green,
                child: Icon(Icons.restaurant_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child:
                    Text(_title, style: Tk.text(17, weight: FontWeight.w900)),
              ),
              InkWell(
                onTap: () => showNutritionSources(context, ctx.db),
                borderRadius: BorderRadius.circular(99),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded,
                          size: 16, color: Tk.primary),
                      const SizedBox(width: 4),
                      Text('Nguồn', style: Tk.text(13, color: Tk.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _advice(target),
            style: Tk.text(14,
                weight: FontWeight.w700, height: 1.4, color: Tk.greenInk),
          ),
          if (!ctx.bodyFromProfile) ...[
            const SizedBox(height: 4),
            Text('Chưa có cân nặng trong hồ sơ, đang tính theo 60 kg.',
                style: Tk.text(12.5,
                    weight: FontWeight.w700, color: Tk.orangeInk)),
          ],
          const SizedBox(height: 12),
          TkSegmented(
            labels: const ['Bắc', 'Trung', 'Nam'],
            selected: _region,
            onChanged: (i) => setState(() => _region = i),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            child: Column(
              key: ValueKey(_region),
              children: [
                if (list.isEmpty)
                  Text('Chưa có thực đơn cho miền này.',
                      style: Tk.text(14,
                          weight: FontWeight.w700, color: Tk.inkSoft))
                else
                  for (final (i, s) in list.indexed)
                    FadeSlideIn(
                      key: ValueKey(s.menu.id),
                      index: i,
                      child: _MenuTile(
                        suggestion: s,
                        logged: _logged.contains(s.menu.id),
                        onLog: () => _log(s),
                        onSwap: deck.canSwap
                            ? () => setState(() => deck.swap(i))
                            : null,
                      ),
                    ),
              ],
            ),
          ),
          if (deck.canSwap)
            Semantics(
              button: true,
              child: TkCard(
                radius: 16,
                padding: const EdgeInsets.all(12),
                onTap: () => setState(deck.swapAll),
                child: Text('Xem thực đơn khác',
                    textAlign: TextAlign.center,
                    style: Tk.text(15,
                        weight: FontWeight.w800, color: Tk.primary)),
              ),
            ),
          if (deck.wrapped)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'Đã xem hết ${deck.length} thực đơn, quay lại từ đầu.',
                    style: Tk.text(13,
                        weight: FontWeight.w700, color: Tk.inkSoft)),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.suggestion,
    required this.logged,
    required this.onLog,
    required this.onSwap,
  });

  final MealSuggestion suggestion;
  final bool logged;
  final VoidCallback onLog;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Tk.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14231E5C), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MenuCollage(foods: [for (final it in s.items) it.food], height: 120),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.menu.name, style: Tk.text(16, weight: FontWeight.w900)),
                const SizedBox(height: 6),
                for (final it in s.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        FoodImage(food: it.food, size: 30, radius: 9),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(it.food.name,
                              style: Tk.text(14, weight: FontWeight.w700)),
                        ),
                        Text(
                          it.food.isDish &&
                                  it.food.defaultPortion?.grams == it.grams
                              ? it.food.defaultPortion!.label
                              : it.food.amountLabel(it.grams),
                          style: Tk.text(13.5, color: Tk.inkSoft),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: MacroPills(
                        kcal: s.total.kcal,
                        protein: s.total.protein,
                        carb: s.total.carb,
                        fat: s.total.fat,
                        dense: true,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: logged
                          ? const Icon(Icons.check_circle_rounded,
                              key: ValueKey(true), color: Tk.green, size: 34)
                          : IconButton(
                              key: const ValueKey(false),
                              tooltip: 'Ghi vào nhật ký',
                              onPressed: onLog,
                              icon: const Icon(Icons.add_circle_rounded,
                                  color: Tk.green, size: 34),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (onSwap != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onSwap,
                      icon:
                          const Icon(Icons.refresh_rounded, color: Tk.primary),
                      label: Text('Đổi thực đơn',
                          style: Tk.text(14,
                              weight: FontWeight.w800, color: Tk.primary)),
                    ),
                  ),
                Text(
                  s.menu.source.startsWith('ifpri')
                      ? 'Khẩu phần ${s.sizeLabel.toLowerCase()} đã cân thật (album IFPRI 2021)'
                      : s.menu.source.startsWith('issn')
                          ? 'Bữa nhẹ trước khi ngủ theo khuyến nghị ISSN 2017'
                          : 'Món theo công thức, tính từ Bảng thành phần thực phẩm Việt Nam',
                  style: Tk.text(11.5,
                      weight: FontWeight.w600, color: Tk.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
