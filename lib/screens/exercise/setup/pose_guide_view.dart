import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';

import 'pose_guides.dart';

const Color _gold = Color(0xFFE3B94F);
const Color _ink = Color(0xFF141110);
const Color _muted = Color(0xFFB9B2A6);

final Map<String, Future<ui.Image?>> _imageCache = <String, Future<ui.Image?>>{};
final Map<String, Future<Map<PoseGuideJoint, Offset>>> _jointCache =
    <String, Future<Map<PoseGuideJoint, Offset>>>{};
Future<Set<String>>? _bundled;

Future<Set<String>> _bundledAssets() => _bundled ??= _listBundledAssets();

Future<Set<String>> _listBundledAssets() async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest.listAssets().toSet();
  } catch (_) {
    return <String>{};
  }
}

Future<ui.Image?> loadPoseGuideImage(PoseGuide guide) =>
    _imageCache[guide.asset] ??= _loadImage(guide.asset);

Future<ui.Image?> _loadImage(String asset) async {
  try {
    if (!(await _bundledAssets()).contains(asset)) return null;
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    return (await codec.getNextFrame()).image;
  } catch (_) {
    return null;
  }
}

Future<Map<PoseGuideJoint, Offset>> loadPoseGuideJoints(PoseGuide guide) =>
    _jointCache[guide.asset] ??= _detectJoints(guide);

Future<Map<PoseGuideJoint, Offset>> _detectJoints(PoseGuide guide) async {
  final image = await loadPoseGuideImage(guide);
  if (image == null) return const <PoseGuideJoint, Offset>{};
  PoseDetector? detector;
  try {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF8A8A8A));
    canvas.drawImage(image, Offset.zero, Paint());
    final flat = await recorder.endRecording().toImage(image.width, image.height);
    final png = await flat.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) return const <PoseGuideJoint, Offset>{};
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/pose_guide_${guide.catalogId}.png');
    await file.writeAsBytes(
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        flush: true);
    detector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.single,
        model: PoseDetectionModel.accurate,
      ),
    );
    final poses = await detector.processImage(InputImage.fromFilePath(file.path));
    if (poses.isEmpty) return const <PoseGuideJoint, Offset>{};
    final landmarks = poses.first.landmarks;
    final joints = <PoseGuideJoint, Offset>{};
    for (final joint in PoseGuideJoint.values) {
      final a = landmarks[joint.left];
      final b = landmarks[joint.right];
      final pick = a == null ? b : (b == null || a.likelihood >= b.likelihood ? a : b);
      if (pick != null) joints[joint] = Offset(pick.x / w, pick.y / h);
    }
    return joints;
  } catch (_) {
    return const <PoseGuideJoint, Offset>{};
  } finally {
    await detector?.close();
  }
}

Rect poseGuideBox(PoseGuideFrame frame, Rect preview) {
  final (widthFactor, heightFactor, bottomFactor) = switch (frame) {
    PoseGuideFrame.standing => (0.42, 0.80, 0.95),
    PoseGuideFrame.floor => (0.80, 0.48, 0.93),
    PoseGuideFrame.seated => (0.58, 0.60, 0.93),
  };
  final w = preview.width * widthFactor;
  final h = preview.height * heightFactor;
  final bottom = preview.top + preview.height * bottomFactor;
  return Rect.fromLTWH(preview.center.dx - w / 2, bottom - h, w, h);
}

Rect _fitBottom(Size image, Rect box) {
  final fitted = applyBoxFit(BoxFit.contain, image, box.size).destination;
  return Alignment.bottomCenter.inscribe(fitted, box);
}

class PoseSilhouetteOverlay extends StatelessWidget {
  const PoseSilhouetteOverlay({
    super.key,
    required this.guide,
    required this.previewAspect,
    required this.fit,
    this.dimmed = false,
  });

  final PoseGuide guide;
  final double previewAspect;
  final BoxFit fit;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: dimmed ? 0.35 : 1,
        duration: const Duration(milliseconds: 300),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final view = constraints.biggest;
            final fitted = applyBoxFit(fit, Size(previewAspect, 1), view).destination;
            final preview = Alignment.center.inscribe(fitted, Offset.zero & view);
            final box = poseGuideBox(guide.frame, preview);
            return FutureBuilder<ui.Image?>(
              future: loadPoseGuideImage(guide),
              builder: (context, snap) => CustomPaint(
                size: view,
                painter: _SilhouettePainter(
                  image: snap.data,
                  box: box,
                  preview: preview,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter({required this.image, required this.box, required this.preview});

  final ui.Image? image;
  final Rect box;
  final Rect preview;

  @override
  void paint(Canvas canvas, Size size) {
    final ground = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.5;
    final groundLeft = math.max(preview.left, 0.0) + 12;
    final groundRight = math.min(preview.right, size.width) - 12;
    canvas.drawLine(Offset(groundLeft, box.bottom), Offset(groundRight, box.bottom), ground);
    canvas.drawCircle(Offset(groundRight, box.bottom), 6, ground..style = PaintingStyle.stroke);
    _brackets(canvas, box.inflate(14));
    final img = image;
    if (img == null) return;
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final dst = _fitBottom(src.size, box);
    canvas.drawImageRect(
      img,
      src,
      dst,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..filterQuality = FilterQuality.medium,
    );
    const stroke = 4.0;
    canvas.saveLayer(dst.inflate(stroke * 2), Paint());
    final tint = Paint()..colorFilter = const ColorFilter.mode(_gold, BlendMode.srcIn);
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8;
      canvas.drawImageRect(img, src, dst.shift(Offset(math.cos(a), math.sin(a)) * stroke), tint);
    }
    canvas.drawImageRect(img, src, dst, Paint()..blendMode = BlendMode.dstOut);
    canvas.restore();
  }

  void _brackets(Canvas canvas, Rect r) {
    final paint = Paint()
      ..color = _gold.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final arm = math.min(r.width, r.height) * 0.16;
    const radius = 18.0;
    for (final corner in <(Offset, double, double)>[
      (r.topLeft, 1, 1),
      (r.topRight, -1, 1),
      (r.bottomLeft, 1, -1),
      (r.bottomRight, -1, -1),
    ]) {
      final (p, sx, sy) = corner;
      final path = Path()
        ..moveTo(p.dx, p.dy + sy * (arm + radius))
        ..lineTo(p.dx, p.dy + sy * radius)
        ..quadraticBezierTo(p.dx, p.dy, p.dx + sx * radius, p.dy)
        ..lineTo(p.dx + sx * (arm + radius), p.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SilhouettePainter old) =>
      old.image != image || old.box != box || old.preview != preview;
}

class PoseGuideChip extends StatelessWidget {
  const PoseGuideChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: _gold.withValues(alpha: 0.7)),
    );
    return Material(
      color: _ink.withValues(alpha: 0.88),
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  '?',
                  style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Xem tư thế mẫu',
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModelPoseSheet extends StatefulWidget {
  const ModelPoseSheet({
    super.key,
    required this.guide,
    required this.exerciseName,
    required this.landscape,
    required this.onClose,
  });

  final PoseGuide guide;
  final String exerciseName;
  final bool landscape;
  final VoidCallback onClose;

  @override
  State<ModelPoseSheet> createState() => _ModelPoseSheetState();
}

class _ModelPoseSheetState extends State<ModelPoseSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  late final Future<(ui.Image?, Map<PoseGuideJoint, Offset>)> _data = () async {
    final image = await loadPoseGuideImage(widget.guide);
    final joints = await loadPoseGuideJoints(widget.guide);
    return (image, joints);
  }();
  int _step = 0;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = _Header(
      subtitle: widget.guide.subtitle,
      onClose: widget.onClose,
    );
    final figure = _figure();
    final card = _StepCard(
      steps: widget.guide.steps,
      index: _step,
      onPrev: _step > 0 ? () => setState(() => _step--) : null,
      onNext: _step < widget.guide.steps.length - 1
          ? () => setState(() => _step++)
          : widget.onClose,
      lastLabel: 'Đã hiểu',
    );
    return Material(
      color: _ink.withValues(alpha: 0.97),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: widget.landscape
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 11, child: figure),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 9,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [header, const Spacer(), card],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [header, Expanded(child: figure), card],
                ),
        ),
      ),
    );
  }

  Widget _figure() {
    return FutureBuilder<(ui.Image?, Map<PoseGuideJoint, Offset>)>(
      future: _data,
      builder: (context, snap) {
        final image = snap.data?.$1;
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(color: _gold));
        }
        if (image == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.accessibility_new_rounded, color: _gold, size: 64),
                const SizedBox(height: 12),
                Text(
                  widget.exerciseName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        }
        final joints = snap.data!.$2;
        final active = widget.guide.steps[_step].joint;
        return AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) => CustomPaint(
            painter: _FigurePainter(
              image: image,
              joints: joints,
              stepJoints: [for (final s in widget.guide.steps) s.joint],
              active: active,
              pulse: _pulse.value,
              leaderToRight: widget.landscape,
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.subtitle, required this.onClose});

  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tư thế mẫu',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: _muted, fontSize: 16)),
            ],
          ),
        ),
        InkWell(
          onTap: onClose,
          customBorder: const CircleBorder(),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.steps,
    required this.index,
    required this.onPrev,
    required this.onNext,
    required this.lastLabel,
  });

  final List<PoseGuideStep> steps;
  final int index;
  final VoidCallback? onPrev;
  final VoidCallback onNext;
  final String lastLabel;

  @override
  Widget build(BuildContext context) {
    final last = index == steps.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF221D18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= index ? _gold : Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (i < steps.length - 1) const SizedBox(width: 6),
              ],
              const SizedBox(width: 16),
              _RoundButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
              const SizedBox(width: 10),
              last
                  ? FilledButton(
                      onPressed: onNext,
                      style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: _ink,
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(lastLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                    )
                  : _RoundButton(icon: Icons.chevron_right_rounded, onTap: onNext),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            steps[index].text,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: onTap == null ? Colors.white24 : Colors.white, size: 30),
      ),
    );
  }
}

class _FigurePainter extends CustomPainter {
  _FigurePainter({
    required this.image,
    required this.joints,
    required this.stepJoints,
    required this.active,
    required this.pulse,
    required this.leaderToRight,
  });

  final ui.Image image;
  final Map<PoseGuideJoint, Offset> joints;
  final List<PoseGuideJoint> stepJoints;
  final PoseGuideJoint active;
  final double pulse;
  final bool leaderToRight;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Alignment.center.inscribe(
      applyBoxFit(BoxFit.contain, src.size, size).destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(image, src, dst, Paint()..filterQuality = FilterQuality.medium);
    Offset? at(PoseGuideJoint j) {
      final n = joints[j];
      if (n == null) return null;
      return Offset(dst.left + n.dx * dst.width, dst.top + n.dy * dst.height);
    }

    final activePoint = at(active);
    if (activePoint != null) {
      final end = leaderToRight
          ? Offset(size.width, activePoint.dy)
          : Offset(activePoint.dx, size.height);
      canvas.drawLine(
        activePoint,
        end,
        Paint()
          ..color = _gold.withValues(alpha: 0.85)
          ..strokeWidth = 2,
      );
      canvas.drawCircle(end, 5, Paint()..color = _gold);
    }
    for (final j in stepJoints.toSet()) {
      final p = at(j);
      if (p == null || j == active) continue;
      canvas.drawCircle(p, 9, Paint()..color = _ink);
      canvas.drawCircle(p, 7, Paint()..color = _gold.withValues(alpha: 0.85));
    }
    if (activePoint != null) {
      canvas.drawCircle(
        activePoint,
        16 + 22 * pulse,
        Paint()
          ..color = _gold.withValues(alpha: 0.45 * (1 - pulse))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(activePoint, 14, Paint()..color = _ink);
      canvas.drawCircle(activePoint, 11, Paint()..color = _gold);
    }
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.pulse != pulse || old.active != active || old.joints != joints || old.image != image;
}
