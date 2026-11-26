import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vika/data/vika_albums.dart';
import 'package:vika/widgets/library/library_card.dart';

void main() {
  test('every album cover exists', () {
    expect(vikaAlbums, isNotEmpty);
    for (final album in vikaAlbums) {
      expect(album.cover, isNotEmpty, reason: album.id);
      expect(File(album.cover).existsSync(), isTrue, reason: album.id);
    }
  });

  testWidgets('album card displays its cover', (tester) async {
    final album = vikaAlbums.first;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LibraryCard(data: album.toCardData(), onTap: () {})),
    ));
    expect(
      find.byWidgetPredicate((widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == album.cover),
      findsOneWidget,
    );
  });
}
