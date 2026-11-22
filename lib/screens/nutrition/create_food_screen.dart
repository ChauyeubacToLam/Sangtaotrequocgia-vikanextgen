import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../nutrition/food_db.dart';
import '../../nutrition/nutrition_store.dart';
import '../../widgets/tk/tk.dart';

Map<String, double> parseNutritionLabel(String text) {
  final lines = text.toLowerCase().split('\n');
  final out = <String, double>{};
  double? firstNumber(String s) {
    final m = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(s);
    return m == null ? null : double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }

  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    final next = i + 1 < lines.length ? lines[i + 1] : '';
    double? value() => firstNumber(l) ?? firstNumber(next);
    if (!out.containsKey('kcal') &&
        (l.contains('năng lượng') ||
            l.contains('nang luong') ||
            l.contains('energy') ||
            l.contains('kcal'))) {
      final kcal = RegExp(r'(\d+(?:[.,]\d+)?)\s*kcal').firstMatch(l)?.group(1);
      final v =
          kcal == null ? value() : double.tryParse(kcal.replaceAll(',', '.'));
      if (v != null) out['kcal'] = v;
    } else if (!out.containsKey('p') &&
        (l.contains('đạm') ||
            l.contains('protein') ||
            l.contains('chất đạm'))) {
      final v = value();
      if (v != null) out['p'] = v;
    } else if (!out.containsKey('f') &&
        (l.contains('béo') || l.contains('fat') || l.contains('lipid'))) {
      final v = value();
      if (v != null) out['f'] = v;
    } else if (!out.containsKey('c') &&
        (l.contains('carbohydrate') ||
            l.contains('bột đường') ||
            l.contains('glucid') ||
            l.contains('carb'))) {
      final v = value();
      if (v != null) out['c'] = v;
    } else if (!out.containsKey('fib') &&
        (l.contains('xơ') || l.contains('fiber') || l.contains('fibre'))) {
      final v = value();
      if (v != null) out['fib'] = v;
    }
  }
  return out;
}

class CreateFoodScreen extends StatefulWidget {
  const CreateFoodScreen({super.key, this.scanLabel = false, this.initial});

  final bool scanLabel;
  final Food? initial;

  @override
  State<CreateFoodScreen> createState() => _CreateFoodScreenState();
}

class _CreateFoodScreenState extends State<CreateFoodScreen> {
  final _name = TextEditingController();
  final _fields = {
    'kcal': TextEditingController(),
    'p': TextEditingController(),
    'f': TextEditingController(),
    'c': TextEditingController(),
    'fib': TextEditingController(),
  };
  final _portion = TextEditingController(text: '100');
  bool _scanning = false;
  String? _scanNote;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    if (f != null) {
      _name.text = f.name;
      _fields['kcal']!.text = f.per100.kcal.toStringAsFixed(0);
      _fields['p']!.text = f.per100.protein.toStringAsFixed(1);
      _fields['f']!.text = f.per100.fat.toStringAsFixed(1);
      _fields['c']!.text = f.per100.carb.toStringAsFixed(1);
      _fields['fib']!.text = f.per100.fiber.toStringAsFixed(1);
    }
    if (widget.scanLabel) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _portion.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _scan() async {
    final shot = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 90);
    if (shot == null) return;
    setState(() => _scanning = true);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(shot.path));
      final values = parseNutritionLabel(result.text);
      setState(() {
        for (final e in values.entries) {
          _fields[e.key]?.text = e.value.toString();
        }
        _scanNote = values.isEmpty
            ? 'Không đọc được nhãn. Hãy chụp gần, thẳng và đủ sáng, hoặc nhập tay.'
            : 'Đã đọc ${values.length} chỉ số từ nhãn. Kiểm tra lại số trên nhãn là theo 100 g hay theo khẩu phần.';
      });
    } catch (_) {
      setState(() => _scanNote = 'Không đọc được nhãn, hãy nhập tay.');
    } finally {
      await recognizer.close();
      if (mounted) setState(() => _scanning = false);
    }
  }

  double _num(String key) =>
      double.tryParse(_fields[key]!.text.replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _num('kcal') <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần có tên món và năng lượng (kcal).')),
      );
      return;
    }
    final base = double.tryParse(_portion.text.replaceAll(',', '.')) ?? 100;
    final k = base <= 0 ? 1.0 : 100 / base;
    final id =
        widget.initial?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}';
    await NutritionStore.instance.saveCustomFood({
      'id': id,
      'name': name,
      'group': 'custom',
      'per100': {
        'kcal': _num('kcal') * k,
        'p': _num('p') * k,
        'f': _num('f') * k,
        'c': _num('c') * k,
        'fib': _num('fib') * k,
      },
      'src': 'user',
      'portions': [
        if (base != 100) {'label': 'Khẩu phần', 'g': base, 'src': 'user'},
      ],
    });
    if (mounted) Navigator.of(context).pop(id);
  }

  Widget _field(String key, String label, String unit) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: _fields[key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            suffixText: unit,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tk.surface,
      appBar: AppBar(
        backgroundColor: Tk.surface,
        surfaceTintColor: Colors.transparent,
        title:
            Text('Tạo thực phẩm', style: Tk.text(20, weight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'Quét nhãn dinh dưỡng',
            onPressed: _scanning ? null : _scan,
            icon: const Icon(Icons.document_scanner_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (_scanning) const LinearProgressIndicator(color: Tk.primary),
          if (_scanNote != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_scanNote!,
                  style: Tk.text(13.5,
                      weight: FontWeight.w700, color: Tk.orangeInk)),
            ),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: 'Tên món',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _portion,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Các số dưới đây tính cho',
              suffixText: 'gram',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 10),
          _field('kcal', 'Năng lượng', 'kcal'),
          _field('p', 'Chất đạm', 'g'),
          _field('f', 'Chất béo', 'g'),
          _field('c', 'Tinh bột', 'g'),
          _field('fib', 'Chất xơ', 'g'),
          const SizedBox(height: 8),
          TkButton(label: 'Lưu món', tone: TkButtonTone.green, onTap: _save),
        ],
      ),
    );
  }
}
