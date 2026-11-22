// ignore_for_file: curly_braces_in_flow_control_structures, non_constant_identifier_names, constant_identifier_names

import 'package:vika/exercise/exercise_base.dart';
import '../../utils/pose_math_helpers.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../utils/exercise_logger.dart';
import 'metrics/lunge_metric_base.dart';
import 'metrics/lunge_depth_metric.dart';
import 'metrics/lunge_trunk_lean_metric.dart';
import 'metrics/lunge_lumbar_proxy_metric.dart';
import '../../utils/debouncer.dart';
import '../../voice/policy_voice_coach.dart';
import '../../voice/voice_coach.dart';
import '../../voice/voice_content.dart';
import '../../voice/voice_policy.dart';
import '../../voice/voice_sink.dart';

// --- Config ---

class LungeConfig {
  static const int MAX_REP = 15;
  static const int LUNGE_STAND_ANGLE_THRESHOLD = 155;
  static const int LUNGE_DESCEND_ANGLE_THRESHOLD = 145;
  static const List<int> LUNGE_BOTTOM_ANGLE_THRESHOLD = [55, 125];
  static const int LUNGE_ASCEND_ANGLE_THRESHOLD = 125;
}

enum LungeState { standing, descending, bottom, ascending }

// --- Lunge ---

class Lunge extends ExerciseBase {
  static const List<String> _voiceFaultIds = [
    'depth',
    'trunk',
    'lumbar',
  ];

  @override
  Set<VikaImageOrientation> get supportedOrientations =>
      const <VikaImageOrientation>{
        VikaImageOrientation.landscapeLeft,
        VikaImageOrientation.landscapeRight,
      };

  final int maxRep;

  Lunge({this.maxRep = LungeConfig.MAX_REP}) : super(targetReps: maxRep);

  LungeState lungeState = LungeState.standing;
  LungeState previousLungeState = LungeState.standing;
  bool _reachedBottomThisRep = false;
  int _rejectedShallowAttempts = 0;

  final LungeDepthMetric depthMetric = LungeDepthMetric();
  final LungeTrunkLeanMetric trunkLeanMetric = LungeTrunkLeanMetric();
  final LungeLumbarProxyMetric lumbarProxyMetric = LungeLumbarProxyMetric();

  late final List<LungeMetricBase> _metrics = [
    depthMetric,
    trunkLeanMetric,
    lumbarProxyMetric,
  ];

  // --- Lead Leg Detection ---
  //
  // In side view, the lead (front) leg is the ankle closest to the
  // camera-facing edge. Debounced (5 frames) and locked per rep.

  bool? _isLeftLegLead;
  bool _leadLegLocked = false;
  final StickyDebouncer _leadLegDebouncer =
      StickyDebouncer(requiredFrames: 5, currentState: true);

  bool? _detectLeadLeg(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = landmarks[PoseLandmarkType.rightAnkle];

    if (leftAnkle == null || rightAnkle == null) return _isLeftLegLead;

    bool leftIsLead;
    if (cameraFacing == CameraFacing.left) {
      leftIsLead = leftAnkle.x < rightAnkle.x;
    } else if (cameraFacing == CameraFacing.right) {
      leftIsLead = leftAnkle.x > rightAnkle.x;
    } else {
      return _isLeftLegLead;
    }

    return _leadLegDebouncer.update(leftIsLead);
  }

  ({
    PoseLandmark? knee,
    PoseLandmark? hip,
    PoseLandmark? ankle,
    PoseLandmark? shoulder,
  }) _getLeadLandmarks(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final isLeft = _isLeftLegLead ?? true;
    return (
      knee: landmarks[
          isLeft ? PoseLandmarkType.leftKnee : PoseLandmarkType.rightKnee],
      hip: landmarks[
          isLeft ? PoseLandmarkType.leftHip : PoseLandmarkType.rightHip],
      ankle: landmarks[
          isLeft ? PoseLandmarkType.leftAnkle : PoseLandmarkType.rightAnkle],
      shoulder: landmarks[isLeft
          ? PoseLandmarkType.leftShoulder
          : PoseLandmarkType.rightShoulder],
    );
  }

  ({
    PoseLandmark? knee,
    PoseLandmark? hip,
    PoseLandmark? ankle,
  }) _getTrailLandmarks(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    final isLeft = _isLeftLegLead ?? true;
    return (
      knee: landmarks[
          isLeft ? PoseLandmarkType.rightKnee : PoseLandmarkType.leftKnee],
      hip: landmarks[
          isLeft ? PoseLandmarkType.rightHip : PoseLandmarkType.leftHip],
      ankle: landmarks[
          isLeft ? PoseLandmarkType.rightAnkle : PoseLandmarkType.leftAnkle],
    );
  }

  // --- UI Bridge ---

  @override
  String get exerciseName => 'Lunge';

  @override
  List<FaultRecord> get liveFaults =>
      [for (final metric in _metrics) ...metric.faults];

  @override
  ExerciseVoiceCoach createVoiceCoach() {
    return PolicyVoiceCoach(
      script: VoiceScript.from(
        VoiceDefaults.repBased,
        slug: 'lunge',
        faultIds: _voiceFaultIds,
        reminderPools: const {
          'trunk': ['lunge.trunk_reminder'],
        },
        repStartPhaseKeys: const {'descending'},
        // Hesitation encouragement, not "push harder"; valid for controlled work too.
        effortPhaseKeys: const {'ascending'},
        hustlePool: const ['common.push'],
        hustleFinalPool: const ['common.one_more_rep'],
      ),
      targetReps: targetReps,
      coach: VoiceCoach(
        sink: AssetVoiceSink(),
        policy: VoicePolicy(),
      ),
    );
  }

  @override
  String get currentPhaseKey => lungeState.toString().split('.').last;

  @override
  String get currentPhaseLabel {
    switch (lungeState) {
      case LungeState.standing:
        return 'Đứng thẳng';
      case LungeState.descending:
        return 'Xuống';
      case LungeState.bottom:
        return 'Giữ';
      case LungeState.ascending:
        return 'Đứng lên';
    }
  }

  // --- Stop Condition ---

  @override
  bool requestStop() => repCount >= maxRep;

  @override
  void onSetComplete() {
    logger.pushKey("depth_fails_count", depthMetric.faultsCount);
    logger.pushKey("trunk_lean_fails_count", trunkLeanMetric.faultsCount);
    logger.pushKey("heel_lift_fails_count", 0);
    logger.pushKey("lumbar_proxy_fails_count", lumbarProxyMetric.faultsCount);
    logger.pushKey("rejected_shallow_attempts_count", _rejectedShallowAttempts);

    logger.pushMin("min_lead_knee_angle", "min_lead_knee_angle");
    logger.pushMax("max_trunk_lean", "max_trunk_lean");

    logger.pushGoodRepCount();
    logger.pushKey("max_rep", maxRep);
  }

  // --- Safety Checks ---

  @override
  GuidanceSignal? checkSafety(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    if (cameraFacing == CameraFacing.front) {
      return const GuidanceSignal.turnSide();
    }

    // Lunge needs BOTH sides (unlike squat which uses getSideLandmark)
    PoseLandmark? leftHip = landmarks[PoseLandmarkType.leftHip];
    PoseLandmark? rightHip = landmarks[PoseLandmarkType.rightHip];
    PoseLandmark? leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    PoseLandmark? rightShoulder = landmarks[PoseLandmarkType.rightShoulder];
    PoseLandmark? leftKnee = landmarks[PoseLandmarkType.leftKnee];
    PoseLandmark? rightKnee = landmarks[PoseLandmarkType.rightKnee];
    PoseLandmark? leftAnkle = landmarks[PoseLandmarkType.leftAnkle];
    PoseLandmark? rightAnkle = landmarks[PoseLandmarkType.rightAnkle];
    PoseLandmark? leftFoot = landmarks[PoseLandmarkType.leftFootIndex];
    PoseLandmark? rightFoot = landmarks[PoseLandmarkType.rightFootIndex];
    PoseLandmark? leftHeel = landmarks[PoseLandmarkType.leftHeel];
    PoseLandmark? rightHeel = landmarks[PoseLandmarkType.rightHeel];

    if (leftHip == null ||
        rightHip == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftKnee == null ||
        rightKnee == null ||
        leftAnkle == null ||
        rightAnkle == null ||
        leftFoot == null ||
        rightFoot == null ||
        leftHeel == null ||
        rightHeel == null) {
      return const GuidanceSignal.bodyInFrame();
    }

    final allLandmarks = [
      leftHip,
      rightHip,
      leftShoulder,
      rightShoulder,
      leftKnee,
      rightKnee,
      leftAnkle,
      rightAnkle,
      leftFoot,
      rightFoot,
      leftHeel,
      rightHeel,
    ];

    if (allLandmarks.any((l) => !ExerciseBase.isLandmarkConfident(l))) {
      return const GuidanceSignal.lighting();
    }

    return null;
  }

  // --- Start Position ---

  @override
  bool isInStartPosition(Map<PoseLandmarkType, PoseLandmark> landmarks) {
    // Require side view
    if (cameraFacing != CameraFacing.left &&
        cameraFacing != CameraFacing.right) {
      return false;
    }

    final shoulder = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightShoulder,
      leftType: PoseLandmarkType.leftShoulder,
    );
    final hip = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightHip,
      leftType: PoseLandmarkType.leftHip,
    );
    final knee = getSideLandmark(
      landmarks: landmarks,
      rightType: PoseLandmarkType.rightKnee,
      leftType: PoseLandmarkType.leftKnee,
    );

    if (shoulder == null || hip == null || knee == null) return false;

    // Trunk roughly vertical
    double trunkAngle = calculateVerticalAngle(pivot: hip, point: shoulder);
    double deviation = trunkAngle > 180 ? 360 - trunkAngle : trunkAngle;
    if (deviation > 25) return false;

    // Hip roughly straight (shoulder-hip-knee; no knee angle is checked).
    // Normalised (0-180): the raw angle read a flexed hip as > 180 when
    // facing left and passed it.
    final hipKneeAngle = calculateAngleNormalized(
        firstPoint: shoulder, midPoint: hip, lastPoint: knee);
    if (hipKneeAngle < LungeConfig.LUNGE_STAND_ANGLE_THRESHOLD) return false;

    return true;
  }

  // --- Main Loop (called every frame when activated) ---

  @override
  void checkingPose(Map<PoseLandmarkType, PoseLandmark> smoothedLandmarks) {
    // 1. Detect lead leg (before locking)
    if (!_leadLegLocked) {
      _isLeftLegLead = _detectLeadLeg(smoothedLandmarks);
    }

    // 2. Get landmarks (lead + trail)
    final lead = _getLeadLandmarks(smoothedLandmarks);
    final trail = _getTrailLandmarks(smoothedLandmarks);

    if (lead.knee == null ||
        lead.hip == null ||
        lead.ankle == null ||
        lead.shoulder == null ||
        trail.knee == null ||
        trail.hip == null ||
        trail.ankle == null) {
      return;
    }

    // 3. Calculate geometry
    double leadKneeAngle = calculateAngleNormalized(
        firstPoint: lead.hip!, midPoint: lead.knee!, lastPoint: lead.ankle!);

    double trailKneeAngle = calculateAngleNormalized(
        firstPoint: trail.hip!, midPoint: trail.knee!, lastPoint: trail.ankle!);

    double backAngle =
        calculateVerticalAngle(pivot: lead.hip!, point: lead.shoulder!);
    double trunkLean = convertClockAngleToTrunkLean(backAngle, cameraFacing);

    // Normalised (0-180) so the same posture reads the same in both facings.
    double shoulderHipTrailKneeAngle = calculateAngleNormalized(
        firstPoint: lead.shoulder!,
        midPoint: lead.hip!,
        lastPoint: trail.knee!);

    int now = frameTimestampMs;

    // 4. Build LungeRepContext
    final ctx = LungeRepContext(
      leadKneeAngle: leadKneeAngle,
      trailKneeAngle: trailKneeAngle,
      trunkLean: trunkLean,
      shoulderHipTrailKneeAngle: shoulderHipTrailKneeAngle,
      lungeState: lungeState,
      isLeftLegLead: _isLeftLegLead ?? true,
      frameTimestamp: now,
      scaleFactor: scaleFactor,
      leadKneeY: lead.knee!.y,
      leadHipY: lead.hip!.y,
      resultIssues: resultIssues,
    );

    final debugEnabled = isDebugModeActive;
    // 5. Debug data
    debugData['lungeState'] = lungeState.toString().split('.').last;
    debugData['reachedBottomThisRep'] = _reachedBottomThisRep;
    debugData['rejectedShallowAttempts'] = _rejectedShallowAttempts;
    debugData['leadLeg'] = (_isLeftLegLead ?? true) ? 'Left' : 'Right';
    debugData['leadKneeAngle'] = leadKneeAngle.toStringAsFixed(1);
    debugData['trailKneeAngle'] = trailKneeAngle.toStringAsFixed(1);
    debugData['backClockAngle'] = backAngle.toStringAsFixed(1);
    debugData['trunkLean'] =
        '${trunkLean >= 0 ? "+" : ""}${trunkLean.toStringAsFixed(1)}°';
    debugData['shTrailKneeAngle'] =
        shoulderHipTrailKneeAngle.toStringAsFixed(1);
    debugData['correctForm'] = correctForm.toString();

    // 6. Rep completion (standing up)
    if (lungeState == LungeState.standing &&
        previousLungeState != LungeState.standing) {
      if (!_reachedBottomThisRep) {
        _rejectedShallowAttempts++;
        resultIssues.feedback['Result'] = 'Không tính';
        previousLungeState = LungeState.standing;
        _reachedBottomThisRep = false;
        _leadLegLocked = false;
        for (final metric in _metrics) {
          metric.reset();
        }
        return;
      }

      repCount += 1;

      _transitionState(LungeState.standing, now);

      final allFaults = <FaultRecord>[];
      for (final metric in _metrics) {
        allFaults.addAll(metric.faults);
      }

      correctForm = !allFaults.any((f) => f.affectsForm);
      resultIssues.feedback
          .removeWhere((key, _) => key != 'System' && key != 'progress');
      resultIssues.feedback['Result'] = correctForm ? 'Tốt lắm!' : 'Chỉnh tư thế';
      if (!correctForm) {
        final formFaults =
            allFaults.where((fault) => fault.affectsForm).toList()
              ..sort((a, b) {
                final priorityCompare = a.priority.compareTo(b.priority);
                if (priorityCompare != 0) return priorityCompare;
                return a.type.compareTo(b.type);
              });
        final topFault = formFaults.first;
        resultIssues.feedback[topFault.type] =
            topFault.voiceMessage ?? topFault.message;
      }

      final faultMap = <String, Map<String, String>>{};
      for (final fault in allFaults) {
        if (!faultMap.containsKey(fault.phase)) {
          faultMap[fault.phase] = {};
        }
        faultMap[fault.phase]![fault.type] = fault.message;
      }
      setFeedback.add({correctForm: faultMap});

      final faultAffectsForm = <String, bool>{};
      final faultPriorities = <String, int>{};
      for (final fault in allFaults) {
        faultAffectsForm[fault.type] =
            (faultAffectsForm[fault.type] ?? false) || fault.affectsForm;
        final previousPriority = faultPriorities[fault.type];
        if (previousPriority == null || fault.priority < previousPriority) {
          faultPriorities[fault.type] = fault.priority;
        }
      }

      if (debugEnabled) {
        for (final metric in _metrics) {
          debugData.addAll(metric.debugData);
        }
      }

      logger.addRepLog(RepLog(
        correctForm: correctForm,
        repNumber: repCount,
        data: {
          "min_lead_knee_angle": depthMetric.minKneeAngle ?? leadKneeAngle,
          "max_trunk_lean": trunkLeanMetric.maxTrunkLean ?? trunkLean,
          "fault_types": allFaults.map((f) => f.type).toSet().toList(),
          "fault_affects_form": faultAffectsForm,
          "fault_priorities": faultPriorities,
        },
      ));

      correctForm = true;
      for (final metric in _metrics) {
        metric.resetAndCountFault();
      }
      _reachedBottomThisRep = false;
      return;
    }

    // 7. Update state machine
    // Same comparison as _detectLeadLeg: the leg held as lead must be in
    // front before a descent starts, so the swing of a stepping lead leg is
    // not read as a lunge. Any other facing (angled) does not block.
    final leadAnkleAhead = cameraFacing == CameraFacing.left
        ? lead.ankle!.x < trail.ankle!.x
        : cameraFacing != CameraFacing.right ||
            lead.ankle!.x > trail.ankle!.x;
    _updateLungeState(leadKneeAngle, now, leadAnkleAhead: leadAnkleAhead);

    // 8. Run all metrics
    if (lungeState != LungeState.standing) {
      for (final metric in _metrics) {
        metric.update(ctx);
      }
    }

    if (debugEnabled) {
      for (final metric in _metrics) {
        debugData.addAll(metric.debugData);
      }
    }

    if (lungeState == LungeState.descending) {
      resultIssues.setPhaseStatus('descending', 'Đang xuống...');
    } else if (lungeState == LungeState.bottom) {
      resultIssues.setPhaseStatus('bottom', 'Đứng lên!');
    } else if (lungeState == LungeState.ascending) {
      resultIssues.setPhaseStatus('ascending', 'Đẩy lên!');
    }
  }

  // --- State Machine ---

  void _updateLungeState(double leadKneeAngle, int timestampMs,
      {required bool leadAnkleAhead}) {
    if (leadKneeAngle < LungeConfig.LUNGE_DESCEND_ANGLE_THRESHOLD &&
        lungeState == LungeState.standing &&
        leadAnkleAhead) {
      _transitionState(LungeState.descending, timestampMs);
    } else if (leadKneeAngle <= LungeConfig.LUNGE_BOTTOM_ANGLE_THRESHOLD[1] &&
        leadKneeAngle >= LungeConfig.LUNGE_BOTTOM_ANGLE_THRESHOLD[0] &&
        lungeState == LungeState.descending) {
      _transitionState(LungeState.bottom, timestampMs);
    } else if (leadKneeAngle > LungeConfig.LUNGE_ASCEND_ANGLE_THRESHOLD &&
        lungeState == LungeState.bottom) {
      _transitionState(LungeState.ascending, timestampMs);
    } else if (leadKneeAngle > LungeConfig.LUNGE_STAND_ANGLE_THRESHOLD &&
        (lungeState == LungeState.ascending ||
            lungeState == LungeState.descending)) {
      _transitionState(LungeState.standing, timestampMs);
    }
  }

  void _transitionState(LungeState newState, int timestampMs) {
    previousLungeState = lungeState;
    lungeState = newState;

    // Lock lead leg at rep start, unlock on return to standing
    if (newState == LungeState.descending &&
        previousLungeState == LungeState.standing) {
      _leadLegLocked = true;
      _reachedBottomThisRep = false;
      resultIssues.phaseStatus.clear();
    } else if (newState == LungeState.bottom) {
      _reachedBottomThisRep = true;
    } else if (newState == LungeState.standing) {
      _leadLegLocked = false;
    }

    for (final metric in _metrics) {
      metric.onStateTransition(previousLungeState, newState, timestampMs);
    }
  }
}
