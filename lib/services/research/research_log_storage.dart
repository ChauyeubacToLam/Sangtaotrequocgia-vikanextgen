import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

import 'json_sanitizer.dart';

class ResearchLogStorage {
  ResearchLogStorage({
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider = directoryProvider ?? _defaultDirectory;

  static const int maxStoredFiles = 300;
  static const String subdirectoryName = 'vika_logs';

  static final ResearchLogStorage instance = ResearchLogStorage();
  static Future<Directory> Function()? _testDirectoryOverride;

  static void setDirectoryProviderForTesting(
    Future<Directory> Function()? provider,
  ) {
    _testDirectoryOverride = provider;
  }

  final Future<Directory> Function() _directoryProvider;
  Future<void> _writeQueue = Future<void>.value();

  static Future<Directory> _defaultDirectory() async {
    final override = _testDirectoryOverride;
    if (override != null) return override();
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}${Platform.pathSeparator}$subdirectoryName');
  }

  Future<Directory> resolveDirectory() => _directoryProvider();

  Future<File?> writeJsonFile({
    required String fileName,
    required Map<String, Object?> payload,
  }) {
    final completer = Completer<File?>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        final encoded = encodeSafeJson(payload);
        final dir = await _directoryProvider();
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final file = File('${dir.path}${Platform.pathSeparator}$fileName');
        await file.writeAsString(encoded, flush: true);
        await _pruneOldFiles(dir);
        completer.complete(file);
      } catch (error) {
        debugPrint('[ResearchLog] Failed to write $fileName: $error');
        completer.complete(null);
      }
    });
    return completer.future;
  }

  Future<List<File>> listStoredLogFiles() async {
    try {
      await _writeQueue;
      final dir = await _directoryProvider();
      if (!await dir.exists()) {
        return const <File>[];
      }
      final files = <File>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          final name = _fileNameOf(entity);
          if (_isResearchLogFile(name)) {
            files.add(entity);
          }
        }
      }
      files.sort(_compareLogFilesOldestFirst);
      return files;
    } catch (error) {
      debugPrint('[ResearchLog] Failed to list log files: $error');
      return const <File>[];
    }
  }

  Future<List<File>> resolveFilesByNames(List<String> fileNames) async {
    try {
      await _writeQueue;
      final dir = await _directoryProvider();
      if (!await dir.exists()) return const <File>[];
      final resolved = <File>[];
      for (final name in fileNames) {
        final f = File('${dir.path}${Platform.pathSeparator}$name');
        if (await f.exists()) {
          resolved.add(f);
        }
      }
      return resolved;
    } catch (error) {
      debugPrint('[ResearchLog] Failed to resolve session files: $error');
      return const <File>[];
    }
  }

  Future<void> _pruneOldFiles(Directory dir) async {
    try {
      final files = <File>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && _isResearchLogFile(_fileNameOf(entity))) {
          files.add(entity);
        }
      }
      if (files.length <= maxStoredFiles) return;
      files.sort(_compareLogFilesOldestFirst);
      final toDeleteCount = files.length - maxStoredFiles;
      for (var i = 0; i < toDeleteCount; i++) {
        try {
          await files[i].delete();
        } catch (error) {
          debugPrint('[ResearchLog] Failed to prune old file: $error');
        }
      }
    } catch (error) {
      debugPrint('[ResearchLog] Prune scan failed: $error');
    }
  }

  static bool _isResearchLogFile(String name) =>
      name.startsWith('vika_') && name.endsWith('.json');

  static String _fileNameOf(File file) {
    final segments = file.uri.pathSegments;
    return segments.isNotEmpty
        ? segments.last
        : file.path.split(Platform.pathSeparator).last;
  }

  static int _compareLogFilesOldestFirst(File a, File b) {
    final na = _fileNameOf(a);
    final nb = _fileNameOf(b);
    final ka = _sortKey(na);
    final kb = _sortKey(nb);
    final cTs = ka.ts.compareTo(kb.ts);
    if (cTs != 0) return cTs;
    final cSid = ka.sessionId.compareTo(kb.sessionId);
    if (cSid != 0) return cSid;
    final cKind = ka.kindOrder.compareTo(kb.kindOrder);
    if (cKind != 0) return cKind;
    final cSeq = ka.seq.compareTo(kb.seq);
    if (cSeq != 0) return cSeq;
    return na.compareTo(nb);
  }

  static final RegExp _setSuffixPattern = RegExp(
    r'^(.+)_(\d+)_[A-Za-z][A-Za-z0-9_-]*_set\d+$',
  );

  static ({String ts, String sessionId, int kindOrder, int seq}) _sortKey(
    String name,
  ) {
    // Expected: vika_<yyyyMMddTHHmmssZ>-<participant>_<seq>_<exercise>_set<n>.json
    // or vika_<yyyyMMddTHHmmssZ>-<participant>_session.json
    if (!name.startsWith('vika_') || !name.endsWith('.json')) {
      return (ts: '', sessionId: name, kindOrder: 0, seq: 0);
    }
    final body = name.substring(5, name.length - 5); // strip 'vika_' & '.json'
    if (body.endsWith('_session') && body.length > '_session'.length) {
      final sessionId = body.substring(0, body.length - '_session'.length);
      final dashIdx = sessionId.indexOf('-');
      final ts = dashIdx > 0 ? sessionId.substring(0, dashIdx) : sessionId;
      return (ts: ts, sessionId: sessionId, kindOrder: 1, seq: 999999);
    }

    final setMatch = _setSuffixPattern.firstMatch(body);
    if (setMatch != null) {
      final sessionId = setMatch.group(1)!;
      final seq = int.tryParse(setMatch.group(2)!) ?? 0;
      final dashIdx = sessionId.indexOf('-');
      final ts = dashIdx > 0 ? sessionId.substring(0, dashIdx) : sessionId;
      return (ts: ts, sessionId: sessionId, kindOrder: 0, seq: seq);
    }

    final firstUnderscore = body.indexOf('_');
    if (firstUnderscore <= 0) {
      return (ts: body, sessionId: body, kindOrder: 0, seq: 0);
    }
    final sessionId = body.substring(0, firstUnderscore);
    final dashIdx = sessionId.indexOf('-');
    final ts = dashIdx > 0 ? sessionId.substring(0, dashIdx) : sessionId;
    final rest = body.substring(firstUnderscore + 1);
    final nextUnderscore = rest.indexOf('_');
    final seqStr =
        nextUnderscore > 0 ? rest.substring(0, nextUnderscore) : rest;
    final seq = int.tryParse(seqStr) ?? 0;
    return (ts: ts, sessionId: sessionId, kindOrder: 0, seq: seq);
  }
}
