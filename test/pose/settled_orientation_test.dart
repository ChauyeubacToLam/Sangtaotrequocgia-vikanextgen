import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:vika/models/pain_regions.dart';
import 'package:vika/pose/vika_image_orientation.dart';
import 'package:vika/widgets/progress/body_3d.dart';

void main() {
  testWidgets('landscape survives brief portrait and unknown readings',
      (tester) async {
    lastSensorOrientation = VikaImageOrientation.portrait;
    final source = StreamController<NativeDeviceOrientation>();
    final seen = <VikaImageOrientation>[];
    final sub = settledSensorOrientation(source.stream).listen(seen.add);

    source.add(NativeDeviceOrientation.landscapeLeft);
    await tester.pump();
    expect(seen, [VikaImageOrientation.landscapeLeft]);

    source.add(NativeDeviceOrientation.unknown);
    source.add(NativeDeviceOrientation.portraitUp);
    await tester.pump(const Duration(milliseconds: 1000));
    source.add(NativeDeviceOrientation.landscapeLeft);
    await tester.pump(const Duration(seconds: 5));
    expect(seen, [VikaImageOrientation.landscapeLeft]);

    source.add(NativeDeviceOrientation.portraitUp);
    await tester.pump(kLandscapeExitHold + const Duration(milliseconds: 100));
    expect(seen.last, VikaImageOrientation.portrait);

    unawaited(sub.cancel());
    unawaited(source.close());
  });

  test('3D body hit test picks the front surface as the body turns', () {
    final parts = bodyParts3D(BodyGender.male);
    const size = Size(200, 330);
    final front = projectBody(parts, 0, size);
    final chest = front.firstWhere((p) => p.part.label == 'Ngực').rect.center;
    expect(hitBodyPart(front, chest)?.label, 'Ngực');

    final back = projectBody(parts, 3.14159, size);
    expect(hitBodyPart(back, chest)?.region, 'back');

    final knee = front.firstWhere((p) => p.part.region == 'knee').rect.center;
    expect(hitBodyPart(front, knee)?.region, 'knee');
    expect(hitBodyPart(front, const Offset(2, 2)), isNull);
  });
}
