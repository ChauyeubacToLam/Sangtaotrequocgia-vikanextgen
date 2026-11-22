import 'package:flutter/material.dart';

import '../../nutrition/food_db.dart';
import '../../widgets/tk/tk.dart';

class FoodImage extends StatelessWidget {
  const FoodImage({
    super.key,
    required this.food,
    this.size = 56,
    this.radius = 16,
    this.heroTag,
    this.width,
    this.height,
  });

  final Food food;
  final double size;
  final double radius;
  final Object? heroTag;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    Widget child = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: w,
        height: h,
        child: Image.asset(
          food.image,
          fit: BoxFit.cover,
          cacheWidth: w.isFinite ? (w * dpr).round().clamp(48, 900) : 512,
          excludeFromSemantics: true,
          frameBuilder: (context, child, frame, sync) => sync
              ? child
              : AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  child: child,
                ),
          errorBuilder: (_, __, ___) => FoodPlaceholder(food: food, size: h),
        ),
      ),
    );
    final tag = heroTag;
    if (tag != null) child = Hero(tag: tag, child: child);
    return child;
  }
}

class FoodPlaceholder extends StatelessWidget {
  const FoodPlaceholder({super.key, required this.food, required this.size});

  final Food food;
  final double size;

  @override
  Widget build(BuildContext context) {
    final g = food.groupInfo;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(g.color, Colors.white, 0.78)!,
            Color.lerp(g.color, Colors.white, 0.55)!,
          ],
        ),
      ),
      child: Center(
        child: Icon(g.icon,
            size: (size * 0.42).clamp(18, 72),
            color: Color.lerp(g.color, Colors.black, 0.15)),
      ),
    );
  }
}

class MenuCollage extends StatelessWidget {
  const MenuCollage({
    super.key,
    required this.foods,
    this.height = 120,
    this.radius = 18,
  });

  final List<Food> foods;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final main =
        foods.where((f) => f.id != 'com_te' && f.id != 'bun_tuoi').toList();
    final shown = (main.isEmpty ? foods : main).take(3).toList();
    if (shown.isEmpty) return SizedBox(height: height);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: FoodImage(
                  food: shown.first,
                  height: height,
                  width: double.infinity,
                  radius: 0),
            ),
            if (shown.length > 1) ...[
              const SizedBox(width: 2),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 1; i < shown.length; i++) ...[
                      if (i > 1) const SizedBox(height: 2),
                      Expanded(
                        child: FoodImage(
                          food: shown[i],
                          width: double.infinity,
                          height: double.infinity,
                          radius: 0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MacroPills extends StatelessWidget {
  const MacroPills({
    super.key,
    required this.kcal,
    required this.protein,
    required this.carb,
    required this.fat,
    this.dense = false,
  });

  final double kcal;
  final double protein;
  final double carb;
  final double fat;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    Widget pill(String text, Color color) => Container(
          padding: EdgeInsets.symmetric(
              horizontal: dense ? 7 : 9, vertical: dense ? 3 : 4),
          decoration: BoxDecoration(
            color: Color.lerp(color, Colors.white, 0.86),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(text,
              style: Tk.text(dense ? 11 : 12,
                  weight: FontWeight.w800,
                  color: Color.lerp(color, Colors.black, 0.35)!)),
        );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        pill('${kcal.round()} kcal', Tk.orange),
        pill('Đạm ${protein.round()}g', Tk.red),
        pill('Bột ${carb.round()}g', const Color(0xFFE5B83A)),
        pill('Béo ${fat.round()}g', Tk.primary),
      ],
    );
  }
}

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + 40 * index.clamp(0, 8)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
      ),
      child: child,
    );
  }
}
