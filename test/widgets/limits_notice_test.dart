import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/widgets/limits_notice.dart';
import 'package:vika/widgets/tk/tk.dart';

void main() {
  testWidgets('limits notice shows on every start and returns true on acknowledge',
      (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => results
              .add(await showLimitsNotice(context, requireAck: true)),
          child: const Text('start'),
        ),
      ),
    ));

    for (var round = 1; round <= 2; round++) {
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      expect(find.text(kLimitsNoticeTitle), findsOneWidget);
      for (final (_, text) in kLimitsNoticePoints) {
        expect(find.text(text), findsOneWidget);
      }
      await tester.tap(find.byType(TkButton));
      await tester.pumpAndSettle();
      expect(find.text(kLimitsNoticeTitle), findsNothing);
      expect(results.length, round);
      expect(results.last, isTrue);
    }
  });
}
