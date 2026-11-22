import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/tk/tk.dart';

typedef BootLoader = Future<Widget> Function(void Function(double) report);

class BootSplash extends StatefulWidget {
  const BootSplash({super.key, required this.load});

  final BootLoader load;

  @override
  State<BootSplash> createState() => _BootSplashState();
}

class _BootSplashState extends State<BootSplash> {
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    final next = await widget.load((value) {
      if (mounted) setState(() => _progress = value.clamp(0, 1));
    });
    if (mounted) setState(() => _progress = 1);
    await Future<void>.delayed(const Duration(milliseconds: 320));
    runApp(next);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Tk.indigo,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              children: [
                const Spacer(flex: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.asset('assets/branding/app_logo.png', width: 132, height: 132),
                ),
                const SizedBox(height: 24),
                Text(
                  'VIKA',
                  style: Tk.text(64, weight: FontWeight.w900, color: Colors.white, letterSpacing: 4, height: 1),
                ),
                const SizedBox(height: 10),
                Text(
                  'HLV AI ngay tại nhà',
                  style: Tk.text(18, weight: FontWeight.w700, color: Tk.onIndigoSoft),
                ),
                const Spacer(flex: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: _progress),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  builder: (context, value, _) => Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: value,
                          minHeight: 12,
                          backgroundColor: Tk.indigoHi,
                          valueColor: const AlwaysStoppedAnimation(Tk.green),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Đang tải ${(value * 100).round()}%',
                        style: Tk.text(14, weight: FontWeight.w800, color: Tk.onIndigoSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
