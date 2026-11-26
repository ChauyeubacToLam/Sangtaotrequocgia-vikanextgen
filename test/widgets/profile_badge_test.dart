import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/screens/main_shell.dart';
import 'package:vika/services/user_profile_service.dart';
import 'package:vika/widgets/ivory/bottom_nav.dart';

AppUserProfile _p({int? weight, int? height}) => AppUserProfile(
      id: 'u',
      displayName: 'A',
      initial: 'A',
      streakWeeks: 0,
      weightKg: weight,
      heightCm: height,
    );

void main() {
  test('profile needs body data when weight or height is missing', () {
    expect(profileNeedsBody(null), isFalse);
    expect(profileNeedsBody(_p(weight: 60, height: 165)), isFalse);
    expect(profileNeedsBody(_p(height: 165)), isTrue);
    expect(profileNeedsBody(_p(weight: 60)), isTrue);
    expect(profileNeedsBody(_p(weight: 0, height: 165)), isTrue);
  });

  testWidgets('bottom nav shows a red dot only on the badged tab',
      (tester) async {
    Future<void> pump(int? badge) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            bottomNavigationBar: IvoryBottomNav(
              currentIndex: 0,
              bottomInset: 0,
              onTap: (_) {},
              badgeIndex: badge,
            ),
          ),
        ));

    await pump(null);
    expect(find.byKey(const ValueKey('nav-badge')), findsNothing);
    await pump(4);
    expect(find.byKey(const ValueKey('nav-badge')), findsOneWidget);
  });
}
