import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'search_normalization.dart';
export 'search_normalization.dart' show normalizeSearch;

class Repository {
  final AssetBundle bundle;
  final List<Dish> dishes;
  final List<Recipe> recipes;
  final List<Ingredient> ingredients;
  final List<Map<String, dynamic>> faqs;
  final List<Map<String, dynamic>> guides;
  Map<String, dynamic> ontology;
  Map<String, dynamic> manifest = {};
  final Map<String, Map<String, String>> uiStrings = {};
  final Map<String, Map<String, String>> _searchTokens = {};
  final Set<String> loadedPartitions = {};
  final Map<String, Future<void>> _loading = {};
  bool _initialized = false;

  Repository({AssetBundle? bundle})
    : bundle = bundle ?? rootBundle,
      dishes = [],
      recipes = [],
      ingredients = [],
      faqs = [],
      guides = [],
      ontology = {};
  Repository.empty() : this();
  Repository.fromData({
    List<Dish> dishes = const [],
    List<Recipe> recipes = const [],
    List<Ingredient> ingredients = const [],
    List<Map<String, dynamic>> faqs = const [],
    List<Map<String, dynamic>> guides = const [],
    Map<String, dynamic> ontology = const {},
  }) : bundle = rootBundle,
       dishes = [...dishes],
       recipes = [...recipes],
       ingredients = [...ingredients],
       faqs = [...faqs],
       guides = [...guides],
       ontology = {...ontology},
       _initialized = true;

  Future<dynamic> _read(String name) async => jsonDecode(
    await bundle.loadString(name.startsWith('assets/') ? name : 'assets/$name'),
  );

  List<Map<String, dynamic>> _rows(dynamic json, String key) {
    final value = json is List ? json : json[key];
    if (value is! List) {
      throw FormatException('Expected $key array in bundled content.');
    }
    return value.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> load() async {
    if (_initialized) return;
    final results = await Future.wait([
      _read('partition-manifest.json'),
      _read('dishes.json'),
      _read('ingredients.json'),
      _read('ontology.json'),
      _read('faqs.json'),
      _read('ingredient-guide.json'),
    ]);
    manifest = Map<String, dynamic>.from(results[0] as Map);
    dishes.addAll(_rows(results[1], 'dishes').map(Dish.fromJson));
    ingredients.addAll(
      _rows(results[2], 'ingredients').map(Ingredient.fromJson),
    );
    ontology = Map<String, dynamic>.from(results[3] as Map);
    faqs.addAll(_rows(results[4], 'faqs'));
    final guideData = results[5];
    guides.addAll(
      _rows(
        guideData,
        guideData is Map && guideData.containsKey('ingredient_guides')
            ? 'ingredient_guides'
            : 'guides',
      ),
    );
    final partitions = manifest['partitions'] as List? ?? [];
    final core = partitions.whereType<Map>().where(
      (p) =>
          p['id'] == 'core' ||
          p['load_at_launch'] == true ||
          p['loading'] == 'eager',
    );
    if (core.isEmpty && partitions.isNotEmpty) {
      await loadPartition((partitions.first as Map)['id'] as String);
    } else {
      await Future.wait(core.map((p) => loadPartition(p['id'] as String)));
    }
    // The build-time index is optional for fixture repositories, never remote.
    try {
      final index = await _read('search-index.json');
      final rows = index is List ? index : index['entries'] ?? index['recipes'];
      if (rows is List) {
        for (final row in rows.whereType<Map>()) {
          final id = (row['recipe_id'] ?? row['id'])?.toString();
          if (id == null) continue;
          final tokens = row['tokens'] ?? row['text'];
          if (tokens is Map) {
            _searchTokens[id] = tokens.map(
              (lang, text) => MapEntry(
                lang.toString(),
                normalizeSearch(
                  text is List ? text.join(' ') : text.toString(),
                ),
              ),
            );
          }
        }
      }
    } on FlutterError {
      /* Fixtures may use direct corpus tokenization. */
    }
    try {
      final strings = await _read('ui-strings.json');
      if (strings is Map) {
        strings.forEach(
          (key, value) => uiStrings[key.toString()] = localizedMap(value),
        );
      }
    } on FlutterError {
      /* UI fallback pairs remain available. */
    }
    _initialized = true;
  }

  Future<void> loadPartition(String id) async {
    if (loadedPartitions.contains(id)) return;
    if (_loading.containsKey(id)) return _loading[id];
    final rows = manifest['partitions'] as List? ?? [];
    final partition = rows
        .whereType<Map>()
        .where((p) => p['id'] == id)
        .firstOrNull;
    if (partition == null) return;
    final future = () async {
      final payload = await _read(
        (partition['file'] ?? partition['path']) as String,
      );
      final known = recipes.map((r) => r.id).toSet();
      for (final row in _rows(payload, 'recipes')) {
        final recipe = Recipe.fromJson(row);
        if (known.add(recipe.id)) recipes.add(recipe);
      }
      loadedPartitions.add(id);
    }();
    _loading[id] = future;
    try {
      await future;
    } finally {
      _loading.remove(id);
    }
  }

  Future<void> loadAll() async {
    await load();
    await Future.wait(
      (manifest['partitions'] as List? ?? []).whereType<Map>().map(
        (p) => loadPartition(p['id'] as String),
      ),
    );
  }

  Future<void> loadForDish(Dish dish) async {
    if (dish.partitionId != null) await loadPartition(dish.partitionId!);
    await Future.wait(dish.secondaryPartitions.map(loadPartition));
  }

  Future<void> loadForRecipe(String id) async {
    if (byId(id) != null) return;
    final partitions = (manifest['partitions'] as List? ?? [])
        .whereType<Map>()
        .where((p) => (p['recipe_ids'] as List? ?? []).contains(id));
    await Future.wait(partitions.map((p) => loadPartition(p['id'] as String)));
  }

  Future<void> loadForQuery(String query, {String lang = 'en'}) async {
    await load();
    final terms = normalizeSearch(
      query,
    ).split(RegExp(r'\s+')).where((term) => term.isNotEmpty).toList();
    if (terms.isEmpty || _searchTokens.isEmpty) {
      await loadAll();
      return;
    }
    final candidates = _searchTokens.entries.where((entry) {
      final text = entry.value[lang] ?? entry.value['en'] ?? '';
      return terms.every(text.contains);
    });
    await Future.wait(candidates.map((entry) => loadForRecipe(entry.key)));
  }

  Recipe? byId(String id) => recipes.where((r) => r.id == id).firstOrNull;
  Dish? dishById(String id) => dishes.where((d) => d.id == id).firstOrNull;
  Ingredient? ingredientById(String id) =>
      ingredients.where((i) => i.id == id).firstOrNull;

  String searchText(Recipe recipe, String lang) {
    final indexed = _searchTokens[recipe.id]?[lang];
    if (indexed != null) return indexed;
    return normalizeSearch(
      [
        localized(recipe.title, lang),
        localized(recipe.description, lang),
        ...recipe.tags,
        ...recipe.ingredients.map(
          (i) => localized(ingredientById(i.id)?.name ?? {'en': i.id}, lang),
        ),
      ].join(' '),
    );
  }

  Future<List<Recipe>> search(
    String query, {
    String lang = 'en',
    Set<String> tags = const {},
  }) async {
    await loadForQuery(query, lang: lang);
    final tokens = normalizeSearch(
      query,
    ).split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    return recipes
        .where(
          (recipe) =>
              tokens.every(searchText(recipe, lang).contains) &&
              tags.every(
                (tag) =>
                    recipe.tags.contains(tag) ||
                    recipe.diet == tag ||
                    recipe.effort == tag,
              ),
        )
        .toList();
  }
}

typedef RecipeRepository = Repository;
