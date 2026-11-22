import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../nutrition/food_db.dart';
import '../../nutrition/nutrition_context.dart';
import '../../nutrition/nutrition_store.dart';
import '../../widgets/tk/tk.dart';

class PhotoFoodScreen extends StatefulWidget {
  const PhotoFoodScreen({super.key, required this.day, required this.meal});

  final DateTime day;
  final MealSlot meal;

  @override
  State<PhotoFoodScreen> createState() => _PhotoFoodScreenState();
}

class _PhotoFoodScreenState extends State<PhotoFoodScreen> {
  File? _photo;
  bool _busy = false;
  String? _message;
  NutritionContext? _ctx;
  final List<(Food, double)> _items = [];

  @override
  void initState() {
    super.initState();
    NutritionContext.load().then((c) {
      if (mounted) setState(() => _ctx = c);
    });
  }

  Future<void> _pick(ImageSource source) async {
    final shot = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (shot == null) return;
    setState(() {
      _photo = File(shot.path);
      _items.clear();
      _message = null;
    });
    await _recognize(File(shot.path));
  }

  Future<void> _recognize(File file) async {
    final ctx = _ctx ?? await NutritionContext.load();
    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      final res = await Supabase.instance.client.functions.invoke(
        'food-photo',
        body: {
          'image': base64Encode(bytes),
          'mediaType': 'image/jpeg',
          'foods': [
            for (final f in ctx.db.foods.values) {'id': f.id, 'name': f.name},
          ],
        },
      );
      final data = res.data;
      final items = data is Map ? data['items'] : null;
      final found = <(Food, double)>[
        if (items is List)
          for (final it in items)
            if (it is Map &&
                ctx.db.foods[it['food']] != null &&
                it['grams'] is num)
              (ctx.db.foods[it['food']]!, (it['grams'] as num).toDouble()),
      ];
      setState(() {
        _items
          ..clear()
          ..addAll(found);
        _message = found.isEmpty
            ? 'Chưa nhận ra món nào có trong kho món ăn của Vika. Bạn có thể nhập tay.'
            : 'Kiểm tra lại khối lượng rồi bấm Thêm. Số dinh dưỡng lấy từ bảng có nguồn, AI chỉ nhận diện món và ước lượng khối lượng.';
      });
    } on FunctionException catch (e) {
      setState(() => _message = e.status == 503
          ? 'Tính năng chụp ảnh chưa được bật trên máy chủ.'
          : 'Không nhận diện được lúc này, thử lại sau hoặc nhập tay.');
    } catch (_) {
      setState(
          () => _message = 'Không gửi được ảnh. Kiểm tra mạng rồi thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final now = DateTime.now();
    for (final (f, g) in _items) {
      await NutritionStore.instance.addEntry(
        widget.day,
        DiaryEntry(foodId: f.id, grams: g, meal: widget.meal, at: now),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final total =
        _items.fold<double>(0, (a, e) => a + e.$1.forGrams(e.$2).kcal);
    return Scaffold(
      backgroundColor: Tk.surface,
      appBar: AppBar(
        backgroundColor: Tk.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('Chụp ảnh món ăn',
            style: Tk.text(20, weight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (_photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.file(_photo!, height: 240, fit: BoxFit.cover),
            )
          else
            Container(
              height: 200,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Tk.surfaceSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.restaurant_rounded,
                  size: 64, color: Tk.inkMuted),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TkButton(
                  label: 'Chụp ảnh',
                  icon: Icons.photo_camera_rounded,
                  onTap: _busy ? null : () => _pick(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TkButton(
                  label: 'Thư viện',
                  tone: TkButtonTone.outline,
                  icon: Icons.photo_library_rounded,
                  onTap: _busy ? null : () => _pick(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Ảnh được gửi tới dịch vụ AI (Anthropic Claude) qua máy chủ Vika để nhận diện món, không lưu lại.',
            style: Tk.text(12, weight: FontWeight.w600, color: Tk.inkMuted),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(color: Tk.primary),
          ],
          if (_message != null) ...[
            const SizedBox(height: 14),
            Text(_message!,
                style: Tk.text(14,
                    weight: FontWeight.w700, color: Tk.inkSoft, height: 1.4)),
          ],
          for (var i = 0; i < _items.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_items[i].$1.name,
                        style: Tk.text(15, weight: FontWeight.w800)),
                  ),
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      initialValue: '${_items[i].$2.round()}',
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(suffixText: 'g', isDense: true),
                      onChanged: (v) {
                        final g = double.tryParse(v);
                        if (g != null && g > 0) {
                          setState(() => _items[i] = (_items[i].$1, g));
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _items.removeAt(i)),
                    icon: const Icon(Icons.close_rounded, color: Tk.inkMuted),
                  ),
                ],
              ),
            ),
          if (_items.isNotEmpty) ...[
            const SizedBox(height: 16),
            TkButton(
              label:
                  'Thêm ${total.round()} kcal vào bữa ${widget.meal.label.toLowerCase()}',
              tone: TkButtonTone.green,
              onTap: _add,
            ),
          ],
        ],
      ),
    );
  }
}
