import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/vn_text.dart';
import 'nutrition_store.dart';
import 'nutrition_targets.dart';

enum Region { bac, trung, nam }

extension RegionLabel on Region {
  String get label => switch (this) {
        Region.bac => 'Miền Bắc',
        Region.trung => 'Miền Trung',
        Region.nam => 'Miền Nam',
      };
}

class Portion {
  const Portion(this.label, this.grams, this.source);

  final String label;
  final double grams;
  final String source;
}

class FoodGroup {
  const FoodGroup(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static const _all = <String, FoodGroup>{
    'mon_an':
        FoodGroup('Món ăn', Icons.ramen_dining_rounded, Color(0xFFFF8A1F)),
    'tinh_bot':
        FoodGroup('Tinh bột', Icons.rice_bowl_rounded, Color(0xFFE5B83A)),
    'ngu_coc': FoodGroup('Ngũ cốc', Icons.grain_rounded, Color(0xFFE5B83A)),
    'khoai_cu': FoodGroup('Khoai củ', Icons.eco_rounded, Color(0xFFB07A3B)),
    'hat_dau': FoodGroup('Hạt, đậu', Icons.spa_rounded, Color(0xFF8E6E3A)),
    'dam': FoodGroup('Món đạm', Icons.set_meal_rounded, Color(0xFFE5484D)),
    'thit': FoodGroup('Thịt', Icons.kebab_dining_rounded, Color(0xFFE5484D)),
    'thuy_san':
        FoodGroup('Thủy sản', Icons.phishing_rounded, Color(0xFF2B5CE6)),
    'trung': FoodGroup('Trứng', Icons.egg_rounded, Color(0xFFE5B83A)),
    'rau': FoodGroup('Rau', Icons.grass_rounded, Color(0xFF3CC35A)),
    'trai_cay': FoodGroup('Trái cây', Icons.apple_rounded, Color(0xFFFF6B6B)),
    'sua': FoodGroup('Sữa', Icons.local_drink_rounded, Color(0xFF7D9BFF)),
    'beo': FoodGroup('Chất béo', Icons.opacity_rounded, Color(0xFFE5B83A)),
    'dau_mo': FoodGroup('Dầu mỡ', Icons.opacity_rounded, Color(0xFFE5B83A)),
    'do_hop': FoodGroup('Đồ hộp', Icons.inventory_2_rounded, Color(0xFF6B6890)),
    'do_ngot': FoodGroup('Đồ ngọt', Icons.cake_rounded, Color(0xFFFF7AB6)),
    'gia_vi':
        FoodGroup('Gia vị', Icons.soup_kitchen_rounded, Color(0xFF8E8BAE)),
    'do_uong':
        FoodGroup('Đồ uống', Icons.local_cafe_rounded, Color(0xFF7D9BFF)),
    'packaged': FoodGroup('Đóng gói', Icons.qr_code_rounded, Color(0xFF6B6890)),
  };

  static FoodGroup of(String key) =>
      _all[key] ??
      const FoodGroup('Khác', Icons.restaurant_rounded, Color(0xFF8E8BAE));
}

const microLabels = <String, (String, String)>{
  'ca': ('Canxi', 'mg'),
  'fe': ('Sắt', 'mg'),
  'mg_': ('Magie', 'mg'),
  'phos': ('Phốt pho', 'mg'),
  'k': ('Kali', 'mg'),
  'na': ('Natri', 'mg'),
  'zn': ('Kẽm', 'mg'),
  'vitc': ('Vitamin C', 'mg'),
  'b1': ('Vitamin B1', 'mg'),
  'b2': ('Vitamin B2', 'mg'),
  'pp': ('Vitamin PP (B3)', 'mg'),
  'b6': ('Vitamin B6', 'mg'),
  'folate': ('Folat', 'µg'),
  'b12': ('Vitamin B12', 'µg'),
  'vita': ('Vitamin A', 'µg'),
  'vitd': ('Vitamin D', 'µg'),
  'vite': ('Vitamin E', 'mg'),
};

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.group,
    required this.per100,
    required this.source,
    this.aka = const [],
    this.portions = const [],
    this.regions = const [],
    this.micro = const {},
    this.refuse,
    this.piece,
    this.howto = const [],
    this.custom = false,
  });

  final Portion? piece;
  final List<String> howto;
  final String id;
  final String name;
  final List<String> aka;
  final String group;
  final Macros per100;
  final String source;
  final List<Portion> portions;
  final List<Region> regions;
  final Map<String, double> micro;
  final double? refuse;
  final bool custom;

  Macros forGrams(double g) => per100.scale(g / 100);

  String amountLabel(double g) {
    final base = '${g.round()} g';
    final p = piece;
    if (p == null || p.grams <= 0) return base;
    final n = (g / p.grams * 2).round() / 2;
    if (n < 0.5) return base;
    final count = n == n.roundToDouble()
        ? '${n.round()}'
        : n.toStringAsFixed(1).replaceAll('.', ',');
    return '$base ≈ $count ${p.label}';
  }

  bool get isDish => group == 'mon_an';
  bool get isRaw => source.startsWith('nin2007');
  String get image => 'assets/food/$id.webp';
  FoodGroup get groupInfo => FoodGroup.of(group);

  Portion? get defaultPortion {
    for (final p in portions) {
      if (p.label == 'Vừa') return p;
    }
    return portions.isEmpty ? null : portions.first;
  }

  String get searchKey => foldVietnamese([name, ...aka].join(' '));

  bool get highProtein =>
      per100.kcal > 0 && per100.protein * 4 / per100.kcal >= 0.3;
  bool get lowCarb => per100.kcal > 0 && per100.carb * 4 / per100.kcal <= 0.2;
  bool get lowFat => per100.kcal > 0 && per100.fat * 9 / per100.kcal <= 0.25;

  static Macros _macros(Map m) => Macros(
        kcal: (m['kcal'] as num).toDouble(),
        protein: (m['p'] as num).toDouble(),
        fat: (m['f'] as num).toDouble(),
        carb: (m['c'] as num).toDouble(),
        fiber: (m['fib'] as num?)?.toDouble() ?? 0,
      );

  static Food fromJson(Map m, {bool custom = false}) => Food(
        id: m['id'] as String,
        name: m['name'] as String,
        aka: [for (final a in (m['aka'] as List? ?? const [])) '$a'],
        group: m['group'] as String? ?? 'other',
        per100: _macros(m['per100'] as Map),
        source: m['src'] as String? ?? '',
        portions: [
          for (final p in (m['portions'] as List? ?? const []))
            if (p is Map)
              Portion('${p['label']}', (p['g'] as num).toDouble(),
                  '${p['src'] ?? ''}'),
        ],
        regions: [
          for (final r in (m['regions'] as List? ?? const []))
            ...Region.values.where((v) => v.name == r),
        ],
        micro: {
          for (final e in ((m['micro'] as Map?) ?? const {}).entries)
            if (e.value is num) '${e.key}': (e.value as num).toDouble(),
        },
        refuse: (m['refuse'] as num?)?.toDouble(),
        piece: switch (m['piece']) {
          {'unit': final u, 'g': final num g} =>
            Portion('$u', g.toDouble(), '${m['piece']['src'] ?? ''}'),
          _ => null,
        },
        howto: [for (final s in (m['howto'] as List? ?? const [])) '$s'],
        custom: custom,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'group': group,
        'per100': {
          'kcal': per100.kcal,
          'p': per100.protein,
          'f': per100.fat,
          'c': per100.carb,
          'fib': per100.fiber,
        },
        'micro': micro,
        'src': source,
        'portions': [
          for (final p in portions)
            {'label': p.label, 'g': p.grams, 'src': p.source},
        ],
      };
}

class MenuItem {
  const MenuItem(this.foodId, this.grams);

  final String foodId;
  final double grams;

  Map<String, Object> toJson() => {'food': foodId, 'g': grams};
}

class RegionalMenu {
  const RegionalMenu({
    required this.id,
    required this.name,
    required this.region,
    required this.items,
    required this.source,
    this.custom = false,
    this.meals = const [],
  });

  final String id;
  final String name;
  final Region? region;
  final List<MenuItem> items;
  final String source;
  final bool custom;
  final List<String> meals;

  bool servesAt(String meal) => meals.isEmpty || meals.contains(meal);

  static RegionalMenu? fromJson(Map m, Map<String, Food> foods,
      {bool custom = false}) {
    final items = [
      for (final it in (m['items'] as List? ?? const []))
        if (it is Map && foods.containsKey(it['food']))
          MenuItem(it['food'] as String, (it['g'] as num).toDouble()),
    ];
    if (items.isEmpty) return null;
    return RegionalMenu(
      id: m['id'] as String,
      name: m['name'] as String,
      region: Region.values.where((r) => r.name == m['region']).firstOrNull,
      source: '${m['src'] ?? ''}',
      items: items,
      custom: custom,
      meals: [for (final s in (m['meals'] as List? ?? const [])) '$s'],
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'region': region?.name,
        'src': source,
        'items': [for (final i in items) i.toJson()],
        if (meals.isNotEmpty) 'meals': meals,
      };
}

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.region,
    required this.serving,
    required this.grams,
    required this.ingredients,
    required this.steps,
    this.tags = const [],
    this.custom = false,
  });

  final String id;
  final String name;
  final Region? region;
  final String serving;
  final double grams;
  final List<MenuItem> ingredients;
  final List<String> steps;
  final List<String> tags;
  final bool custom;

  static Recipe? fromJson(Map m, {bool custom = false}) {
    final id = m['id'];
    if (id is! String) return null;
    return Recipe(
      id: id,
      name: '${m['name']}',
      region: Region.values.where((r) => r.name == m['region']).firstOrNull,
      serving: '${m['serving'] ?? '1 phần'}',
      grams: (m['grams'] as num?)?.toDouble() ?? 0,
      ingredients: [
        for (final it in (m['ingredients'] as List? ?? const []))
          if (it is Map) MenuItem('${it['food']}', (it['g'] as num).toDouble()),
      ],
      steps: [for (final s in (m['steps'] as List? ?? const [])) '$s'],
      tags: [for (final t in (m['tags'] as List? ?? const [])) '$t'],
      custom: custom,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'region': region?.name,
        'serving': serving,
        'grams': grams,
        'ingredients': [for (final i in ingredients) i.toJson()],
        'steps': steps,
        'tags': tags,
      };
}

class SourceRef {
  const SourceRef(this.id, this.cite, this.url);

  final String id;
  final String cite;
  final String url;
}

Map<String, Object?> dishFromIngredients({
  required String id,
  required String name,
  required String serving,
  required List<(Food, double)> ingredients,
  Region? region,
}) {
  var total = Macros.zero;
  var grams = 0.0;
  final micro = <String, double>{};
  for (final (f, g) in ingredients) {
    total = total + f.forGrams(g);
    grams += g;
    for (final e in f.micro.entries) {
      micro[e.key] = (micro[e.key] ?? 0) + e.value * g / 100;
    }
  }
  final k = grams <= 0 ? 0.0 : 100 / grams;
  return {
    'id': id,
    'name': name,
    'group': 'mon_an',
    'per100': {
      'kcal': total.kcal * k,
      'p': total.protein * k,
      'f': total.fat * k,
      'c': total.carb * k,
      'fib': total.fiber * k,
    },
    'micro': {for (final e in micro.entries) e.key: e.value * k},
    'src': 'recipe:user',
    'portions': [
      {'label': serving, 'g': grams, 'src': 'recipe'},
    ],
    'regions': [if (region != null) region.name],
  };
}

class FoodDb {
  FoodDb._(this.foods, this.menus, this.recipes, this.sources);

  static FoodDb? _cache;
  static const asset = 'assets/data/vn_nutrition.json';

  final Map<String, Food> foods;
  final List<RegionalMenu> menus;
  final List<Recipe> recipes;
  final Map<String, SourceRef> sources;

  static Future<FoodDb> load({AssetBundle? bundle}) async {
    final cached = _cache;
    if (cached != null) {
      await cached._mergeCustom();
      return cached;
    }
    final raw =
        jsonDecode(await (bundle ?? rootBundle).loadString(asset)) as Map;
    final db = parse(raw);
    _cache = db;
    await db._mergeCustom();
    return db;
  }

  static FoodDb parse(Map raw) {
    final foods = <String, Food>{
      for (final f in (raw['foods'] as List))
        if (f is Map) (f['id'] as String): Food.fromJson(f),
    };
    final menus = <RegionalMenu>[
      for (final m in (raw['menus'] as List? ?? const []))
        if (m is Map)
          if (RegionalMenu.fromJson(m, foods) case final menu?) menu,
    ];
    final recipes = <Recipe>[
      for (final r in (raw['recipes'] as List? ?? const []))
        if (r is Map)
          if (Recipe.fromJson(r) case final recipe?) recipe,
    ];
    final sources = <String, SourceRef>{
      for (final s in (raw['sources'] as List? ?? const []))
        if (s is Map)
          (s['id'] as String):
              SourceRef(s['id'] as String, '${s['cite']}', '${s['url'] ?? ''}'),
    };
    return FoodDb._(foods, menus, recipes, sources);
  }

  Future<void> _mergeCustom() async {
    try {
      final store = NutritionStore.instance;
      for (final m in await store.customFoods()) {
        final food = Food.fromJson(m, custom: true);
        foods[food.id] = food;
      }
      recipes.removeWhere((r) => r.custom);
      for (final m in await store.customRecipes()) {
        if (Recipe.fromJson(m, custom: true) case final r?) recipes.add(r);
      }
      menus.removeWhere((m) => m.custom);
      for (final m in await store.customMenus()) {
        if (RegionalMenu.fromJson(m, foods, custom: true) case final menu?) {
          menus.add(menu);
        }
      }
    } catch (_) {}
  }

  Recipe? recipeFor(String foodId) {
    for (final r in recipes) {
      if (r.id == foodId) return r;
    }
    return null;
  }

  static const recipeFilters = [
    'Giàu đạm',
    'Ít tinh bột',
    'Ít béo',
    'Bò',
    'Lợn',
    'Gà',
    'Cá, tôm, cua',
    'Trứng',
    'Đậu phụ',
  ];

  bool recipeMatches(Recipe r, String filter) {
    final region = Region.values.where((g) => g.label == filter).firstOrNull;
    if (region != null) return r.region == region;
    final dish = foods[r.id];
    switch (filter) {
      case 'Giàu đạm':
        return dish?.highProtein ?? false;
      case 'Ít tinh bột':
        return dish?.lowCarb ?? false;
      case 'Ít béo':
        return dish?.lowFat ?? false;
    }
    return r.ingredients.any((i) {
      final f = foods[i.foodId];
      if (f == null) return false;
      final n = f.name.toLowerCase();
      return switch (filter) {
        'Bò' => n.contains('bò'),
        'Lợn' => n.contains('lợn') || n.contains('heo'),
        'Gà' => n.contains('gà'),
        'Cá, tôm, cua' => f.group == 'thuy_san',
        'Trứng' => f.group == 'trung',
        'Đậu phụ' => n.contains('đậu phụ'),
        _ => false,
      };
    });
  }

  List<Food> search(String query, {String? filter, String? group}) {
    final q = foldVietnamese(query.trim());
    final words = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    int rank(Food f) => f.isDish ? 0 : (f.isRaw ? 2 : 1);
    final out = foods.values.where((f) {
      if (group != null && f.group != group) return false;
      if (filter == 'protein' && !f.highProtein) return false;
      if (filter == 'lowcarb' && !f.lowCarb) return false;
      if (filter == 'lowfat' && !f.lowFat) return false;
      final key = f.searchKey;
      return words.every(key.contains);
    }).toList()
      ..sort((a, b) {
        final ap = foldVietnamese(a.name).startsWith(q) ? 0 : 1;
        final bp = foldVietnamese(b.name).startsWith(q) ? 0 : 1;
        if (ap != bp) return ap - bp;
        final ar = rank(a), br = rank(b);
        return ar != br ? ar - br : a.name.compareTo(b.name);
      });
    return out;
  }

  List<(Food, double)> matchSpoken(String text) {
    final folded = foldVietnamese(text);
    final hits = <(Food, double)>[];
    final names = foods.values.toList()
      ..sort((a, b) {
        final byLen = b.name.length.compareTo(a.name.length);
        if (byLen != 0) return byLen;
        return (a.isRaw ? 1 : 0) - (b.isRaw ? 1 : 0);
      });
    var rest = folded;
    for (final f in names) {
      for (final n in [f.name, if (!f.isRaw) ...f.aka]) {
        final key = foldVietnamese(n);
        if (key.length < 3) continue;
        final i = rest.indexOf(key);
        if (i < 0) continue;
        hits.add((f, f.defaultPortion?.grams ?? 100));
        rest = rest.replaceRange(i, i + key.length, ' ' * key.length);
        break;
      }
    }
    return hits;
  }
}
