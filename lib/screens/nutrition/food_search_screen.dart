import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../nutrition/food_db.dart';
import '../../nutrition/nutrition_context.dart';
import '../../nutrition/nutrition_store.dart';
import '../../widgets/tk/tk.dart';
import 'food_visuals.dart';
import 'recipe_screen.dart';

const burnActivities = <(String, double, IconData)>[
  ('Đi bộ', 3.5, Icons.directions_walk_rounded),
  ('Chạy bộ', 9.8, Icons.directions_run_rounded),
  ('Đạp xe', 8.0, Icons.directions_bike_rounded),
  ('Nhảy dây', 11.8, Icons.sports_rounded),
];

int burnMinutes(double kcal, double met, double weightKg) =>
    (kcal / (met * weightKg) * 60).round();

const _groupFilters = <(String?, String)>[
  (null, 'Tất cả'),
  ('mon_an', 'Món ăn'),
  ('dam', 'Món đạm'),
  ('thit', 'Thịt'),
  ('thuy_san', 'Thủy sản'),
  ('rau', 'Rau'),
  ('trai_cay', 'Trái cây'),
  ('sua', 'Sữa'),
  ('ngu_coc', 'Ngũ cốc'),
  ('do_uong', 'Đồ uống'),
];

typedef FoodPick = ({double grams, MealSlot meal});

String servingLabel(double k, String serving) {
  final n = switch (k) {
    0.5 => '½',
    1.5 => '1½',
    2.5 => '2½',
    _ => '${k.round()}',
  };
  return serving.startsWith('1 ')
      ? '$n ${serving.substring(2)}'
      : '$n × $serving';
}

class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({
    super.key,
    required this.day,
    required this.meal,
    this.multi = false,
    this.startVoice = false,
    this.pickOnly = false,
  });

  final DateTime day;
  final MealSlot meal;
  final bool multi;
  final bool startVoice;
  final bool pickOnly;

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _query = TextEditingController();
  final _speech = SpeechToText();
  NutritionContext? _ctx;
  late MealSlot _meal = widget.meal;
  String? _filter;
  String? _group;
  int _tab = 0;
  List<String> _recent = const [];
  Set<String> _fav = const {};
  final Map<String, double> _picked = {};
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ctx = await NutritionContext.load();
    final recent = await NutritionStore.instance.recent();
    final fav = await NutritionStore.instance.favorites();
    if (!mounted) return;
    setState(() {
      _ctx = ctx;
      _recent = recent;
      _fav = fav;
    });
    if (widget.startVoice) _listen();
  }

  @override
  void dispose() {
    _query.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _listen() async {
    final ok = await _speech.initialize(onError: (_) {
      if (mounted) setState(() => _listening = false);
    });
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Máy chưa hỗ trợ nhận giọng nói hoặc chưa cho phép micro.'),
      ));
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      listenOptions:
          SpeechListenOptions(partialResults: false, localeId: 'vi_VN'),
      onResult: (r) {
        if (!r.finalResult) return;
        final ctx = _ctx;
        setState(() => _listening = false);
        if (ctx == null) return;
        final hits = ctx.db.matchSpoken(r.recognizedWords);
        if (hits.isEmpty) {
          setState(() => _query.text = r.recognizedWords);
          return;
        }
        setState(() {
          for (final (f, g) in hits) {
            _picked[f.id] = g;
          }
        });
      },
    );
  }

  Future<void> _addPicked() async {
    if (widget.pickOnly) {
      Navigator.of(context).pop(Map<String, double>.of(_picked));
      return;
    }
    final now = DateTime.now();
    var i = 0;
    for (final e in _picked.entries) {
      await NutritionStore.instance.addEntry(
        widget.day,
        DiaryEntry(
          foodId: e.key,
          grams: e.value,
          meal: _meal,
          at: now.add(Duration(milliseconds: i++)),
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openDetail(Food food) async {
    final ctx = _ctx;
    if (ctx == null) return;
    final pick = await showFoodDetail(context, food, ctx,
        mealLabel: _meal.label, meal: _meal);
    if (pick == null || !mounted) return;
    if (widget.multi || widget.pickOnly || _picked.isNotEmpty) {
      setState(() => _picked[food.id] = pick.grams);
      return;
    }
    await NutritionStore.instance.addEntry(
      widget.day,
      DiaryEntry(
          foodId: food.id,
          grams: pick.grams,
          meal: pick.meal,
          at: DateTime.now()),
    );
    if (mounted) Navigator.of(context).pop();
  }

  List<Food> _results(FoodDb db) {
    final q = _query.text.trim();
    if (q.isNotEmpty || _filter != null || _group != null) {
      return db.search(q, filter: _filter, group: _group);
    }
    final ids = switch (_tab) {
      0 => _recent,
      1 => _fav.toList(),
      _ => [
          for (final f in db.foods.values)
            if (f.custom) f.id
        ],
    };
    final list = [
      for (final id in ids)
        if (db.foods[id] case final f?) f,
    ];
    if (list.isEmpty && _tab == 0) {
      return db.foods.values.where((f) => !f.isRaw).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ctx = _ctx;
    final browsing =
        _query.text.trim().isEmpty && _filter == null && _group == null;
    return Scaffold(
      backgroundColor: Tk.surface,
      appBar: AppBar(
        backgroundColor: Tk.surface,
        surfaceTintColor: Colors.transparent,
        title: widget.pickOnly
            ? Text('Chọn món', style: Tk.text(18, weight: FontWeight.w900))
            : DropdownButtonHideUnderline(
                child: DropdownButton<MealSlot>(
                  value: _meal,
                  style: Tk.text(18, weight: FontWeight.w900),
                  items: [
                    for (final m in MealSlot.values)
                      DropdownMenuItem(
                          value: m,
                          child: Text('Bữa ${m.label.toLowerCase()}')),
                  ],
                  onChanged: (m) => setState(() => _meal = m ?? _meal),
                ),
              ),
      ),
      body: ctx == null
          ? const Center(child: CircularProgressIndicator(color: Tk.primary))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText:
                          'Tìm trong ${ctx.db.foods.length} món, ví dụ: giò lụa',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'Nói tên món',
                        onPressed: _listening ? _speech.stop : _listen,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _listening
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded,
                            key: ValueKey(_listening),
                            color: _listening ? Tk.red : Tk.primary,
                          ),
                        ),
                      ),
                      filled: true,
                      fillColor: Tk.surfaceSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final (key, label) in _groupFilters)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _group == key,
                            onSelected: (_) => setState(() => _group = key),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final (key, label) in const [
                        ('protein', 'Giàu đạm'),
                        ('lowcarb', 'Ít tinh bột'),
                        ('lowfat', 'Ít béo'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(label),
                            selected: _filter == key,
                            onSelected: (v) =>
                                setState(() => _filter = v ? key : null),
                          ),
                        ),
                    ],
                  ),
                ),
                if (browsing)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: TkSegmented(
                      labels: const ['Gần đây', 'Yêu thích', 'Của tôi'],
                      selected: _tab,
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                  ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _listening
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                              'Đang nghe… hãy nói tên các món, ví dụ "cơm, giò lụa, rau muống"',
                              style: Tk.text(13.5, color: Tk.red)),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                Expanded(
                  child: Builder(builder: (context) {
                    final list = _results(ctx.db);
                    if (list.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded,
                                size: 56, color: Tk.inkMuted),
                            const SizedBox(height: 8),
                            Text('Không có món nào ở đây',
                                style: Tk.text(15, color: Tk.inkSoft)),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final f = list[i];
                        final picked = _picked.containsKey(f.id);
                        final portion = f.defaultPortion;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: FadeSlideIn(
                            index: i,
                            child: Material(
                              color: picked ? Tk.greenSoft : Tk.surface,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => _openDetail(f),
                                child: Container(
                                  padding:
                                      const EdgeInsets.fromLTRB(8, 8, 4, 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                        color: picked ? Tk.green : Tk.lineSoft,
                                        width: 2),
                                  ),
                                  child: Row(
                                    children: [
                                      FoodImage(
                                          food: f,
                                          size: 56,
                                          radius: 14,
                                          heroTag: 'food_${f.id}'),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(f.name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: Tk.text(15.5,
                                                    weight: FontWeight.w900)),
                                            const SizedBox(height: 2),
                                            Text(
                                              portion == null
                                                  ? '100 g · ${f.per100.kcal.round()} kcal · ${f.groupInfo.label}${f.isRaw ? ' (sống)' : ''}'
                                                  : '${portion.label} ${portion.grams.round()} g · ${f.forGrams(portion.grams).kcal.round()} kcal',
                                              style: Tk.text(12.5,
                                                  weight: FontWeight.w700,
                                                  color: Tk.inkSoft),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: picked ? 'Bỏ chọn' : 'Thêm',
                                        onPressed: () {
                                          if (picked) {
                                            setState(
                                                () => _picked.remove(f.id));
                                          } else if (widget.multi ||
                                              widget.pickOnly ||
                                              _picked.isNotEmpty) {
                                            setState(() => _picked[f.id] =
                                                portion?.grams ?? 100);
                                          } else {
                                            _openDetail(f);
                                          }
                                        },
                                        icon: AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          transitionBuilder: (c, a) =>
                                              ScaleTransition(
                                                  scale: a, child: c),
                                          child: Icon(
                                            picked
                                                ? Icons.check_circle_rounded
                                                : Icons
                                                    .add_circle_outline_rounded,
                                            key: ValueKey(picked),
                                            color:
                                                picked ? Tk.green : Tk.primary,
                                            size: 30,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (c, a) => SizeTransition(sizeFactor: a, child: c),
        child: _picked.isEmpty
            ? const SizedBox.shrink()
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: TkButton(
                    label: widget.pickOnly
                        ? 'Chọn ${_picked.length} món'
                        : 'Thêm ${_picked.length} món vào bữa ${_meal.label.toLowerCase()}',
                    tone: TkButtonTone.green,
                    onTap: _addPicked,
                  ),
                ),
              ),
      ),
    );
  }
}

Future<FoodPick?> showFoodDetail(
  BuildContext context,
  Food food,
  NutritionContext ctx, {
  required String mealLabel,
  MealSlot? meal,
  double? initialGrams,
  bool editing = false,
  VoidCallback? onDelete,
}) {
  return showModalBottomSheet<FoodPick>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FoodDetail(
      food: food,
      ctx: ctx,
      meal: meal,
      initialGrams: initialGrams,
      editing: editing,
      onDelete: onDelete,
      viewOnly: mealLabel == 'xem',
    ),
  );
}

class _FoodDetail extends StatefulWidget {
  const _FoodDetail({
    required this.food,
    required this.ctx,
    required this.meal,
    required this.initialGrams,
    required this.editing,
    required this.onDelete,
    required this.viewOnly,
  });

  final Food food;
  final NutritionContext ctx;
  final MealSlot? meal;
  final double? initialGrams;
  final bool editing;
  final VoidCallback? onDelete;
  final bool viewOnly;

  @override
  State<_FoodDetail> createState() => _FoodDetailState();
}

class _FoodDetailState extends State<_FoodDetail> {
  late double _grams =
      widget.initialGrams ?? widget.food.defaultPortion?.grams ?? 100;
  late final _gramsField = TextEditingController(text: '${_grams.round()}');
  late MealSlot _meal = widget.meal ?? mealSlotForHour(DateTime.now().hour);
  bool _fav = false;

  @override
  void initState() {
    super.initState();
    NutritionStore.instance.favorites().then((f) {
      if (mounted) setState(() => _fav = f.contains(widget.food.id));
    });
  }

  @override
  void dispose() {
    _gramsField.dispose();
    super.dispose();
  }

  void _setGrams(double g) {
    setState(() => _grams = g);
    _gramsField.text = '${g.round()}';
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.food;
    final m = f.forGrams(_grams);
    final energy = m.protein * 4 + m.carb * 4 + m.fat * 9;
    double share(double kcal) => energy <= 0 ? 0 : kcal / energy;
    final sourceIds = f.source.split(RegExp(r'[+,; ]+'));
    final source = [
      for (final id in sourceIds)
        widget.ctx.db.sources[id.split(':').first]?.cite.split('.').first ??
            (id.startsWith('recipe') ? 'Công thức' : id),
    ].where((s) => s.isNotEmpty).toSet().join(' · ');
    final recipe = widget.ctx.db.recipeFor(f.id);
    final dishServing = f.isDish ? f.defaultPortion : null;
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Tk.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          controller: controller,
          padding: EdgeInsets.only(
              bottom: 24 + MediaQuery.of(context).viewInsets.bottom),
          children: [
            Stack(
              children: [
                FoodImage(
                  food: f,
                  width: double.infinity,
                  height: 200,
                  radius: 0,
                  heroTag: 'food_${f.id}',
                ),
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(99)),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 18,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                    child: IconButton(
                      tooltip: 'Yêu thích',
                      onPressed: () async {
                        await NutritionStore.instance.toggleFavorite(f.id);
                        setState(() => _fav = !_fav);
                      },
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (c, a) =>
                            ScaleTransition(scale: a, child: c),
                        child: Icon(
                            _fav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            key: ValueKey(_fav),
                            color: Tk.red),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(f.name, style: Tk.text(24, weight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Nguồn: $source',
                      style: Tk.text(12,
                          weight: FontWeight.w600,
                          color: Tk.inkMuted,
                          height: 1.35)),
                  if (f.isRaw && (f.refuse ?? 0) > 0)
                    Text(
                        'Số liệu tính cho phần ăn được (đã bỏ ${f.refuse!.round()}% phần thải bỏ như vỏ, xương).',
                        style: Tk.text(12,
                            weight: FontWeight.w600, color: Tk.inkMuted)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox.expand(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                builder: (_, t, __) => CustomPaint(
                                  painter: _MacroRing([
                                    (
                                      share(m.carb * 4) * t,
                                      const Color(0xFFE5B83A)
                                    ),
                                    (share(m.protein * 4) * t, Tk.red),
                                    (share(m.fat * 9) * t, Tk.primary),
                                  ]),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${m.kcal.round()}',
                                    style:
                                        Tk.text(26, weight: FontWeight.w900)),
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
                          children: [
                            _Row('Tinh bột', m.carb, const Color(0xFFE5B83A)),
                            _Row('Chất đạm', m.protein, Tk.red),
                            _Row('Chất béo', m.fat, Tk.primary),
                            _Row('Chất xơ', m.fiber, Tk.green),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (recipe != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        openRecipe(context, recipe);
                      },
                      icon: const Icon(Icons.menu_book_rounded),
                      label: const Text('Xem công thức và nguyên liệu'),
                    ),
                  ],
                  if (f.howto.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text('CÁCH CHẾ BIẾN', style: Tk.eyebrow()),
                    const SizedBox(height: 8),
                    for (final (i, s) in f.howto.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 22,
                              child: Text('${i + 1}.',
                                  style: Tk.text(14,
                                      weight: FontWeight.w800,
                                      color: Tk.primary)),
                            ),
                            Expanded(
                              child: Text(s, style: Tk.text(14, height: 1.4)),
                            ),
                          ],
                        ),
                      ),
                    Text(
                        'Dầu, đường, nước chấm nêm thêm chưa nằm trong số liệu trên; dùng nhiều thì ghi riêng vào nhật ký.',
                        style: Tk.text(12,
                            weight: FontWeight.w600, color: Tk.inkMuted)),
                  ],
                  const SizedBox(height: 18),
                  Text(
                      'CẦN VẬN ĐỘNG BAO LÂU ĐỂ TIÊU HAO ${m.kcal.round()} KCAL?',
                      style: Tk.eyebrow()),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final (label, met, icon) in burnActivities)
                        Expanded(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Tk.greenSoft,
                                child: Icon(icon, color: Tk.greenInk, size: 22),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                  '${burnMinutes(m.kcal, met, widget.ctx.body.weightKg)} phút',
                                  style: Tk.text(14, weight: FontWeight.w900)),
                              Text(label,
                                  style: Tk.text(11.5, color: Tk.inkSoft)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                      'Theo MET của Compendium of Physical Activities 2011, cân nặng ${widget.ctx.body.weightKg.round()} kg.',
                      style: Tk.text(11.5,
                          weight: FontWeight.w600, color: Tk.inkMuted)),
                  if (f.micro.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    MicroTable(food: f, grams: _grams),
                  ],
                  if (!widget.viewOnly) ...[
                    const SizedBox(height: 18),
                    Text('KHẨU PHẦN', style: Tk.eyebrow()),
                    const SizedBox(height: 8),
                    if (dishServing != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final k in const [0.5, 1.0, 1.5, 2.0])
                            ChoiceChip(
                              label: Text(servingLabel(k, dishServing.label)),
                              selected:
                                  (_grams - dishServing.grams * k).abs() < 0.5,
                              onSelected: (_) =>
                                  _setGrams(dishServing.grams * k),
                            ),
                        ],
                      )
                    else ...[
                      if (f.portions.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final p in f.portions)
                              ChoiceChip(
                                label:
                                    Text('${p.label} · ${p.grams.round()} g'),
                                selected: _grams == p.grams,
                                onSelected: (_) => _setGrams(p.grams),
                              ),
                          ],
                        ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _gramsField,
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final g = double.tryParse(v.replaceAll(',', '.'));
                          if (g != null && g > 0 && g < 3000) {
                            setState(() => _grams = g);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Khối lượng',
                          suffixText: 'gram',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      if (f.portions.any((p) => p.source.startsWith('ifpri')))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                              'Các cỡ Nhỏ/Vừa/Lớn/Rất lớn đã cân thật, theo album ảnh khẩu phần IFPRI 2021.',
                              style: Tk.text(11.5,
                                  weight: FontWeight.w600, color: Tk.inkMuted)),
                        ),
                    ],
                    const SizedBox(height: 14),
                    Text('BỮA', style: Tk.eyebrow()),
                    const SizedBox(height: 8),
                    TkSegmented(
                      labels: [for (final s in MealSlot.values) s.label],
                      selected: MealSlot.values.indexOf(_meal),
                      onChanged: (i) =>
                          setState(() => _meal = MealSlot.values[i]),
                    ),
                    const SizedBox(height: 16),
                    TkButton(
                      label: widget.editing
                          ? 'Lưu thay đổi'
                          : 'Thêm vào bữa ${_meal.label.toLowerCase()}',
                      tone: TkButtonTone.green,
                      onTap: () => Navigator.of(context)
                          .pop((grams: _grams, meal: _meal)),
                    ),
                    if (widget.editing && widget.onDelete != null)
                      TextButton(
                        onPressed: () {
                          widget.onDelete!();
                          Navigator.of(context).pop();
                        },
                        child: Text('Xóa khỏi nhật ký',
                            style: Tk.text(14.5, color: Tk.redInk)),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.grams, this.color);

  final String label;
  final double grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label, style: Tk.text(14, weight: FontWeight.w700))),
          Text('${grams.toStringAsFixed(1)} g', style: Tk.text(14)),
        ],
      ),
    );
  }
}

class _MacroRing extends CustomPainter {
  _MacroRing(this.parts);

  final List<(double, Color)> parts;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    const full = 6.283185307179586;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    var start = -full / 4;
    canvas.drawArc(
        rect,
        0,
        full,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = Tk.lineSoft);
    for (final (share, color) in parts) {
      final sweep = full * share;
      if (sweep <= 0) continue;
      canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.butt
            ..color = color);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_MacroRing old) => true;
}
