import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'vika_pose_landmark.dart';

class PoseDisplaySmoother extends ChangeNotifier {
  PoseDisplaySmoother({
    this.followTimeConstant = const Duration(milliseconds: 25),
    this.maxLead = const Duration(milliseconds: 40),
    this.snapFraction = 0.2,
    this.velocityBlend = 0.6,
  });

  final Duration followTimeConstant;
  final Duration maxLead;
  final double snapFraction;
  final double velocityBlend;

  final Map<PoseLandmarkType, _LandmarkTrack> _tracks =
      <PoseLandmarkType, _LandmarkTrack>{};
  Size _imageSize = Size.zero;
  Duration? _lastTick;
  Pose? _displayPose;

  Pose? get displayPose => _displayPose;

  bool get hasPose => _displayPose != null;

  void setTarget(Pose? pose, Size imageSize, Duration now) {
    if (pose == null || pose.landmarks.isEmpty || imageSize.isEmpty) {
      final hadPose = _displayPose != null;
      _tracks.clear();
      _displayPose = null;
      _lastTick = null;
      if (hadPose) {
        notifyListeners();
      }
      return;
    }
    if (imageSize != _imageSize) {
      _tracks.clear();
      _imageSize = imageSize;
    }
    final snapDistance = snapFraction *
        math.sqrt(imageSize.width * imageSize.width +
            imageSize.height * imageSize.height);
    final seen = <PoseLandmarkType>{};
    for (final landmark in pose.landmarks.values) {
      seen.add(landmark.type);
      final track = _tracks[landmark.type];
      if (track == null) {
        _tracks[landmark.type] = _LandmarkTrack(landmark, now);
      } else {
        track.retarget(
          landmark,
          now,
          snapDistance: snapDistance,
          velocityBlend: velocityBlend,
        );
      }
    }
    _tracks.removeWhere((type, _) => !seen.contains(type));
    _compose();
    notifyListeners();
  }

  void tick(Duration now) {
    final last = _lastTick;
    _lastTick = now;
    if (_tracks.isEmpty || last == null) {
      return;
    }
    final dtSeconds = (now - last).inMicroseconds / 1e6;
    if (dtSeconds <= 0) {
      return;
    }
    final tau = followTimeConstant.inMicroseconds / 1e6;
    final alpha = tau <= 0 ? 1.0 : 1 - math.exp(-dtSeconds / tau);
    final maxLeadSeconds = maxLead.inMicroseconds / 1e6;
    for (final track in _tracks.values) {
      track.advance(now, alpha: alpha, maxLeadSeconds: maxLeadSeconds);
    }
    _compose();
    notifyListeners();
  }

  void _compose() {
    _displayPose = Pose(
      landmarks: <PoseLandmarkType, PoseLandmark>{
        for (final entry in _tracks.entries)
          entry.key: entry.value.toLandmark(entry.key),
      },
    );
  }
}

class _LandmarkTrack {
  _LandmarkTrack(PoseLandmark landmark, this.targetTime)
      : targetX = landmark.x,
        targetY = landmark.y,
        displayX = landmark.x,
        displayY = landmark.y,
        z = landmark.z,
        presence = landmark.presence,
        visibility = landmark.visibility;

  double targetX;
  double targetY;
  double displayX;
  double displayY;
  double velocityX = 0;
  double velocityY = 0;
  double z;
  double presence;
  double visibility;
  Duration targetTime;

  void retarget(
    PoseLandmark landmark,
    Duration now, {
    required double snapDistance,
    required double velocityBlend,
  }) {
    final dt = (now - targetTime).inMicroseconds / 1e6;
    if (dt > 0 && dt < 0.25) {
      final vx = (landmark.x - targetX) / dt;
      final vy = (landmark.y - targetY) / dt;
      velocityX += (vx - velocityX) * velocityBlend;
      velocityY += (vy - velocityY) * velocityBlend;
    } else {
      velocityX = 0;
      velocityY = 0;
    }
    final dx = landmark.x - displayX;
    final dy = landmark.y - displayY;
    if (math.sqrt(dx * dx + dy * dy) > snapDistance) {
      displayX = landmark.x;
      displayY = landmark.y;
      velocityX = 0;
      velocityY = 0;
    }
    targetX = landmark.x;
    targetY = landmark.y;
    z = landmark.z;
    presence = landmark.presence;
    visibility = landmark.visibility;
    targetTime = now;
  }

  void advance(
    Duration now, {
    required double alpha,
    required double maxLeadSeconds,
  }) {
    final sinceTarget = (now - targetTime).inMicroseconds / 1e6;
    final lead = sinceTarget.clamp(0.0, maxLeadSeconds);
    final aimX = targetX + velocityX * lead;
    final aimY = targetY + velocityY * lead;
    displayX += (aimX - displayX) * alpha;
    displayY += (aimY - displayY) * alpha;
  }

  PoseLandmark toLandmark(PoseLandmarkType type) {
    return poseLandmarkWithVikaConfidence(
      type: type,
      x: displayX,
      y: displayY,
      z: z,
      presence: presence,
      visibility: visibility,
    );
  }
}
