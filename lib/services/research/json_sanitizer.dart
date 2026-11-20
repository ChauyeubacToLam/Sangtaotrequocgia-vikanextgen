import 'dart:collection';
import 'dart:convert';

String formatUtcIsoMillis(DateTime dt) {
  final u = dt.toUtc();
  final y = u.year.toString().padLeft(4, '0');
  final mo = u.month.toString().padLeft(2, '0');
  final d = u.day.toString().padLeft(2, '0');
  final h = u.hour.toString().padLeft(2, '0');
  final mi = u.minute.toString().padLeft(2, '0');
  final s = u.second.toString().padLeft(2, '0');
  final ms = u.millisecond.toString().padLeft(3, '0');
  return '$y-$mo-${d}T$h:$mi:$s.${ms}Z';
}

String formatSessionTimestampUtc(DateTime dt) {
  final u = dt.toUtc();
  final y = u.year.toString().padLeft(4, '0');
  final mo = u.month.toString().padLeft(2, '0');
  final d = u.day.toString().padLeft(2, '0');
  final h = u.hour.toString().padLeft(2, '0');
  final mi = u.minute.toString().padLeft(2, '0');
  final s = u.second.toString().padLeft(2, '0');
  return '$y$mo${d}T$h$mi${s}Z';
}

Object? sanitizeForJson(Object? value) {
  return _sanitize(value, HashSet<Object>.identity());
}

const JsonEncoder _prettyJsonEncoder = JsonEncoder.withIndent('  ');

String encodeSafeJson(Map<String, Object?> payload) {
  final sanitized = sanitizeForJson(payload);
  return _prettyJsonEncoder.convert(sanitized);
}

Object? _sanitize(Object? value, Set<Object> ancestors) {
  if (value == null || value is bool || value is String) {
    return value;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    if (value.isNaN || value.isInfinite) {
      return null;
    }
    return value;
  }
  if (value is DateTime) {
    return formatUtcIsoMillis(value);
  }
  if (value is Enum) {
    return value.name;
  }
  if (value is Map) {
    if (!ancestors.add(value)) {
      return null;
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      String keyStr;
      try {
        keyStr = entry.key?.toString() ?? 'null';
      } catch (_) {
        keyStr = 'unknown';
      }
      result[keyStr] = _sanitize(entry.value, ancestors);
    }
    ancestors.remove(value);
    return result;
  }
  if (value is Iterable) {
    if (!ancestors.add(value)) {
      return null;
    }
    final result = <Object?>[
      for (final item in value) _sanitize(item, ancestors),
    ];
    ancestors.remove(value);
    return result;
  }
  try {
    return value.toString();
  } catch (_) {
    return null;
  }
}
