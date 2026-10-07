import 'dart:convert';

import 'package:flutter/services.dart';

import 'model/dish.dart';
import 'model/guide.dart';
import 'model/ingredient.dart';
import 'model/ontology.dart';
import 'model/recipe.dart';

/// Partition registry (assets/partition-manifest.json).
class PartitionManifest {
  final int corpusVersion;
  final List<PartitionInfo> partitions;
  final Map<String, List<String>> crossReferences; // partitionId -> partitionIds
  final String loadingStrategy;

  const PartitionManifest({
    required this.corpusVersion,
    required this.partitions,
    required this.crossReferences,
    required this.loadingStrategy,
  });

  factory PartitionManifest.fromJson(Map<String, dynamic> json) => PartitionManifest(
        corpusVersion: json['corpus_version'] as int,
        partitions: (json['partitions'] as List)
            .map((p) => PartitionInfo.fromJson(p as Map<String, dynamic>))
            .toList(),
        crossReferences: (json['cross_references'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, (value as List).cast<String>()),
        ),
        loadingStrategy: json['loading_strategy'] as String,
      );

  /// Partition visit order: launch partitions first, then the rest in
  /// manifest order.
  List<PartitionInfo> get orderedPartitions {
    final launch = partitions.where((p) => p.loadsAtLaunch).toList();
    final rest = partitions.where((p) => !p.loadsAtLaunch).toList();
    return [...launch, ...rest];
  }
}

class PartitionInfo {
  final String id;
  final String file;
  final String type; // core | extended | cuisine
  final bool loadsAtLaunch;
  final List<String> dishIds;
  final List<String> recipeIds;

  const PartitionInfo({
    required this.id,
    required this.file,
    required this.type,
    required this.loadsAtLaunch,
    required this.dishIds,
    required this.recipeIds,
  });

  factory PartitionInfo.fromJson(Map<String, dynamic> json) => PartitionInfo(
        id: json['id'] as String,
        file: json['file'] as String,
        type: json['type'] as String,
        loadsAtLaunch: json['loads_at_launch'] as bool,
        dishIds: (json['dish_ids'] as List).cast<String>(),
        recipeIds: (json['recipe_ids'] as List).cast<String>(),
      );
}

/// Loads the bundled corpus: manifest, dishes, ontology, ingredient tree at
/// launch; recipe partitions on demand (concurrent callers share one future).
class Corpus {
  PartitionManifest? _manifest;
  List<Dish> _dishes = [];
  Ontology? _ontology;
  IngredientDictionary? _ingredients;

  final Map<String, List<Recipe>> _partitions = {};
  final Map<String, Future<List<Recipe>>> _loading = {};

  /// recipeId → dishId, built from dishes.json so any recipe is locatable
  /// without opening its partition.
  final Map<String, String> _dishOfRecipe = {};
  final Map<String, Dish> _dishById = {};

  bool _initialized = false;

  PartitionManifest get manifest => _manifest!;
  List<Dish> get dishes => _dishes;
  Ontology get ontology => _ontology!;
  IngredientDictionary get ingredients => _ingredients!;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    final manifestJson =
        jsonDecode(await rootBundle.loadString('assets/partition-manifest.json'))
            as Map<String, dynamic>;
    _manifest = PartitionManifest.fromJson(manifestJson);

    final dishesJson =
        jsonDecode(await rootBundle.loadString('assets/dishes.json')) as Map<String, dynamic>;
    _dishes = (dishesJson['dishes'] as List)
        .map((d) => Dish.fromJson(d as Map<String, dynamic>))
        .toList();
    for (final dish in _dishes) {
      _dishById[dish.id] = dish;
      for (final recipeId in dish.variantIds) {
        _dishOfRecipe[recipeId] = dish.id;
      }
    }

    final ontologyJson =
        jsonDecode(await rootBundle.loadString('assets/ontology.json')) as Map<String, dynamic>;
    _ontology = Ontology.fromJson(ontologyJson);

    final ingredientsJson =
        jsonDecode(await rootBundle.loadString('assets/ingredients.json')) as Map<String, dynamic>;
    _ingredients = IngredientDictionary.fromJson(ingredientsJson);

    // Launch partitions (core) load at launch; the rest load on demand.
    for (final partition in _manifest!.partitions.where((p) => p.loadsAtLaunch)) {
      await ensurePartition(partition.id);
    }
    _initialized = true;
  }

  Dish? dishById(String id) => _dishById[id];

  String? partitionIdOfDish(String dishId) => _dishById[dishId]?.partitionId;

  String? dishIdOfRecipe(String recipeId) => _dishOfRecipe[recipeId];

  List<Dish> dishesInPartition(String partitionId) => _dishes
      .where((d) => d.partitionId == partitionId || d.secondaryPartitions.contains(partitionId))
      .toList();

  List<Recipe> loadedRecipesOfPartition(String partitionId) =>
      _partitions[partitionId] ?? const [];

  /// Ensure a partition is loaded. Concurrent callers share one future, so a
  /// partition is read and parsed once.
  Future<List<Recipe>> ensurePartition(String partitionId) {
    final existing = _partitions[partitionId];
    if (existing != null) return Future.value(existing);
    final loading = _loading[partitionId];
    if (loading != null) return loading;

    final info = _manifest!.partitions.firstWhere(
      (p) => p.id == partitionId,
      orElse: () => throw StateError('unknown partition: $partitionId'),
    );
    final future = () async {
      final raw = await rootBundle.loadString('assets/${info.file}');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final recipes = (json['recipes'] as List)
          .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
          .toList();
      _partitions[partitionId] = recipes;
      return recipes;
    }();
    _loading[partitionId] = future;
    future.whenComplete(() => _loading.remove(partitionId));
    return future;
  }

  /// All variants of a dish (loads the dish's partition on demand).
  Future<List<Recipe>> recipesOfDish(String dishId) async {
    final dish = _dishById[dishId];
    if (dish == null) return const [];
    final partition = await ensurePartition(dish.partitionId);
    return partition.where((r) => r.dishId == dishId).toList();
  }

  /// Load a single recipe by id, wherever it lives.
  Future<Recipe?> loadRecipe(String recipeId) async {
    for (final recipes in _partitions.values) {
      for (final r in recipes) {
        if (r.id == recipeId) return r;
      }
    }
    final dishId = _dishOfRecipe[recipeId];
    if (dishId == null) return null;
    final partitionId = _dishById[dishId]?.partitionId;
    if (partitionId == null) return null;
    final partition = await ensurePartition(partitionId);
    for (final r in partition) {
      if (r.id == recipeId) return r;
    }
    return null;
  }

  Recipe? loadedRecipe(String recipeId) {
    for (final recipes in _partitions.values) {
      for (final r in recipes) {
        if (r.id == recipeId) return r;
      }
    }
    return null;
  }

  /// Every recipe id known to the corpus (from the manifest), in partition
  /// order.
  List<String> get allRecipeIds => [
        for (final p in _manifest!.orderedPartitions) ...p.recipeIds,
      ];

  // ── kitchen reference (ingredient guide) ──────────────────────────────

  Map<String, IngredientGuideEntry>? _guide;

  /// The full ingredient guide, loaded on first use.
  Future<Map<String, IngredientGuideEntry>> loadIngredientGuide() async {
    if (_guide != null) return _guide!;
    final raw = await rootBundle.loadString('assets/ingredient-guide.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _guide = (json['entries'] as List).fold<Map<String, IngredientGuideEntry>>(
      {},
      (map, e) {
        final entry = IngredientGuideEntry.fromJson(e as Map<String, dynamic>);
        map[entry.ingredientId] = entry;
        return map;
      },
    );
    return _guide!;
  }

  Future<IngredientGuideEntry?> loadIngredientGuideEntry(String ingredientId) async {
    final guide = await loadIngredientGuide();
    return guide[ingredientId] ??
        guide[ingredientId.split('-').first]; // fall back to the family entry
  }
}
