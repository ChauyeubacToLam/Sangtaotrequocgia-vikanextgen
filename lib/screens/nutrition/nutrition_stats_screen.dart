import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../nutrition/nutrition_context.dart';
import '../../nutrition/nutrition_store.dart';
import '../../widgets/tk/tk.dart';
import 'nutrition_screen.dart';

class _DayStat {
  const _DayStat(this.day, this.kcal, this.protein, this.water, this.steps);

  final DateTime day;
  final double kcal;
  final double protein;
  final int water;
  final int steps;
}

class NutritionStatsScreen extends StatefulWidget {
  const NutritionStatsScreen({super.key, required this.ctx});

  final NutritionContext ctx;

  @override
  State<NutritionStatsScreen> createState() => _NutritionStatsScreenState();
}

class _NutritionStatsScreenState extends State<NutritionStatsScreen> {
  int _range = 0;
  List<_DayStat> _days = const [];
  List<WeightPoint> _weights = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final n = _range == 0 ? 7 : 30;
    final today = DateTime.now();
    final out = <_DayStat>[];
    for (var i = n - 1; i >= 0; i--) {
      final d = DateTime(today.year, today.month, today.day - i);
      final log = await NutritionStore.instance.loadDay(d);
      final m = entriesTotal(widget.ctx.db, log.entries);
      final steps = await NutritionStore.instance.stepsOn(d) ?? 0;
      out.add(_DayStat(d, m.kcal, m.protein, log.waterMl, steps));
    }
    final weights = await NutritionStore.instance.weights();
    if (mounted) {
      setState(() {
        _days = out;
        _weights = weights;
      });
    }
  }

  double _avg(Iterable<double> v) {
    final logged = v.where((x) => x > 0).toList();
    return logged.isEmpty ? 0 : logged.reduce((a, b) => a + b) / logged.length;
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.ctx.daily.macros;
    final label = _range == 0 ? '7 ngày' : '30 ngày';
    return Scaffold(
      backgroundColor: Tk.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Tk.surfaceSoft,
        surfaceTintColor: Colors.transparent,
        title: Text('Thống kê', style: Tk.text(20, weight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          TkSegmented(
            labels: const ['7 ngày', '30 ngày'],
            selected: _range,
            onChanged: (i) {
              setState(() => _range = i);
              _load();
            },
          ),
          const SizedBox(height: 14),
          _ChartCard(
            title: 'Năng lượng nạp vào',
            subtitle:
                'TB ${_avg(_days.map((d) => d.kcal)).round()} kcal/ngày · mục tiêu ${target.kcal.round()}',
            values: [for (final d in _days) d.kcal],
            days: [for (final d in _days) d.day],
            goal: target.kcal,
            color: Tk.green,
            overColor: Tk.orange,
          ),
          _ChartCard(
            title: 'Chất đạm',
            subtitle:
                'TB ${_avg(_days.map((d) => d.protein)).round()} g/ngày · mục tiêu ${target.protein.round()} g',
            values: [for (final d in _days) d.protein],
            days: [for (final d in _days) d.day],
            goal: target.protein,
            color: Tk.red,
          ),
          _ChartCard(
            title: 'Uống nước',
            subtitle:
                'TB ${_avg(_days.map((d) => d.water.toDouble())).round()} ml/ngày · mục tiêu ${widget.ctx.settings.waterGoalMl} ml',
            values: [for (final d in _days) d.water.toDouble()],
            days: [for (final d in _days) d.day],
            goal: widget.ctx.settings.waterGoalMl.toDouble(),
            color: Tk.primary,
          ),
          _ChartCard(
            title: 'Bước chân',
            subtitle:
                'TB ${_avg(_days.map((d) => d.steps.toDouble())).round()} bước/ngày',
            values: [for (final d in _days) d.steps.toDouble()],
            days: [for (final d in _days) d.day],
            goal: widget.ctx.settings.stepGoal.toDouble(),
            color: const Color(0xFF7D6BFF),
          ),
          TkCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Cân nặng', style: Tk.text(17, weight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  _weights.isEmpty
                      ? 'Chưa ghi cân nặng.'
                      : 'Gần nhất ${_weights.last.kg.toStringAsFixed(1)} kg · ${_weights.length} lần ghi',
                  style:
                      Tk.text(13, weight: FontWeight.w700, color: Tk.inkSoft),
                ),
                if (_weights.length >= 2) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (_, t, __) => CustomPaint(
                        painter:
                            _LinePainter([for (final w in _weights) w.kg], t),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Nhu cầu: BMR Mifflin-St Jeor ${widget.ctx.daily.bmr.round()} kcal × hệ số vận động 1,4 = ${widget.ctx.daily.tdee.round()} kcal, rồi điều chỉnh theo mục tiêu. '
            'Số đo đang dùng: ${widget.ctx.body.weightKg.toStringAsFixed(1)} kg, ${widget.ctx.body.heightCm.round()} cm, ${widget.ctx.body.age} tuổi. Thống kê $label.',
            style: Tk.text(12,
                weight: FontWeight.w600, color: Tk.inkSoft, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.values,
    required this.days,
    required this.goal,
    required this.color,
    this.overColor,
  });

  final String title;
  final String subtitle;
  final List<double> values;
  final List<DateTime> days;
  final double goal;
  final Color color;
  final Color? overColor;

  @override
  Widget build(BuildContext context) {
    final maxV = math.max(goal, values.isEmpty ? 0 : values.reduce(math.max));
    final dense = values.length > 10;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TkCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Tk.text(17, weight: FontWeight.w900)),
            Text(subtitle,
                style:
                    Tk.text(12.5, weight: FontWeight.w700, color: Tk.inkSoft)),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: Stack(
                children: [
                  if (goal > 0 && maxV > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 18 + 100 * goal / maxV,
                      child: Container(height: 1.5, color: Tk.line),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < values.length; i++)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                    begin: 0,
                                    end: maxV <= 0 ? 0 : values[i] / maxV),
                                duration: Duration(
                                    milliseconds:
                                        380 + (dense ? i * 12 : i * 50)),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, __) => Container(
                                  height: 100 * v,
                                  margin: EdgeInsets.symmetric(
                                      horizontal: dense ? 1.5 : 6),
                                  decoration: BoxDecoration(
                                    color: overColor != null && values[i] > goal
                                        ? overColor
                                        : color,
                                    borderRadius:
                                        BorderRadius.circular(dense ? 3 : 7),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 18,
                                child: dense && i % 5 != 4
                                    ? null
                                    : Text('${days[i].day}',
                                        style:
                                            Tk.text(10.5, color: Tk.inkSoft)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.t);

  final List<double> values;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce(math.min) - 0.5;
    final hi = values.reduce(math.max) + 0.5;
    Offset at(int i) => Offset(
          size.width * i / (values.length - 1),
          size.height - (values[i] - lo) / (hi - lo) * size.height,
        );
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..color = Tk.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < values.length; i++) {
      if (i / (values.length - 1) > t) break;
      canvas.drawCircle(at(i), 4, Paint()..color = Tk.orange);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.t != t || old.values != values;
}
