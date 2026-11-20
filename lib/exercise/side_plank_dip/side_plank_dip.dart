import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';
import '../fault_record.dart';
import '../hold/rep_counted_hold_exercise.dart';

class SidePlankConfig {
  static const double MIN_BODY_ANGLE = 155.0;
  static const double MAX_SHOULDER_ELBOW_OFFSET_RATIO = 0.55;
  static const int MAX_FRAME_DELTA_MS = 250;
}

class _SidePlankPoseFrame {
  const _SidePlankPoseFrame({
    required this.bodyAngle,
    required this.shoulderOffsetRatio,
    required this.hipOffsetRatio,
    required this.bodyStraight,
    required this.shoulderAligned,
    required this.bodyHorizontal,
  });

  final double bodyAngle;
  final double shoulderOffsetRatio;
  final double hipOffsetRatio;
  final bool bodyStraight;
  final bool shoulderAligned;
  final bool bodyHorizontal;

  bool get formClean => bodyStraight && shoulderAligned && bodyHorizontal;
}

/// Static side plank hold.
///
/// The historical class/id is retained so saved sessions and report routing
/// remain compatible, but hip-dip rep counting is intentionally removed.
class SidePlankDip extends RepCountedHoldExercise {
  SidePlankDip({
    required super.maxHolds,
    required super.holdSeconds,
  });

  int get maxSeconds => holdSeconds;

  _SidePlankPoseFrame? _sampledFrame;

  bool _shoulderFaultSeen = false;
  bool _bodyLineFaultSeen = false;
  int _shoulderFaultHolds = 0;
  int _bodyLineFaultHolds = 0;

  // The 1-frame exit gate moves the first faulting frame to `dropping`, where
  // the engine's accumulator does not run, so the engine's `*_seconds` stay 0.
  // Fault time is measured here instead: frame gaps (10-250 ms, as in
  // HoldSecondsAccumulator) that end on a `dropping` frame with the fault.
  // `dropping` lasts until the user is back in position, so these seconds
  // are "time out of line", and include time spent resting out of position
  // (for example kneeling between attempts), not only time spent holding a
  // faulty plank.
  final Map<String, double> _faultSeconds = <String, double>{
    'shoulder_seconds': 0.0,
    'body_line_seconds': 0.0,
  };
  int? _lastMetricFrameMs;

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.portrait,
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Side Plank with Hip Dip';

  @override
  int get holdingDebounceFrames => 1;

  @override
  int get droppingDebounceFrames => 1;

  @override
  String get currentPhaseLabel {
    switch (phase) {
      case HoldPhase.setup:
        return 'Vào tư thế plank nghiêng';
      case HoldPhase.holding:
        return 'Giữ plank nghiêng';
      case HoldPhase.dropping:
        return 'Chỉnh lại tư thế';
      case HoldPhase.resting:
        return 'Nghỉ';
      case HoldPhase.reArming:
        return 'Vào tư thế';
    }
  }

  @override
  List<FaultRecord> get liveFaults {
    final sample = _sampledFrame;
    if (sample == null ||
        (phase != HoldPhase.holding && phase != HoldPhase.dropping)) {
      return const <FaultRecord>[];
    }
    return <FaultRecord>[
      if (!sample.shoulderAligned)
        FaultRecord(
          phase: phase.name,
          type: 'shoulder',
          message: 'Khuỷu tay trụ lệch khỏi vai',
          affectsForm: true,
          priority: 0,
        ),
      if (!sample.bodyStraight)
        FaultRecord(
          phase: phase.name,
          type: 'amplitude',
          message: 'Thân người mất đường thẳng',
          affectsForm: true,
          priority: 2,
        ),
    ];
  }

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      interruptReArm();
      return const GuidanceSignal.turnSide();
    }
    if (_trackedBody(landmarks) == null) {
      interruptActiveHold(interruptedHoldFaultId);
      interruptReArm();
      return const GuidanceSignal.bodyInFrame();
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final body = _trackedBody(landmarks);
    if (body == null) return false;

    final geometry = _geometry(body);
    return geometry.bodyStraight &&
        geometry.shoulderAligned &&
        geometry.bodyHorizontal;
  }

  @override
  Set<String> get faultSecondsKeys => const <String>{
        'shoulder_seconds',
        'body_line_seconds',
      };

  @override
  HoldPoseSample? samplePose(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final body = _trackedBody(landmarks);
    if (body == null) return null;

    final geometry = _geometry(body);
    scaleFactor = geometry.scale;
    final sample = _SidePlankPoseFrame(
      bodyAngle: geometry.bodyAngle,
      shoulderOffsetRatio: geometry.shoulderOffsetRatio,
      hipOffsetRatio: geometry.hipOffsetRatio,
      bodyStraight: geometry.bodyStraight,
      shoulderAligned: geometry.shoulderAligned,
      bodyHorizontal: geometry.bodyHorizontal,
    );
    _sampledFrame = sample;

    return HoldPoseSample(
      insideOuterEntry: sample.formClean,
      outsideOuterExit: !sample.formClean,
    );
  }

  @override
  Map<String, bool> updateFormMetrics() {
    final sample = _sampledFrame!;
    final shoulderFaulting = !sample.shoulderAligned;
    final bodyLineFaulting = !sample.bodyStraight;

    if (phase == HoldPhase.holding || phase == HoldPhase.dropping) {
      _shoulderFaultSeen |= shoulderFaulting;
      _bodyLineFaultSeen |= bodyLineFaulting;
    }

    if (bodyLineFaulting) {
      resultIssues.feedback['Amplitude'] =
          'Nâng hông để vai, hông và cổ chân thành một đường thẳng.';
    }
    if (shoulderFaulting) {
      resultIssues.feedback['Shoulder'] = 'Đặt khuỷu tay trụ ngay dưới vai.';
    }
    debugData['sidePlankBodyAngle'] = sample.bodyAngle;
    // Measurement only (D1/S2): no gate, fault or user-facing text reads it.
    debugData['sidePlankHipOffset'] = sample.hipOffsetRatio;
    debugData['sidePlankShoulderOffset'] = sample.shoulderOffsetRatio;
    debugData['sidePlankHoldSeconds'] = timerMetric.totalHoldingTimeMs / 1000.0;

    final faultingByKey = <String, bool>{
      'shoulder_seconds': shoulderFaulting,
      'body_line_seconds': bodyLineFaulting,
    };
    final previousMs = _lastMetricFrameMs;
    _lastMetricFrameMs = frameTimestampMs;
    if (phase == HoldPhase.dropping && previousMs != null) {
      final dtMs = frameTimestampMs - previousMs;
      if (dtMs >= 10 && dtMs <= 250) {
        for (final entry in faultingByKey.entries) {
          if (entry.value) {
            _faultSeconds[entry.key] = _faultSeconds[entry.key]! + dtMs / 1000;
          }
        }
      }
    }
    return faultingByKey;
  }

  @override
  Map<String, FaultRecord> snapshotHoldFaults() => <String, FaultRecord>{
        if (_shoulderFaultSeen)
          'shoulder': FaultRecord(
            phase: HoldPhase.holding.name,
            type: 'shoulder',
            message: 'Khuỷu tay trụ lệch khỏi vai',
            affectsForm: true,
            priority: 0,
          ),
        if (_bodyLineFaultSeen)
          'amplitude': FaultRecord(
            phase: HoldPhase.holding.name,
            type: 'amplitude',
            message: 'Thân người mất đường thẳng',
            affectsForm: true,
            priority: 2,
          ),
      };

  @override
  void resetFormMetrics({required bool countFaults}) {
    if (countFaults) {
      if (_shoulderFaultSeen) _shoulderFaultHolds += 1;
      if (_bodyLineFaultSeen) _bodyLineFaultHolds += 1;
    }
    _shoulderFaultSeen = false;
    _bodyLineFaultSeen = false;
  }

  @override
  void onHoldPhaseChanged(
    HoldPhase previous,
    HoldPhase next,
    int nowMs,
  ) {}

  @override
  void onHoldSetReset() {
    _sampledFrame = null;
    _shoulderFaultSeen = false;
    _bodyLineFaultSeen = false;
    _shoulderFaultHolds = 0;
    _bodyLineFaultHolds = 0;
    _faultSeconds.updateAll((_, __) => 0.0);
    _lastMetricFrameMs = null;
  }

  @override
  void onSetComplete() {
    final targetSeconds = (maxHolds * holdSeconds).toDouble();
    logger.pushKey('shoulder_align_fails_count', _shoulderFaultHolds);
    logger.pushKey('dip_depth_fails_count', _bodyLineFaultHolds);
    logger.pushKey('total_seconds', targetSeconds);
    logger.pushKey('good_seconds', clampedGoodHoldSeconds(targetSeconds));
    _faultSeconds.forEach(logger.pushKey);
    logger.pushKey('max_rep', maxHolds);
    logger.pushGoodRepCount();
  }

  _SidePlankBody? _trackedBody(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    final required = <PoseLandmark?>[
      leftElbow,
      rightElbow,
      leftShoulder,
      rightShoulder,
      leftHip,
      rightHip,
      leftAnkle,
      rightAnkle,
    ];
    if (required.any((landmark) =>
        landmark == null || !ExerciseBase.isLandmarkConfident(landmark))) {
      return null;
    }

    final isLeftSupport = leftElbow!.y >= rightElbow!.y;
    return _SidePlankBody(
      supportShoulder: isLeftSupport ? leftShoulder! : rightShoulder!,
      supportElbow: isLeftSupport ? leftElbow : rightElbow,
      supportHip: isLeftSupport ? leftHip! : rightHip!,
      supportAnkle: isLeftSupport ? leftAnkle! : rightAnkle!,
    );
  }

  ({
    double scale,
    double bodyAngle,
    double shoulderOffsetRatio,
    double hipOffsetRatio,
    bool bodyStraight,
    bool shoulderAligned,
    bool bodyHorizontal,
  }) _geometry(_SidePlankBody body) {
    final scale = calculateDistance(body.supportShoulder, body.supportHip);
    if (!scale.isFinite || scale <= 1e-6) {
      return (
        scale: 1.0,
        bodyAngle: 0.0,
        shoulderOffsetRatio: double.infinity,
        hipOffsetRatio: 0.0,
        bodyStraight: false,
        shoulderAligned: false,
        bodyHorizontal: false,
      );
    }

    final bodyAngle = calculateAngleNormalized(
      firstPoint: body.supportShoulder,
      midPoint: body.supportHip,
      lastPoint: body.supportAnkle,
    );
    final shoulderOffset =
        (body.supportShoulder.x - body.supportElbow.x).abs() / scale;
    // Shoulder-ankle line closer to horizontal than vertical (a geometric
    // 45 deg): rejects a person standing side-on.
    final dx = body.supportAnkle.x - body.supportShoulder.x;
    final dy = body.supportAnkle.y - body.supportShoulder.y;
    final lineLength = calculateDistance(body.supportShoulder, body.supportAnkle);
    // Signed hip distance from the shoulder-ankle line, in torso lengths,
    // positive when the hip is below the line (larger image y).
    final cross = dx * (body.supportHip.y - body.supportShoulder.y) -
        dy * (body.supportHip.x - body.supportShoulder.x);
    final hipOffset = lineLength > 1e-6
        ? cross / lineLength / scale * (dx < 0 ? -1 : 1)
        : 0.0;
    return (
      scale: scale,
      bodyAngle: bodyAngle,
      shoulderOffsetRatio: shoulderOffset,
      hipOffsetRatio: hipOffset,
      bodyStraight: bodyAngle >= SidePlankConfig.MIN_BODY_ANGLE,
      shoulderAligned:
          shoulderOffset <= SidePlankConfig.MAX_SHOULDER_ELBOW_OFFSET_RATIO,
      bodyHorizontal: dx.abs() > dy.abs(),
    );
  }
}

class _SidePlankBody {
  const _SidePlankBody({
    required this.supportShoulder,
    required this.supportElbow,
    required this.supportHip,
    required this.supportAnkle,
  });

  final PoseLandmark supportShoulder;
  final PoseLandmark supportElbow;
  final PoseLandmark supportHip;
  final PoseLandmark supportAnkle;
}
