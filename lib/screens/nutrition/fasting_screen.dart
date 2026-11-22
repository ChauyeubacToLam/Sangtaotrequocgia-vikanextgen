import 'dart:async';

import 'package:flutter/material.dart';

import '../../nutrition/nutrition_store.dart';
import '../../widgets/tk/tk.dart';

class FastingScreen extends StatefulWidget {
  const FastingScreen({super.key});

  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen> {
  FastingState _state = const FastingState();
  int _goal = 16;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await NutritionStore.instance.fasting();
    if (mounted) {
      setState(() {
        _state = s;
        _goal = s.goalHours;
      });
    }
  }

  String _fmt(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final start = _state.startedAt;
    final elapsed =
        start == null ? Duration.zero : DateTime.now().difference(start);
    final progress = start == null ? 0.0 : elapsed.inMinutes / (_goal * 60);
    return Scaffold(
      backgroundColor: Tk.surface,
      appBar: AppBar(
        backgroundColor: Tk.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('Nhịn ăn gián đoạn',
            style: Tk.text(20, weight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      strokeWidth: 16,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Tk.lineSoft,
                      color: progress >= 1 ? Tk.green : Tk.primary,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(start == null ? 'Chưa bắt đầu' : 'Đã nhịn',
                          style: Tk.text(14, color: Tk.inkSoft)),
                      Text(_fmt(elapsed),
                          style: Tk.text(44, weight: FontWeight.w900)),
                      Text('Mục tiêu $_goal giờ',
                          style: Tk.text(14, color: Tk.inkSoft)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (start == null) ...[
            Text('CHỌN KHUNG', style: Tk.eyebrow()),
            const SizedBox(height: 8),
            TkSegmented(
              labels: const ['12:12', '14:10', '16:8'],
              selected: [12, 14, 16].indexOf(_goal).clamp(0, 2),
              onChanged: (i) => setState(() => _goal = [12, 14, 16][i]),
            ),
            const SizedBox(height: 16),
            TkButton(
              label: 'Bắt đầu nhịn ăn',
              onTap: () async {
                await NutritionStore.instance.startFast(_goal);
                await _load();
              },
            ),
          ] else
            TkButton(
              label: 'Kết thúc',
              tone: TkButtonTone.orange,
              onTap: () async {
                await NutritionStore.instance.endFast();
                await _load();
              },
            ),
          const SizedBox(height: 14),
          Text(
            'Nhịn ăn gián đoạn không phù hợp với người có bệnh tiểu đường, phụ nữ mang thai, đang cho con bú, '
            'người dưới 18 tuổi hoặc có tiền sử rối loạn ăn uống. Hãy hỏi bác sĩ trước khi bắt đầu.',
            style: Tk.text(13,
                weight: FontWeight.w600, color: Tk.orangeInk, height: 1.45),
          ),
          const SizedBox(height: 20),
          Text('LỊCH SỬ', style: Tk.eyebrow()),
          const SizedBox(height: 8),
          if (_state.history.isEmpty)
            Text('Chưa có lần nhịn ăn nào.',
                style: Tk.text(14, color: Tk.inkSoft))
          else
            for (final (a, b) in _state.history.reversed.take(14))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          '${a.day}/${a.month} ${a.hour}:${a.minute.toString().padLeft(2, '0')}',
                          style: Tk.text(14, weight: FontWeight.w700)),
                    ),
                    Text(_fmt(b.difference(a)), style: Tk.text(14)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
