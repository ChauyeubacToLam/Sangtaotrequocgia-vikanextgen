import 'package:flutter/material.dart';

import '../../nutrition/food_db.dart';
import '../../nutrition/nutrition_context.dart';
import '../../nutrition/nutrition_store.dart';
import '../../nutrition/nutrition_targets.dart';
import '../../widgets/tk/tk.dart';
import 'food_search_screen.dart';
import 'food_visuals.dart';

class CreateDishScreen extends StatefulWidget {
  const CreateDishScreen({super.key, this.menu = false});

  final bool menu;

  @override
  State<CreateDishScreen> createState() => _CreateDishScreenState();
}

class _CreateDishScreenState extends State<CreateDishScreen> {
  final _name = TextEditingController();
  final _serving = TextEditingController(text: '1 phần');
  final _steps = TextEditingController();
  NutritionContext? _ctx;
  Region? _region;
  final List<(Food, double)> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    NutritionContext.load().then((c) {
      if (mounted) setState(() => _ctx = c);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _serving.dispose();
    _steps.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final ctx = _ctx;
    if (ctx == null) return;
    final picked = await Navigator.of(context).push<Map<String, double>>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          day: DateTime.now(),
          meal: MealSlot.lunch,
          pickOnly: true,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      for (final e in picked.entries) {
        final f = ctx.db.foods[e.key];
        if (f != null) _items.add((f, e.value));
      }
    });
  }

  Macros get _total =>
      _items.fold(Macros.zero, (a, it) => a + it.$1.forGrams(it.$2));

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.menu
            ? 'Cần tên thực đơn và ít nhất 1 món.'
            : 'Cần tên món và ít nhất 1 nguyên liệu.'),
      ));
      return;
    }
    setState(() => _saving = true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    if (widget.menu) {
      await NutritionStore.instance.saveCustomMenu(RegionalMenu(
        id: 'umenu_$stamp',
        name: name,
        region: _region,
        items: [for (final (f, g) in _items) MenuItem(f.id, g)],
        source: 'user',
      ).toJson());
    } else {
      final id = 'urecipe_$stamp';
      final serving =
          _serving.text.trim().isEmpty ? '1 phần' : _serving.text.trim();
      final food = dishFromIngredients(
        id: id,
        name: name,
        serving: serving,
        ingredients: _items,
        region: _region,
      );
      await NutritionStore.instance.saveCustomFood(food);
      await NutritionStore.instance.saveCustomRecipe(Recipe(
        id: id,
        name: name,
        region: _region,
        serving: serving,
        grams: _items.fold(0.0, (a, it) => a + it.$2),
        ingredients: [for (final (f, g) in _items) MenuItem(f.id, g)],
        steps: [
          for (final s in _steps.text.split('\n'))
            if (s.trim().isNotEmpty) s.trim(),
        ],
      ).toJson());
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    return Scaffold(
      backgroundColor: Tk.surface,
      appBar: AppBar(
        backgroundColor: Tk.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.menu ? 'Tạo thực đơn' : 'Tạo công thức',
            style: Tk.text(20, weight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: widget.menu ? 'Tên thực đơn' : 'Tên món',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          if (!widget.menu) ...[
            TextField(
              controller: _serving,
              decoration: InputDecoration(
                labelText: 'Công thức này làm được',
                hintText: 'ví dụ: 1 bát, 2 đĩa',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text('MIỀN (KHÔNG BẮT BUỘC)', style: Tk.eyebrow()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final r in Region.values)
                ChoiceChip(
                  label: Text(r.label),
                  selected: _region == r,
                  onSelected: (v) => setState(() => _region = v ? r : null),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(widget.menu ? 'CÁC MÓN' : 'NGUYÊN LIỆU',
                    style: Tk.eyebrow()),
              ),
              TextButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.add_rounded),
                label: Text(widget.menu ? 'Thêm món' : 'Thêm nguyên liệu'),
              ),
            ],
          ),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                widget.menu
                    ? 'Chọn các món có trong bữa, ví dụ cơm, thịt kho, canh.'
                    : 'Chọn nguyên liệu sống và nhập số gram, Vika tự tính dinh dưỡng theo bảng thành phần thực phẩm.',
                style: Tk.text(14,
                    weight: FontWeight.w600, color: Tk.inkSoft, height: 1.4),
              ),
            ),
          for (var i = 0; i < _items.length; i++)
            FadeSlideIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    FoodImage(food: _items[i].$1, size: 44, radius: 12),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_items[i].$1.name,
                          style: Tk.text(14.5, weight: FontWeight.w700)),
                    ),
                    SizedBox(
                      width: 84,
                      child: TextFormField(
                        initialValue: '${_items[i].$2.round()}',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            suffixText: 'g', isDense: true),
                        onChanged: (v) {
                          final g = double.tryParse(v.replaceAll(',', '.'));
                          if (g != null && g > 0) {
                            setState(() => _items[i] = (_items[i].$1, g));
                          }
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Bỏ',
                      onPressed: () => setState(() => _items.removeAt(i)),
                      icon: const Icon(Icons.close_rounded, color: Tk.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 12),
            MacroPills(
              kcal: total.kcal,
              protein: total.protein,
              carb: total.carb,
              fat: total.fat,
            ),
          ],
          if (!widget.menu) ...[
            const SizedBox(height: 18),
            Text('CÁCH LÀM', style: Tk.eyebrow()),
            const SizedBox(height: 8),
            TextField(
              controller: _steps,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Mỗi dòng một bước',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TkButton(
            label: widget.menu ? 'Lưu thực đơn' : 'Lưu công thức',
            tone: TkButtonTone.green,
            busy: _saving,
            onTap: _saving ? null : _save,
          ),
        ),
      ),
    );
  }
}
