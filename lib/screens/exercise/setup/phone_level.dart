import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../pose/vika_image_orientation.dart';

const double kLevelPitchMinDeg = -3;
const double kLevelPitchMaxDeg = 9;
const double kLevelRollMaxDeg = 4;
const Duration kLevelHold = Duration(milliseconds: 900);
const Duration kLevelQuickHold = Duration(milliseconds: 400);
const Duration kLevelCelebrate = Duration(milliseconds: 1300);
const Duration kLevelSensorTimeout = Duration(milliseconds: 1500);
const Duration kLevelReuseWindow = Duration(minutes: 15);

const Color _panelBg = Color(0xF21A1612);
const Color _gold = Color(0xFFE3B94F);
const Color _muted = Color(0xFFB9B2A6);

DateTime? lastPhoneLevelConfirmedAt;

class PhoneTilt {
  const PhoneTilt({required this.pitchDeg, required this.rollDeg});

  final double pitchDeg;
  final double rollDeg;
}

PhoneTilt? phoneTiltFromGravity({
  required double x,
  required double y,
  required double z,
  required VikaImageOrientation orientation,
  bool frontCamera = true,
}) {
  final (right, up) = switch (orientation) {
    VikaImageOrientation.landscapeLeft => (-y, x),
    VikaImageOrientation.landscapeRight => (y, -x),
    VikaImageOrientation.portrait => (x, y),
    VikaImageOrientation.portraitUpsideDown => (-x, -y),
  };
  final inPlane = math.sqrt(right * right + up * up);
  if (inPlane < 1e-6 && z.abs() < 1e-6) return null;
  final roll = math.atan2(right, up) * 180 / math.pi;
  final pitch = math.atan2(z, inPlane) * 180 / math.pi;
  return PhoneTilt(pitchDeg: frontCamera ? pitch : -pitch, rollDeg: roll);
}

enum PhoneLevelVerdict {
  tiltedBack('Dựng máy thẳng hơn', 'Đẩy phần dưới điện thoại ra xa bạn thêm chút.'),
  tiltedForward('Máy đang chúi xuống', 'Kéo phần dưới điện thoại lại gần bạn thêm chút.'),
  rolled('Đặt máy cho cân', 'Chỉnh để cạnh dài của máy nằm ngang với sàn.'),
  level('Chuẩn rồi', 'Giữ nguyên nhé…');

  const PhoneLevelVerdict(this.title, this.body);

  final String title;
  final String body;
}

PhoneLevelVerdict judgePhoneLevel(PhoneTilt tilt) {
  if (tilt.pitchDeg > kLevelPitchMaxDeg) return PhoneLevelVerdict.tiltedBack;
  if (tilt.pitchDeg < kLevelPitchMinDeg) return PhoneLevelVerdict.tiltedForward;
  if (tilt.rollDeg.abs() > kLevelRollMaxDeg) return PhoneLevelVerdict.rolled;
  return PhoneLevelVerdict.level;
}

class PhoneLevelPanel extends StatefulWidget {
  const PhoneLevelPanel({
    super.key,
    required this.orientation,
    required this.frontCamera,
    required this.onDone,
    this.placementLine,
    this.source,
  });

  final VikaImageOrientation orientation;
  final bool frontCamera;
  final VoidCallback onDone;
  final String? placementLine;
  final Stream<AccelerometerEvent>? source;

  @override
  State<PhoneLevelPanel> createState() => _PhoneLevelPanelState();
}

class _PhoneLevelPanelState extends State<PhoneLevelPanel> {
  StreamSubscription<AccelerometerEvent>? _sub;
  Timer? _sensorTimeout;
  Timer? _finish;
  double? _x;
  double? _y;
  double? _z;
  DateTime? _levelSince;
  bool _done = false;
  bool _finished = false;

  bool get _recentlyConfirmed {
    final at = lastPhoneLevelConfirmedAt;
    return at != null && DateTime.now().difference(at) < kLevelReuseWindow;
  }

  @override
  void initState() {
    super.initState();
    final stream = widget.source ??
        accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval);
    _sub = stream.listen(_onEvent, onError: (_) => _complete());
    _sensorTimeout = Timer(kLevelSensorTimeout, () {
      if (_x == null) _complete();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sensorTimeout?.cancel();
    _finish?.cancel();
    super.dispose();
  }

  void _onEvent(AccelerometerEvent e) {
    if (_done) return;
    const alpha = 0.2;
    _x = _x == null ? e.x : _x! + alpha * (e.x - _x!);
    _y = _y == null ? e.y : _y! + alpha * (e.y - _y!);
    _z = _z == null ? e.z : _z! + alpha * (e.z - _z!);
    final tilt = _tilt;
    if (tilt == null) return;
    final now = DateTime.now();
    if (judgePhoneLevel(tilt) == PhoneLevelVerdict.level) {
      _levelSince ??= now;
      final hold = _recentlyConfirmed ? kLevelQuickHold : kLevelHold;
      if (now.difference(_levelSince!) >= hold) {
        _done = true;
        final celebrate = _recentlyConfirmed ? Duration.zero : kLevelCelebrate;
        lastPhoneLevelConfirmedAt = now;
        _finish = Timer(celebrate, _complete);
      }
    } else {
      _levelSince = null;
    }
    if (mounted) setState(() {});
  }

  void _complete() {
    if (_finished) return;
    _finished = true;
    _sub?.cancel();
    widget.onDone();
  }

  PhoneTilt? get _tilt {
    if (_x == null) return null;
    return phoneTiltFromGravity(
      x: _x!,
      y: _y!,
      z: _z!,
      orientation: widget.orientation,
      frontCamera: widget.frontCamera,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tilt = _tilt;
    final verdict = tilt == null ? null : judgePhoneLevel(tilt);
    final aligned = _done || verdict == PhoneLevelVerdict.level;
    final title = _done ? 'Tuyệt vời!' : (verdict?.title ?? 'Đặt máy dựng thẳng');
    final body = _done
        ? 'Máy đã đứng chuẩn, bắt đầu thôi!'
        : (verdict?.body ?? 'Đặt máy nằm ngang, tựa chắc vào tường hoặc giá đỡ.');
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: aligned ? _gold : Colors.white24, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 190,
            height: 130,
            child: CustomPaint(
              painter: _LevelPainter(
                rollDeg: tilt?.rollDeg ?? 0,
                pitchDeg: tilt?.pitchDeg ?? 0,
                aligned: aligned,
                done: _done,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CĂN CHỈNH MÁY',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Container(width: 28, height: 2, color: _gold),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(color: _muted, fontSize: 15, height: 1.35),
                ),
                if (widget.placementLine != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.placementLine!,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
                if (!_done)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _complete,
                      style: TextButton.styleFrom(foregroundColor: _muted),
                      child: const Text('Bỏ qua'),
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

class _LevelPainter extends CustomPainter {
  _LevelPainter({
    required this.rollDeg,
    required this.pitchDeg,
    required this.aligned,
    required this.done,
  });

  final double rollDeg;
  final double pitchDeg;
  final bool aligned;
  final bool done;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final phone = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: size.width * 0.62, height: size.height * 0.56),
      const Radius.circular(14),
    );
    final lineColor = aligned ? _gold : Colors.white70;
    if (aligned) {
      canvas.drawRRect(
        phone.inflate(3),
        Paint()
          ..color = _gold.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    canvas.drawRRect(phone, Paint()..color = Colors.white.withValues(alpha: 0.05));
    canvas.drawRRect(
      phone,
      Paint()
        ..color = aligned ? _gold : Colors.white38
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final tickPaint = Paint()
      ..color = aligned ? _gold : Colors.white38
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, center.dy), Offset(size.width * 0.12, center.dy), tickPaint);
    canvas.drawLine(
      Offset(size.width * 0.88, center.dy),
      Offset(size.width, center.dy),
      tickPaint,
    );
    final offsetY = (pitchDeg * 2.2).clamp(-size.height * 0.42, size.height * 0.42);
    canvas.save();
    canvas.translate(center.dx, center.dy - offsetY);
    canvas.rotate(rollDeg * math.pi / 180);
    final half = size.width * 0.44;
    canvas.drawLine(
      Offset(-half, 0),
      Offset(half, 0),
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset.zero, 5, Paint()..color = lineColor);
    canvas.restore();
    if (done) {
      canvas.drawCircle(center.translate(0, size.height * 0.08), 18, Paint()..color = _gold);
      final check = Path()
        ..moveTo(center.dx - 8, center.dy + size.height * 0.08)
        ..lineTo(center.dx - 2, center.dy + size.height * 0.08 + 6)
        ..lineTo(center.dx + 9, center.dy + size.height * 0.08 - 6);
      canvas.drawPath(
        check,
        Paint()
          ..color = const Color(0xFF1A1612)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_LevelPainter old) =>
      old.rollDeg != rollDeg ||
      old.pitchDeg != pitchDeg ||
      old.aligned != aligned ||
      old.done != done;
}
