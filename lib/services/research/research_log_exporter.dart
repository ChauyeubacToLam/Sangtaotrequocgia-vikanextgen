import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:share_plus/share_plus.dart';

import 'research_log_storage.dart';

class ResearchLogExporter {
  const ResearchLogExporter._();

  static const Rect _fallbackOrigin = Rect.fromLTWH(0, 0, 1, 1);

  static List<XFile> _toXFiles(List<File> files) {
    return <XFile>[
      for (final file in files)
        XFile(
          file.path,
          mimeType: 'application/json',
          name: file.uri.pathSegments.isNotEmpty
              ? file.uri.pathSegments.last
              : file.path.split(Platform.pathSeparator).last,
        ),
    ];
  }

  static Future<bool> shareFiles(
    List<File> files, {
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    if (files.isEmpty) return false;
    try {
      await Share.shareXFiles(
        _toXFiles(files),
        subject: subject ?? 'Nhật ký nghiên cứu Vika',
        sharePositionOrigin: sharePositionOrigin ?? _fallbackOrigin,
      );
      return true;
    } catch (error) {
      debugPrint('[ResearchLog] Failed to share files: $error');
      return false;
    }
  }

  static Future<bool> shareAllStoredLogs({
    Rect? sharePositionOrigin,
    ResearchLogStorage? storage,
  }) async {
    final files =
        await (storage ?? ResearchLogStorage.instance).listStoredLogFiles();
    if (files.isEmpty) return false;
    try {
      await Share.shareXFiles(
        _toXFiles(files),
        subject: 'Tất cả tệp nhật ký Vika (${files.length})',
        sharePositionOrigin: sharePositionOrigin ?? _fallbackOrigin,
      );
      return true;
    } catch (error) {
      debugPrint('[ResearchLog] Failed to share all stored logs: $error');
      return false;
    }
  }

  static Future<bool> shareSessionLogs(
    List<String> fileNames, {
    Rect? sharePositionOrigin,
    ResearchLogStorage? storage,
  }) async {
    final files = await (storage ?? ResearchLogStorage.instance)
        .resolveFilesByNames(fileNames);
    if (files.isEmpty) return false;
    try {
      await Share.shareXFiles(
        _toXFiles(files),
        subject: 'Nhật ký phiên tập Vika (${files.length})',
        sharePositionOrigin: sharePositionOrigin ?? _fallbackOrigin,
      );
      return true;
    } catch (error) {
      debugPrint('[ResearchLog] Failed to share session logs: $error');
      return false;
    }
  }
}
