import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vika/services/research/research_log_storage.dart';

void main() {
  test('deleteAllLogFiles removes only research log files', () async {
    final dir = await Directory.systemTemp.createTemp('vika_logs_test');
    addTearDown(() => dir.delete(recursive: true));
    final storage = ResearchLogStorage(directoryProvider: () async => dir);
    await storage.writeJsonFile(fileName: 'vika_set_a.json', payload: {'reps': 3});
    await storage.writeJsonFile(fileName: 'vika_set_b.json', payload: {'reps': 5});
    final other = File('${dir.path}${Platform.pathSeparator}notes.txt');
    await other.writeAsString('keep');

    expect(await storage.deleteAllLogFiles(), 2);
    expect(await storage.listStoredLogFiles(), isEmpty);
    expect(await other.exists(), isTrue);
  });
}
