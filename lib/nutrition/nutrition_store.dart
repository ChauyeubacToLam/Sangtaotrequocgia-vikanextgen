import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'nutrition_sync.dart';
import 'nutrition_targets.dart';

enum MealSlot { breakfast, lunch, dinner, snack }

extension MealSlotLabel on MealSlot {
  String get label => switch (this) {
        MealSlot.breakfast => 'Sáng',
        MealSlot.lunch => 'Trưa',
        MealSlot.dinner => 'Tối',
        MealSlot.snack => 'Phụ',
      };
}

MealSlot mealSlotForHour(int hour) => hour < 10
    ? MealSlot.breakfast
    : hour < 15
        ? MealSlot.lunch
        : hour < 21
            ? MealSlot.dinner
            : MealSlot.snack;

class DiaryEntry {
  const DiaryEntry({
    required this.foodId,
    required this.grams,
    required this.meal,
    required this.at,
  });

  final String foodId;
  final double grams;
  final MealSlot meal;
  final DateTime at;

  Map<String, Object> toJson() => {
        'food': foodId,
        'g': grams,
        'meal': meal.name,
        'at': at.toIso8601String(),
      };

  static DiaryEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final food = raw['food'];
    final g = raw['g'];
    if (food is! String || g is! num) return null;
    return DiaryEntry(
      foodId: food,
      grams: g.toDouble(),
      meal: MealSlot.values.firstWhere(
        (m) => m.name == raw['meal'],
        orElse: () => MealSlot.snack,
      ),
      at: DateTime.tryParse('${raw['at']}') ?? DateTime.now(),
    );
  }
}

class DayLog {
  DayLog({
    List<DiaryEntry>? entries,
    this.waterMl = 0,
    this.note = '',
    this.burnedKcal = 0,
    List<String>? activities,
  })  : entries = entries ?? [],
        activities = activities ?? [];

  final List<DiaryEntry> entries;
  int waterMl;
  String note;
  double burnedKcal;
  final List<String> activities;

  Map<String, Object> toJson() => {
        'entries': [for (final e in entries) e.toJson()],
        'water': waterMl,
        'note': note,
        'burned': burnedKcal,
        'acts': activities,
      };

  static DayLog fromJson(Object? raw) {
    if (raw is! Map) return DayLog();
    return DayLog(
      entries: [
        for (final e in (raw['entries'] as List? ?? const []))
          if (DiaryEntry.fromJson(e) case final entry?) entry,
      ],
      waterMl: (raw['water'] as num?)?.toInt() ?? 0,
      note: raw['note'] as String? ?? '',
      burnedKcal: (raw['burned'] as num?)?.toDouble() ?? 0,
      activities: [
        for (final a in (raw['acts'] as List? ?? const []))
          if (a is String) a,
      ],
    );
  }
}

class WeightPoint {
  const WeightPoint(this.day, this.kg);

  final String day;
  final double kg;
}

class FastingState {
  const FastingState({
    this.startedAt,
    this.goalHours = 16,
    this.history = const [],
  });

  final DateTime? startedAt;
  final int goalHours;
  final List<(DateTime, DateTime)> history;
}

class NutritionSettings {
  const NutritionSettings({
    this.goal = NutritionGoal.maintain,
    this.mode = DietMode.balanced,
    this.waterGoalMl = 2000,
    this.stepGoal = 7000,
  });

  final NutritionGoal goal;
  final DietMode mode;
  final int waterGoalMl;
  final int stepGoal;

  NutritionSettings copyWith({
    NutritionGoal? goal,
    DietMode? mode,
    int? waterGoalMl,
    int? stepGoal,
  }) =>
      NutritionSettings(
        goal: goal ?? this.goal,
        mode: mode ?? this.mode,
        waterGoalMl: waterGoalMl ?? this.waterGoalMl,
        stepGoal: stepGoal ?? this.stepGoal,
      );
}

class NutritionStore {
  NutritionStore._();

  static final instance = NutritionStore._();

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  void _changed(String key) => NutritionSync.instance.markDirty(key);

  Future<DayLog> loadDay(DateTime day) async {
    final raw = (await _prefs).getString('nutri_day_${dayKey(day)}');
    if (raw == null) return DayLog();
    try {
      return DayLog.fromJson(jsonDecode(raw));
    } catch (_) {
      return DayLog();
    }
  }

  Future<void> saveDay(DateTime day, DayLog log) async {
    await (await _prefs)
        .setString('nutri_day_${dayKey(day)}', jsonEncode(log.toJson()));
    _changed('nutri_day_${dayKey(day)}');
  }

  Future<DayLog> update(DateTime day, void Function(DayLog log) change) async {
    final log = await loadDay(day);
    change(log);
    await saveDay(day, log);
    return log;
  }

  Future<void> addEntry(DateTime day, DiaryEntry entry) async {
    await update(day, (l) => l.entries.add(entry));
    await _pushRecent(entry.foodId);
  }

  Future<List<String>> recent() async =>
      (await _prefs).getStringList('nutri_recent') ?? const [];

  Future<void> _pushRecent(String id) async {
    final prefs = await _prefs;
    final list = [
      id,
      ...(prefs.getStringList('nutri_recent') ?? const <String>[])
          .where((e) => e != id),
    ];
    await prefs.setStringList('nutri_recent', list.take(30).toList());
    _changed('nutri_recent');
  }

  Future<Set<String>> favorites() async =>
      ((await _prefs).getStringList('nutri_fav') ?? const <String>[]).toSet();

  Future<void> toggleFavorite(String id) async {
    final prefs = await _prefs;
    final set = (prefs.getStringList('nutri_fav') ?? const <String>[]).toSet();
    set.contains(id) ? set.remove(id) : set.add(id);
    await prefs.setStringList('nutri_fav', set.toList());
    _changed('nutri_fav');
  }

  Future<List<Map<String, Object?>>> customFoods() async {
    final raw = (await _prefs).getString('nutri_custom');
    if (raw == null) return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          if (e is Map) e.cast<String, Object?>(),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveCustomFood(Map<String, Object?> food) async {
    final list = [...await customFoods()]
      ..removeWhere((e) => e['id'] == food['id'])
      ..add(food);
    await (await _prefs).setString('nutri_custom', jsonEncode(list));
    _changed('nutri_custom');
  }

  Future<List<WeightPoint>> weights() async {
    final raw = (await _prefs).getStringList('nutri_weights') ?? const [];
    final out = <WeightPoint>[];
    for (final s in raw) {
      final parts = s.split('|');
      final kg = parts.length == 2 ? double.tryParse(parts[1]) : null;
      if (kg != null) out.add(WeightPoint(parts[0], kg));
    }
    out.sort((a, b) => a.day.compareTo(b.day));
    return out;
  }

  Future<void> logWeight(DateTime day, double kg) async {
    final key = dayKey(day);
    final list = [
      for (final w in await weights())
        if (w.day != key) '${w.day}|${w.kg}',
      '$key|$kg',
    ];
    await (await _prefs).setStringList('nutri_weights', list);
    _changed('nutri_weights');
  }

  Future<FastingState> fasting() async {
    final prefs = await _prefs;
    final start = DateTime.tryParse(prefs.getString('nutri_fast_start') ?? '');
    final history = <(DateTime, DateTime)>[];
    for (final s
        in prefs.getStringList('nutri_fast_hist') ?? const <String>[]) {
      final p = s.split('|');
      if (p.length != 2) continue;
      final a = DateTime.tryParse(p[0]);
      final b = DateTime.tryParse(p[1]);
      if (a != null && b != null) history.add((a, b));
    }
    return FastingState(
      startedAt: start,
      goalHours: prefs.getInt('nutri_fast_goal') ?? 16,
      history: history,
    );
  }

  Future<void> startFast(int goalHours) async {
    final prefs = await _prefs;
    await prefs.setString('nutri_fast_start', DateTime.now().toIso8601String());
    await prefs.setInt('nutri_fast_goal', goalHours);
    _changed('nutri_fast_start');
    _changed('nutri_fast_goal');
  }

  Future<void> endFast() async {
    final prefs = await _prefs;
    final start = DateTime.tryParse(prefs.getString('nutri_fast_start') ?? '');
    await prefs.remove('nutri_fast_start');
    _changed('nutri_fast_start');
    if (start == null) return;
    final hist = prefs.getStringList('nutri_fast_hist') ?? const <String>[];
    await prefs.setStringList('nutri_fast_hist', [
      ...hist.skip(hist.length > 59 ? hist.length - 59 : 0),
      '${start.toIso8601String()}|${DateTime.now().toIso8601String()}',
    ]);
    _changed('nutri_fast_hist');
  }

  Future<List<Map<String, Object?>>> _jsonList(String key) async {
    final raw = (await _prefs).getString(key);
    if (raw == null) return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          if (e is Map) e.cast<String, Object?>(),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _upsert(String key, Map<String, Object?> item) async {
    final list = [...await _jsonList(key)]
      ..removeWhere((e) => e['id'] == item['id'])
      ..add(item);
    await (await _prefs).setString(key, jsonEncode(list));
    _changed(key);
  }

  Future<List<Map<String, Object?>>> customRecipes() =>
      _jsonList('nutri_recipes');

  Future<void> saveCustomRecipe(Map<String, Object?> recipe) =>
      _upsert('nutri_recipes', recipe);

  Future<List<Map<String, Object?>>> customMenus() => _jsonList('nutri_menus');

  Future<void> saveCustomMenu(Map<String, Object?> menu) =>
      _upsert('nutri_menus', menu);

  Future<DayLog> replaceEntry(
      DateTime day, DiaryEntry old, DiaryEntry next) async {
    return update(day, (l) {
      final i =
          l.entries.indexWhere((e) => e.at == old.at && e.foodId == old.foodId);
      if (i >= 0) l.entries[i] = next;
    });
  }

  Future<DayLog> removeEntry(DateTime day, DiaryEntry old) async {
    return update(
        day,
        (l) => l.entries
            .removeWhere((e) => e.at == old.at && e.foodId == old.foodId));
  }

  Future<int> copyMeal(DateTime from, DateTime to, MealSlot meal) async {
    final src = await loadDay(from);
    final items = src.entries.where((e) => e.meal == meal).toList();
    if (items.isEmpty) return 0;
    final now = DateTime.now();
    await update(to, (l) {
      for (var i = 0; i < items.length; i++) {
        l.entries.add(DiaryEntry(
          foodId: items[i].foodId,
          grams: items[i].grams,
          meal: meal,
          at: now.add(Duration(milliseconds: i)),
        ));
      }
    });
    return items.length;
  }

  Future<void> saveSteps(DateTime day, int steps) async {
    await (await _prefs).setInt('nutri_steps_${dayKey(day)}', steps);
    _changed('nutri_steps_${dayKey(day)}');
  }

  Future<int?> stepsOn(DateTime day) async =>
      (await _prefs).getInt('nutri_steps_${dayKey(day)}');

  Future<bool> waterReminderOn() async =>
      (await _prefs).getBool('nutri_water_remind') ?? false;

  Future<void> setWaterReminder(bool on) async {
    await (await _prefs).setBool('nutri_water_remind', on);
    _changed('nutri_water_remind');
  }

  Future<NutritionSettings> settings() async {
    final prefs = await _prefs;
    return NutritionSettings(
      goal: NutritionGoal.values.firstWhere(
        (g) => g.name == prefs.getString('nutri_goal'),
        orElse: () => NutritionGoal.maintain,
      ),
      mode: DietMode.values.firstWhere(
        (m) => m.name == prefs.getString('nutri_mode'),
        orElse: () => DietMode.balanced,
      ),
      waterGoalMl: prefs.getInt('nutri_water_goal') ?? 2000,
      stepGoal: prefs.getInt('nutri_step_goal') ?? 7000,
    );
  }

  Future<void> saveSettings(NutritionSettings s) async {
    final prefs = await _prefs;
    await prefs.setString('nutri_goal', s.goal.name);
    await prefs.setString('nutri_mode', s.mode.name);
    await prefs.setInt('nutri_water_goal', s.waterGoalMl);
    await prefs.setInt('nutri_step_goal', s.stepGoal);
    for (final k in [
      'nutri_goal',
      'nutri_mode',
      'nutri_water_goal',
      'nutri_step_goal'
    ]) {
      _changed(k);
    }
  }
}
