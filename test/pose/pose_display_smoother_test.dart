import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vika/pose/pose_display_smoother.dart';
import 'package:vika/pose/vika_pose_landmark.dart';
import 'package:vika/screens/exercise/widgets/smoothed_pose_overlay.dart';

const Size _image = Size(1280, 960);

Pose _pose(double x, double y, {double presence = 0.9, double visibility = 0.8}) {
  return Pose(
    landmarks: <PoseLandmarkType, PoseLandmark>{
      PoseLandmarkType.leftHip: poseLandmarkWithVikaConfidence(
        type: PoseLandmarkType.leftHip,
        x: x,
        y: y,
        z: 0,
        presence: presence,
        visibility: visibility,
      ),
      PoseLandmarkType.leftKnee: poseLandmarkWithVikaConfidence(
        type: PoseLandmarkType.leftKnee,
        x: x,
        y: y + 100,
        z: 0,
        presence: presence,
        visibility: visibility,
      ),
    },
  );
}

Duration _ms(int value) => Duration(milliseconds: value);

PoseLandmark _hip(PoseDisplaySmoother smoother) =>
    smoother.displayPose!.landmarks[PoseLandmarkType.leftHip]!;

void main() {
  group('PoseDisplaySmoother', () {
    test('first target is shown exactly with its confidence', () {
      final smoother = PoseDisplaySmoother();
      smoother.setTarget(
        _pose(100, 200, presence: 0.7, visibility: 0.6),
        _image,
        _ms(0),
      );

      final hip = _hip(smoother);
      expect(hip.x, 100);
      expect(hip.y, 200);
      expect(hip.presence, 0.7);
      expect(hip.visibility, 0.6);
      expect(smoother.displayPose!.landmarks.length, 2);
    });

    test('display glides toward a new target between detections', () {
      final smoother = PoseDisplaySmoother();
      smoother.setTarget(_pose(100, 200), _image, _ms(0));
      smoother.tick(_ms(0));
      smoother.setTarget(_pose(130, 200), _image, _ms(33));

      smoother.tick(_ms(41));
      final early = _hip(smoother).x;
      expect(early, greaterThan(100));
      expect(early, lessThan(130));

      for (var t = 49; t <= 400; t += 8) {
        smoother.setTarget(_pose(130, 200), _image, _ms(t));
        smoother.tick(_ms(t));
      }
      expect(_hip(smoother).x, closeTo(130, 0.5));
    });

    test('lead never runs further than maxLead past the last target', () {
      final smoother = PoseDisplaySmoother(
        followTimeConstant: const Duration(microseconds: 1),
      );
      smoother.setTarget(_pose(100, 200), _image, _ms(0));
      smoother.setTarget(_pose(110, 200), _image, _ms(33));
      smoother.tick(_ms(33));
      smoother.tick(_ms(500));

      final velocity = (110 - 100) / 0.033 * smoother.velocityBlend;
      final maxAhead = 110 + velocity * smoother.maxLead.inMicroseconds / 1e6;
      expect(_hip(smoother).x, closeTo(maxAhead, 0.01));
    });

    test('large jumps snap instead of sliding across the frame', () {
      final smoother = PoseDisplaySmoother();
      smoother.setTarget(_pose(100, 200), _image, _ms(0));
      smoother.tick(_ms(0));
      smoother.setTarget(_pose(900, 700), _image, _ms(33));

      expect(_hip(smoother).x, 900);
      expect(_hip(smoother).y, 700);
    });

    test('null pose clears the display and notifies once', () {
      final smoother = PoseDisplaySmoother();
      var notifications = 0;
      smoother.addListener(() => notifications++);
      smoother.setTarget(_pose(100, 200), _image, _ms(0));
      smoother.setTarget(null, _image, _ms(33));
      smoother.setTarget(null, _image, _ms(66));

      expect(smoother.displayPose, isNull);
      expect(smoother.hasPose, isFalse);
      expect(notifications, 2);
    });

    test('image size change restarts tracking without gliding', () {
      final smoother = PoseDisplaySmoother();
      smoother.setTarget(_pose(100, 200), _image, _ms(0));
      smoother.tick(_ms(0));
      smoother.setTarget(_pose(120, 210), const Size(960, 1280), _ms(33));

      expect(_hip(smoother).x, 120);
      expect(_hip(smoother).y, 210);
    });

    test('ticks without a pose do not notify', () {
      final smoother = PoseDisplaySmoother();
      var notifications = 0;
      smoother.addListener(() => notifications++);
      smoother.tick(_ms(0));
      smoother.tick(_ms(16));

      expect(notifications, 0);
    });
  });

  testWidgets('SmoothedPoseOverlay paints a pose and stops ticking without one',
      (tester) async {
    Widget build(Pose? pose) => MaterialApp(
          home: Scaffold(
            body: SmoothedPoseOverlay(
              size: const Size(400, 300),
              pose: pose,
              imageSize: _image,
              rotation: InputImageRotation.rotation0deg,
              lensDirection: CameraLensDirection.front,
              fit: BoxFit.contain,
            ),
          ),
        );

    await tester.pumpWidget(build(_pose(100, 200)));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(build(_pose(140, 220)));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(build(null));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
