import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/exercise/exercise_base.dart';
import 'package:vika/exercise/push_up_rotation/push_up_rotation.dart';

typedef _Points = Map<PoseLandmarkType, (double, double)>;

const _ls = PoseLandmarkType.leftShoulder;
const _rs = PoseLandmarkType.rightShoulder;
const _le = PoseLandmarkType.leftElbow;
const _re = PoseLandmarkType.rightElbow;
const _lw = PoseLandmarkType.leftWrist;
const _rw = PoseLandmarkType.rightWrist;
const _lh = PoseLandmarkType.leftHip;
const _rh = PoseLandmarkType.rightHip;
const _la = PoseLandmarkType.leftAnkle;
const _ra = PoseLandmarkType.rightAnkle;

const _Points _plank = {
  _ls: (600, 400),
  _rs: (605, 395),
  _le: (600, 500),
  _re: (605, 495),
  _lw: (600, 600),
  _rw: (605, 595),
  _lh: (400, 410),
  _rh: (405, 405),
  _la: (100, 420),
  _ra: (105, 415),
};

const _Points _bottom = {
  _ls: (600, 520),
  _rs: (605, 515),
  _le: (560, 560),
  _re: (565, 555),
  _lw: (600, 600),
  _rw: (605, 595),
  _lh: (400, 500),
  _rh: (405, 495),
  _la: (100, 420),
  _ra: (105, 415),
};

const _Points _shallow = {
  _ls: (600, 460),
  _rs: (605, 455),
  _le: (570, 530),
  _re: (575, 525),
  _lw: (600, 600),
  _rw: (605, 595),
  _lh: (400, 455),
  _rh: (405, 450),
  _la: (100, 420),
  _ra: (105, 415),
};

const _Points _nearArmHalfway = {
  _ls: (600, 350),
  _rs: (605, 420),
  _le: (650, 300),
  _re: (605, 510),
  _lw: (700, 250),
  _rw: (605, 600),
  _lh: (400, 395),
  _rh: (405, 418),
  _la: (100, 410),
  _ra: (105, 418),
};

const _Points _nearArmOpen = {
  _ls: (600, 300),
  _rs: (605, 450),
  _le: (600, 200),
  _re: (605, 525),
  _lw: (600, 100),
  _rw: (605, 600),
  _lh: (400, 380),
  _rh: (405, 430),
  _la: (100, 400),
  _ra: (105, 420),
};

const _Points _farArmHalfway = {
  _ls: (600, 420),
  _rs: (605, 350),
  _le: (600, 510),
  _re: (655, 300),
  _lw: (600, 600),
  _rw: (705, 250),
  _lh: (400, 418),
  _rh: (405, 395),
  _la: (100, 418),
  _ra: (105, 410),
};

const _Points _farArmOpen = {
  _ls: (600, 450),
  _rs: (605, 300),
  _le: (600, 525),
  _re: (605, 200),
  _lw: (600, 600),
  _rw: (605, 100),
  _lh: (400, 430),
  _rh: (405, 380),
  _la: (100, 420),
  _ra: (105, 400),
};

Map<PoseLandmarkType, PoseLandmark> _pose(_Points points) => {
      for (final entry in points.entries)
        entry.key: PoseLandmark(
          type: entry.key,
          x: entry.value.$1,
          y: entry.value.$2,
          z: entry.key.name.startsWith('left') ? -0.2 : 0.0,
          likelihood: 0.99,
        ),
    };

_Points _lerp(_Points a, _Points b, double t) => {
      for (final type in a.keys)
        type: (
          a[type]!.$1 + (b[type]!.$1 - a[type]!.$1) * t,
          a[type]!.$2 + (b[type]!.$2 - a[type]!.$2) * t,
        ),
    };

class _Harness {
  _Harness() {
    final start = _pose(_plank);
    exercise.cameraFacing = exercise.detectCameraFacing(start);
    expect(exercise.isInStartPosition(start), isTrue);
    exercise.exerciseState = ExerciseState.activated;
    exercise.onExerciseActivated();
  }

  final PushUpRotation exercise = PushUpRotation(maxRep: 10);
  int _timestampMs = 0;

  void frame(_Points points) {
    final pose = _pose(points);
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

  void path(List<_Points> keyframes, {int framesPerLeg = 8}) {
    for (var k = 1; k < keyframes.length; k++) {
      for (var i = 1; i <= framesPerLeg; i++) {
        frame(_lerp(keyframes[k - 1], keyframes[k], i / framesPerLeg));
      }
    }
  }

  void pushUp({_Points depth = _bottom}) {
    hold(_plank, 4);
    path([_plank, depth, _plank], framesPerLeg: 10);
    hold(_plank, 3);
  }

  void rotate({required bool nearArm}) {
    final halfway = nearArm ? _nearArmHalfway : _farArmHalfway;
    final open = nearArm ? _nearArmOpen : _farArmOpen;
    path([_plank, halfway, open]);
    hold(open, 4);
    path([open, halfway, _plank]);
    hold(_plank, 4);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('push-up, rotation with the arm to the ceiling, and return counts one rep',
      () {
    final h = _Harness();
    h.pushUp();
    expect(h.exercise.state, PushUpRotationState.rotate);
    expect(h.exercise.repCount, 0);

    h.rotate(nearArm: true);

    expect(h.exercise.repCount, 1);
    expect(h.exercise.state, PushUpRotationState.plank);
    final rep = h.exercise.logger.repLogs.single;
    expect(rep.correctForm, isTrue);
    expect(rep.data['min_elbow_angle'] as double, lessThan(100));
    expect(rep.data['max_wrist_rise'] as double, greaterThan(0.9));
    expect(rep.data['max_shoulder_stack'] as double, greaterThan(0.7));
    expect(rep.data['open_side'], 'left');
    expect(rep.data['fault_types'], isEmpty);
  });

  test('a shallow push-up followed by a rotation is not counted', () {
    final h = _Harness();
    h.pushUp(depth: _shallow);
    expect(h.exercise.state, PushUpRotationState.plank);
    expect(h.exercise.debugData['noCount'], 'depth');

    h.rotate(nearArm: true);

    expect(h.exercise.repCount, 0);
    h.exercise.onSetComplete();
    expect(h.exercise.logger.setLogs['shallow_attempts'], 1);
  });

  test('a push-up without the rotation is not counted', () {
    final h = _Harness();
    h.pushUp();
    h.path([_plank, _nearArmHalfway, _plank]);
    h.hold(_plank, 4);
    expect(h.exercise.state, PushUpRotationState.rotate);

    h.pushUp();

    expect(h.exercise.repCount, 0);
    expect(h.exercise.debugData['noCount'], 'rotation');
    expect(h.exercise.state, PushUpRotationState.rotate);
    h.exercise.onSetComplete();
    expect(h.exercise.logger.setLogs['no_rotation_attempts'], 1);
  });

  test('alternating arms counts every rep; repeating an arm is logged only',
      () {
    final h = _Harness();
    h.pushUp();
    h.rotate(nearArm: true);
    h.pushUp();
    h.rotate(nearArm: false);
    h.pushUp();
    h.rotate(nearArm: false);

    expect(h.exercise.repCount, 3);
    expect(
      h.exercise.logger.repLogs.map((rep) => rep.data['open_side']),
      ['left', 'right', 'right'],
    );
    expect(
      h.exercise.logger.repLogs.map((rep) => rep.data['fault_types']),
      [isEmpty, isEmpty, ['alternate']],
    );
    expect(h.exercise.logger.repLogs.last.correctForm, isTrue);
    h.exercise.onSetComplete();
    expect(h.exercise.logger.setLogs['alternate_fails_count'], 1);
    expect(h.exercise.logger.setLogs['body_line_fails_count'], 0);
  });
}
