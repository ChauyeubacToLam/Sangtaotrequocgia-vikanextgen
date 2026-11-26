import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../nutrition/food_db.dart';
import '../../nutrition/nutrition_context.dart';
import '../../nutrition/nutrition_store.dart';
import '../../nutrition/nutrition_sync.dart';
import '../../nutrition/nutrition_targets.dart';
import '../../nutrition/step_counter.dart';
import '../../services/workout_reminders.dart';
import '../../widgets/tk/tk.dart';
import 'create_dish_screen.dart';
import 'fasting_screen.dart';
import 'food_search_screen.dart';
import 'food_visuals.dart';
import 'nutrition_sources_sheet.dart';
import 'nutrition_stats_screen.dart';
import 'post_workout_card.dart';
import 'quick_add_sheet.dart';
import 'recipe_screen.dart';

const _weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

Macros entriesTotal(FoodDb db, Iterable<DiaryEntry> entries) {
  var total = Macros.zero;
  for (final e in entries) {
    final f = db.foods[e.foodId];
    if (f != null) total = total + f.forGrams(e.grams);
  }
  return total;
}

Future<void> logMenu(BuildContext context, RegionalMenu m, DateTime day) async {
  final now = DateTime.now();
  for (var i = 0; i < m.items.length; i++) {
    await NutritionStore.instance.addEntry(
      day,
      DiaryEntry(
        foodId: m.items[i].foodId,
        grams: m.items[i].grams,
        meal: mealSlotForHour(now.hour),
        at: now.add(Duration(milliseconds: i)),
      ),
    );
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã ghi "${m.name}" vào nhật ký')),
    );
  }
}

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key, this.bottomPadding = 0});

  final double bottomPadding;

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  DateTime _day = _dateOnly(DateTime.now());
  NutritionContext? _ctx;
  DayLog _log = DayLog();
  List<DayLog> _week = const [];
  FastingState _fast = const FastingState();
  List<WeightPoint> _weights = const [];
  int? _steps;
  StreamSubscription<int>? _stepSub;
  int _calView = 0;
  int _region = 0;
  MealSlot _menuMeal = mealSlotForHour(DateTime.now().hour);
  int _menuLimit = 6;
  MealSlot? _openMeal;
  bool _waterRemind = false;
  String? _recipeFilter;

  bool get _isToday => _day == _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _reload();
    NutritionSync.instance.revision.addListener(_onSynced);
    _listenSteps();
    NutritionStore.instance.waterReminderOn().then((on) {
      if (!mounted) return;
      setState(() => _waterRemind = on);
      if (on) WorkoutReminders.refreshWater(on: true);
    });
  }

  void _listenSteps() {
    _stepSub?.cancel();
    _stepSub = StepCounter.instance.todaySteps().listen(
      (s) {
        if (mounted) setState(() => _steps = s);
      },
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    NutritionSync.instance.revision.removeListener(_onSynced);
    _stepSub?.cancel();
    super.dispose();
  }

  void _onSynced() {
    if (mounted) _reload();
  }

  Future<void> _reload() async {
    final ctx = await NutritionContext.load();
    final log = await NutritionStore.instance.loadDay(_day);
    final week = [
      for (var i = 6; i >= 0; i--)
        await NutritionStore.instance.loadDay(_day.subtract(Duration(days: i))),
    ];
    final fast = await NutritionStore.instance.fasting();
    final weights = await NutritionStore.instance.weights();
    if (!mounted) return;
    setState(() {
      _ctx = ctx;
      _log = log;
      _week = week;
      _fast = fast;
      _weights = weights;
    });
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    await _reload();
  }

  Future<void> _quickAdd() async {
    await showQuickAddSheet(context, day: _day, onChanged: _reload);
    await _reload();
  }

  Future<void> _addWater(int ml) async {
    final log = await NutritionStore.instance
        .update(_day, (l) => l.waterMl = math.max(0, l.waterMl + ml));
    if (mounted) setState(() => _log = log);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      helpText: 'Chọn ngày',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked == null) return;
    setState(() => _day = _dateOnly(picked));
    await _reload();
  }

  Future<void> _editEntry(DiaryEntry e) async {
    final ctx = _ctx;
    final f = ctx?.db.foods[e.foodId];
    if (ctx == null || f == null) return;
    final pick = await showFoodDetail(
      context,
      f,
      ctx,
      mealLabel: e.meal.label,
      meal: e.meal,
      initialGrams: e.grams,
      editing: true,
      onDelete: () async {
        await NutritionStore.instance.removeEntry(_day, e);
        await _reload();
      },
    );
    if (pick == null) return;
    await NutritionStore.instance.replaceEntry(
      _day,
      e,
      DiaryEntry(
          foodId: e.foodId, grams: pick.grams, meal: pick.meal, at: e.at),
    );
    await _reload();
  }

  Future<void> _copyYesterday(MealSlot meal) async {
    final n = await NutritionStore.instance
        .copyMeal(_day.subtract(const Duration(days: 1)), _day, meal);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(n == 0
          ? 'Hôm qua chưa ghi bữa ${meal.label.toLowerCase()}.'
          : 'Đã chép $n món từ bữa ${meal.label.toLowerCase()} hôm qua.'),
    ));
    await _reload();
  }

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _log.note);
    final text = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Ghi chú', style: Tk.text(20, weight: FontWeight.w900)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'Hôm nay ăn uống thế nào?'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          TextButton(
              onPressed: () => Navigator.pop(c, controller.text),
              child: const Text('Lưu')),
        ],
      ),
    );
    if (text == null) return;
    final log =
        await NutritionStore.instance.update(_day, (l) => l.note = text.trim());
    if (mounted) setState(() => _log = log);
  }

  Future<void> _logWeight() async {
    final kg = await showWeightDialog(
        context, _weights.isEmpty ? null : _weights.last.kg);
    if (kg == null) return;
    await NutritionStore.instance.logWeight(_day, kg);
    await _reload();
  }

  Future<void> _waterSettings() async {
    final ctx = _ctx;
    if (ctx == null) return;
    var remind = _waterRemind;
    var goal = ctx.settings.waterGoalMl;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Tk.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Uống nước', style: Tk.text(22, weight: FontWeight.w900)),
                const SizedBox(height: 12),
                Text('MỤC TIÊU MỖI NGÀY', style: Tk.eyebrow()),
                const SizedBox(height: 8),
                TkSegmented(
                  labels: const ['1.500 ml', '2.000 ml', '2.500 ml'],
                  selected: [1500, 2000, 2500].indexOf(goal).clamp(0, 2),
                  onChanged: (i) =>
                      setSheet(() => goal = [1500, 2000, 2500][i]),
                ),
                const SizedBox(height: 6),
                Text(
                  'EFSA (2010): tổng lượng nước nên vào mỗi ngày khoảng 2,0 lít với nữ và 2,5 lít với nam, trong đó khoảng 20% đến từ thức ăn.',
                  style: Tk.text(12,
                      weight: FontWeight.w600, color: Tk.inkSoft, height: 1.4),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: remind,
                  activeTrackColor: Tk.green,
                  title: Text('Nhắc uống nước',
                      style: Tk.text(16, weight: FontWeight.w800)),
                  subtitle: Text('Mỗi 2 tiếng, từ 9:00 đến 21:00',
                      style: Tk.text(13,
                          weight: FontWeight.w600, color: Tk.inkSoft)),
                  onChanged: (v) => setSheet(() => remind = v),
                ),
                const SizedBox(height: 8),
                TkButton(
                  label: 'Lưu',
                  onTap: () async {
                    await NutritionStore.instance
                        .saveSettings(ctx.settings.copyWith(waterGoalMl: goal));
                    await NutritionStore.instance.setWaterReminder(remind);
                    await WorkoutReminders.refreshWater(on: remind);
                    if (sheet.mounted) Navigator.of(sheet).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final on = await NutritionStore.instance.waterReminderOn();
    if (mounted) setState(() => _waterRemind = on);
    await _reload();
  }

  Future<void> _editSettings() async {
    final ctx = _ctx;
    if (ctx == null) return;
    final next = await showModalBottomSheet<NutritionSettings>(
      context: context,
      backgroundColor: Tk.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _SettingsSheet(initial: ctx.settings),
    );
    if (next == null) return;
    await NutritionStore.instance.saveSettings(next);
    await _reload();
  }

  String get _dayTitle {
    if (_isToday) return 'Hôm nay, ${_day.day} tháng ${_day.month}';
    final yesterday =
        _dateOnly(DateTime.now()).subtract(const Duration(days: 1));
    if (_day == yesterday) return 'Hôm qua, ${_day.day} tháng ${_day.month}';
    return '${_weekdays[_day.weekday - 1]}, ${_day.day} tháng ${_day.month}';
  }

  @override
  Widget build(BuildContext context) {
    final ctx = _ctx;
    if (ctx == null) {
      return const Center(child: CircularProgressIndicator(color: Tk.primary));
    }
    final eaten = entriesTotal(ctx.db, _log.entries);
    final target = ctx.daily.macros;
    final weekTotals = [for (final l in _week) entriesTotal(ctx.db, l.entries)];
    final loggedDays = weekTotals.where((m) => m.kcal > 0).toList();
    final weekAvg = loggedDays.isEmpty
        ? Macros.zero
        : loggedDays
            .fold(Macros.zero, (a, b) => a + b)
            .scale(1 / loggedDays.length);
    final regionMenus = ctx.db.menus
        .where((m) =>
            !m.custom &&
            (m.region == null || m.region == Region.values[_region]) &&
            m.servesAt(_menuMeal.name))
        .toList();
    final myMenus = ctx.db.menus.where((m) => m.custom).toList();
    return RefreshIndicator(
      color: Tk.primary,
      onRefresh: _reload,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 10, 16, widget.bottomPadding + 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dinh dưỡng',
                        style: Tk.text(28,
                            weight: FontWeight.w900, letterSpacing: -0.4)),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(_dayTitle,
                          key: ValueKey(_day),
                          style: Tk.text(14,
                              weight: FontWeight.w700, color: Tk.inkSoft)),
                    ),
                  ],
                ),
              ),
              _RoundIcon(Icons.calendar_month_rounded, 'Chọn ngày', _pickDate),
              _RoundIcon(Icons.insights_rounded, 'Thống kê',
                  () => _push(NutritionStatsScreen(ctx: ctx))),
              _RoundIcon(Icons.verified_outlined, 'Nguồn khoa học',
                  () => showNutritionSources(context, ctx.db)),
              const SizedBox(width: 4),
              Material(
                color: Tk.green,
                shape: const CircleBorder(),
                elevation: 2,
                shadowColor: Tk.greenLip,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _quickAdd,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child:
                        Icon(Icons.add_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DateStrip(
            selected: _day,
            onSelect: (d) {
              setState(() => _day = d);
              _reload();
            },
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            child: _CalorieCard(
              view: _calView,
              onView: (v) => setState(() => _calView = v),
              eaten: _calView == 0 ? eaten : weekAvg,
              target: target,
              burned: _calView == 0 ? _log.burnedKcal : 0,
              weekly: weekTotals,
              weekDays: [
                for (var i = 6; i >= 0; i--) _day.subtract(Duration(days: i))
              ],
              settings: ctx.settings,
              onSettings: _editSettings,
            ),
          ),
          if (_isToday) ...[
            const SizedBox(height: 14),
            FadeSlideIn(
                index: 1,
                child: PostWorkoutMealCard(compact: true, onLogged: _reload)),
          ],
          const SizedBox(height: 22),
          _SectionTitle('Nhật ký ăn uống'),
          const SizedBox(height: 10),
          for (final (i, m) in MealSlot.values.indexed)
            FadeSlideIn(
              index: i + 2,
              child: _MealCard(
                meal: m,
                db: ctx.db,
                entries: _log.entries.where((e) => e.meal == m).toList(),
                open: _openMeal == m,
                onToggle: () =>
                    setState(() => _openMeal = _openMeal == m ? null : m),
                onAdd: () => _push(FoodSearchScreen(day: _day, meal: m)),
                onEdit: _editEntry,
                onCopy: () => _copyYesterday(m),
              ),
            ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _Tracker(
                icon: Icons.water_drop_rounded,
                color: Tk.primary,
                title: 'Uống nước',
                value: '${_log.waterMl} ml',
                sub: _waterRemind
                    ? 'Đang bật nhắc · mục tiêu ${ctx.settings.waterGoalMl} ml'
                    : 'Mục tiêu ${ctx.settings.waterGoalMl} ml',
                progress: _log.waterMl / ctx.settings.waterGoalMl,
                action: '+250 ml',
                onAction: () => _addWater(250),
                onLongPress: () => _addWater(-250),
                onMore: _waterSettings,
              ),
              _Tracker(
                icon: Icons.directions_walk_rounded,
                color: Tk.green,
                title: 'Bước chân',
                value: _isToday ? (_steps == null ? '—' : '$_steps') : '—',
                sub: _steps == null && _isToday
                    ? 'Chạm để cho phép đếm bước'
                    : 'Mục tiêu ${ctx.settings.stepGoal}',
                progress: _isToday ? (_steps ?? 0) / ctx.settings.stepGoal : 0,
                onAction: () async {
                  await StepCounter.instance.requestPermission();
                  _listenSteps();
                },
              ),
              _Tracker(
                icon: Icons.monitor_weight_rounded,
                color: Tk.orange,
                title: 'Cân nặng',
                value: _weights.isEmpty
                    ? '${ctx.body.weightKg.toStringAsFixed(1)} kg'
                    : '${_weights.last.kg.toStringAsFixed(1)} kg',
                sub: _weights.length > 1
                    ? '${(_weights.last.kg - _weights.first.kg) >= 0 ? '+' : ''}${(_weights.last.kg - _weights.first.kg).toStringAsFixed(1)} kg từ lần đầu'
                    : 'Chạm để ghi cân nặng',
                progress: null,
                action: 'Ghi',
                onAction: _logWeight,
              ),
              _Tracker(
                icon: Icons.timer_rounded,
                color: Tk.red,
                title: 'Nhịn ăn',
                value: _fast.startedAt == null
                    ? 'Chưa bắt đầu'
                    : '${DateTime.now().difference(_fast.startedAt!).inHours} giờ',
                sub: 'Mục tiêu ${_fast.goalHours} giờ',
                progress: _fast.startedAt == null
                    ? 0
                    : DateTime.now().difference(_fast.startedAt!).inMinutes /
                        (_fast.goalHours * 60),
                onAction: () => _push(const FastingScreen()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _SectionTitle('Công thức món Việt')),
              TextButton.icon(
                onPressed: () => _push(const CreateDishScreen()),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo công thức'),
              ),
            ],
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in [
                  ...Region.values.map((r) => r.label),
                  ...FoodDb.recipeFilters,
                ])
                  if (ctx.db.recipes.any((r) => ctx.db.recipeMatches(r, f)))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f),
                        selected: _recipeFilter == f,
                        onSelected: (v) =>
                            setState(() => _recipeFilter = v ? f : null),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final shown = [
              for (final r in ctx.db.recipes.reversed)
                if (_recipeFilter == null ||
                    ctx.db.recipeMatches(r, _recipeFilter!))
                  r,
            ];
            return SizedBox(
              height: 214,
              child: ListView.separated(
                key: ValueKey(_recipeFilter),
                scrollDirection: Axis.horizontal,
                itemCount: shown.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final r = shown[i];
                  final dish = ctx.db.foods[r.id];
                  if (dish == null) return const SizedBox.shrink();
                  final m = dish.forGrams(r.grams);
                  return FadeSlideIn(
                    index: i,
                    child: GestureDetector(
                      onTap: () async {
                        await openRecipe(context, r, day: _day);
                        await _reload();
                      },
                      child: SizedBox(
                        width: 158,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                FoodImage(
                                  food: dish,
                                  width: 158,
                                  height: 140,
                                  radius: 20,
                                  heroTag: 'recipe_${r.id}',
                                ),
                                if (r.region != null || r.custom)
                                  Positioned(
                                    left: 8,
                                    top: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.92),
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                          r.custom
                                              ? 'Của tôi'
                                              : r.region!.label,
                                          style: Tk.text(11, color: Tk.ink)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(r.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Tk.text(14.5,
                                    weight: FontWeight.w900, height: 1.2)),
                            Text(
                                '${m.kcal.round()} kcal · ${m.protein.round()} g đạm',
                                style: Tk.text(12,
                                    weight: FontWeight.w700,
                                    color: Tk.inkSoft)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _SectionTitle('Thực đơn mẫu')),
              TextButton.icon(
                onPressed: () => _push(const CreateDishScreen(menu: true)),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo thực đơn'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TkSegmented(
            labels: const ['Bắc', 'Trung', 'Nam'],
            selected: _region,
            onChanged: (i) => setState(() {
              _region = i;
              _menuLimit = 6;
            }),
          ),
          const SizedBox(height: 8),
          TkSegmented(
            labels: const ['Sáng', 'Trưa', 'Tối', 'Ăn khuya'],
            selected: _menuMeal.index,
            onChanged: (i) => setState(() {
              _menuMeal = MealSlot.values[i];
              _menuLimit = 6;
            }),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Column(
              key: ValueKey((_region, _menuMeal)),
              children: [
                for (final (i, m) in regionMenus.take(_menuLimit).indexed)
                  FadeSlideIn(
                    index: i,
                    child: _MenuCard(
                        menu: m,
                        db: ctx.db,
                        onLog: () async {
                          await logMenu(context, m, _day);
                          await _reload();
                        }),
                  ),
                if (regionMenus.length > _menuLimit)
                  Semantics(
                    button: true,
                    child: TkCard(
                      radius: 16,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      onTap: () => setState(() => _menuLimit += 6),
                      child: Text('Xem thêm',
                          style: Tk.text(15,
                              weight: FontWeight.w800, color: Tk.primary)),
                    ),
                  ),
              ],
            ),
          ),
          if (myMenus.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SectionTitle('Thực đơn của tôi'),
            const SizedBox(height: 10),
            for (final m in myMenus)
              _MenuCard(
                  menu: m,
                  db: ctx.db,
                  onLog: () async {
                    await logMenu(context, m, _day);
                    await _reload();
                  }),
          ],
          const SizedBox(height: 14),
          TkCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Tk.greenSoft,
                  child: Icon(Icons.fitness_center_rounded, color: Tk.greenInk),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nhật ký vận động',
                          style: Tk.text(16, weight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        _log.activities.isEmpty
                            ? 'Chưa có buổi tập nào. Buổi tập với Vika sẽ tự ghi vào đây.'
                            : '${_log.activities.length} buổi · ${_log.burnedKcal.round()} kcal\n${_log.activities.join('\n')}',
                        style: Tk.text(13.5,
                            weight: FontWeight.w700,
                            color: Tk.inkSoft,
                            height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TkCard(
            onTap: _editNote,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Tk.primarySoft,
                  child: Icon(Icons.edit_note_rounded, color: Tk.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _log.note.isEmpty ? 'Ghi chú hôm nay' : _log.note,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Tk.text(15,
                        weight: FontWeight.w700,
                        color: _log.note.isEmpty ? Tk.inkSoft : Tk.ink),
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

Future<double?> showWeightDialog(BuildContext context, double? current) async {
  final controller =
      TextEditingController(text: current?.toStringAsFixed(1) ?? '');
  final text = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title:
          Text('Cân nặng hôm nay', style: Tk.text(20, weight: FontWeight.w900)),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(suffixText: 'kg'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
        TextButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('Lưu')),
      ],
    ),
  );
  final kg = double.tryParse((text ?? '').replaceAll(',', '.'));
  if (kg == null || kg < 25 || kg > 300) return null;
  return kg;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: Tk.text(19, weight: FontWeight.w900, letterSpacing: -0.2));
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon, this.tooltip, this.onTap);

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(backgroundColor: Tk.surfaceSoft),
      icon: Icon(icon, color: Tk.ink, size: 22),
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.selected, required this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final end = selected.isAfter(today.subtract(const Duration(days: 6)))
        ? today
        : selected.add(const Duration(days: 3));
    final days = [for (var i = 6; i >= 0; i--) end.subtract(Duration(days: i))];
    return Row(
      children: [
        for (final d in days)
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: d == selected ? Tk.green : Tk.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: d == selected ? Tk.green : Tk.line, width: 2),
                  boxShadow: d == selected
                      ? const [
                          BoxShadow(color: Tk.greenLip, offset: Offset(0, 3))
                        ]
                      : const [],
                ),
                child: Column(
                  children: [
                    Text(_weekdays[d.weekday - 1],
                        style: Tk.text(11.5,
                            color: d == selected ? Colors.white : Tk.inkSoft)),
                    Text('${d.day}',
                        style: Tk.text(17,
                            weight: FontWeight.w900,
                            color: d == selected ? Colors.white : Tk.ink)),
                    if (d == today)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: d == selected ? Colors.white : Tk.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalorieCard extends StatelessWidget {
  const _CalorieCard({
    required this.view,
    required this.onView,
    required this.eaten,
    required this.target,
    required this.burned,
    required this.weekly,
    required this.weekDays,
    required this.settings,
    required this.onSettings,
  });

  final int view;
  final ValueChanged<int> onView;
  final Macros eaten;
  final Macros target;
  final double burned;
  final List<Macros> weekly;
  final List<DateTime> weekDays;
  final NutritionSettings settings;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final remaining = target.kcal - eaten.kcal + burned;
    final goal = switch (settings.goal) {
      NutritionGoal.lose => 'Giảm cân',
      NutritionGoal.maintain => 'Giữ cân',
      NutritionGoal.gain => 'Tăng cân',
    };
    final mode =
        settings.mode == DietMode.highProtein ? 'Giàu đạm' : 'Cân bằng';
    final ratio =
        target.kcal <= 0 ? 0.0 : (eaten.kcal / target.kcal).clamp(0.0, 1.0);
    final maxWeek =
        [target.kcal, for (final m in weekly) m.kcal].reduce(math.max);
    return TkCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Calo & Dinh dưỡng',
                    style: Tk.text(18, weight: FontWeight.w900)),
              ),
              SizedBox(
                width: 150,
                child: TkSegmented(
                  labels: const ['Ngày', 'Tuần'],
                  selected: view,
                  onChanged: onView,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            child: view == 0
                ? Row(
                    key: const ValueKey('day'),
                    children: [
                      SizedBox(
                        width: 132,
                        height: 132,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: ratio),
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, __) =>
                                    CircularProgressIndicator(
                                  value: v,
                                  strokeWidth: 13,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor: Tk.lineSoft,
                                  color: eaten.kcal > target.kcal + burned
                                      ? Tk.red
                                      : Tk.green,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Đã nạp',
                                    style: Tk.text(12.5, color: Tk.inkSoft)),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: eaten.kcal),
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, v, __) => Text('${v.round()}',
                                      style: Tk.text(30,
                                          weight: FontWeight.w900,
                                          color: Tk.orangeInk)),
                                ),
                                Text('kcal',
                                    style: Tk.text(12, color: Tk.inkSoft)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _KcalLine(Icons.bolt_rounded, Tk.green, 'Cần nạp',
                                target.kcal),
                            _KcalLine(Icons.restaurant_rounded, Tk.primary,
                                'Còn lại', remaining),
                            _KcalLine(Icons.local_fire_department_rounded,
                                Tk.red, 'Tiêu hao', burned),
                          ],
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    key: const ValueKey('week'),
                    height: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            'Trung bình ${eaten.kcal.round()} kcal/ngày (những ngày có ghi)',
                            style: Tk.text(13,
                                weight: FontWeight.w700, color: Tk.inkSoft)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (var i = 0; i < weekly.length; i++)
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TweenAnimationBuilder<double>(
                                        tween: Tween(
                                            begin: 0,
                                            end: maxWeek <= 0
                                                ? 0
                                                : weekly[i].kcal / maxWeek),
                                        duration: Duration(
                                            milliseconds: 400 + i * 60),
                                        curve: Curves.easeOutCubic,
                                        builder: (_, v, __) => Container(
                                          height: 92 * v,
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 6),
                                          decoration: BoxDecoration(
                                            color: weekly[i].kcal > target.kcal
                                                ? Tk.orange
                                                : Tk.green,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(_weekdays[weekDays[i].weekday - 1],
                                          style:
                                              Tk.text(11, color: Tk.inkSoft)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MacroBar(
                  'Tinh bột', eaten.carb, target.carb, const Color(0xFFE5B83A)),
              const SizedBox(width: 10),
              _MacroBar('Chất đạm', eaten.protein, target.protein, Tk.red),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MacroBar('Chất béo', eaten.fat, target.fat, Tk.primary),
              const SizedBox(width: 10),
              _MacroBar('Chất xơ', eaten.fiber, target.fiber, Tk.green),
            ],
          ),
          TextButton(
            onPressed: onSettings,
            child: Text('Mục tiêu: $goal · Chế độ: $mode  ▾',
                style: Tk.text(14, color: Tk.greenInk)),
          ),
        ],
      ),
    );
  }
}

class _KcalLine extends StatelessWidget {
  const _KcalLine(this.icon, this.color, this.label, this.value);

  final IconData icon;
  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Color.lerp(color, Colors.white, 0.86),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      Tk.text(12, weight: FontWeight.w700, color: Tk.inkSoft)),
              Text('${value.round()}',
                  style: Tk.text(18, weight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar(this.label, this.value, this.goal, this.color);

  final String label;
  final double value;
  final double goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Tk.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(label,
                        style: Tk.text(13, weight: FontWeight.w700))),
                Text('${value.round()}/${goal.round()}g', style: Tk.text(13)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                    begin: 0,
                    end: goal <= 0 ? 0 : (value / goal).clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 7,
                  color: color,
                  backgroundColor: Tk.line,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.db,
    required this.entries,
    required this.open,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onCopy,
  });

  final MealSlot meal;
  final FoodDb db;
  final List<DiaryEntry> entries;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final ValueChanged<DiaryEntry> onEdit;
  final VoidCallback onCopy;

  static const _icons = {
    MealSlot.breakfast: (Icons.free_breakfast_rounded, Color(0xFFFFB547)),
    MealSlot.lunch: (Icons.rice_bowl_rounded, Color(0xFF3CC35A)),
    MealSlot.dinner: (Icons.dinner_dining_rounded, Color(0xFF7D6BFF)),
    MealSlot.snack: (Icons.icecream_rounded, Color(0xFFFF7AB6)),
  };

  @override
  Widget build(BuildContext context) {
    final total = entriesTotal(db, entries);
    final (icon, color) = _icons[meal]!;
    final foods = [
      for (final e in entries)
        if (db.foods[e.foodId] case final f?) f,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TkCard(
        padding: EdgeInsets.zero,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: entries.isEmpty ? onAdd : onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Color.lerp(color, Colors.white, 0.82),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(icon,
                            color: Color.lerp(color, Colors.black, 0.2)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bữa ${meal.label.toLowerCase()}',
                                style: Tk.text(16, weight: FontWeight.w900)),
                            Text(
                              entries.isEmpty
                                  ? 'Chưa ghi món nào'
                                  : '${entries.length} món · ${total.kcal.round()} kcal · ${total.protein.round()} g đạm',
                              style: Tk.text(12.5,
                                  weight: FontWeight.w700, color: Tk.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      if (foods.isNotEmpty && !open)
                        SizedBox(
                          width: 26.0 * math.min(foods.length, 3) + 12,
                          height: 38,
                          child: Stack(
                            children: [
                              for (var i = 0;
                                  i < math.min(foods.length, 3);
                                  i++)
                                Positioned(
                                  left: i * 24.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: FoodImage(
                                        food: foods[i], size: 34, radius: 17),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      IconButton(
                        tooltip: 'Thêm món',
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_circle_rounded,
                            color: Tk.green, size: 32),
                      ),
                    ],
                  ),
                ),
              ),
              if (open) ...[
                const Divider(height: 1, color: Tk.lineSoft),
                for (final e in entries)
                  if (db.foods[e.foodId] case final f?)
                    InkWell(
                      onTap: () => onEdit(e),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                        child: Row(
                          children: [
                            FoodImage(food: f, size: 42, radius: 12),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f.name,
                                      style: Tk.text(14.5,
                                          weight: FontWeight.w800)),
                                  Text(f.amountLabel(e.grams),
                                      style: Tk.text(12,
                                          weight: FontWeight.w700,
                                          color: Tk.inkSoft)),
                                ],
                              ),
                            ),
                            Text('${f.forGrams(e.grams).kcal.round()} kcal',
                                style: Tk.text(13.5, color: Tk.orangeInk)),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded,
                                color: Tk.inkMuted),
                          ],
                        ),
                      ),
                    ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: onCopy,
                        icon: const Icon(Icons.content_copy_rounded, size: 18),
                        label: const Text('Chép bữa hôm qua'),
                      ),
                    ],
                  ),
                ),
              ],
              if (!open && entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onCopy,
                      icon: const Icon(Icons.content_copy_rounded, size: 16),
                      label: const Text('Chép bữa hôm qua'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tracker extends StatelessWidget {
  const _Tracker({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.sub,
    required this.progress,
    required this.onAction,
    this.action,
    this.onLongPress,
    this.onMore,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String sub;
  final double? progress;
  final String? action;
  final VoidCallback onAction;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: TkCard(
        onTap: onAction,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Color.lerp(color, Colors.white, 0.85),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        style: Tk.text(14, weight: FontWeight.w800))),
                if (onMore != null)
                  GestureDetector(
                    onTap: onMore,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child:
                          Icon(Icons.tune_rounded, size: 20, color: Tk.inkSoft),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.3), end: Offset.zero)
                      .animate(a),
                  child: c,
                ),
              ),
              child: Text(value,
                  key: ValueKey(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tk.text(20, weight: FontWeight.w900)),
            ),
            Text(sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    Tk.text(11.5, weight: FontWeight.w700, color: Tk.inkSoft)),
            const SizedBox(height: 6),
            Row(
              children: [
                if (progress != null)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress!.clamp(0.0, 1.0)),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 6,
                          color: color,
                          backgroundColor: Tk.lineSoft,
                        ),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (action != null) ...[
                  const SizedBox(width: 8),
                  Text(action!, style: Tk.text(12.5, color: color)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.menu, required this.db, required this.onLog});

  final RegionalMenu menu;
  final FoodDb db;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final foods = [
      for (final it in menu.items)
        if (db.foods[it.foodId] case final f?) f,
    ];
    final total = menu.items.fold(
      Macros.zero,
      (a, it) => a + (db.foods[it.foodId]?.forGrams(it.grams) ?? Macros.zero),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TkCard(
        padding: const EdgeInsets.all(10),
        onTap: () => _showMenu(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MenuCollage(foods: foods, height: 132),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(menu.name,
                            style: Tk.text(16,
                                weight: FontWeight.w900, height: 1.2)),
                        const SizedBox(height: 6),
                        MacroPills(
                          kcal: total.kcal,
                          protein: total.protein,
                          carb: total.carb,
                          fat: total.fat,
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ghi vào nhật ký',
                    onPressed: onLog,
                    icon: const Icon(Icons.add_circle_rounded,
                        color: Tk.green, size: 34),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Tk.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(menu.name, style: Tk.text(22, weight: FontWeight.w900)),
              const SizedBox(height: 12),
              for (final it in menu.items)
                if (db.foods[it.foodId] case final f?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        FoodImage(food: f, size: 52, radius: 14),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.name,
                                  style: Tk.text(15, weight: FontWeight.w800)),
                              Text(
                                f.isDish && f.defaultPortion?.grams == it.grams
                                    ? f.defaultPortion!.label
                                    : f.amountLabel(it.grams),
                                style: Tk.text(12.5,
                                    weight: FontWeight.w700, color: Tk.inkSoft),
                              ),
                            ],
                          ),
                        ),
                        Text('${f.forGrams(it.grams).kcal.round()} kcal',
                            style: Tk.text(14, color: Tk.orangeInk)),
                      ],
                    ),
                  ),
              const SizedBox(height: 8),
              Text(
                menu.source.startsWith('ifpri')
                    ? 'Khẩu phần đã cân thật theo album ảnh khẩu phần IFPRI 2021.'
                    : menu.source == 'recipe'
                        ? 'Món theo công thức, dinh dưỡng tính từ Bảng thành phần thực phẩm Việt Nam 2007.'
                        : 'Thực đơn của bạn.',
                style: Tk.text(12, weight: FontWeight.w600, color: Tk.inkMuted),
              ),
              const SizedBox(height: 14),
              TkButton(
                label: 'Ghi vào nhật ký',
                tone: TkButtonTone.green,
                onTap: () {
                  Navigator.of(sheet).pop();
                  onLog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.initial});

  final NutritionSettings initial;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late NutritionSettings _s = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mục tiêu dinh dưỡng',
                style: Tk.text(22, weight: FontWeight.w900)),
            const SizedBox(height: 14),
            Text('MỤC TIÊU', style: Tk.eyebrow()),
            const SizedBox(height: 8),
            TkSegmented(
              labels: const ['Giảm cân', 'Giữ cân', 'Tăng cân'],
              selected: NutritionGoal.values.indexOf(_s.goal),
              onChanged: (i) => setState(
                  () => _s = _s.copyWith(goal: NutritionGoal.values[i])),
            ),
            const SizedBox(height: 14),
            Text('CHẾ ĐỘ ĂN', style: Tk.eyebrow()),
            const SizedBox(height: 8),
            TkSegmented(
              labels: const ['Cân bằng', 'Giàu đạm'],
              selected: DietMode.values.indexOf(_s.mode),
              onChanged: (i) =>
                  setState(() => _s = _s.copyWith(mode: DietMode.values[i])),
            ),
            const SizedBox(height: 10),
            Text(
              'Cân bằng: 1,6 g đạm/kg. Giàu đạm: 2,0 g đạm/kg (ISSN: 1,4–2,0 g/kg/ngày). '
              'Chất béo 25% năng lượng (WHO: không quá 30%). Giảm cân: bớt 500 kcal/ngày (NHLBI). Tăng cân: thêm 10% (Iraki 2019).',
              style: Tk.text(12.5,
                  weight: FontWeight.w600, color: Tk.inkSoft, height: 1.4),
            ),
            const SizedBox(height: 16),
            TkButton(label: 'Lưu', onTap: () => Navigator.of(context).pop(_s)),
          ],
        ),
      ),
    );
  }
}
