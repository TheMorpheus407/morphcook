import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;

import '../logic/search.dart';
import '../models/dish.dart';
import '../models/faq.dart';
import '../models/ingredient.dart';
import '../models/ontology.dart';
import '../models/recipe.dart';

/// Partition registry entry from partition-manifest.json.
class PartitionInfo {
  final String id;
  final String file;
  final List<String> dishIds;

  const PartitionInfo({
    required this.id,
    required this.file,
    required this.dishIds,
  });

  factory PartitionInfo.fromJson(Map<String, dynamic> json) => PartitionInfo(
        id: json['id'] as String,
        file: json['file'] as String,
        dishIds: List<String>.from(json['dish_ids'] as List),
      );
}

/// Loads the bundled corpus. The core partition loads at launch; the rest
/// load on demand (dish detail, full search) and are indexed as they come in.
class CorpusRepository {
  final AssetBundle bundle;

  CorpusRepository({required this.bundle});

  late Ontology ontology;
  late IngredientDictionary dictionary;
  late FaqCorpus faqs;
  final Map<String, GuideEntry> guide = {};
  final SearchIndex searchIndex = SearchIndex();

  final Map<String, Dish> _dishes = {};
  final Map<String, Recipe> _recipes = {};
  final Map<String, PartitionInfo> _partitions = {};
  final Set<String> _loadedPartitions = {};
  List<String> _launchPartitions = const [];
  List<DishCategory> _categories = const [];

  List<Dish> get dishes => _dishes.values.toList();
  Iterable<Recipe> get loadedRecipes => _recipes.values;

  /// Browse categories in dishes.json display order.
  List<DishCategory> get categories => _categories;

  Dish? dishById(String id) => _dishes[id];

  DishCategory? categoryById(String id) {
    for (final c in _categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// The category a recipe's dish files under; null for recipes without a
  /// corpus dish (personal recipes).
  String? categoryOfRecipe(Recipe recipe) => _dishes[recipe.dishId]?.category;

  Future<Map<String, dynamic>> _loadJson(String path) async =>
      json.decode(await bundle.loadString(path)) as Map<String, dynamic>;

  /// Loads manifest, ontology, dictionary, dishes, FAQ, guide, and the
  /// at-launch partitions.
  Future<void> initialize() async {
    final manifest = await _loadJson('assets/partition-manifest.json');
    for (final p in manifest['partitions'] as List) {
      final info = PartitionInfo.fromJson(p as Map<String, dynamic>);
      _partitions[info.id] = info;
    }
    _launchPartitions = List<String>.from(
        (manifest['loading_strategy']
            as Map<String, dynamic>)['at_launch'] as List);

    ontology = Ontology.fromJson(await _loadJson('assets/ontology.json'));
    dictionary = IngredientDictionary.fromJson(
        await _loadJson('assets/ingredients.json'));
    faqs = FaqCorpus.fromJson(await _loadJson('assets/faqs.json'));

    final guideJson = await _loadJson('assets/ingredient-guide.json');
    for (final e in guideJson['entries'] as List) {
      final entry = GuideEntry.fromJson(e as Map<String, dynamic>);
      guide[entry.ingredientId] = entry;
    }

    final dishesJson = await _loadJson('assets/dishes.json');
    _categories = ((dishesJson['categories'] as List?) ?? const [])
        .map((e) => DishCategory.fromJson(e as Map<String, dynamic>))
        .toList();
    for (final d in dishesJson['dishes'] as List) {
      final dish = Dish.fromJson(d as Map<String, dynamic>);
      _dishes[dish.id] = dish;
    }

    for (final id in _launchPartitions) {
      await loadPartition(id);
    }
  }

  bool isPartitionLoaded(String id) => _loadedPartitions.contains(id);

  Future<void> loadPartition(String id) async {
    if (_loadedPartitions.contains(id)) return;
    final info = _partitions[id];
    if (info == null) return;
    final data = await _loadJson(info.file);
    final recipes = (data['recipes'] as List)
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
    for (final recipe in recipes) {
      _recipes[recipe.id] = recipe;
    }
    _loadedPartitions.add(id);
    searchIndex.indexPartition(id, recipes, dictionary);
  }

  Future<void> ensureAllLoaded() async {
    for (final id in _partitions.keys) {
      await loadPartition(id);
    }
  }

  /// Recipe lookup that pulls in the owning partition if necessary.
  Future<Recipe?> recipeById(String id) async {
    final hit = _recipes[id];
    if (hit != null) return hit;
    for (final dish in _dishes.values) {
      if (dish.recipeIds.contains(id)) {
        await loadPartition(dish.partitionId);
        return _recipes[id];
      }
    }
    return null;
  }

  /// Synchronous lookup for already-loaded recipes.
  Recipe? loadedRecipeById(String id) => _recipes[id];

  /// All variants of a dish (loads its partition on demand).
  Future<List<Recipe>> variantsOf(Dish dish) async {
    await loadPartition(dish.partitionId);
    return dish.recipeIds
        .map((id) => _recipes[id])
        .whereType<Recipe>()
        .toList();
  }

  /// Dishes for a cuisine partition, including cross-referenced ones.
  List<Dish> dishesInPartition(String partitionId) => _dishes.values
      .where((d) =>
          d.partitionId == partitionId ||
          d.secondaryPartitions.contains(partitionId))
      .toList();
}
