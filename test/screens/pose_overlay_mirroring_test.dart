import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/screens/exercise/widgets/pose_overlay_painter.dart';

void main() {
  group('pose overlay presentation mirror', () {
    test('mirrors Android native front-camera landmarks', () {
      expect(
        shouldMirrorPoseOverlay(
          lensDirection: CameraLensDirection.front,
          usesNativeMediaPipe: true,
          platform: TargetPlatform.android,
        ),
        isTrue,
      );
    });

    test('does not double-mirror iOS native front-camera landmarks', () {
      expect(
        shouldMirrorPoseOverlay(
          lensDirection: CameraLensDirection.front,
          usesNativeMediaPipe: true,
          platform: TargetPlatform.iOS,
        ),
        isFalse,
      );
    });

    test('mirrors front camera in the Flutter camera fallback', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
      ]) {
        expect(
          shouldMirrorPoseOverlay(
            lensDirection: CameraLensDirection.front,
            usesNativeMediaPipe: false,
            platform: platform,
          ),
          isTrue,
        );
      }
    });

    test('never mirrors the back camera', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
      ]) {
        for (final usesNativeMediaPipe in <bool>[true, false]) {
          expect(
            shouldMirrorPoseOverlay(
              lensDirection: CameraLensDirection.back,
              usesNativeMediaPipe: usesNativeMediaPipe,
              platform: platform,
            ),
            isFalse,
          );
        }
      }
    });
  });
}
