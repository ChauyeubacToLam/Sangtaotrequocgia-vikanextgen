import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../models/pain_regions.dart';

class BodyPart3D {
  const BodyPart3D(
    this.label,
    this.region,
    this.x,
    this.y,
    this.z,
    this.rx,
    this.ry,
    this.rz,
  );

  final String label;
  final String? region;
  final double x;
  final double y;
  final double z;
  final double rx;
  final double ry;
  final double rz;

  String get displayLabel => region == null ? label : painRegionLabel(region!);
}

List<BodyPart3D> bodyParts3D(BodyGender gender) {
  final female = gender == BodyGender.female;
  final sh = female ? 0.165 : 0.19;
  final hip = female ? 0.185 : 0.165;
  final parts = <BodyPart3D>[
    const BodyPart3D('Đầu', null, 0, 1.62, 0, 0.092, 0.112, 0.102),
    const BodyPart3D('Cổ', 'shoulder_neck', 0, 1.475, 0, 0.05, 0.06, 0.05),
    BodyPart3D('Ngực', null, 0, 1.26, 0.035, sh - 0.02, 0.14, 0.085),
    BodyPart3D('Lưng trên', 'back', 0, 1.27, -0.035, sh - 0.02, 0.15, 0.085),
    const BodyPart3D('Bụng', null, 0, 1.04, 0.03, 0.135, 0.12, 0.08),
    const BodyPart3D(
        'Lưng dưới', 'lower_back', 0, 1.04, -0.035, 0.135, 0.12, 0.08),
    BodyPart3D('Hông', 'hip', 0, 0.9, 0, hip, 0.095, 0.105),
  ];
  for (final s in const [-1.0, 1.0]) {
    parts.addAll([
      BodyPart3D('Vai', 'shoulder_neck', s * sh, 1.385, 0, 0.075, 0.065, 0.07),
      BodyPart3D(
          'Bắp tay', null, s * (sh + 0.035), 1.22, 0, 0.052, 0.14, 0.052),
      BodyPart3D(
          'Khuỷu tay', null, s * (sh + 0.05), 1.06, 0, 0.045, 0.045, 0.045),
      BodyPart3D(
          'Cẳng tay', null, s * (sh + 0.06), 0.92, 0.015, 0.042, 0.12, 0.042),
      BodyPart3D('Cổ tay', 'wrist', s * (sh + 0.065), 0.785, 0.02, 0.036, 0.036,
          0.034),
      BodyPart3D('Bàn tay', 'wrist', s * (sh + 0.068), 0.715, 0.025, 0.034,
          0.055, 0.022),
      BodyPart3D('Hông', 'hip', s * 0.095, 0.84, 0, 0.085, 0.08, 0.09),
      BodyPart3D('Đùi', null, s * 0.095, 0.66, 0, 0.075, 0.19, 0.08),
      BodyPart3D('Đầu gối', 'knee', s * 0.093, 0.46, 0.012, 0.058, 0.055, 0.06),
      BodyPart3D('Cẳng chân', null, s * 0.09, 0.28, -0.005, 0.05, 0.16, 0.055),
      BodyPart3D('Cổ chân', 'ankle', s * 0.09, 0.1, 0, 0.045, 0.045, 0.045),
      BodyPart3D('Bàn chân', 'ankle', s * 0.09, 0.04, 0.05, 0.045, 0.035, 0.1),
    ]);
  }
  return parts;
}

class ProjectedPart {
  const ProjectedPart(this.part, this.rect, this.depth);

  final BodyPart3D part;
  final Rect rect;
  final double depth;

  bool contains(Offset p) {
    final c = rect.center;
    final dx = (p.dx - c.dx) / (rect.width / 2);
    final dy = (p.dy - c.dy) / (rect.height / 2);
    return dx * dx + dy * dy <= 1;
  }
}

List<ProjectedPart> projectBody(
  List<BodyPart3D> parts,
  double yaw,
  Size size,
) {
  final scale = size.height / 1.82;
  final c = math.cos(yaw);
  final s = math.sin(yaw);
  final out = <ProjectedPart>[
    for (final p in parts)
      () {
        final x = p.x * c + p.z * s;
        final z = -p.x * s + p.z * c;
        final persp = 1 + z * 0.35;
        final rx = math.sqrt(p.rx * p.rx * c * c + p.rz * p.rz * s * s);
        final center = Offset(
          size.width / 2 + x * scale * persp,
          size.height - (p.y + 0.03) * scale,
        );
        return ProjectedPart(
          p,
          Rect.fromCenter(
            center: center,
            width: rx * 2 * scale * persp,
            height: p.ry * 2 * scale * persp,
          ),
          z,
        );
      }(),
  ]..sort((a, b) => a.depth.compareTo(b.depth));
  return out;
}

BodyPart3D? hitBodyPart(List<ProjectedPart> projected, Offset point) {
  for (final p in projected.reversed) {
    if (p.contains(point)) return p.part;
  }
  for (final p in projected.reversed) {
    if (ProjectedPart(p.part, p.rect.inflate(10), p.depth).contains(point)) {
      return p.part;
    }
  }
  return null;
}

class Body3DPicker extends StatefulWidget {
  const Body3DPicker({
    super.key,
    required this.gender,
    required this.height,
    required this.colorFor,
    required this.onTapPart,
  });

  final BodyGender gender;
  final double height;
  final Color? Function(BodyPart3D part) colorFor;
  final void Function(BodyPart3D part) onTapPart;

  @override
  State<Body3DPicker> createState() => _Body3DPickerState();
}

class _Body3DPickerState extends State<Body3DPicker>
    with SingleTickerProviderStateMixin {
  static const _rest = -0.35;
  late final AnimationController _yaw =
      AnimationController.unbounded(vsync: this, value: _rest - math.pi * 2);
  late List<BodyPart3D> _parts = bodyParts3D(widget.gender);
  BodyPart3D? _pressed;

  @override
  void initState() {
    super.initState();
    _yaw.animateTo(
      _rest,
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(Body3DPicker old) {
    super.didUpdateWidget(old);
    if (old.gender != widget.gender) _parts = bodyParts3D(widget.gender);
  }

  @override
  void dispose() {
    _yaw.dispose();
    super.dispose();
  }

  Size get _size => Size(widget.height * 0.62, widget.height);

  void _turnTo(double target) {
    var diff = (target - _yaw.value) % (math.pi * 2);
    if (diff > math.pi) diff -= math.pi * 2;
    _yaw.animateTo(
      _yaw.value + diff,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  void _tap(Offset local) {
    final part = hitBodyPart(projectBody(_parts, _yaw.value, _size), local);
    if (part == null) return;
    HapticFeedback.selectionClick();
    setState(() => _pressed = part);
    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _pressed = null);
    });
    widget.onTapPart(part);
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Hình cơ thể 3D. Kéo ngang để xoay, chạm vào vùng đau.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _yaw.stop(),
            onHorizontalDragUpdate: (d) => _yaw.value += d.delta.dx * 0.013,
            onHorizontalDragEnd: (d) => _yaw.animateWith(
              FrictionSimulation(
                0.08,
                _yaw.value,
                d.velocity.pixelsPerSecond.dx * 0.013,
              ),
            ),
            onTapUp: (d) => _tap(d.localPosition),
            child: SizedBox.fromSize(
              size: size,
              child: CustomPaint(
                painter: _BodyPainter(
                  parts: _parts,
                  yaw: _yaw,
                  colorFor: widget.colorFor,
                  pressed: _pressed,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TurnChip(label: 'Trước', onTap: () => _turnTo(0)),
            const SizedBox(width: 8),
            _TurnChip(label: 'Nghiêng', onTap: () => _turnTo(-math.pi / 2)),
            const SizedBox(width: 8),
            _TurnChip(label: 'Sau', onTap: () => _turnTo(math.pi)),
          ],
        ),
      ],
    );
  }
}

class _TurnChip extends StatelessWidget {
  const _TurnChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'BeVietnamPro',
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE9E4F7),
            ),
          ),
        ),
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.parts,
    required this.yaw,
    required this.colorFor,
    required this.pressed,
  }) : super(repaint: yaw);

  final List<BodyPart3D> parts;
  final Animation<double> yaw;
  final Color? Function(BodyPart3D part) colorFor;
  final BodyPart3D? pressed;

  static const _light = Color(0xFFF6F2EA);
  static const _base = Color(0xFFCFC7DA);
  static const _dark = Color(0xFF6E6788);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / 1.82;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height - 0.02 * scale),
        width: size.width * 0.62,
        height: 0.07 * scale,
      ),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x66000000), Color(0x00000000)],
        ).createShader(Rect.fromCenter(
          center: Offset(size.width / 2, size.height - 0.02 * scale),
          width: size.width * 0.62,
          height: 0.07 * scale,
        )),
    );
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x33000000);
    for (final p in projectBody(parts, yaw.value, size)) {
      final mark = colorFor(p.part);
      final isPressed = identical(p.part, pressed);
      final base = mark ?? (isPressed ? const Color(0xFFFFD27A) : _base);
      final light = Color.lerp(base, _light, mark == null ? 0.75 : 0.45)!;
      final dark = Color.lerp(base, _dark, mark == null ? 0.7 : 0.35)!;
      canvas.drawOval(
        p.rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.45),
            radius: 1.05,
            colors: [light, base, dark],
            stops: const [0, 0.5, 1],
          ).createShader(p.rect),
      );
      canvas.drawOval(p.rect, outline);
      if (mark != null) {
        canvas.drawOval(
          p.rect.inflate(1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.75),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.parts != parts || old.colorFor != colorFor || old.pressed != pressed;
}
