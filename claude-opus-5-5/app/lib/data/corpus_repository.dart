import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/ingredient_tree.dart';
import '../models/ontology.dart';
import '../models/recipe.dart';
import '../models/reference.dart';
import 'search_index.dart';

class PartitionInfo {
  const PartitionInfo({
    required this.id,
    required this.file,
    required this.kind,
    required this.load,
    required this.recipeCount,
    required this.dishIds,
  });

  factory PartitionInfo.fromJson(Map<String, dynamic> j) => PartitionInfo(
    id: j['id'] as String,
    file: j['file'] as String,
    kind: j['kind'] as String? ?? 'frequency',
    load: j['load'] as String? ?? 'lazy',
    recipeCount: j['recipe_count'] as int? ?? 0,
    dishIds: [for (final d in (j['dish_ids'] as List? ?? const [])) d as String],
  );

  final String id;
  final String file;
  final String kind;

  /// `eager` partitions load at launch; `lazy` ones on demand or when idle.
  final String load;
  final int recipeCount;
  final List<String> dishIds;
}

class PartitionManifest {
  const PartitionManifest({required this.corpusVersion, required this.partitions, required this.crossReferences});

  factory PartitionManifest.fromJson(Map<String, dynamic> j) => PartitionManifest(
    corpusVersion: j['corpus_version'] as String? ?? '',
    partitions: [for (final p in j['partitions'] as List) PartitionInfo.fromJson(p as Map<String, dynamic>)],
    crossReferences: {
      for (final e in ((j['cross_references'] as Map?) ?? const {}).entries)
        e.key as String: [for (final d in e.value as List) d as String],
    },
  );

  final String corpusVersion;
  final List<PartitionInfo> partitions;

  /// partition → dishes listed there for discovery although stored elsewhere.
  final Map<String, List<String>> crossReferences;

  PartitionInfo? byId(String id) {
    for (final p in partitions) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Read-only access to the bundled corpus. Shared files and eager
/// partitions load at launch; the rest arrive on demand (opening a dish,
/// a search hit) or in the background after the first frame.
class CorpusRepository extends ChangeNotifier {
  CorpusRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  late Ontology ontology;
  late IngredientTree ingredients;
  late PartitionManifest manifest;
  late SearchIndex searchIndex;
  late FaqCatalog faqs;
  late IngredientGuide guide;
  final Map<String, Dish> dishes = {};
  final Map<String, Recipe> _recipes = {};
  final Set<String> _loaded = {};
  final Map<String, Future<void>> _inflight = {};
  bool _ready = false;

  bool get isReady => _ready;
  Set<String> get loadedPartitions => Set.unmodifiable(_loaded);
  bool get allLoaded => manifest.partitions.every((p) => _loaded.contains(p.id));
  Iterable<Recipe> get loadedRecipes => _recipes.values;

  Future<Map<String, dynamic>> _json(String path) async =>
      jsonDecode(await _bundle.loadString(path, cache: false)) as Map<String, dynamic>;

  Future<void> init() async {
    final results = await Future.wait([
      _json('assets/ontology.json'),
      _json('assets/ingredients.json'),
      _json('assets/dishes.json'),
      _json('assets/partition-manifest.json'),
      _json('assets/search-index.json'),
      _json('assets/faqs.json'),
      _json('assets/ingredient-guide.json'),
    ]);
    ontology = Ontology.fromJson(results[0]);
    ingredients = IngredientTree.fromJson(results[1]);
    for (final d in results[2]['dishes'] as List) {
      final dish = Dish.fromJson(d as Map<String, dynamic>);
      dishes[dish.id] = dish;
    }
    manifest = PartitionManifest.fromJson(results[3]);
    searchIndex = SearchIndex.fromJson(results[4]);
    faqs = FaqCatalog.fromJson(results[5]);
    guide = IngredientGuide.fromJson(results[6]);
    await Future.wait([for (final p in manifest.partitions.where((p) => p.load == 'eager')) ensurePartition(p.id)]);
    _ready = true;
    notifyListeners();
  }

  Future<void> ensurePartition(String id) {
    if (_loaded.contains(id)) return Future.value();
    return _inflight[id] ??= () async {
      final info = manifest.byId(id);
      if (info == null) return;
      final data = await _json(info.file);
      for (final r in data['recipes'] as List) {
        final recipe = Recipe.fromJson(r as Map<String, dynamic>, partitionId: id);
        _recipes[recipe.id] = recipe;
      }
      _loaded.add(id);
      _inflight.remove(id);
      notifyListeners();
    }();
  }

  /// Loads every partition not yet in memory, one at a time, so the UI
  /// thread gets breathing room between them.
  Future<void> prefetchRemaining() async {
    for (final p in manifest.partitions) {
      if (!_loaded.contains(p.id)) {
        await ensurePartition(p.id);
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  Future<void> ensureDish(String dishId) async {
    final dish = dishes[dishId];
    if (dish != null) await ensurePartition(dish.partitionId);
  }

  Future<void> ensureRecipes(Iterable<String> recipeIds) async {
    final parts = <String>{};
    for (final id in recipeIds) {
      if (_recipes.containsKey(id)) continue;
      final p = searchIndex.partitionOf(id);
      if (p != null) parts.add(p);
    }
    await Future.wait(parts.map(ensurePartition));
  }

  Recipe? recipe(String id) => _recipes[id];

  bool isDishLoaded(String dishId) {
    final dish = dishes[dishId];
    return dish != null && _loaded.contains(dish.partitionId);
  }

  /// Variants in authored order (only once the dish's partition is loaded).
  List<Recipe> recipesForDish(String dishId) {
    final dish = dishes[dishId];
    if (dish == null) return const [];
    return [
      for (final id in dish.variants)
        if (_recipes[id] != null) _recipes[id]!,
    ];
  }

  Dish? dishOf(Recipe r) => dishes[r.dishId];

  @visibleForTesting
  void debugAddRecipe(Recipe r) => _recipes[r.id] = r;
}
