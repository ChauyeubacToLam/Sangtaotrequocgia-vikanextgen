import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/rep_replay.dart';
import 'tk/tk.dart';

typedef ReplayClipLoader = Future<Map<String, dynamic>?> Function(String id);

ReplayClipLoader cachedClipLoader(ReplayClipLoader load) {
  final cache = <String, Future<Map<String, dynamic>?>>{};
  return (id) => cache.putIfAbsent(id, () => load(id));
}

class RepReplayCard extends StatelessWidget {
  const RepReplayCard({
    super.key,
    required this.goodRep,
    required this.faultReps,
    required this.loadClip,
  });

  final RepReplayEntry? goodRep;
  final List<RepReplayEntry> faultReps;
  final ReplayClipLoader loadClip;

  @override
  Widget build(BuildContext context) {
    final good = goodRep;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Tk.line, width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('XEM LẠI REP', style: Tk.eyebrow()),
          for (final fault in faultReps) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: good == null
                      ? const _NoGoodRep()
                      : _ClipTile(
                          entry: good,
                          loadClip: loadClip,
                          color: Tk.green,
                          captionColor: Tk.greenInk,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ClipTile(
                    entry: fault,
                    loadClip: loadClip,
                    color: Tk.orange,
                    captionColor: Tk.orangeInk,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NoGoodRep extends StatelessWidget {
  const _NoGoodRep();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Hiệp này chưa có rep đúng để so sánh',
          textAlign: TextAlign.center,
          style: Tk.text(12.5, weight: FontWeight.w800, color: Tk.inkSoft),
        ),
      ),
    );
  }
}

class _ClipTile extends StatelessWidget {
  const _ClipTile({
    required this.entry,
    required this.loadClip,
    required this.color,
    required this.captionColor,
  });

  final RepReplayEntry entry;
  final ReplayClipLoader loadClip;
  final Color color;
  final Color captionColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepClipPlayer(
          key: ValueKey('${entry.clipId}-${entry.repNumber}'),
          clipId: entry.clipId,
          loadClip: loadClip,
          borderColor: color,
        ),
        const SizedBox(height: 4),
        Text(
          entry.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Tk.text(12.5, weight: FontWeight.w900, color: captionColor),
        ),
      ],
    );
  }
}

class RepClipPlayer extends StatefulWidget {
  const RepClipPlayer({
    super.key,
    required this.clipId,
    required this.loadClip,
    required this.borderColor,
  });

  static const double slowMotion = 1.0;
  static const int endPauseMs = 500;

  final String clipId;
  final ReplayClipLoader loadClip;
  final Color borderColor;

  @override
  State<RepClipPlayer> createState() => _RepClipPlayerState();
}

class _RepClipPlayerState extends State<RepClipPlayer> {
  final List<ui.Image> _frames = <ui.Image>[];
  List<int> _timestamps = const <int>[];
  double _aspect = 4 / 3;
  bool _mirrored = false;
  bool _loading = true;
  int _index = 0;
  Timer? _timer;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final clip = await widget.loadClip(widget.clipId);
    final rawFrames = clip?['frames'];
    if (rawFrames is List) {
      for (final bytes in rawFrames) {
        if (_disposed) break;
        if (bytes is! Uint8List) continue;
        try {
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          codec.dispose();
          if (_disposed) {
            frame.image.dispose();
            break;
          }
          _frames.add(frame.image);
        } catch (_) {}
      }
      final rawTimes = clip?['timestampsMs'];
      _timestamps = rawTimes is List
          ? rawTimes.map((t) => (t as num).toInt()).toList()
          : const <int>[];
      final width = (clip?['width'] as num?)?.toDouble();
      final height = (clip?['height'] as num?)?.toDouble();
      if (width != null && height != null && width > 0 && height > 0) {
        _aspect = width / height;
      }
      _mirrored = clip?['mirrored'] == true;
    }
    if (_disposed) {
      _disposeFrames();
      return;
    }
    setState(() => _loading = false);
    _scheduleNext();
  }

  void _scheduleNext() {
    if (_disposed || _frames.length < 2) return;
    final i = _index;
    final last = i >= _frames.length - 1;
    final gapMs = last
        ? RepClipPlayer.endPauseMs
        : (i + 1 < _timestamps.length
                ? math.max(60, _timestamps[i + 1] - _timestamps[i])
                : 100) *
            RepClipPlayer.slowMotion;
    _timer = Timer(Duration(milliseconds: gapMs.round()), () {
      if (_disposed) return;
      setState(() => _index = last ? 0 : i + 1);
      _scheduleNext();
    });
  }

  void _disposeFrames() {
    for (final image in _frames) {
      image.dispose();
    }
    _frames.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _disposeFrames();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_loading) {
      body = const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    } else if (_frames.isEmpty) {
      body = Center(
        child: Text(
          'Không có hình',
          style: Tk.text(12.5, weight: FontWeight.w800, color: Tk.inkSoft),
        ),
      );
    } else {
      body = Transform.flip(
        flipX: _mirrored,
        child: RawImage(
          image: _frames[_index.clamp(0, _frames.length - 1)],
          fit: BoxFit.cover,
        ),
      );
    }
    return AspectRatio(
      aspectRatio: _aspect,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1B2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.borderColor, width: 3),
        ),
        clipBehavior: Clip.antiAlias,
        child: body,
      ),
    );
  }
}
