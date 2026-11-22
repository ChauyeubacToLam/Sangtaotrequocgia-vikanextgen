import 'package:flutter/material.dart';

import '../../nutrition/food_db.dart';
import '../../nutrition/nutrition_context.dart';
import '../../nutrition/nutrition_store.dart';
import '../../nutrition/post_workout.dart';
import '../../widgets/tk/tk.dart';
import 'food_visuals.dart';
import 'nutrition_sources_sheet.dart';

class PostWorkoutMealCard extends StatefulWidget {
  const PostWorkoutMealCard({super.key, this.onLogged, this.compact = false});

  final VoidCallback? onLogged;
  final bool compact;

  @override
  State<PostWorkoutMealCard> createState() => _PostWorkoutMealCardState();
}

class _PostWorkoutMealCardState extends State<PostWorkoutMealCard> {
  NutritionContext? _ctx;
  Map<Region, List<MealSuggestion>> _byRegion = const {};
  int _region = 0;
  final Set<String> _logged = {};

  @override
  void initState() {
    super.initState();
    NutritionContext.load().then((ctx) {
      if (!mounted) return;
      setState(() {
        _ctx = ctx;
        _byRegion = PostWorkoutPlanner.forAllRegions(ctx.db, ctx.postWorkout);
      });
    }).catchError((Object _) {});
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
    if (ctx == null) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator(color: Tk.primary)),
      );
    }
    final target = ctx.postWorkout;
    final region = Region.values[_region];
    final list = _byRegion[region] ?? const [];
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
                child: Text('Sau buổi tập nên ăn gì?',
                    style: Tk.text(17, weight: FontWeight.w900)),
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
            'Trong 2 giờ sau tập, ăn một bữa có khoảng '
            '${target.proteinLow.round()}–${target.proteinHigh.round()} g đạm '
            '(0,25–0,4 g cho mỗi kg cân nặng).',
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
                  for (final (i, s)
                      in list.take(widget.compact ? 2 : 4).indexed)
                    FadeSlideIn(
                      index: i,
                      child: _MenuTile(
                        suggestion: s,
                        logged: _logged.contains(s.menu.id),
                        onLog: () => _log(s),
                      ),
                    ),
              ],
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
  });

  final MealSuggestion suggestion;
  final bool logged;
  final VoidCallback onLog;

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
                          it.food.isDish && it.food.defaultPortion != null
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
                Text(
                  s.menu.source.startsWith('ifpri')
                      ? 'Khẩu phần ${s.sizeLabel.toLowerCase()} đã cân thật (album IFPRI 2021)'
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
