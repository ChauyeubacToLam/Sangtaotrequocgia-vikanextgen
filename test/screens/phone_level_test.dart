import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vika/models/kept_exercises.dart';
import 'package:vika/pose/vika_image_orientation.dart';
import 'package:vika/screens/exercise/setup/phone_level.dart';
import 'package:vika/screens/exercise/setup/pose_guides.dart';

const double g = 9.81;

double rad(double deg) => deg * math.pi / 180;

void main() {
  group('phoneTiltFromGravity', () {
    test('upright landscape is level on both sides', () {
      for (final (orientation, x) in [
        (VikaImageOrientation.landscapeLeft, g),
        (VikaImageOrientation.landscapeRight, -g),
      ]) {
        final tilt = phoneTiltFromGravity(x: x, y: 0, z: 0, orientation: orientation)!;
        expect(tilt.pitchDeg, closeTo(0, 1e-6));
        expect(tilt.rollDeg, closeTo(0, 1e-6));
        expect(judgePhoneLevel(tilt), PhoneLevelVerdict.level);
      }
    });

    test('screen tilted up reads as leaning back for the front camera', () {
      final tilt = phoneTiltFromGravity(
        x: g * math.cos(rad(15)),
        y: 0,
        z: g * math.sin(rad(15)),
        orientation: VikaImageOrientation.landscapeLeft,
      )!;
      expect(tilt.pitchDeg, closeTo(15, 1e-6));
      expect(judgePhoneLevel(tilt), PhoneLevelVerdict.tiltedBack);
    });

    test('back camera flips the lean direction', () {
      final tilt = phoneTiltFromGravity(
        x: g * math.cos(rad(15)),
        y: 0,
        z: g * math.sin(rad(15)),
        orientation: VikaImageOrientation.landscapeLeft,
        frontCamera: false,
      )!;
      expect(tilt.pitchDeg, closeTo(-15, 1e-6));
      expect(judgePhoneLevel(tilt), PhoneLevelVerdict.tiltedForward);
    });

    test('rotation within the screen plane is roll', () {
      final tilt = phoneTiltFromGravity(
        x: g * math.cos(rad(10)),
        y: g * math.sin(rad(10)),
        z: 0,
        orientation: VikaImageOrientation.landscapeLeft,
      )!;
      expect(tilt.rollDeg.abs(), closeTo(10, 1e-6));
      expect(judgePhoneLevel(tilt), PhoneLevelVerdict.rolled);
    });

    test('small lean inside the window stays level', () {
      final tilt = phoneTiltFromGravity(
        x: -g * math.cos(rad(5)),
        y: g * math.sin(rad(2)),
        z: g * math.sin(rad(5)),
        orientation: VikaImageOrientation.landscapeRight,
      )!;
      expect(judgePhoneLevel(tilt), PhoneLevelVerdict.level);
    });

    test('zero vector has no reading', () {
      expect(
        phoneTiltFromGravity(
          x: 0,
          y: 0,
          z: 0,
          orientation: VikaImageOrientation.landscapeLeft,
        ),
        isNull,
      );
    });
  });

  test('every kept exercise has a model pose guide', () {
    for (final id in keptExerciseIds) {
      final guide = kPoseGuides[id];
      expect(guide, isNotNull, reason: id);
      expect(guide!.steps.length, greaterThanOrEqualTo(2), reason: id);
      expect(guide.asset, 'assets/pose_guide/$id.png');
    }
  });
}
