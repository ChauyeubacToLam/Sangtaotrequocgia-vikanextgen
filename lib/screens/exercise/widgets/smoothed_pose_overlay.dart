import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../../pose/pose_display_smoother.dart';
import 'pose_overlay_painter.dart';

class SmoothedPoseOverlay extends StatefulWidget {
  const SmoothedPoseOverlay({
    super.key,
    required this.size,
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
    required this.fit,
    this.mirrorHorizontally,
    this.debugData = const <String, dynamic>{},
    this.debugLabelsEnabled = false,
    this.style = SkeletonStyle.vikaCream,
  });

  final Size size;
  final Pose? pose;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;
  final BoxFit fit;
  final bool? mirrorHorizontally;
  final Map<String, dynamic> debugData;
  final bool debugLabelsEnabled;
  final SkeletonStyle style;

  @override
  State<SmoothedPoseOverlay> createState() => _SmoothedPoseOverlayState();
}

class _SmoothedPoseOverlayState extends State<SmoothedPoseOverlay>
    with SingleTickerProviderStateMixin {
  final PoseDisplaySmoother _smoother = PoseDisplaySmoother();
  final Stopwatch _clock = Stopwatch()..start();
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _smoother.tick(_clock.elapsed));
    _retarget();
  }

  @override
  void didUpdateWidget(covariant SmoothedPoseOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.pose, widget.pose) ||
        oldWidget.imageSize != widget.imageSize) {
      _retarget();
    }
  }

  void _retarget() {
    _smoother.setTarget(widget.pose, widget.imageSize, _clock.elapsed);
    if (_smoother.hasPose) {
      if (!_ticker.isActive) {
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _smoother.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: widget.size,
        painter: _SmoothedPosePainter(
          smoother: _smoother,
          imageSize: widget.imageSize,
          rotation: widget.rotation,
          lensDirection: widget.lensDirection,
          fit: widget.fit,
          mirrorHorizontally: widget.mirrorHorizontally,
          debugData: widget.debugData,
          debugLabelsEnabled: widget.debugLabelsEnabled,
          style: widget.style,
        ),
      ),
    );
  }
}

class _SmoothedPosePainter extends CustomPainter {
  _SmoothedPosePainter({
    required this.smoother,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
    required this.fit,
    required this.mirrorHorizontally,
    required this.debugData,
    required this.debugLabelsEnabled,
    required this.style,
  }) : super(repaint: smoother);

  final PoseDisplaySmoother smoother;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;
  final BoxFit fit;
  final bool? mirrorHorizontally;
  final Map<String, dynamic> debugData;
  final bool debugLabelsEnabled;
  final SkeletonStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final pose = smoother.displayPose;
    if (pose == null || imageSize.isEmpty) {
      return;
    }
    PoseOverlayPainter(
      pose: pose,
      imageSize: imageSize,
      rotation: rotation,
      lensDirection: lensDirection,
      fit: fit,
      mirrorHorizontally: mirrorHorizontally,
      debugData: debugData,
      debugLabelsEnabled: debugLabelsEnabled,
      style: style,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _SmoothedPosePainter oldDelegate) {
    return !identical(oldDelegate.smoother, smoother) ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.rotation != rotation ||
        oldDelegate.lensDirection != lensDirection ||
        oldDelegate.fit != fit ||
        oldDelegate.mirrorHorizontally != mirrorHorizontally ||
        oldDelegate.style != style ||
        oldDelegate.debugLabelsEnabled != debugLabelsEnabled ||
        ((oldDelegate.debugLabelsEnabled || debugLabelsEnabled) &&
            !mapEquals(oldDelegate.debugData, debugData));
  }
}
