import 'dart:convert';
import 'package:flutter/services.dart';
import 'matching.dart';
import 'models.dart';

class RecipeRepository {
  final AssetBundle bundle;
  RecipeRepository({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;
  final Map<String, Recipe> recipes = {};
  final Map<String, Dish> dishes = {};
  final Set<String> loadedPartitions = {};
  final Map<String, Future<void>> _loading = {};
  late Ontology ontology;
  late IngredientDictionary dictionary;
  Map<String, dynamic> manifest = {};
  Map<String, dynamic> guide = {};
  List<Map<String, dynamic>> faqs = [];
  List<Map<String, dynamic>> searchIndex = [];
  Map<String, Localized> uiStrings = {};

  Future<dynamic> _read(String name) async =>
      jsonDecode(await bundle.loadString('assets/$name', cache: false));

  Future<void> initialize() async {
    final data = await Future.wait([
      _read('partition-manifest.json'),
      _read('dishes.json'),
      _read('ontology.json'),
      _read('ingredients.json'),
      _read('ingredient-guide.json'),
      _read('faqs.json'),
      _read('search-index.json'),
      _read('ui-strings.json'),
    ]);
    manifest = Map<String, dynamic>.from(data[0] as Map);
    for (final json in data[1] as List) {
      final dish = Dish.fromJson(Map<String, dynamic>.from(json as Map));
      dishes[dish.id] = dish;
    }
    ontology = Ontology(Map<String, dynamic>.from(data[2] as Map));
    final entries = <String, Ingredient>{};
    for (final json in data[3] as List) {
      final ingredient = Ingredient.fromJson(
        Map<String, dynamic>.from(json as Map),
      );
      entries[ingredient.id] = ingredient;
    }
    dictionary = IngredientDictionary(entries);
    guide = Map<String, dynamic>.from(data[4] as Map);
    faqs = (data[5] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    searchIndex = (data[6] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    uiStrings = (data[7] as Map).map(
      (key, value) => MapEntry(key.toString(), localized(value)),
    );
    await loadPartition('core');
  }

  Future<void> loadPartition(String id) {
    if (loadedPartitions.contains(id)) return Future.value();
    return _loading.putIfAbsent(id, () async {
      try {
        final partition = (manifest['partitions'] as Map)[id] as Map?;
        if (partition == null) {
          throw StateError('Unknown recipe partition: $id');
        }
        final data = await _read(partition['file'] as String) as List;
        for (final json in data) {
          final recipe = Recipe.fromJson(
            Map<String, dynamic>.from(json as Map),
          );
          recipes[recipe.id] = recipe;
        }
        loadedPartitions.add(id);
      } finally {
        _loading.remove(id);
      }
    });
  }

  Future<void> loadDish(String dishId) async {
    final dish = dishes[dishId];
    if (dish != null) await loadPartition(dish.partitionId);
  }

  Future<void> loadRecipeIds(Iterable<String> ids) async {
    final missing = ids.where((id) => !recipes.containsKey(id)).toSet();
    if (missing.isEmpty) return;
    final partitions = dishes.values
        .where((d) => d.recipeIds.any(missing.contains))
        .map((d) => d.partitionId)
        .toSet();
    await Future.wait(partitions.map(loadPartition));
  }

  Future<void> loadAll() async => Future.wait(
    (manifest['partitions'] as Map).keys.cast<String>().map(loadPartition),
  );

  List<Recipe> variants(String dishId) =>
      recipes.values.where((r) => r.dishId == dishId).toList();

  Future<List<Recipe>> search(
    String query,
    Set<String> tags,
    Profile profile,
  ) async {
    final tokens = normalizeSearch(
      query,
    ).split(' ').where((t) => t.isNotEmpty).toList();
    final candidates = searchIndex.where((entry) {
      final text = normalizeSearch(
        '${(entry['text'] as Map)[profile.lang] ?? (entry['text'] as Map)['en']} ${entry['id']}',
      );
      return tokens.every(text.contains) &&
          strings(entry['tags']).containsAll(tags);
    }).toList();
    await Future.wait(
      candidates
          .map((e) => e['partition_id'] as String)
          .toSet()
          .map(loadPartition),
    );
    final results = candidates
        .map((e) => recipes[e['id']])
        .whereType<Recipe>()
        .where((r) => visible(r, profile, ontology, dictionary))
        .toList();
    results.sort(
      (a, b) => translate(
        a.title,
        profile.lang,
      ).compareTo(translate(b.title, profile.lang)),
    );
    return results;
  }
}
