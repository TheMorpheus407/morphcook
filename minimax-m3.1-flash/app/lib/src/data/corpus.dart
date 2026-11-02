import 'package:flutter/foundation.dart';

import '../models/dish.dart';
import '../models/ingredient.dart';
import '../models/ontology.dart';
import '../models/recipe.dart';
import 'asset_loader.dart';

/// One partition of the recipe corpus.
class Partition {
  const Partition({
    required this.id,
    required this.file,
    required this.type,
    required this.frequencyTier,
    this.recipeIds = const <String>[],
    this.description,
  });

  factory Partition.fromJson(Map<String, dynamic> json) {
    return Partition(
      id: '${json['id']}',
      file: '${json['file']}',
      type: '${json['type'] ?? 'recipes'}',
      frequencyTier: '${json['frequency_tier'] ?? 'standard'}',
      recipeIds: (json['recipe_ids'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => '$value')
          .toList(growable: false),
      description: json['description'] as String?,
    );
  }

  final String id;

  /// Asset file that holds the partition's payload.
  final String file;

  /// `recipes` holds recipe objects; `index` only holds a list of ids and is
  /// used for cuisine-based discovery.
  final String type;

  final String frequencyTier;
  final List<String> recipeIds;
  final String? description;

  bool get holdsRecipes => type == 'recipes';
}

/// The partition registry shipped as `assets/partition-manifest.json`.
class PartitionManifest {
  const PartitionManifest({
    required this.version,
    required this.corpusVersion,
    required this.partitions,
    required this.recipePartition,
    required this.dishPartition,
  });

  factory PartitionManifest.fromJson(Map<String, dynamic> json) {
    final partitions = <String, Partition>{};
    for (final entry in (json['partitions'] as List<dynamic>? ?? <dynamic>[])) {
      final partition = Partition.fromJson(entry as Map<String, dynamic>);
      partitions[partition.id] = partition;
    }

    final crossReferences =
        (json['cross_references'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final recipePartition =
        (crossReferences['recipe_to_partition'] as Map<String, dynamic>? ??
                <String, dynamic>{})
            .map((key, value) => MapEntry(key, '$value'));
    final dishPartition =
        (crossReferences['dish_to_partition'] as Map<String, dynamic>? ??
                <String, dynamic>{})
            .map((key, value) => MapEntry(key, '$value'));

    return PartitionManifest(
      version: (json['version'] as num?)?.toInt() ?? 1,
      corpusVersion: '${json['corpus_version'] ?? '1.0.0'}',
      partitions: partitions,
      recipePartition: recipePartition,
      dishPartition: dishPartition,
    );
  }

  final int version;
  final String corpusVersion;
  final Map<String, Partition> partitions;

  /// recipe id → partition id.
  final Map<String, String> recipePartition;

  /// dish id → partition id.
  final Map<String, String> dishPartition;

  Partition? partition(String id) => partitions[id];

  List<Partition> get recipePartitions => partitions.values
      .where((partition) => partition.holdsRecipes)
      .toList(growable: false);
}

/// The bundled recipe corpus.
///
/// The corpus ships partitioned: the `core` partition (the 80% most-used
/// recipes) is loaded at launch, the `extended` partition is fetched on
/// demand, and cuisine partitions are lightweight indexes used for
/// discovery.
class Corpus extends ChangeNotifier {
  Corpus._({
    required this.manifest,
    required this.ontology,
    required this.ingredients,
    required this.dishes,
    required Map<String, Recipe> recipes,
    required Set<String> loadedPartitions,
  })  : _recipes = recipes,
        _loadedPartitions = loadedPartitions;

  final PartitionManifest manifest;
  final Ontology ontology;
  final IngredientTree ingredients;

  final Map<String, Dish> dishes;
  final Map<String, Recipe> _recipes;
  final Set<String> _loadedPartitions;

  final Set<String> _loading = <String>{};

  Set<String> get loadedPartitions => Set<String>.unmodifiable(_loadedPartitions);

  Recipe? recipe(String id) => _recipes[id];

  Dish? dish(String id) => dishes[id];

  List<Recipe> get allRecipes => List<Recipe>.unmodifiable(_recipes.values);

  int get recipeCount => _recipes.length;

  /// Loads the corpus: manifest, dishes, ontology, ingredients and the core
  /// recipe partition.
  static Future<Corpus> load({AssetLoader? loader}) async {
    final assets = loader ?? AssetLoader();

    final manifestJson = await assets.loadJson('assets/partition-manifest.json');
    final manifest = PartitionManifest.fromJson(manifestJson);

    final ontologyJson = await assets.loadJson('assets/ontology.json');
    final ontology = Ontology.fromJson(ontologyJson);

    final ingredientsJson = await assets.loadJson('assets/ingredients.json');
    final ingredients = IngredientTree.fromJson(ingredientsJson);

    final dishesJson = await assets.loadJson('assets/dishes.json');
    final dishes = <String, Dish>{};
    for (final entry in (dishesJson['dishes'] as List<dynamic>? ?? <dynamic>[])) {
      final dish = Dish.fromJson(entry as Map<String, dynamic>);
      dishes[dish.id] = dish;
    }

    final corpus = Corpus._(
      manifest: manifest,
      ontology: ontology,
      ingredients: ingredients,
      dishes: dishes,
      recipes: <String, Recipe>{},
      loadedPartitions: <String>{},
    );

    await corpus.loadPartition('core');
    return corpus;
  }

  /// Loads one partition of recipe objects into memory.
  Future<void> loadPartition(String partitionId) async {
    if (_loadedPartitions.contains(partitionId)) return;
    if (_loading.contains(partitionId)) return;
    final partition = manifest.partition(partitionId);
    if (partition == null || !partition.holdsRecipes) {
      _loadedPartitions.add(partitionId);
      return;
    }

    _loading.add(partitionId);
    try {
      final assets = AssetLoader();
      final json = await assets.loadJson('assets/${partition.file}');
      final recipes = (json['recipes'] as List<dynamic>? ?? <dynamic>[]);
      for (final entry in recipes) {
        final recipe = Recipe.fromJson(entry as Map<String, dynamic>);
        _recipes[recipe.id] = recipe;
      }
      _loadedPartitions.add(partitionId);
      notifyListeners();
    } finally {
      _loading.remove(partitionId);
    }
  }

  /// Makes sure the recipe with [recipeId] is in memory.
  Future<void> ensureRecipeLoaded(String recipeId) async {
    if (_recipes.containsKey(recipeId)) return;
    final partitionId = manifest.recipePartition[recipeId];
    if (partitionId == null) return;
    await loadPartition(partitionId);
  }

  /// Makes sure every variant of [dishId] is in memory.
  Future<void> ensureDishLoaded(String dishId) async {
    final dish = dishes[dishId];
    if (dish == null) return;
    for (final variantId in dish.variantIds) {
      await ensureRecipeLoaded(variantId);
    }
  }

  /// Loads every recipe partition. Used before a full-corpus operation such
  /// as search or backup export.
  Future<void> loadAll() async {
    for (final partition in manifest.recipePartitions) {
      await loadPartition(partition.id);
    }
  }

  /// The recipes that belong to a dish, in authoring order.
  List<Recipe> variantsOf(String dishId) {
    final dish = dishes[dishId];
    if (dish == null) return const <Recipe>[];
    final result = <Recipe>[];
    for (final variantId in dish.variantIds) {
      final recipe = _recipes[variantId];
      if (recipe != null) result.add(recipe);
    }
    return result;
  }

  /// The recipes listed in a cuisine partition.
  List<Recipe> recipesInPartition(String partitionId) {
    final partition = manifest.partition(partitionId);
    if (partition == null) return const <Recipe>[];
    return <Recipe>[
      for (final id in partition.recipeIds)
        if (_recipes[id] != null) _recipes[id]!,
    ];
  }
}
