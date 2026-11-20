import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vika/pose/pose_landmarker_adapter.dart';

void main() {
  group('CameraX preview geometry', () {
    Map<String, dynamic> event({required int rotationDegrees}) =>
        <String, dynamic>{
          'previewBufferWidth': 1280,
          'previewBufferHeight': 720,
          'previewCropLeft': 160,
          'previewCropTop': 90,
          'previewCropRight': 1120,
          'previewCropBottom': 630,
          'previewRotationDegrees': rotationDegrees,
        };

    test('keeps crop axes for 0 and 180 degree previews', () {
      for (final rotation in <int>[0, 180]) {
        final geometry = PoseLandmarkerAdapter.previewGeometryFromChannelData(
          event(rotationDegrees: rotation),
        );

        expect(geometry, isNotNull);
        expect(geometry!.bufferSize, const Size(1280, 720));
        expect(geometry.displaySize, const Size(960, 540));
      }
    });

    test('swaps crop axes exactly once for 90 and 270 degree previews', () {
      for (final rotation in <int>[90, 270]) {
        final geometry = PoseLandmarkerAdapter.previewGeometryFromChannelData(
          event(rotationDegrees: rotation),
        );

        expect(geometry, isNotNull);
        expect(geometry!.displaySize, const Size(540, 960));
      }
    });

    test('falls back to raw buffer bounds when crop metadata is empty', () {
      final geometry = PoseLandmarkerAdapter.previewGeometryFromChannelData(
        <String, dynamic>{
          'previewBufferWidth': 1280,
          'previewBufferHeight': 720,
          'previewCropLeft': 0,
          'previewCropTop': 0,
          'previewCropRight': 0,
          'previewCropBottom': 0,
          'previewRotationDegrees': 90,
        },
      );

      expect(geometry, isNotNull);
      expect(geometry!.displaySize, const Size(720, 1280));
    });

    test('rejects incomplete or non-positive preview metadata', () {
      expect(
        PoseLandmarkerAdapter.previewGeometryFromChannelData(
          <String, dynamic>{
            'previewBufferWidth': 1280,
            'previewBufferHeight': 720,
          },
        ),
        isNull,
      );
      expect(
        PoseLandmarkerAdapter.previewGeometryFromChannelData(
          <String, dynamic>{
            'previewBufferWidth': 0,
            'previewBufferHeight': 720,
            'previewRotationDegrees': 0,
          },
        ),
        isNull,
      );
    });
  });
}
