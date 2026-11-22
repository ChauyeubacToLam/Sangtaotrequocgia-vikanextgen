import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../utils/debouncer.dart';
import '../../utils/exercise_logger.dart';
import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';
import '../fault_record.dart';
import '../side_tracked_exercise_mixin.dart';

class StepUpConfig {
  static const double START_KNEE_MIN = 160.0;
  static const double START_TRUNK_MAX = 25.0;
  static const double BASELINE_DRIFT_MAX = 0.05;
  static const double BASELINE_ALPHA = 0.1;
  static const double RISE_START = 0.12;
  static const double TOP_RISE_MIN = 0.30;
  static const double TOP_KNEE_MIN = 155.0;
  static const double FLOOR_RETURN_MAX = 0.08;
  static const double LEAD_ANKLE_LIFT_MIN = 0.20;
  static const double TOP_TRUNK_LEAN_MAX = 30.0;
  static const int RISE_FRAMES = 2;
  static const int TOP_FRAMES = 3;
  static const int FLOOR_FRAMES = 3;
  static const int TRUNK_FRAMES = 3;
}

enum StepUpState { standing, rising, top, lowering }

class StepUp extends ExerciseBase with SideTrackedExerciseMixin {
  StepUp({required this.maxRep}) : super(targetReps: maxRep);

  final int maxRep;

  StepUpState state = StepUpState.standing;

  double? _floorHipY;
  double? _floorAnkleY;
  double? _torsoLen;

  double _repMaxRise = 0.0;
  double _repTopKnee = 0.0;
  double _repMaxTrunkLean = 0.0;
  bool _repTrunkFault = false;
  TrackedSide? _repLeadSide;
  TrackedSide? _lastLeadSide;

  int _trunkFails = 0;
  int _alternateFails = 0;
  int _noCountAttempts = 0;

  final Debouncer _riseDebouncer =
      Debouncer(requiredFrames: StepUpConfig.RISE_FRAMES);
  final Debouncer _topDebouncer =
      Debouncer(requiredFrames: StepUpConfig.TOP_FRAMES);
  final Debouncer _floorDebouncer =
      Debouncer(requiredFrames: StepUpConfig.FLOOR_FRAMES);
  final Debouncer _trunkDebouncer =
      Debouncer(requiredFrames: StepUpConfig.TRUNK_FRAMES);

  @override
  Map<String, SideLandmarkPair> get requiredSideLandmarks => const {
        'shoulder': (
          right: PoseLandmarkType.rightShoulder,
          left: PoseLandmarkType.leftShoulder,
        ),
        'hip': (
          right: PoseLandmarkType.rightHip,
          left: PoseLandmarkType.leftHip,
        ),
        'knee': (
          right: PoseLandmarkType.rightKnee,
          left: PoseLandmarkType.leftKnee,
        ),
        'ankle': (
          right: PoseLandmarkType.rightAnkle,
          left: PoseLandmarkType.leftAnkle,
        ),
      };

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  @override
  String get exerciseName => 'Step-Up';

  @override
  String get currentPhaseKey => state.name;

  @override
  String get currentPhaseLabel => switch (state) {
        StepUpState.standing => 'Bước lên',
        StepUpState.rising => 'Đẩy người lên',
        StepUpState.top => 'Đứng thẳng trên ghế',
        StepUpState.lowering => 'Bước xuống',
      };

  @override
  List<FaultRecord> get liveFaults => [
        if (_repTrunkFault) _trunkFault(),
      ];

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return const GuidanceSignal.turnSide();
    }
    if (getSideTrackedLandmarks(landmarks) == null) {
      return const GuidanceSignal.bodyInFrame();
    }
    return null;
  }

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return false;
    }
    final lm = getSideTrackedLandmarks(landmarks);
    if (lm == null) return false;
    final shoulder = lm['shoulder']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ankle = lm['ankle']!;
    if (_trunkLean(shoulder, hip) > StepUpConfig.START_TRUNK_MAX) return false;
    if (_kneeAngle(hip, knee, ankle) < StepUpConfig.START_KNEE_MIN) {
      return false;
    }
    _floorHipY = hip.y;
    _floorAnkleY = ankle.y;
    _torsoLen = math.max(calculateDistance(shoulder, hip), 1.0);
    return true;
  }

  @override
  void onExerciseActivated() {
    super.onExerciseActivated();
    _resetCycle();
  }

  @override
  void onPauseReactivationStarted() => _resetCycle();

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final lm = getSideTrackedLandmarks(landmarks);
    if (lm == null) return;
    final shoulder = lm['shoulder']!;
    final hip = lm['hip']!;
    final knee = lm['knee']!;
    final ankle = lm['ankle']!;

    final torso =
        _torsoLen ??= math.max(calculateDistance(shoulder, hip), 1.0);
    final floorHipY = _floorHipY ??= hip.y;
    final floorAnkleY = _floorAnkleY ??= ankle.y;

    final rise = (floorHipY - hip.y) / torso;
    final ankleLift = (floorAnkleY - ankle.y) / torso;
    final nearKnee = _kneeAngle(hip, knee, ankle);
    final farKnee = _farKneeAngle(landmarks);
    final topKnee = math.max(nearKnee, farKnee ?? 0.0);
    final trunkLean = _trunkLean(shoulder, hip);
    final atTopHeight = rise >= StepUpConfig.TOP_RISE_MIN &&
        topKnee >= StepUpConfig.TOP_KNEE_MIN;
    final onFloor = rise <= StepUpConfig.FLOOR_RETURN_MAX;

    debugData
      ..['state'] = state.name
      ..['hipRise'] = rise
      ..['ankleLift'] = ankleLift
      ..['nearKnee'] = nearKnee
      ..['farKnee'] = farKnee ?? -1.0
      ..['trunkLean'] = trunkLean;

    switch (state) {
      case StepUpState.standing:
        if (rise.abs() <= StepUpConfig.BASELINE_DRIFT_MAX &&
            nearKnee >= StepUpConfig.START_KNEE_MIN) {
          _floorHipY = _blend(floorHipY, hip.y);
          if (ankleLift.abs() <= StepUpConfig.BASELINE_DRIFT_MAX) {
            _floorAnkleY = _blend(floorAnkleY, ankle.y);
          }
        }
        if (_riseDebouncer.update(rise >= StepUpConfig.RISE_START)) {
          _repLeadSide = ankleLift >= StepUpConfig.LEAD_ANKLE_LIFT_MIN
              ? trackedSide
              : _opposite(trackedSide);
          _transition(StepUpState.rising);
        }
        break;
      case StepUpState.rising:
        _track(rise, topKnee, trunkLean);
        if (_topDebouncer.update(atTopHeight)) {
          _transition(StepUpState.top);
        } else if (_floorDebouncer.update(onFloor)) {
          _rejectAttempt();
        }
        break;
      case StepUpState.top:
        _track(rise, topKnee, trunkLean);
        if (_trunkDebouncer.update(
            trunkLean > StepUpConfig.TOP_TRUNK_LEAN_MAX)) {
          _repTrunkFault = true;
          resultIssues.feedback['Trunk'] = 'Đứng thẳng người khi ở trên ghế';
        }
        if (rise < StepUpConfig.TOP_RISE_MIN) {
          _transition(StepUpState.lowering);
        }
        break;
      case StepUpState.lowering:
        _track(rise, topKnee, trunkLean);
        if (_floorDebouncer.update(onFloor)) {
          _completeRep();
        } else if (_topDebouncer.update(atTopHeight)) {
          _transition(StepUpState.top);
        }
        break;
    }

    resultIssues.setPhaseStatus(state.name, currentPhaseLabel);
  }

  @override
  void onSetComplete() {
    logger.pushKey('trunk_fails_count', _trunkFails);
    logger.pushKey('alternate_fails_count', _alternateFails);
    logger.pushKey('no_count_attempts', _noCountAttempts);
    logger.pushMin('max_hip_rise', 'min_hip_rise');
    logger.pushMax('max_trunk_lean', 'max_trunk_lean');
    logger.pushGoodRepCount();
    logger.pushKey('max_rep', maxRep);
  }

  void _track(double rise, double topKnee, double trunkLean) {
    _repMaxRise = math.max(_repMaxRise, rise);
    if (rise >= StepUpConfig.TOP_RISE_MIN) {
      _repTopKnee = math.max(_repTopKnee, topKnee);
      _repMaxTrunkLean = math.max(_repMaxTrunkLean, trunkLean);
    }
  }

  void _transition(StepUpState next) {
    if (next == state) return;
    state = next;
    _riseDebouncer.reset();
    _topDebouncer.reset();
    _floorDebouncer.reset();
  }

  void _rejectAttempt() {
    _noCountAttempts += 1;
    resultIssues.feedback['Result'] = 'Lần này chưa tính nhé';
    resultIssues.feedback['Form'] = _repMaxRise < StepUpConfig.TOP_RISE_MIN
        ? 'Bước hẳn lên ghế rồi đứng thẳng'
        : 'Duỗi thẳng gối chân bước khi ở trên ghế';
    debugData['noCount'] =
        _repMaxRise < StepUpConfig.TOP_RISE_MIN ? 'height' : 'knee';
    _resetCycle();
  }

  void _completeRep() {
    repCount += 1;
    final alternateMissed =
        _lastLeadSide != null && _repLeadSide == _lastLeadSide;
    final faults = <FaultRecord>[
      if (_repTrunkFault) _trunkFault(),
      if (alternateMissed)
        FaultRecord(
          phase: StepUpState.rising.name,
          type: 'alternate',
          message: 'Đổi chân bước lên ở rep sau',
          affectsForm: false,
          priority: 5,
        ),
    ];
    if (_repTrunkFault) _trunkFails += 1;
    if (alternateMissed) _alternateFails += 1;
    _lastLeadSide = _repLeadSide;

    correctForm = !faults.any((fault) => fault.affectsForm);
    resultIssues.feedback['Result'] = correctForm ? 'Tốt!' : 'Chỉnh tư thế';
    setFeedback.add({
      correctForm: <String, Map<String, String>>{
        for (final fault in faults)
          fault.phase: <String, String>{fault.type: fault.message},
      },
    });
    logger.addRepLog(RepLog(
      correctForm: correctForm,
      repNumber: repCount,
      data: {
        'max_hip_rise': _repMaxRise,
        'top_knee_angle': _repTopKnee,
        'max_trunk_lean': _repMaxTrunkLean,
        'lead_leg': _repLeadSide?.name ?? 'unknown',
        'fault_types': [for (final fault in faults) fault.type],
        'fault_affects_form': <String, bool>{
          for (final fault in faults) fault.type: fault.affectsForm,
        },
      },
    ));
    _resetCycle();
  }

  void _resetCycle() {
    state = StepUpState.standing;
    correctForm = true;
    _repMaxRise = 0.0;
    _repTopKnee = 0.0;
    _repMaxTrunkLean = 0.0;
    _repTrunkFault = false;
    _repLeadSide = null;
    _riseDebouncer.reset();
    _topDebouncer.reset();
    _floorDebouncer.reset();
    _trunkDebouncer.reset();
  }

  FaultRecord _trunkFault() => FaultRecord(
        phase: StepUpState.top.name,
        type: 'trunk',
        message: 'Đổ người ra trước khi ở trên ghế',
        affectsForm: true,
        priority: 1,
      );

  double? _farKneeAngle(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final farIsRight = trackedSide == TrackedSide.left;
    final hip = landmarks[
        farIsRight ? PoseLandmarkType.rightHip : PoseLandmarkType.leftHip];
    final knee = landmarks[
        farIsRight ? PoseLandmarkType.rightKnee : PoseLandmarkType.leftKnee];
    final ankle = landmarks[
        farIsRight ? PoseLandmarkType.rightAnkle : PoseLandmarkType.leftAnkle];
    if (hip == null || knee == null || ankle == null) return null;
    if (!ExerciseBase.isLandmarkConfident(hip) ||
        !ExerciseBase.isLandmarkConfident(knee) ||
        !ExerciseBase.isLandmarkConfident(ankle)) {
      return null;
    }
    return _kneeAngle(hip, knee, ankle);
  }

  static double _kneeAngle(
    PoseLandmark hip,
    PoseLandmark knee,
    PoseLandmark ankle,
  ) =>
      calculateAngleNormalized(firstPoint: hip, midPoint: knee, lastPoint: ankle);

  static double _trunkLean(PoseLandmark shoulder, PoseLandmark hip) {
    final clock = calculateVerticalAngle(pivot: hip, point: shoulder);
    return clock > 180 ? 360 - clock : clock;
  }

  static double _blend(double previous, double current) =>
      previous + (current - previous) * StepUpConfig.BASELINE_ALPHA;

  static TrackedSide? _opposite(TrackedSide? side) => switch (side) {
        TrackedSide.left => TrackedSide.right,
        TrackedSide.right => TrackedSide.left,
        null => null,
      };
}
