import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../../widgets/tk/tk.dart';
import 'sensor_rotated_box.dart';

const kGuideVideoSeenPrefix = 'guide_video_seen_';

Future<bool> guideVideoSeen(String exerciseId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$kGuideVideoSeenPrefix$exerciseId') ?? false;
  } catch (_) {
    return true;
  }
}

Future<void> _markGuideVideoSeen(String exerciseId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$kGuideVideoSeenPrefix$exerciseId', true);
  } catch (_) {}
}

Future<void> showExerciseGuideVideo(
  BuildContext context, {
  required String asset,
  required String title,
  required String exerciseId,
  bool firstTime = false,
}) async {
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => SensorRotatedBox(
        child: ExerciseGuideVideoPage(
          asset: asset,
          title: title,
          firstTime: firstTime,
        ),
      ),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    ),
  );
  await _markGuideVideoSeen(exerciseId);
}

class ExerciseGuideVideoPage extends StatefulWidget {
  const ExerciseGuideVideoPage({
    super.key,
    required this.asset,
    required this.title,
    this.firstTime = false,
  });

  final String asset;
  final String title;
  final bool firstTime;

  @override
  State<ExerciseGuideVideoPage> createState() => _ExerciseGuideVideoPageState();
}

class _ExerciseGuideVideoPageState extends State<ExerciseGuideVideoPage> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _watched = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _watched = !widget.firstTime;
    unawaited(_load());
  }

  Future<void> _load() async {
    final controller = VideoPlayerController.asset(widget.asset);
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      controller.addListener(_tick);
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _watched = true);
    }
  }

  void _tick() {
    final value = _controller?.value;
    if (value == null || !value.isInitialized) return;
    final total = value.duration.inMilliseconds;
    if (total <= 0) return;
    final pos = value.position.inMilliseconds;
    final progress = (pos / total).clamp(0.0, 1.0);
    final done = _watched || pos >= total - 350;
    if (done != _watched || (progress - _progress).abs() > 0.02) {
      setState(() {
        _watched = done;
        _progress = done && widget.firstTime ? 1 : progress;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_tick);
    _controller?.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final top = Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.firstTime ? 'LẦN ĐẦU TẬP BÀI NÀY' : 'VIDEO MẪU',
              style: Tk.text(13,
                  weight: FontWeight.w900,
                  color: Tk.onIndigoSoft,
                  letterSpacing: 1.2),
            ),
          ),
          if (widget.firstTime)
            TextButton(
              onPressed: _close,
              child: Text('Bỏ qua',
                  style: Tk.text(16,
                      weight: FontWeight.w900, color: Colors.white)),
            )
          else
            IconButton(
              tooltip: 'Đóng',
              onPressed: _close,
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 28),
            ),
        ],
      ),
    );
    final title = Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Text(
        widget.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Tk.text(28,
            weight: FontWeight.w900,
            color: Colors.white,
            height: 1.15,
            letterSpacing: -0.4),
      ),
    );
    final video = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: _ready && controller != null
                ? controller.value.aspectRatio
                : 16 / 9,
            child: ColoredBox(
              color: Tk.indigoHi,
              child: _ready && controller != null
                  ? VideoPlayer(controller)
                  : const Center(
                      child: Icon(Icons.play_circle_outline_rounded,
                          size: 64, color: Tk.onIndigoSoft),
                    ),
            ),
          ),
        ),
      ),
    );
    final bottom = Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.firstTime) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                color: Tk.green,
                backgroundColor: Tk.indigoHi,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _watched
                  ? 'Xong! Bạn đã nắm động tác.'
                  : 'Xem hết một lượt để nắm động tác.',
              textAlign: TextAlign.center,
              style: Tk.text(14.5,
                  weight: FontWeight.w700, color: Tk.onIndigoSoft),
            ),
            const SizedBox(height: 14),
          ],
          TkButton(
            label: widget.firstTime ? 'Tôi đã hiểu' : 'Đóng',
            tone: TkButtonTone.green,
            onTap: _watched ? _close : null,
          ),
        ],
      ),
    );
    return Scaffold(
      backgroundColor: Tk.indigo,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth > box.maxHeight) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: video,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [top, title, const Spacer(), bottom],
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [top, title, Expanded(child: video), bottom],
            );
          },
        ),
      ),
    );
  }
}
