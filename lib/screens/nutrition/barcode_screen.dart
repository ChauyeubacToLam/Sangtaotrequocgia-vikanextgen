import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../nutrition/food_db.dart';
import '../../nutrition/nutrition_context.dart';
import '../../nutrition/nutrition_store.dart';
import '../../widgets/tk/tk.dart';
import 'create_food_screen.dart';
import 'food_search_screen.dart';

Future<Map<String, Object?>?> lookupBarcode(String code) async {
  final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$code.json?fields=product_name,product_name_vi,nutriments');
  final res = await http.get(uri, headers: {
    'User-Agent': 'VikaApp/1.0'
  }).timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) return null;
  final body = jsonDecode(res.body);
  if (body is! Map || body['status'] != 1) return null;
  final p = body['product'];
  if (p is! Map) return null;
  final n = p['nutriments'];
  if (n is! Map) return null;
  double v(String k) => (n[k] as num?)?.toDouble() ?? 0;
  final kcal = v('energy-kcal_100g');
  if (kcal <= 0) return null;
  final name = '${p['product_name_vi'] ?? ''}'.trim().isNotEmpty
      ? '${p['product_name_vi']}'
      : '${p['product_name'] ?? 'Sản phẩm $code'}';
  return {
    'id': 'off_$code',
    'name': name,
    'group': 'packaged',
    'per100': {
      'kcal': kcal,
      'p': v('proteins_100g'),
      'f': v('fat_100g'),
      'c': v('carbohydrates_100g'),
      'fib': v('fiber_100g'),
    },
    'src': 'off:$code',
  };
}

class BarcodeScreen extends StatefulWidget {
  const BarcodeScreen({super.key, required this.day, required this.meal});

  final DateTime day;
  final MealSlot meal;

  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE
    ],
  );
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;
    setState(() {
      _busy = true;
      _message = 'Đang tra mã $code…';
    });
    await _controller.stop();
    Map<String, Object?>? food;
    try {
      food = await lookupBarcode(code);
    } catch (_) {
      food = null;
    }
    if (!mounted) return;
    if (food == null) {
      final created =
          await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => const CreateFoodScreen(scanLabel: true),
      ));
      if (!mounted) return;
      if (created == null) {
        setState(() {
          _busy = false;
          _message =
              'Không tìm thấy mã $code. Thử lại hoặc quét nhãn dinh dưỡng.';
        });
        await _controller.start();
        return;
      }
      Navigator.of(context).pop();
      return;
    }
    await NutritionStore.instance.saveCustomFood(food);
    final ctx = await NutritionContext.load();
    final f = ctx.db.foods[food['id']] ?? Food.fromJson(food);
    if (!mounted) return;
    final grams = await showFoodDetail(context, f, ctx,
        mealLabel: widget.meal.label, meal: widget.meal);
    if (grams != null) {
      await NutritionStore.instance.addEntry(
        widget.day,
        DiaryEntry(
            foodId: f.id,
            grams: grams.grams,
            meal: grams.meal,
            at: DateTime.now()),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Quét mã vạch'),
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: Text(
              _message ??
                  'Đưa mã vạch trên bao bì vào khung. Dữ liệu từ Open Food Facts.',
              textAlign: TextAlign.center,
              style: Tk.text(15, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
