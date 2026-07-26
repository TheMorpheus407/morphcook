import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/models.dart';

/// Reads the bundled corpus. Partition-aware: the core partition loads at
/// launch, everything else is pulled out of the bundle the first time a dish
/// inside it is asked for, then cached for the session.
///
/// There is no network path here at all, by design.
abstract class AssetSource {
  Future<String> loadString(String path);
}

class BundleAssetSource implements AssetSource {
  const BundleAssetSource({this.prefix = 'assets/data/'});

  final String prefix;

  @override
  Future<String> loadString(String path) =>
      rootBundle.loadString('$prefix$path');
}

/// Used by tests and by the corpus-integrity checks, which read the same files
/// straight off disk rather than through the asset bundle.
class MapAssetSource implements AssetSource {
  const MapAssetSource(this.files);

  final Map<String, String> files;

  @override
  Future<String> loadString(String path) async {
    final content = files[path];
    if (content == null) throw StateError('missing asset: $path');
    return content;
  }
}

class CorpusRepository {
  CorpusRepository({AssetSource? source})
    : _source = source ?? const BundleAssetSource();

  final AssetSource _source;

  late PartitionManifest _manifest;
  late Ontology _ontology;
  late IngredientDictionary _ingredients;
  late FaqCollection _faqs;
  late Map<String, Dish> _dishes;
  late Map<String, IngredientGuideEntry> _guide;

  final Map<String, Recipe> _recipes = {};
  final Set<String> _loadedPartitions = {};
  final Map<String, Future<void>> _inFlight = {};

  Map<String, Map<String, List<String>>>? _searchIndex;
  Future<void>? _searchIndexLoad;

  bool _ready = false;

  bool get isReady => _ready;
  PartitionManifest get manifest => _manifest;
  Ontology get ontology => _ontology;
  IngredientDictionary get ingredients => _ingredients;
  FaqCollection get faqs => _faqs;
  Iterable<Dish> get dishes => _dishes.values;
  Set<String> get loadedPartitions => Set.unmodifiable(_loadedPartitions);

  Future<Map<String, dynamic>> _json(String path) async =>
      (jsonDecode(await _source.loadString(path)) as Map)
          .cast<String, dynamic>();

  /// Launch path: manifest, ontology, ingredients, dish index, FAQ and the
  /// eager partitions. Everything else waits.
  Future<void> initialise() async {
    if (_ready) return;
    final results = await Future.wait([
      _json('partition-manifest.json'),
      _json('ontology.json'),
      _json('ingredients.json'),
      _json('dishes.json'),
      _json('faqs.json'),
      _json('ingredient-guide.json'),
    ]);

    _manifest = PartitionManifest.fromJson(results[0]);
    _ontology = Ontology.fromJson(results[1]);
    _ingredients = IngredientDictionary.fromJson(results[2]);
    _dishes = {
      for (final raw in (results[3]['dishes'] as List))
        (raw as Map)['id'] as String: Dish.fromJson(
          raw.cast<String, dynamic>(),
        ),
    };
    _faqs = FaqCollection.fromJson(results[4]);
    _guide = {
      for (final raw in (results[5]['entries'] as List))
        (raw as Map)['ingredient_id'] as String: IngredientGuideEntry.fromJson(
          raw.cast<String, dynamic>(),
        ),
    };

    for (final p in _manifest.partitions.where((p) => p.isEager)) {
      await loadPartition(p.id);
    }
    _ready = true;
  }

  /// Pulls the remaining partitions in the background once the first frame is
  /// out of the way. Failure here is not fatal — the on-demand path still works.
  Future<void> prefetchIdlePartitions() async {
    for (final id in _manifest.prefetchOnIdle) {
      try {
        await loadPartition(id);
      } on Object {
        // A missing optional partition must never break a running app.
      }
    }
  }

  Future<void> loadPartition(String partitionId) {
    if (_loadedPartitions.contains(partitionId)) return Future.value();
    final existing = _inFlight[partitionId];
    if (existing != null) return existing;
    final future = _readPartition(partitionId);
    _inFlight[partitionId] = future;
    return future;
  }

  Future<void> _readPartition(String partitionId) async {
    try {
      final info = _manifest.byId(partitionId);
      if (info == null) throw StateError('unknown partition: $partitionId');
      final payload = await _json(info.file);
      for (final raw in (payload['recipes'] as List)) {
        final recipe = Recipe.fromJson((raw as Map).cast<String, dynamic>());
        _recipes.putIfAbsent(recipe.id, () => recipe);
      }
      _loadedPartitions.add(partitionId);
    } finally {
      // A failed read must not poison the retry path. The wildcard keeps the
      // discarded Future from tripping unawaited_futures.
      final _ = _inFlight.remove(partitionId);
    }
  }

  Future<void> loadAllPartitions() async {
    for (final p in _manifest.partitions) {
      await loadPartition(p.id);
    }
  }

  Dish? dish(String id) => _dishes[id];

  /// Loads whichever partition holds the dish, if it is not resident yet.
  Future<void> ensureDishLoaded(String dishId) async {
    final dish = _dishes[dishId];
    if (dish == null) return;
    if (dish.recipeIds.every(_recipes.containsKey)) return;
    for (final partitionId in _manifest.partitionsFor(dishId)) {
      await loadPartition(partitionId);
      if (dish.recipeIds.every(_recipes.containsKey)) return;
    }
  }

  Future<void> ensureRecipeLoaded(String recipeId) async {
    if (_recipes.containsKey(recipeId)) return;
    for (final dish in _dishes.values) {
      if (dish.recipeIds.contains(recipeId)) {
        await ensureDishLoaded(dish.id);
        return;
      }
    }
  }

  Recipe? recipe(String id) => _recipes[id];

  Iterable<Recipe> get loadedRecipes => _recipes.values;

  /// All siblings of a dish. Call [ensureDishLoaded] first for a lazy dish.
  List<Recipe> variantsOf(String dishId) {
    final dish = _dishes[dishId];
    if (dish == null) return const [];
    return [for (final id in dish.recipeIds) ?_recipes[id]];
  }

  Dish? dishForRecipe(String recipeId) {
    final r = _recipes[recipeId];
    return r == null ? null : _dishes[r.dishId];
  }

  IngredientGuideEntry? guideFor(String ingredientId) => _guide[ingredientId];

  bool hasGuideFor(String ingredientId) => _guide.containsKey(ingredientId);

  // --- search index -------------------------------------------------------

  Future<Map<String, List<String>>> searchTokens(String lang) async {
    _searchIndexLoad ??= _loadSearchIndex();
    await _searchIndexLoad;
    return _searchIndex?[lang] ?? _searchIndex?['en'] ?? const {};
  }

  Future<void> _loadSearchIndex() async {
    final payload = await _json('search-index.json');
    final langs = (payload['languages'] as Map).cast<String, dynamic>();
    _searchIndex = langs.map(
      (lang, tokens) => MapEntry(
        lang,
        (tokens as Map).map(
          (t, ids) => MapEntry(t.toString(), (ids as List).cast<String>()),
        ),
      ),
    );
  }

  /// Dishes grouped for the home feed, honouring the corpus's frequency tiers.
  List<Dish> dishesInPartition(String partitionId) {
    final info = _manifest.byId(partitionId);
    if (info == null) return const [];
    return [for (final id in info.dishIds) ?_dishes[id]];
  }

  List<String> get categories {
    final seen = <String>{};
    for (final d in _dishes.values) {
      seen.addAll(d.categories);
    }
    final out = seen.toList()..sort();
    return out;
  }

  List<Dish> dishesInCategory(String category) =>
      _dishes.values.where((d) => d.categories.contains(category)).toList();
}
