import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NutritionSync {
  NutritionSync._();

  static final instance = NutritionSync._();
  static const table = 'nutrition_kv';
  static const ownerKey = 'nutri__owner';

  static bool syncable(String key) =>
      key.startsWith('nutri_') &&
      key != ownerKey &&
      key != 'nutri_steps_last' &&
      !key.startsWith('nutri_steps_base_');

  final revision = ValueNotifier<int>(0);
  final Set<String> _dirty = {};
  Timer? _timer;
  StreamSubscription<AuthState>? _sub;
  String? _pulledFor;

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void start() {
    final client = _client;
    if (client == null || _sub != null) return;
    _sub = client.auth.onAuthStateChange.listen(
      (s) {
        final uid = s.session?.user.id;
        if (uid != null && uid != _pulledFor) unawaited(pull(uid));
      },
      onError: (Object _) {},
    );
  }

  void markDirty(String key) {
    _dirty.add(key);
    _schedule(const Duration(seconds: 2));
  }

  void _schedule(Duration after) {
    _timer?.cancel();
    _timer = Timer(after, () => unawaited(flush()));
  }

  Future<void> flush() async {
    final client = _client;
    final uid = client?.auth.currentUser?.id;
    if (client == null || uid == null || _dirty.isEmpty) return;
    if (_pulledFor != uid) return;
    final keys = _dirty.toList();
    _dirty.removeAll(keys);
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc().toIso8601String();
    final upserts = <Map<String, Object?>>[];
    final deletes = <String>[];
    for (final k in keys) {
      final v = prefs.get(k);
      if (v == null) {
        deletes.add(k);
      } else {
        upserts.add({'user_id': uid, 'key': k, 'value': v, 'updated_at': now});
      }
    }
    try {
      if (upserts.isNotEmpty) await client.from(table).upsert(upserts);
      if (deletes.isNotEmpty) {
        await client
            .from(table)
            .delete()
            .eq('user_id', uid)
            .inFilter('key', deletes);
      }
    } catch (_) {
      _dirty.addAll(keys);
      _schedule(const Duration(seconds: 30));
    }
  }

  Future<void> pull(String uid) async {
    final client = _client;
    if (client == null) return;
    final List<Map<String, dynamic>> rows;
    try {
      rows = await client.from(table).select('key, value').eq('user_id', uid);
    } catch (_) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final owner = prefs.getString(ownerKey);
    final local = [
      for (final k in prefs.getKeys())
        if (syncable(k)) k,
    ];
    if (owner != null && owner != uid) {
      _dirty.clear();
      for (final k in local) {
        await prefs.remove(k);
      }
    }
    final remote = <String>{};
    for (final r in rows) {
      final k = r['key'];
      if (k is! String || !syncable(k)) continue;
      remote.add(k);
      if (_dirty.contains(k)) continue;
      await _write(prefs, k, r['value']);
    }
    await prefs.setString(ownerKey, uid);
    if (owner == null || owner == uid) {
      _dirty.addAll(local.where((k) => !remote.contains(k)));
    }
    _pulledFor = uid;
    revision.value++;
    await flush();
  }

  static Future<void> _write(SharedPreferences p, String k, Object? v) async {
    switch (v) {
      case final String s:
        await p.setString(k, s);
      case final bool b:
        await p.setBool(k, b);
      case final int i:
        await p.setInt(k, i);
      case final double d:
        await p.setDouble(k, d);
      case final List<dynamic> l:
        await p.setStringList(k, [for (final e in l) '$e']);
    }
  }
}
