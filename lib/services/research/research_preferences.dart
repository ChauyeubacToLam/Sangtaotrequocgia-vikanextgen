import 'package:shared_preferences/shared_preferences.dart';

enum ResearchCondition { ai, control }

extension ResearchConditionCodec on ResearchCondition {
  String get storageValue => name;

  static ResearchCondition fromStorage(String? value) {
    return switch (value) {
      'control' => ResearchCondition.control,
      _ => ResearchCondition.ai,
    };
  }
}

class ResearchConfig {
  const ResearchConfig({
    this.rawParticipantId = '',
    this.condition = ResearchCondition.ai,
  });

  final String rawParticipantId;
  final ResearchCondition condition;

  String get sanitizedParticipantId {
    final trimmed = rawParticipantId.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'anon') {
      return '';
    }
    return trimmed
        .replaceAll(RegExp(r'[^A-Za-z0-9-]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-$'), '');
  }

  bool get hasParticipantId => sanitizedParticipantId.isNotEmpty;

  String get participantId =>
      hasParticipantId ? sanitizedParticipantId : 'anon';

  bool get isControl => condition == ResearchCondition.control;
}

class ResearchPreferences {
  static const String participantIdKey = 'vika_research_participant_id';
  static const String conditionKey = 'vika_research_condition';

  static ResearchConfig _cached = const ResearchConfig();
  static ResearchConfig get cachedConfig => _cached;

  const ResearchPreferences._();

  static Future<ResearchConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawId = prefs.getString(participantIdKey) ?? '';
    final cond = ResearchConditionCodec.fromStorage(
      prefs.getString(conditionKey),
    );
    final config = ResearchConfig(rawParticipantId: rawId, condition: cond);
    _cached = config;
    return config;
  }

  static Future<void> saveParticipantId(String participantId) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = participantId.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(participantIdKey);
    } else {
      await prefs.setString(participantIdKey, trimmed);
    }
    _cached = ResearchConfig(
      rawParticipantId: trimmed,
      condition: _cached.condition,
    );
  }

  static Future<void> saveCondition(ResearchCondition condition) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(conditionKey, condition.storageValue);
    _cached = ResearchConfig(
      rawParticipantId: _cached.rawParticipantId,
      condition: condition,
    );
  }

  static void resetCacheForTesting() {
    _cached = const ResearchConfig();
  }
}
