import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/pose/vika_pose_landmark.dart';

import '../../utils/debouncer.dart';
import '../../utils/exercise_logger.dart';
import '../../utils/pose_math_helpers.dart';
import '../exercise_base.dart';
import '../fault_record.dart';
import '../push up/push_up.dart' show PushUpConfig;
import '../side_tracked_exercise_mixin.dart';

class PushUpRotationConfig {
  static const double TOP_RETURN_TOLERANCE = 15.0;
  static const double TOP_REFRESH_BAND = 8.0;
  static const double TOP_REFRESH_ALPHA = 0.2;
  static const double PRESS_START_RISE = 15.0;
  static const double OPEN_WRIST_RISE_MIN = 0.6;
  static const double OPEN_SHOULDER_STACK_MIN = 0.35;
  static const double CLOSED_WRIST_RISE_MAX = 0.25;
  static const double CLOSED_SHOULDER_STACK_MAX = 0.2;
  static const int ELBOW_FRAMES = 2;
  static const int ROTATION_FRAMES = 3;
  static const int BODY_LINE_FRAMES = 4;
}

enum PushUpRotationState { plank, lowering, bottom, pressing, rotate, open }

class _RotationSample {
  const _RotationSample({
    required this.wristRise,
    required this.shoulderStack,
    required this.raisedSide,
    required this.opened,
    required this.closed,
  });

  final double? wristRise;
  final double? shoulderStack;
  final String? raisedSide;
  final bool opened;
  final bool closed;
}

class PushUpRotation extends ExerciseBase with SideTrackedExerciseMixin {
  PushUpRotation({required this.maxRep}) : super(targetReps: maxRep);

  final int maxRep;

  PushUpRotationState state = PushUpRotationState.plank;

  double? _topElbow;
  double? _torsoLen;

  double? _repMinElbow;
  double _repMaxWristRise = 0.0;
  double _repMaxShoulderStack = 0.0;
  bool _repBodyLineFault = false;
  String? _repOpenSide;
  String? _lastOpenSide;

  int _bodyLineFails = 0;
  int _alternateFails = 0;
  int _shallowAttempts = 0;
  int _noRotationAttempts = 0;

  final Debouncer _bendDebouncer =
      Debouncer(requiredFrames: PushUpRotationConfig.ELBOW_FRAMES);
  final Debouncer _bottomDebouncer =
      Debouncer(requiredFrames: PushUpRotationConfig.ELBOW_FRAMES);
  final Debouncer _pressDebouncer =
      Debouncer(requiredFrames: PushUpRotationConfig.ELBOW_FRAMES);
  final Debouncer _topDebouncer =
      Debouncer(requiredFrames: PushUpRotationConfig.ELBOW_FRAMES);
  final Debouncer _openDebouncer =
      Debouncer(requiredFrames: PushUpRotationConfig.ROTATION_FRAMES);
  final Debouncer _closeDebouncer =
      Debouncer(requiredFrames: PushUpRotationConfig.ROTATION_FRAMES);
  final Debouncer _bodyLineDebouncer =
      Debouncer(requiredFrames: PushUpRotationConfig.BODY_LINE_FRAMES);

  @override
  Map<String, SideLandmarkPair> get requiredSideLandmarks => const {
        'shoulder': (
          right: PoseLandmarkType.rightShoulder,
          left: PoseLandmarkType.leftShoulder,
        ),
        'elbow': (
          right: PoseLandmarkType.rightElbow,
          left: PoseLandmarkType.leftElbow,
        ),
        'wrist': (
          right: PoseLandmarkType.rightWrist,
          left: PoseLandmarkType.leftWrist,
        ),
        'hip': (
          right: PoseLandmarkType.rightHip,
          left: PoseLandmarkType.leftHip,
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
  String get exerciseName => 'Push-Up with Rotation';

  @override
  String get currentPhaseKey => state.name;

  @override
  String get currentPhaseLabel => switch (state) {
        PushUpRotationState.plank => 'Chuẩn bị',
        PushUpRotationState.lowering => 'Xuống',
        PushUpRotationState.bottom => 'Đẩy lên',
        PushUpRotationState.pressing => 'Đẩy lên',
        PushUpRotationState.rotate => 'Xoay người mở tay',
        PushUpRotationState.open => 'Hạ tay về sàn',
      };

  @override
  List<FaultRecord> get liveFaults => [
        if (_repBodyLineFault) _bodyLineFault(),
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
    final wrist = lm['wrist']!;
    final hip = lm['hip']!;
    final ankle = lm['ankle']!;
    final torso = math.max(calculateDistance(shoulder, hip), 1.0);
    final horizontal =
        (shoulder.x - ankle.x).abs() > (shoulder.y - ankle.y).abs() * 1.2;
    final elbow = _elbowAngle(lm);
    if (!horizontal ||
        elbow < PushUpConfig.START_ARM_MIN ||
        _bodyLine(lm) < PushUpConfig.START_BODY_MIN ||
        (wrist.y - shoulder.y) / torso < PushUpConfig.WRIST_BELOW_SHOULDER_MIN) {
      return false;
    }
    _topElbow = math.max(elbow, PushUpConfig.PLANK_ANGLE_THRESHOLD);
    _torsoLen = torso;
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
    final torso = _torsoLen ??=
        math.max(calculateDistance(lm['shoulder']!, lm['hip']!), 1.0);
    final topElbow = _topElbow ?? PushUpConfig.PLANK_ANGLE_THRESHOLD;
    final elbow = _elbowAngle(lm);
    final bodyLine = _bodyLine(lm);
    final rotation = _sampleRotation(landmarks, torso);
    final armDown = rotation.wristRise == null ||
        rotation.wristRise! <= PushUpRotationConfig.CLOSED_WRIST_RISE_MAX;
    final bent = armDown && topElbow - elbow > PushUpConfig.ROM_GATE;
    final atTop = armDown &&
        elbow >= topElbow - PushUpRotationConfig.TOP_RETURN_TOLERANCE;

    debugData
      ..['state'] = state.name
      ..['elbowAngle'] = elbow
      ..['topElbow'] = topElbow
      ..['bodyLine'] = bodyLine
      ..['wristRise'] = rotation.wristRise ?? -9.0
      ..['shoulderStack'] = rotation.shoulderStack ?? -1.0;

    switch (state) {
      case PushUpRotationState.plank:
        if (armDown &&
            elbow >= topElbow - PushUpRotationConfig.TOP_REFRESH_BAND) {
          _topElbow = math.max(
            PushUpConfig.PLANK_ANGLE_THRESHOLD,
            topElbow +
                (elbow - topElbow) * PushUpRotationConfig.TOP_REFRESH_ALPHA,
          );
        }
        if (_bendDebouncer.update(bent)) _startLowering(elbow);
        break;
      case PushUpRotationState.lowering:
        _trackPush(elbow, bodyLine);
        if (_bottomDebouncer.update(
            elbow <= PushUpConfig.BOTTOM_ANGLE_RANGE[1])) {
          _transition(PushUpRotationState.bottom);
        } else if (_topDebouncer.update(atTop)) {
          _rejectAttempt(
            reason: 'depth',
            message: 'Hạ ngực xuống thấp hơn',
          );
        }
        break;
      case PushUpRotationState.bottom:
        _trackPush(elbow, bodyLine);
        if (_pressDebouncer.update(elbow >=
            (_repMinElbow ?? elbow) + PushUpRotationConfig.PRESS_START_RISE)) {
          _transition(PushUpRotationState.pressing);
        }
        break;
      case PushUpRotationState.pressing:
        _trackPush(elbow, bodyLine);
        if (_openDebouncer.update(rotation.opened)) {
          _open(rotation);
        } else if (_topDebouncer.update(atTop)) {
          _transition(PushUpRotationState.rotate);
        }
        break;
      case PushUpRotationState.rotate:
        if (_openDebouncer.update(rotation.opened)) {
          _open(rotation);
        } else if (_bendDebouncer.update(bent)) {
          _rejectAttempt(
            reason: 'rotation',
            message: 'Xoay người, mở tay lên trần sau mỗi lần chống đẩy',
          );
          _startLowering(elbow);
        }
        break;
      case PushUpRotationState.open:
        _repMaxWristRise =
            math.max(_repMaxWristRise, rotation.wristRise ?? 0.0);
        _repMaxShoulderStack =
            math.max(_repMaxShoulderStack, rotation.shoulderStack ?? 0.0);
        if (_closeDebouncer.update(rotation.closed)) _completeRep();
        break;
    }

    resultIssues.setPhaseStatus(state.name, currentPhaseLabel);
  }

  @override
  void onSetComplete() {
    logger.pushKey('body_line_fails_count', _bodyLineFails);
    logger.pushKey('alternate_fails_count', _alternateFails);
    logger.pushKey('shallow_attempts', _shallowAttempts);
    logger.pushKey('no_rotation_attempts', _noRotationAttempts);
    logger.pushMax('min_elbow_angle', 'max_bottom_elbow_angle');
    logger.pushMin('max_wrist_rise', 'min_wrist_rise');
    logger.pushGoodRepCount();
    logger.pushKey('max_rep', maxRep);
  }

  void _startLowering(double elbow) {
    _repMinElbow = elbow;
    _repBodyLineFault = false;
    _repOpenSide = null;
    _repMaxWristRise = 0.0;
    _repMaxShoulderStack = 0.0;
    _bodyLineDebouncer.reset();
    _transition(PushUpRotationState.lowering);
  }

  void _trackPush(double elbow, double bodyLine) {
    _repMinElbow = math.min(_repMinElbow ?? elbow, elbow);
    if (_bodyLineDebouncer.update(bodyLine < PushUpConfig.ACTIVE_BODY_LINE_MIN)) {
      _repBodyLineFault = true;
      resultIssues.feedback['Form'] = 'Giữ vai, hông, cổ chân thẳng hàng';
    }
  }

  void _open(_RotationSample rotation) {
    _repOpenSide = rotation.raisedSide;
    _transition(PushUpRotationState.open);
  }

  void _transition(PushUpRotationState next) {
    if (next == state) return;
    state = next;
    _bendDebouncer.reset();
    _bottomDebouncer.reset();
    _pressDebouncer.reset();
    _topDebouncer.reset();
    _openDebouncer.reset();
    _closeDebouncer.reset();
  }

  void _rejectAttempt({required String reason, required String message}) {
    if (reason == 'depth') {
      _shallowAttempts += 1;
    } else {
      _noRotationAttempts += 1;
    }
    resultIssues.feedback['Result'] = 'Lần này chưa tính nhé';
    resultIssues.feedback['Form'] = message;
    debugData['noCount'] = reason;
    _resetCycle();
  }

  void _completeRep() {
    repCount += 1;
    final alternateMissed =
        _lastOpenSide != null && _repOpenSide == _lastOpenSide;
    final faults = <FaultRecord>[
      if (_repBodyLineFault) _bodyLineFault(),
      if (alternateMissed)
        FaultRecord(
          phase: PushUpRotationState.open.name,
          type: 'alternate',
          message: 'Đổi tay mở lên ở rep sau',
          affectsForm: false,
          priority: 5,
        ),
    ];
    if (_repBodyLineFault) _bodyLineFails += 1;
    if (alternateMissed) _alternateFails += 1;
    _lastOpenSide = _repOpenSide;

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
        'min_elbow_angle': _repMinElbow ?? 0.0,
        'max_wrist_rise': _repMaxWristRise,
        'max_shoulder_stack': _repMaxShoulderStack,
        'open_side': _repOpenSide ?? 'unknown',
        'fault_types': [for (final fault in faults) fault.type],
        'fault_affects_form': <String, bool>{
          for (final fault in faults) fault.type: fault.affectsForm,
        },
      },
    ));
    _resetCycle();
  }

  void _resetCycle() {
    state = PushUpRotationState.plank;
    correctForm = true;
    _repMinElbow = null;
    _repMaxWristRise = 0.0;
    _repMaxShoulderStack = 0.0;
    _repBodyLineFault = false;
    _repOpenSide = null;
    _bendDebouncer.reset();
    _bottomDebouncer.reset();
    _pressDebouncer.reset();
    _topDebouncer.reset();
    _openDebouncer.reset();
    _closeDebouncer.reset();
    _bodyLineDebouncer.reset();
  }

  _RotationSample _sampleRotation(
    Map<PoseLandmarkType, PoseLandmark> landmarks,
    double torso,
  ) {
    final shoulders = [
      landmarks[PoseLandmarkType.leftShoulder],
      landmarks[PoseLandmarkType.rightShoulder],
    ].whereType<PoseLandmark>().where(
        (landmark) => landmark.presence >= ExerciseBase.MIN_PRESENCE);
    final wrists = <String, PoseLandmark>{
      for (final entry in {
        'left': landmarks[PoseLandmarkType.leftWrist],
        'right': landmarks[PoseLandmarkType.rightWrist],
      }.entries)
        if (entry.value != null &&
            ExerciseBase.isLandmarkConfident(entry.value!))
          entry.key: entry.value!,
    };
    if (shoulders.isEmpty || wrists.isEmpty) {
      return const _RotationSample(
        wristRise: null,
        shoulderStack: null,
        raisedSide: null,
        opened: false,
        closed: false,
      );
    }
    final topShoulderY = shoulders.map((s) => s.y).reduce(math.min);
    final raised = wrists.entries.reduce((a, b) => a.value.y <= b.value.y ? a : b);
    final wristRise = (topShoulderY - raised.value.y) / torso;
    final pair = shoulders.toList();
    final stackY =
        pair.length == 2 ? (pair[0].y - pair[1].y).abs() / torso : null;
    final stackX =
        pair.length == 2 ? (pair[0].x - pair[1].x).abs() / torso : null;
    final stacked = stackY != null &&
        stackY >= PushUpRotationConfig.OPEN_SHOULDER_STACK_MIN &&
        stackY > stackX!;
    return _RotationSample(
      wristRise: wristRise,
      shoulderStack: stackY,
      raisedSide: raised.key,
      opened: wristRise >= PushUpRotationConfig.OPEN_WRIST_RISE_MIN && stacked,
      closed: wristRise <= PushUpRotationConfig.CLOSED_WRIST_RISE_MAX &&
          (stackY == null ||
              stackY <= PushUpRotationConfig.CLOSED_SHOULDER_STACK_MAX),
    );
  }

  FaultRecord _bodyLineFault() => FaultRecord(
        phase: PushUpRotationState.lowering.name,
        type: 'body_line',
        message: 'Hông võng hoặc nhô khi chống đẩy',
        affectsForm: true,
        priority: 1,
      );

  static double _elbowAngle(Map<String, PoseLandmark> lm) =>
      calculateAngleNormalized(
        firstPoint: lm['shoulder']!,
        midPoint: lm['elbow']!,
        lastPoint: lm['wrist']!,
      );

  static double _bodyLine(Map<String, PoseLandmark> lm) =>
      calculateAngleNormalized(
        firstPoint: lm['shoulder']!,
        midPoint: lm['hip']!,
        lastPoint: lm['ankle']!,
      );
}
