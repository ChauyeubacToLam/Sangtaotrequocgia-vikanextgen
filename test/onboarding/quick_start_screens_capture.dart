// One-off screenshot capture for the quick-start flow. Run with:
//   fvm flutter test test/onboarding/quick_start_screens_capture.dart --update-goldens
// PNGs land in build/quick_start_screens/.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:vika/screens/onboarding/quick_start/quick_start_navigator.dart';
import 'package:vika/services/catalog/catalog_source.dart';

const _out = '../../build/quick_start_screens';
const _materialFonts = '.fvm/flutter_sdk/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  final vietnam = FontLoader('BeVietnamPro');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    vietnam.addFont(
      rootBundle.load('assets/fonts/be_vietnam_pro/BeVietnamPro-$w.ttf'),
    );
  }
  await vietnam.load();
  ByteData file(String name) => ByteData.view(
        File('$_materialFonts/$name').readAsBytesSync().buffer,
      );
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(file('materialicons-regular.otf'))))
      .load();
  await (FontLoader('Roboto')
        ..addFont(Future.value(file('roboto-regular.ttf')))
        ..addFont(Future.value(file('roboto-bold.ttf'))))
      .load();
}

String _b64(Map<String, dynamic> m) =>
    base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');

/// Fake, never-sent session so the navigator opens at B2.
Future<void> _fakeSignIn() async {
  final exp = DateTime.now().add(const Duration(days: 30));
  final jwt = '${_b64({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${_b64({
        'sub': '00000000-0000-4000-8000-000000000001',
        'exp': exp.millisecondsSinceEpoch ~/ 1000,
        'role': 'authenticated',
      })}.sig';
  await Supabase.instance.client.auth.recoverSession(jsonEncode({
    'access_token': jwt,
    'token_type': 'bearer',
    'expires_in': 2592000,
    'expires_at': exp.millisecondsSinceEpoch ~/ 1000,
    'refresh_token': 'fake',
    'user': {
      'id': '00000000-0000-4000-8000-000000000001',
      'aud': 'authenticated',
      'email': 'demo@example.com',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': DateTime.now().toIso8601String(),
    },
  }));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
    await _loadFonts();
    // main.dart does this before any screen is built; it supplies the
    // Vietnamese exercise names.
    await CatalogSource.instance.ensureLoaded();
  });

  Future<void> shot(WidgetTester tester, String name) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await expectLater(
      find.byType(QuickStartNavigator),
      matchesGoldenFile('$_out/$name.png'),
    );
  }

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: QuickStartNavigator(key: UniqueKey()),
      ),
    );
  }

  Future<void> settleAsync(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('capture quick-start screens', (tester) async {
    debugDisableShadows = false;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // B1
    await start(tester);
    await shot(tester, '01_b1_tao_tai_khoan');
    await tester.tap(find.text('Đăng nhập').first);
    await shot(tester, '02_b1_dang_nhap');
    await tester.tap(find.text('Đăng nhập').last);
    await shot(tester, '03_b1_loi_email');

    // B2 (signed in)
    await tester.runAsync(_fakeSignIn);
    await start(tester);
    await shot(tester, '04_b2_chon_muc_tieu');

    await tester.tap(find.text('Tăng cơ, giảm mỡ'));
    await shot(tester, '05_b2_co_mo_chua_chon');
    await tester.tap(find.text('Giảm mỡ toàn thân'));
    await shot(tester, '06_b2_co_mo_da_chon');

    await tester.tap(find.text('Đau mỏi'));
    await shot(tester, '07_b2_dau_moi');

    await tester.tap(find.text('Nổi tiếng'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Herschel Walker'));
    await shot(tester, '08_b2_noi_tieng_da_chon');

    await tester.tap(find.text('Tiếp tục'));
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, '09_b3_dang_chuan_bi');
    await settleAsync(tester);
    await shot(tester, '10_b3_dat_dien_thoai');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    debugDisableShadows = true;
  });
}
