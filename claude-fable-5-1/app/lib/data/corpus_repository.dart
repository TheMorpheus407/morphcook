import 'dart:async';
import 'dart:convert';

import 'asset_source.dart';
import 'models/dish.dart';
import 'models/faq.dart';
import 'models/ingredient.dart';
import 'models/ingredient_guide.dart';
import 'models/ontology.dart';
import 'models/partition.dart';
import 'models/recipe.dart';
import 'models/search_index.dart';

/// The bundled corpus. Loads the manifest, ontology, dictionary, dishes,
/// FAQ, guide and search index at launch plus the eager partitions; every
/// other partition is fetched on demand and cached for the session.
class CorpusRepository {
  CorpusRepository(this.source);

  final AssetSource source;

  Ontology? _ontology;
  IngredientDictionary? _dictionary;
  PartitionManifest? _manifest;
  List<Dish> _dishes = const [];
  Map<String, Dish> _dishById = const {};
  FaqCorpus? _faqs;
  IngredientGuide? _guide;
  SearchIndex? _index;

  final Map<String, Recipe> _recipes = {};
  final Set<String> _loadedPartitions = {};
  final Map<String, Future<void>> _inflight = {};
  final StreamController<String> _partitionLoaded = StreamController.broadcast();

  bool get isLoaded => _manifest != null;
  Ontology get ontology => _ontology!;
  IngredientDictionary get ingredients => _dictionary!;
  PartitionManifest get manifest => _manifest!;
  List<Dish> get dishes => _dishes;
  FaqCorpus get faqs => _faqs ?? const FaqCorpus(categories: [], entries: []);
  IngredientGuide get guide => _guide ?? IngredientGuide(const []);
  SearchIndex get searchIndex => _index ?? SearchIndex.empty();
  Set<String> get loadedPartitions => Set.unmodifiable(_loadedPartitions);
  Iterable<Recipe> get loadedRecipes => _recipes.values;
  Stream<String> get onPartitionLoaded => _partitionLoaded.stream;

  Dish? dish(String id) => _dishById[id];

  Future<Map<String, dynamic>> _json(String path) async =>
      (jsonDecode(await source.loadString(path)) as Map).cast<String, dynamic>();

  Future<void> load() async {
    final results = await Future.wait([
      _json('assets/partition-manifest.json'),
      _json('assets/ontology.json'),
      _json('assets/ingredients.json'),
      _json('assets/dishes.json'),
      _json('assets/faqs.json'),
      _json('assets/ingredient-guide.json'),
      _json('assets/search-index.json'),
    ]);
    _manifest = PartitionManifest.fromJson(results[0]);
    _ontology = Ontology.fromJson(results[1]);
    _dictionary = IngredientDictionary.fromJson(results[2]);
    _dishes = (results[3]['dishes'] as List).map((e) => Dish.fromJson(e as Map<String, dynamic>)).toList();
    _dishById = {for (final d in _dishes) d.id: d};
    _faqs = FaqCorpus.fromJson(results[4]);
    _guide = IngredientGuide.fromJson(results[5]);
    _index = SearchIndex.fromJson(results[6]);
    for (final p in _manifest!.loadingStrategy.eager) {
      await ensurePartition(p);
    }
  }

  Future<void> ensurePartition(String id) {
    if (_loadedPartitions.contains(id)) return Future.value();
    // The callback must not return the removed future (whenComplete would
    // wait on it, i.e. on itself), hence the block body.
    return _inflight.putIfAbsent(id, () => _loadPartition(id).whenComplete(() {
          _inflight.remove(id);
        }));
  }

  Future<void> _loadPartition(String id) async {
    final def = manifest.byId[id];
    if (def == null) throw StateError('unknown partition $id');
    final doc = await _json(def.file);
    for (final rj in (doc['recipes'] as List).cast<Map>()) {
      final r = Recipe.fromJson(rj.cast<String, dynamic>());
      _recipes.putIfAbsent(r.id, () => r);
    }
    _loadedPartitions.add(id);
    _partitionLoaded.add(id);
  }

  /// Which partition to open for a recipe: manifest cross-references first,
  /// then the search index, then the dish's primary partition.
  String? partitionFor(String recipeId) {
    final fromManifest = manifest.primaryPartitionOf(recipeId);
    if (fromManifest != null) return fromManifest;
    final entry = searchIndex.byRecipe[recipeId];
    if (entry != null) return entry.partitionId;
    for (final d in _dishes) {
      if (d.variantIds.contains(recipeId)) return d.partitionId;
    }
    return null;
  }

  Future<void> ensureRecipe(String recipeId) async {
    if (_recipes.containsKey(recipeId)) return;
    final p = partitionFor(recipeId);
    if (p != null) await ensurePartition(p);
  }

  Recipe? recipeIfLoaded(String id) => _recipes[id];

  Future<Recipe?> recipe(String id) async {
    await ensureRecipe(id);
    return _recipes[id];
  }

  List<Recipe> variantsIfLoaded(String dishId) {
    final d = _dishById[dishId];
    if (d == null) return const [];
    return [for (final id in d.variantIds) if (_recipes[id] != null) _recipes[id]!];
  }

  Future<List<Recipe>> variantsOf(String dishId) async {
    final d = _dishById[dishId];
    if (d == null) return const [];
    await ensurePartition(d.partitionId);
    return variantsIfLoaded(dishId);
  }

  Future<void> prefetchIdle() async {
    for (final p in manifest.loadingStrategy.prefetchOnIdle) {
      await ensurePartition(p);
    }
  }

  Future<void> loadAll() async {
    for (final p in manifest.partitions) {
      await ensurePartition(p.id);
    }
  }

  void dispose() {
    _partitionLoaded.close();
  }
}
