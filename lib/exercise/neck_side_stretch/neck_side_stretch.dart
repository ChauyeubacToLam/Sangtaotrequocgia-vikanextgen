import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../utils/debouncer.dart';
import '../exercise_base.dart';
import '../fault_record.dart';
import '../hold/rep_counted_hold_exercise.dart';

class NeckStretchConfig {
  static const double ENTRY_TILT_MIN = 25.0;
  static const double EXIT_TILT_MAX = 18.0;
  static const double START_TILT_MAX = 10.0;
  static const double SHOULDER_TILT_MAX = 10.0;
  static const double SHRUG_RISE_MAX = 0.08;
  static const double TILT_SMOOTHING = 0.35;
  static const double TILT_JUMP_MAX = 25.0;
  static const int TILT_JUMP_FRAMES_MAX = 2;
  static const int MISSING_HEAD_FRAMES_MAX = 6;
  static const int FAULT_FRAMES = 6;
}

enum NeckSide { left, right }

class _NeckFrame {
  const _NeckFrame({
    required this.tilt,
    required this.side,
    required this.shoulderTilt,
    required this.shrugRise,
    required this.shoulderLeaning,
    required this.shrugging,
  });

  final double tilt;
  final NeckSide side;
  final double shoulderTilt;
  final double? shrugRise;
  final bool shoulderLeaning;
  final bool shrugging;
}

class NeckSideStretch extends RepCountedHoldExercise {
  NeckSideStretch({
    required super.maxHolds,
    required super.holdSeconds,
  });

  double? _smoothedTilt;
  int _missingHeadFrames = 0;
  int _jumpFrames = 0;
  double _baselineShoulderAngle = 0.0;
  double? _baselineShoulderHipGap;

  _NeckFrame? _frame;
  NeckSide? _holdSide;
  NeckSide? _lastHoldSide;
  double _holdMaxTilt = 0.0;

  bool _shrugSeen = false;
  bool _shoulderSeen = false;
  int _shrugHolds = 0;
  int _shoulderHolds = 0;

  final Debouncer _shrugDebouncer =
      Debouncer(requiredFrames: NeckStretchConfig.FAULT_FRAMES);
  final Debouncer _shoulderDebouncer =
      Debouncer(requiredFrames: NeckStretchConfig.FAULT_FRAMES);

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Neck Side Stretch';

  @override
  int get droppingDebounceFrames => 3;

  NeckSide? get holdSide => _holdSide;

  @override
  String get currentPhaseLabel => switch (phase) {
        HoldPhase.setup => 'Nghiêng đầu về một bên',
        HoldPhase.holding => 'Giữ nghiêng đầu',
        HoldPhase.dropping => 'Chỉnh lại tư thế',
        HoldPhase.resting => 'Nghỉ',
        HoldPhase.reArming => 'Đổi bên',
      };

  @override
  List<FaultRecord> get liveFaults {
    final frame = _frame;
    if (frame == null ||
        (phase != HoldPhase.holding && phase != HoldPhase.dropping)) {
      return const <FaultRecord>[];
    }
    return <FaultRecord>[
      if (frame.shrugging) _shrugFault(phase.name),
      if (frame.shoulderLeaning) _shoulderFault(phase.name),
    ];
  }

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.left ||
        cameraFacing == CameraFacing.right) {
      interruptReArm();
      return const GuidanceSignal.faceCamera();
    }
    if (_shoulders(landmarks) == null) {
      interruptActiveHold(interruptedHoldFaultId);
      interruptReArm();
      return const GuidanceSignal.bodyInFrame();
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.front) return false;
    final shoulders = _shoulders(landmarks);
    if (shoulders == null) return false;
    final tilt = _rawSignedTilt(landmarks, shoulders.left, shoulders.right);
    if (tilt == null || tilt.abs() > NeckStretchConfig.START_TILT_MAX) {
      return false;
    }
    _baselineShoulderAngle = _shoulderAngle(shoulders.left, shoulders.right);
    _baselineShoulderHipGap = _shoulderHipGap(landmarks, shoulders);
    _smoothedTilt = tilt;
    return true;
  }

  @override
  Set<String> get faultSecondsKeys => const <String>{
        'shrug_seconds',
        'shoulder_seconds',
      };

  @override
  HoldPoseSample? samplePose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final shoulders = _shoulders(landmarks);
    if (shoulders == null) return null;
    final signedTilt = _filteredTilt(
      _rawSignedTilt(landmarks, shoulders.left, shoulders.right),
    );
    if (signedTilt == null) return null;

    final tilt = signedTilt.abs();
    final side = signedTilt >= 0 ? NeckSide.left : NeckSide.right;
    final shoulderTilt =
        (_shoulderAngle(shoulders.left, shoulders.right) -
                _baselineShoulderAngle)
            .abs();
    final gap = _shoulderHipGap(landmarks, shoulders);
    final baselineGap = _baselineShoulderHipGap;
    final shrugRise = gap != null && baselineGap != null && baselineGap > 0
        ? (gap - baselineGap) / baselineGap
        : null;
    final frame = _NeckFrame(
      tilt: tilt,
      side: side,
      shoulderTilt: shoulderTilt,
      shrugRise: shrugRise,
      shoulderLeaning: _shoulderDebouncer
          .update(shoulderTilt > NeckStretchConfig.SHOULDER_TILT_MAX),
      shrugging: _shrugDebouncer.update(
          shrugRise != null && shrugRise > NeckStretchConfig.SHRUG_RISE_MAX),
    );
    _frame = frame;

    final sideOk = _sideAllowed(side);
    final formOk = !frame.shoulderLeaning && !frame.shrugging;
    final coaching =
        phase != HoldPhase.holding && phase != HoldPhase.resting;
    if (coaching && !sideOk) {
      resultIssues.feedback['Side'] = 'Đổi sang nghiêng đầu bên kia';
    } else if (coaching && tilt < NeckStretchConfig.ENTRY_TILT_MIN) {
      resultIssues.feedback['Tilt'] = 'Nghiêng tai về phía vai thêm chút nữa';
    }

    debugData
      ..['neckTilt'] = tilt
      ..['neckSide'] = side.name
      ..['shoulderTilt'] = shoulderTilt
      ..['shrugRise'] = shrugRise ?? -1.0;

    return HoldPoseSample(
      insideOuterEntry:
          tilt >= NeckStretchConfig.ENTRY_TILT_MIN && sideOk && formOk,
      outsideOuterExit:
          tilt < NeckStretchConfig.EXIT_TILT_MAX || !sideOk || !formOk,
    );
  }

  @override
  Map<String, bool> updateFormMetrics() {
    final frame = _frame!;
    if (phase == HoldPhase.holding || phase == HoldPhase.dropping) {
      _shrugSeen |= frame.shrugging;
      _shoulderSeen |= frame.shoulderLeaning;
    }
    if (phase == HoldPhase.holding) {
      _holdMaxTilt = math.max(_holdMaxTilt, frame.tilt);
    }
    if (frame.shrugging) {
      resultIssues.feedback['Shrug'] = 'Thả lỏng, hạ vai xuống';
    }
    if (frame.shoulderLeaning) {
      resultIssues.feedback['Shoulder'] = 'Giữ hai vai ngang, chỉ nghiêng đầu';
    }
    debugData['neckHoldSeconds'] = timerMetric.totalHoldingTimeMs / 1000.0;
    return <String, bool>{
      'shrug_seconds': frame.shrugging,
      'shoulder_seconds': frame.shoulderLeaning,
    };
  }

  @override
  Map<String, FaultRecord> snapshotHoldFaults() => <String, FaultRecord>{
        if (_shrugSeen) 'shrug': _shrugFault(HoldPhase.holding.name),
        if (_shoulderSeen) 'shoulder': _shoulderFault(HoldPhase.holding.name),
      };

  @override
  void resetFormMetrics({required bool countFaults}) {
    if (countFaults) {
      if (_shrugSeen) _shrugHolds += 1;
      if (_shoulderSeen) _shoulderHolds += 1;
    }
    _shrugSeen = false;
    _shoulderSeen = false;
    _holdMaxTilt = 0.0;
  }

  @override
  void onHoldPhaseChanged(HoldPhase previous, HoldPhase next, int nowMs) {
    if (next == HoldPhase.holding && previous != HoldPhase.dropping) {
      _holdSide = _frame?.side;
    } else if (next == HoldPhase.resting) {
      _lastHoldSide = _holdSide;
    } else if (next == HoldPhase.setup) {
      _holdSide = null;
    }
  }

  @override
  Map<String, dynamic> holdRepLogExtras() => <String, dynamic>{
        'hold_side': _holdSide?.name ?? 'unknown',
        'max_tilt': _holdMaxTilt,
      };

  @override
  void onHoldSetReset() {
    _frame = null;
    _holdSide = null;
    _lastHoldSide = null;
    _holdMaxTilt = 0.0;
    _shrugSeen = false;
    _shoulderSeen = false;
    _shrugHolds = 0;
    _shoulderHolds = 0;
    _shrugDebouncer.reset();
    _shoulderDebouncer.reset();
  }

  @override
  void onSetComplete() {
    final targetSeconds = (maxHolds * holdSeconds).toDouble();
    logger.pushKey('shrug_fails_count', _shrugHolds);
    logger.pushKey('shoulder_fails_count', _shoulderHolds);
    logger.pushKey('total_seconds', targetSeconds);
    logger.pushKey('good_seconds', clampedGoodHoldSeconds(targetSeconds));
    logger.pushMin('max_tilt', 'min_hold_tilt');
    logger.pushKey('max_rep', maxHolds);
    logger.pushGoodRepCount();
  }

  bool _sideAllowed(NeckSide side) {
    if (phase == HoldPhase.holding || phase == HoldPhase.dropping) {
      return _holdSide == null || side == _holdSide;
    }
    return _lastHoldSide == null || side != _lastHoldSide;
  }

  double? _filteredTilt(double? raw) {
    final previous = _smoothedTilt;
    if (raw == null) {
      _missingHeadFrames += 1;
      return _missingHeadFrames <= NeckStretchConfig.MISSING_HEAD_FRAMES_MAX
          ? previous
          : null;
    }
    _missingHeadFrames = 0;
    if (previous == null) return _smoothedTilt = raw;
    if ((raw - previous).abs() > NeckStretchConfig.TILT_JUMP_MAX &&
        _jumpFrames < NeckStretchConfig.TILT_JUMP_FRAMES_MAX) {
      _jumpFrames += 1;
      return previous;
    }
    _jumpFrames = 0;
    return _smoothedTilt =
        previous + (raw - previous) * NeckStretchConfig.TILT_SMOOTHING;
  }

  ({PoseLandmark left, PoseLandmark right})? _shoulders(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    final left = landmarks[PoseLandmarkType.leftShoulder];
    final right = landmarks[PoseLandmarkType.rightShoulder];
    if (left == null ||
        right == null ||
        !ExerciseBase.isLandmarkConfident(left) ||
        !ExerciseBase.isLandmarkConfident(right)) {
      return null;
    }
    return (left: left, right: right);
  }

  ({PoseLandmark left, PoseLandmark right})? _headPair(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
  ) {
    for (final pair in const [
      (left: PoseLandmarkType.leftEar, right: PoseLandmarkType.rightEar),
      (left: PoseLandmarkType.leftEye, right: PoseLandmarkType.rightEye),
    ]) {
      final left = landmarks[pair.left];
      final right = landmarks[pair.right];
      if (left != null &&
          right != null &&
          ExerciseBase.isLandmarkConfident(left) &&
          ExerciseBase.isLandmarkConfident(right)) {
        return (left: left, right: right);
      }
    }
    return null;
  }

  double? _rawSignedTilt(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    PoseLandmark leftShoulder,
    PoseLandmark rightShoulder,
  ) {
    final head = _headPair(landmarks);
    if (head == null) return null;
    final sx = leftShoulder.x - rightShoulder.x;
    final sy = leftShoulder.y - rightShoulder.y;
    final hx = head.left.x - head.right.x;
    final hy = head.left.y - head.right.y;
    final dot = sx * hx + sy * hy;
    if (dot <= 0 || sx == 0) return null;
    final cross = sx * hy - sy * hx;
    final degrees = math.atan2(cross, dot) * 180.0 / math.pi;
    return sx > 0 ? degrees : -degrees;
  }

  double _shoulderAngle(PoseLandmark left, PoseLandmark right) =>
      math.atan2(left.y - right.y, (left.x - right.x).abs()) * 180.0 / math.pi;

  double? _shoulderHipGap(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    ({PoseLandmark left, PoseLandmark right}) shoulders,
  ) {
    final leftHip = landmarks[PoseLandmarkType.leftHip];
    final rightHip = landmarks[PoseLandmarkType.rightHip];
    if (leftHip == null ||
        rightHip == null ||
        !ExerciseBase.isLandmarkConfident(leftHip) ||
        !ExerciseBase.isLandmarkConfident(rightHip)) {
      return null;
    }
    return (leftHip.y + rightHip.y) / 2 -
        (shoulders.left.y + shoulders.right.y) / 2;
  }

  FaultRecord _shrugFault(String phaseName) => FaultRecord(
        phase: phaseName,
        type: 'shrug',
        message: 'Nhún vai khi giãn cổ',
        affectsForm: true,
        priority: 0,
      );

  FaultRecord _shoulderFault(String phaseName) => FaultRecord(
        phase: phaseName,
        type: 'shoulder',
        message: 'Vai nghiêng theo đầu',
        affectsForm: true,
        priority: 1,
      );
}
