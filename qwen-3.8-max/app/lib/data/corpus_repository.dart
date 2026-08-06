import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

/// Loads the bundled corpus with partition semantics:
///  - eager partitions (core) load at launch,
///  - idle-prefetch partitions (extended) load when the app is idle,
///  - lazy partitions (cuisine views) load on demand,
///  - opening a dish ensures its primary partition is resident.
///
/// Recipes are de-duplicated on the way in: cuisine partitions re-list the
/// same recipes, and a recipe read twice occupies memory once.
class CorpusRepository {
  PartitionManifest? _manifest;
  Ontology? _ontology;
  IngredientDictionary? _ingredients;
  final Map<String, Dish> _dishes = {};
  final Map<String, Recipe> _recipes = {};
  final Map<String, Faq> _faqs = {};
  final Map<String, GuideEntry> _guide = {};
  final Map<String, Future<void>> _inFlight = {};
  final Set<String> _loadedPartitions = {};

  bool get ready => _manifest != null && _ontology != null;

  PartitionManifest get manifest => _manifest!;
  Ontology get ontology => _ontology!;
  IngredientDictionary get ingredients => _ingredients!;

  Iterable<Dish> get dishes => _dishes.values;
  Dish? dish(String id) => _dishes[id];
  Recipe? recipe(String id) => _recipes[id];
  Iterable<Recipe> get loadedRecipes => _recipes.values;
  Faq? faq(String id) => _faqs[id];
  List<Faq> get faqs => _faqs.values.toList();
  GuideEntry? guideEntry(String ingredientId) => _guide[ingredientId];

  List<Recipe> recipesForDish(String dishId) {
    final dish = _dishes[dishId];
    if (dish == null) return const [];
    return dish.recipeIds
        .map((id) => _recipes[id])
        .whereType<Recipe>()
        .toList();
  }

  Future<Map<String, dynamic>> _readJson(String file) async {
    final raw = await rootBundle.loadString(file);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Launch load: manifest + reference data + every eager partition.
  Future<void> init() async {
    final results = await Future.wait([
      _readJson('assets/partition-manifest.json'),
      _readJson('assets/ontology.json'),
      _readJson('assets/ingredients.json'),
      _readJson('assets/dishes.json'),
      _readJson('assets/faqs.json'),
      _readJson('assets/ingredient-guide.json'),
    ]);
    _manifest = PartitionManifest.fromJson(results[0]);
    _ontology = Ontology.fromJson(results[1]);
    _ingredients = IngredientDictionary.fromJson(results[2]);
    for (final d in results[3]['dishes'] as List) {
      final dish = Dish.fromJson(d as Map<String, dynamic>);
      _dishes[dish.id] = dish;
    }
    for (final f in results[4]['faqs'] as List) {
      final faq = Faq.fromJson(f as Map<String, dynamic>);
      _faqs[faq.id] = faq;
    }
    for (final g in results[5]['entries'] as List) {
      final entry = GuideEntry.fromJson(g as Map<String, dynamic>);
      _guide[entry.ingredientId] = entry;
    }

    await Future.wait([
      for (final p in _manifest!.partitions)
        if (p.loading == 'eager') loadPartition(p.id)
    ]);
  }

  /// Prefetch partitions marked `idle_prefetch` (the long tail).
  Future<void> prefetchIdlePartitions() async {
    if (_manifest == null) return;
    await Future.wait([
      for (final p in _manifest!.partitions)
        if (p.loading == 'idle_prefetch') loadPartition(p.id)
    ]);
  }

  bool isPartitionLoaded(String id) => _loadedPartitions.contains(id);

  /// Load one partition. Concurrent calls for the same partition are
  /// de-duplicated through [_inFlight]; a failed load removes its entry so a
  /// retry stays possible.
  Future<void> loadPartition(String id) {
    if (_loadedPartitions.contains(id)) return Future.value();
    final pending = _inFlight[id];
    if (pending != null) return pending;
    final info = _manifest?.byId(id);
    if (info == null) return Future.value();
    final future = _loadPartitionFile(info).whenComplete(() {
      _inFlight.remove(id);
    });
    _inFlight[id] = future;
    return future;
  }

  Future<void> _loadPartitionFile(PartitionInfo info) async {
    final json = await _readJson(info.file);
    for (final r in json['recipes'] as List? ?? const []) {
      final recipe = Recipe.fromJson(r as Map<String, dynamic>);
      _recipes.putIfAbsent(recipe.id, () => recipe);
    }
    _loadedPartitions.add(info.id);
  }

  /// Make sure every partition that may hold [dishId] is resident,
  /// primary first.
  Future<void> ensureDishLoaded(String dishId) async {
    final routing = _manifest?.dishRouting[dishId];
    if (routing == null) return;
    await loadPartition(routing.primary);
    for (final secondary in routing.alsoIn) {
      await loadPartition(secondary);
    }
  }

  /// Load every partition (search fallback when a hit is not resident yet).
  Future<void> loadAllPartitions() async {
    if (_manifest == null) return;
    await Future.wait(
        [for (final p in _manifest!.partitions) loadPartition(p.id)]);
  }
}
