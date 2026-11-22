import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/step_up/step_up.dart';

typedef _Points = Map<PoseLandmarkType, (double, double)>;

const _ls = PoseLandmarkType.leftShoulder;
const _rs = PoseLandmarkType.rightShoulder;
const _lh = PoseLandmarkType.leftHip;
const _rh = PoseLandmarkType.rightHip;
const _lk = PoseLandmarkType.leftKnee;
const _rk = PoseLandmarkType.rightKnee;
const _la = PoseLandmarkType.leftAnkle;
const _ra = PoseLandmarkType.rightAnkle;

const _farLeg = {_rh, _rk, _ra};

const _Points _stand = {
  _ls: (300, 200),
  _rs: (305, 200),
  _lh: (300, 400),
  _rh: (305, 400),
  _lk: (300, 600),
  _rk: (305, 600),
  _la: (300, 800),
  _ra: (305, 800),
};

final _Points _nearFootOnChair = {
  ..._stand,
  _lk: (390, 480),
  _la: (400, 640),
};

final _Points _farFootOnChair = {
  ..._stand,
  _rk: (395, 480),
  _ra: (405, 640),
};

final _Points _farPush = {
  _ls: (330, 160),
  _rs: (335, 160),
  _lh: (330, 360),
  _rh: (335, 360),
  _lk: (315, 580),
  _rk: (400, 470),
  _la: (300, 800),
  _ra: (405, 640),
};

final _nearLead = [_nearFootOnChair, _top];
final _farLead = [_farFootOnChair, _farPush, _top];

const _Points _top = {
  _ls: (400, 40),
  _rs: (405, 40),
  _lh: (400, 240),
  _rh: (405, 240),
  _lk: (400, 440),
  _rk: (405, 440),
  _la: (400, 640),
  _ra: (405, 640),
};

const _Points _halfUp = {
  _ls: (350, 160),
  _rs: (355, 160),
  _lh: (350, 360),
  _rh: (355, 360),
  _lk: (395, 470),
  _rk: (305, 600),
  _la: (400, 640),
  _ra: (305, 800),
};

Map<PoseLandmarkType, PoseLandmark> _pose(
  _Points points, {
  Set<PoseLandmarkType> lowConfidence = const {},
}) {
  return {
    for (final entry in points.entries)
      entry.key: PoseLandmark(
        type: entry.key,
        x: entry.value.$1,
        y: entry.value.$2,
        z: entry.key.name.startsWith('left') ? -0.2 : 0.0,
        likelihood: lowConfidence.contains(entry.key) ? 0.1 : 0.99,
      ),
  };
}

_Points _lerp(_Points a, _Points b, double t) => {
      for (final type in a.keys)
        type: (
          a[type]!.$1 + (b[type]!.$1 - a[type]!.$1) * t,
          a[type]!.$2 + (b[type]!.$2 - a[type]!.$2) * t,
        ),
    };

class _Harness {
  _Harness({this.lowConfidence = const {}}) {
    final start = _pose(_stand, lowConfidence: lowConfidence);
    exercise.cameraFacing = exercise.detectCameraFacing(start);
    expect(exercise.isInStartPosition(start), isTrue);
    exercise.exerciseState = ExerciseState.activated;
    exercise.onExerciseActivated();
  }

  final StepUp exercise = StepUp(maxRep: 10);
  final Set<PoseLandmarkType> lowConfidence;
  int _timestampMs = 0;

  void frame(_Points points) {
    final pose = _pose(points, lowConfidence: lowConfidence);
    exercise.frameTimestamp =
        DateTime.fromMillisecondsSinceEpoch(_timestampMs += 50);
    exercise.cameraFacing = exercise.detectCameraFacing(pose);
    expect(exercise.checkSafety(pose), isNull);
    exercise.checkingPose(pose);
  }

  void hold(_Points points, int frames) {
    for (var i = 0; i < frames; i++) {
      frame(points);
    }
  }

  void move(_Points from, _Points to, int frames) {
    for (var i = 1; i <= frames; i++) {
      frame(_lerp(from, to, i / frames));
    }
  }

  void stepUpAndDown(List<_Points> upPath) {
    hold(_stand, 5);
    var previous = _stand;
    for (final next in upPath) {
      move(previous, next, 8);
      previous = next;
    }
    hold(_top, 6);
    move(_top, _stand, 10);
    hold(_stand, 5);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stepping up onto the chair, standing tall and stepping down counts one rep',
      () {
    final h = _Harness();
    h.stepUpAndDown(_nearLead);

    expect(h.exercise.repCount, 1);
    expect(h.exercise.state, StepUpState.standing);
    final data = h.exercise.logger.repLogs.single.data;
    expect(data['max_hip_rise'] as double, greaterThan(0.75));
    expect(data['top_knee_angle'] as double, greaterThan(170));
    expect(data['lead_leg'], 'left');
    expect(data['fault_types'], isEmpty);
    expect(h.exercise.logger.repLogs.single.correctForm, isTrue);
  });

  test('a half step that never stands up on the chair is not counted', () {
    final h = _Harness();
    h.hold(_stand, 5);
    h.move(_stand, _nearFootOnChair, 6);
    h.move(_nearFootOnChair, _halfUp, 6);
    h.hold(_halfUp, 4);
    h.move(_halfUp, _stand, 8);
    h.hold(_stand, 5);

    expect(h.exercise.repCount, 0);
    expect(h.exercise.debugData['noCount'], 'height');
    h.exercise.onSetComplete();
    expect(h.exercise.logger.setLogs['no_count_attempts'], 1);
  });

  test('far-side hip, knee and ankle hidden by the chair still count', () {
    final h = _Harness(lowConfidence: _farLeg);
    h.stepUpAndDown(_farLead);
    h.stepUpAndDown(_nearLead);

    expect(h.exercise.repCount, 2);
    expect(
      h.exercise.logger.repLogs.map((rep) => rep.data['lead_leg']),
      ['right', 'left'],
    );
  });

  test('leading with the same leg twice is logged but still counted', () {
    final h = _Harness();
    h.stepUpAndDown(_nearLead);
    h.stepUpAndDown(_nearLead);
    h.stepUpAndDown(_farLead);

    expect(h.exercise.repCount, 3);
    final faults = h.exercise.logger.repLogs
        .map((rep) => rep.data['fault_types'] as List)
        .toList();
    expect(faults[0], isEmpty);
    expect(faults[1], ['alternate']);
    expect(faults[2], isEmpty);
    expect(h.exercise.logger.repLogs[1].correctForm, isTrue);
    h.exercise.onSetComplete();
    expect(h.exercise.logger.setLogs['alternate_fails_count'], 1);
    expect(h.exercise.logger.setLogs['trunk_fails_count'], 0);
  });
}
