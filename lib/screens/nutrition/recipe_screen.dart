import 'package:flutter/material.dart';

import '../../nutrition/food_db.dart';
import '../../nutrition/nutrition_context.dart';
import '../../nutrition/nutrition_store.dart';
import '../../nutrition/nutrition_targets.dart';
import '../../widgets/tk/tk.dart';
import 'food_search_screen.dart';
import 'food_visuals.dart';

Future<void> openRecipe(BuildContext context, Recipe recipe, {DateTime? day}) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (_, __, ___) => RecipeScreen(recipe: recipe, day: day),
    transitionsBuilder: (_, a, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: child,
    ),
  ));
}

class RecipeScreen extends StatefulWidget {
  const RecipeScreen({super.key, required this.recipe, this.day});

  final Recipe recipe;
  final DateTime? day;

  @override
  State<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends State<RecipeScreen> {
  NutritionContext? _ctx;
  double _servings = 1;
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    NutritionContext.load().then((c) {
      if (mounted) setState(() => _ctx = c);
    });
  }

  Future<void> _log(Food dish) async {
    final now = DateTime.now();
    await NutritionStore.instance.addEntry(
      widget.day ?? now,
      DiaryEntry(
        foodId: dish.id,
        grams: widget.recipe.grams * _servings,
        meal: mealSlotForHour(now.hour),
        at: now,
      ),
    );
    if (!mounted) return;
    setState(() => _logged = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã ghi ${widget.recipe.name} vào nhật ký')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final ctx = _ctx;
    final dish = ctx?.db.foods[r.id];
    final total = dish?.forGrams(r.grams * _servings) ?? Macros.zero;
    return Scaffold(
      backgroundColor: Tk.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            backgroundColor: Tk.surface,
            surfaceTintColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.92),
                child: IconButton(
                  tooltip: 'Quay lại',
                  icon: const Icon(Icons.arrow_back_rounded, color: Tk.ink),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: dish == null
                  ? const ColoredBox(color: Tk.surfaceSoft)
                  : FoodImage(
                      food: dish,
                      heroTag: 'recipe_${r.id}',
                      width: double.infinity,
                      height: 300,
                      radius: 0,
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: ctx == null || dish == null
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                        child: CircularProgressIndicator(color: Tk.primary)),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            if (r.region != null)
                              _Tag(r.region!.label, Tk.primary),
                            for (final t in r.tags) _Tag(t, Tk.green),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(r.name,
                            style: Tk.text(30,
                                weight: FontWeight.w900,
                                letterSpacing: -0.5,
                                height: 1.1)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Khẩu phần',
                                  style: Tk.text(15, weight: FontWeight.w800)),
                            ),
                            _Stepper(
                              value: _servings,
                              label: '${_fmt(_servings)} × ${r.serving}',
                              onChanged: (v) => setState(() => _servings = v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: MacroPills(
                            key: ValueKey(_servings),
                            kcal: total.kcal,
                            protein: total.protein,
                            carb: total.carb,
                            fat: total.fat,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TkButton(
                          label: _logged
                              ? 'Đã ghi vào nhật ký'
                              : 'Ghi vào nhật ký',
                          tone: TkButtonTone.green,
                          icon:
                              _logged ? Icons.check_rounded : Icons.add_rounded,
                          onTap: _logged ? null : () => _log(dish),
                        ),
                        const SizedBox(height: 24),
                        Text('NGUYÊN LIỆU', style: Tk.eyebrow()),
                        const SizedBox(height: 8),
                        for (final (i, it) in r.ingredients.indexed)
                          if (ctx.db.foods[it.foodId] case final f?)
                            FadeSlideIn(
                              index: i,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => showFoodDetail(context, f, ctx,
                                    mealLabel: 'xem'),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      FoodImage(food: f, size: 44, radius: 12),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(f.name,
                                            style: Tk.text(15,
                                                weight: FontWeight.w700)),
                                      ),
                                      Text(
                                          '${(it.grams * _servings).round()} g',
                                          style:
                                              Tk.text(14.5, color: Tk.inkSoft)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        const SizedBox(height: 20),
                        Text('CÁCH LÀM', style: Tk.eyebrow()),
                        const SizedBox(height: 8),
                        for (final (i, s) in r.steps.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 13,
                                  backgroundColor: Tk.primarySoft,
                                  child: Text('${i + 1}',
                                      style: Tk.text(13, color: Tk.primary)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(s,
                                      style: Tk.text(15,
                                          weight: FontWeight.w600,
                                          height: 1.45)),
                                ),
                              ],
                            ),
                          ),
                        if (dish.micro.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          MicroTable(food: dish, grams: r.grams * _servings),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          r.custom
                              ? 'Công thức của bạn. Dinh dưỡng cộng từ nguyên liệu đã chọn.'
                              : 'Dinh dưỡng cộng từ nguyên liệu sống theo Bảng thành phần thực phẩm Việt Nam (Viện Dinh dưỡng, 2007), chưa trừ hao hụt khi nấu. Nước dùng hầm xương chưa tính.',
                          style: Tk.text(12,
                              weight: FontWeight.w600,
                              color: Tk.inkMuted,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String _fmt(double v) => v == v.roundToDouble()
    ? '${v.round()}'
    : v.toStringAsFixed(1).replaceAll('.', ',');

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Color.lerp(color, Colors.white, 0.88),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text,
          style: Tk.text(12, color: Color.lerp(color, Colors.black, 0.25)!)),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper(
      {required this.value, required this.label, required this.onChanged});

  final double value;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tk.surfaceSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Bớt',
            visualDensity: VisualDensity.compact,
            onPressed: value > 0.5 ? () => onChanged(value - 0.5) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Text(label, style: Tk.text(14.5, weight: FontWeight.w800)),
          IconButton(
            tooltip: 'Thêm',
            visualDensity: VisualDensity.compact,
            onPressed: value < 5 ? () => onChanged(value + 0.5) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class MicroTable extends StatefulWidget {
  const MicroTable({super.key, required this.food, required this.grams});

  final Food food;
  final double grams;

  @override
  State<MicroTable> createState() => _MicroTableState();
}

class _MicroTableState extends State<MicroTable> {
  bool _open = false;

  String _num(double v) => v >= 100
      ? v.round().toString()
      : v >= 10
          ? v.toStringAsFixed(1)
          : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final e in microLabels.entries)
        if (widget.food.micro[e.key] case final v?)
          (e.value.$1, v * widget.grams / 100, e.value.$2),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: Tk.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Vitamin & khoáng chất',
                          style: Tk.text(15, weight: FontWeight.w800)),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(Icons.expand_more_rounded),
                    ),
                  ],
                ),
              ),
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  children: [
                    for (final (label, v, unit) in entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(label,
                                    style:
                                        Tk.text(14, weight: FontWeight.w600))),
                            Text('${_num(v)} $unit', style: Tk.text(14)),
                          ],
                        ),
                      ),
                    Text(
                        'Theo Bảng thành phần thực phẩm Việt Nam 2007. Chất không có số liệu được bỏ qua.',
                        style: Tk.text(11.5,
                            weight: FontWeight.w600, color: Tk.inkMuted)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
