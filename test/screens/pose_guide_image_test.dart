import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/screens/exercise/setup/pose_guide_view.dart';
import 'package:vika/screens/exercise/setup/pose_guides.dart';

void main() {
  testWidgets('pose guide images load even when the asset manifest is cached',
      (tester) async {
    await tester.runAsync(() async {
      await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final guide in kPoseGuides.values) {
        final image = await loadPoseGuideImage(guide)
            .timeout(const Duration(seconds: 10));
        expect(image, isNotNull, reason: guide.asset);
      }
    });
  });
}
