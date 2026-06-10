import 'dart:async';

import '../models/dish.dart';
import '../models/recipe.dart';
import 'local_storage.dart';
import 'partition_manifest.dart';

/// Loads dishes and recipes from bundled partitions. Eager partitions are
/// loaded at boot; lazy partitions on demand. Cross-reference cuisine
/// partitions are loaded only when the user filters by cuisine.
class RecipeRepository {
  RecipeRepository._({
    required this.manifest,
    required Map<String, Dish> dishesById,
    required Map<String, Recipe> recipesById,
  })  : _dishes = dishesById,
        _recipes = recipesById;

  final PartitionManifest manifest;
  final Map<String, Dish> _dishes;
  final Map<String, Recipe> _recipes;
  final Set<String> _loadedPartitions = {};
  final Map<String, List<String>> _cuisineRefs = {};

  static Future<RecipeRepository> load() async {
    final manifestJson = await loadJsonAsset('assets/partition-manifest.json');
    final manifest = PartitionManifest.fromJson(manifestJson);

    final dishesJson = await loadJsonAsset('assets/dishes.json');
    final dishes = <String, Dish>{};
    for (final raw in (dishesJson['dishes'] as List)) {
      final d = Dish.fromJson(raw as Map<String, dynamic>);
      dishes[d.id] = d;
    }

    final repo = RecipeRepository._(
      manifest: manifest,
      dishesById: dishes,
      recipesById: {},
    );

    // Eager-load all launch partitions.
    for (final id in manifest.launchPartitions) {
      await repo._loadPartition(id);
    }

    // Background-load post-launch partitions without awaiting completion.
    unawaited(() async {
      for (final id in manifest.backgroundPartitions) {
        try {
          await repo._loadPartition(id);
        } catch (_) {
          // partition loads are best-effort; ignore failures
        }
      }
    }());

    return repo;
  }

  Future<void> _loadPartition(String partitionId) async {
    if (_loadedPartitions.contains(partitionId)) return;
    final info = manifest.byId(partitionId);
    if (info == null) return;
    try {
      final json = await loadJsonAsset(info.assetPath);
      final recipes = (json['recipes'] as List?) ?? const [];
      for (final raw in recipes) {
        final r = Recipe.fromJson(raw as Map<String, dynamic>);
        _recipes[r.id] = r;
      }
      final refs = (json['recipe_refs'] as List?)?.cast<String>();
      if (refs != null) {
        _cuisineRefs[partitionId] = refs;
      }
      _loadedPartitions.add(partitionId);
    } catch (_) {
      // ignore missing partitions; this is offline-only and corpus may evolve
    }
  }

  Future<void> ensurePartition(String id) => _loadPartition(id);

  List<Dish> allDishes() => _dishes.values.toList();

  Dish? dish(String id) => _dishes[id];

  Recipe? recipe(String id) => _recipes[id];

  /// All currently loaded recipes (eager + lazy that have been awaited).
  List<Recipe> allRecipes() => _recipes.values.toList();

  /// Recipes belonging to [dishId]. Will trigger lazy load if the dish's
  /// primary partition has not yet been loaded.
  Future<List<Recipe>> recipesForDish(String dishId) async {
    final d = _dishes[dishId];
    if (d == null) return const [];
    await _loadPartition(d.partitionId);
    for (final sp in d.secondaryPartitions) {
      await _loadPartition(sp);
    }
    return d.variantRecipeIds
        .map((id) => _recipes[id])
        .whereType<Recipe>()
        .toList();
  }

  /// Recipes referenced by a cuisine partition.
  Future<List<Recipe>> recipesForCuisine(String partitionId) async {
    await _loadPartition(partitionId);
    final refs = _cuisineRefs[partitionId] ?? const <String>[];
    return refs.map((id) => _recipes[id]).whereType<Recipe>().toList();
  }
}
