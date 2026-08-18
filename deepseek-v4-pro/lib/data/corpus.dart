import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/dish.dart';
import '../models/faq.dart';
import '../models/ingredient.dart';
import '../models/ontology.dart';
import '../models/recipe.dart';

/// A partition of the recipe corpus.
class Partition {
  const Partition({
    required this.id,
    required this.file,
    required this.tier,
    required this.load,
  });

  final String id;
  final String file;
  final String tier;
  final String load;

  factory Partition.fromJson(Map<String, dynamic> json) => Partition(
        id: json['id'] as String,
        file: json['file'] as String,
        tier: json['tier'] as String? ?? 'core',
        load: json['load'] as String? ?? 'eager',
      );
}

/// Holds the full bundled corpus: recipes, dishes, ontology, ingredients,
/// guides, faqs, partitions. Implements partition-based loading with
/// eager / lazy / on-demand fetching.
class Corpus {
  Corpus._();

  final Map<String, Recipe> _recipes = {};
  final Map<String, Dish> _dishes = {};
  final Map<String, List<Dish>> _dishesByPartition = {};
  final Set<String> _loadedPartitions = {};
  Ontology ontology = const Ontology(
    containsFlags: {}, compoundAvoidFlags: {}, positiveMarkers: {},
    effort: [], timeBuckets: [], calorieBuckets: [], techniques: [], mealTypes: [],
  );
  IngredientTree ingredientTree = IngredientTree.fromJson(const {'tree': []});
  Map<String, IngredientGuideEntry> guides = const {};
  List<FaqEntry> faqs = const [];
  List<Partition> partitions = const [];
  String corpusVersion = '0';

  // Search index: token -> recipe ids
  final Map<String, Set<String>> _index = {};


  Iterable<Recipe> get allRecipes => _recipes.values;
  Iterable<Dish> get allDishes => _dishes.values;
  int get recipeCount => _recipes.length;
  int get dishCount => _dishes.length;

  Recipe? recipe(String id) => _recipes[id];
  Dish? dish(String id) => _dishes[id];
  List<Recipe> variantsOf(String dishId) {
    final d = _dishes[dishId];
    if (d == null) return const [];
    return [
      for (final id in d.variantRecipeIds)
        if (_recipes[id] != null) _recipes[id]!,
    ];
  }

  /// Loads the eager partition (core) plus all shared reference data.
  /// [bundle] is injectable for tests.
  static Future<Corpus> load({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    final corpus = Corpus._();

    final manifest = jsonDecode(await b.loadString('assets/partition-manifest.json'))
        as Map<String, dynamic>;
    corpus.corpusVersion = manifest['corpus_version'] as String? ?? '0';
    corpus.partitions = (manifest['partitions'] as List<dynamic>? ?? const [])
        .map((e) => Partition.fromJson(e as Map<String, dynamic>))
        .toList();

    corpus.ontology = Ontology.fromString(await b.loadString('assets/ontology.json'));
    corpus.ingredientTree =
        IngredientTree.fromString(await b.loadString('assets/ingredients.json'));
    corpus.guides = IngredientGuideEntry.mapFromString(
        await b.loadString('assets/ingredient-guide.json'));
    corpus.faqs = FaqEntry.listFromString(await b.loadString('assets/faqs.json'));

    final dishData = jsonDecode(await b.loadString('assets/dishes.json'))
        as Map<String, dynamic>;
    for (final d in (dishData['dishes'] as List<dynamic>? ?? const [])) {
      final dish = Dish.fromJson(d as Map<String, dynamic>);
      corpus._dishes[dish.id] = dish;
      for (final p in {dish.partitionId, ...dish.secondaryPartitions}) {
        corpus._dishesByPartition.putIfAbsent(p, () => []).add(dish);
      }
    }

    // Eager: core partition at launch.
    final strategy = manifest['loading_strategy'] as Map<String, dynamic>? ?? const {};
    for (final id in (strategy['eager'] as List<dynamic>? ?? const ['core'])) {
      await corpus._loadPartition(id as String, b);
    }
    return corpus;
  }

  Future<void> _loadPartition(String id, AssetBundle b) async {
    if (_loadedPartitions.contains(id)) return;
    final p = partitions.where((x) => x.id == id).firstOrNull;
    if (p == null) return;
    final raw = await b.loadString(p.file);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json.containsKey('recipes')) {
      for (final r in (json['recipes'] as List<dynamic>? ?? const [])) {
        final recipe = Recipe.fromJson(r as Map<String, dynamic>);
        _recipes[recipe.id] = recipe;
        _indexRecipe(recipe);
      }
    }
    // Cross-reference partitions: recipe id lists resolved against loaded ids.
    if (json.containsKey('recipe_ids')) {
      for (final rid in (json['recipe_ids'] as List<dynamic>? ?? const [])) {
        if (!_recipes.containsKey(rid)) {
          // Resolve from the lazy extended partition if present.
          await _loadPartition('extended', b);
        }
      }
    }
    _loadedPartitions.add(id);
  }

  /// On-demand partition load (cuisines, extended).
  Future<void> loadPartition(String id, {AssetBundle? bundle}) =>
      _loadPartition(id, bundle ?? rootBundle);

  /// Ensures recipes for every dish of a cuisine partition are present.
  Future<void> ensureDishesOfPartition(String partitionId) async {
    await _loadPartition(partitionId, rootBundle);
    // Make sure each dish's variants exist — pull from extended if needed.
    for (final dish in _dishesByPartition[partitionId] ?? const <Dish>[]) {
      for (final rid in dish.variantRecipeIds) {
        if (!_recipes.containsKey(rid)) {
          await _loadPartition('extended', rootBundle);
          break;
        }
      }
    }
  }

  List<Dish> dishesOfPartition(String id) =>
      List.unmodifiable(_dishesByPartition[id] ?? const <Dish>[]);

  void _indexRecipe(Recipe r) {
    void add(String token) {
      if (token.isEmpty) return;
      _index.putIfAbsent(token, () => <String>{}).add(r.id);
    }

    for (final lang in const ['en', 'de']) {
      for (final word in _tokenize(r.name[lang] ?? '')) {
        add(word);
      }
      for (final word in _tokenize(r.blurb[lang] ?? '')) {
        add(word);
      }
      for (final tag in r.tags) {
        add(tag);
        for (final word in _tokenize(tag.replaceAll('-', ' '))) {
          add(word);
        }
      }
      for (final id in r.ingredientIds) {
        final node = ingredientTree.byId(id);
        if (node != null) {
          for (final word
              in _tokenize(node.name[lang] ?? node.name['en'] ?? '')) {
            add(word);
          }
        }
        // index id tokens (e.g. "garlic", "cow", "milk")
        for (final word
            in _tokenize(id.replaceAll('.', ' ').replaceAll('-', ' '))) {
          add(word);
        }
      }
    }
    for (final word
        in _tokenize(r.id.replaceAll('.', ' ').replaceAll('-', ' '))) {
      add(word);
    }
  }

  /// Free-text search against the built-time index. All query tokens must
  /// match (AND). [lang] picks the language the index was built in; the
  /// index is bilingual so we search both.
  List<String> searchIds(String query) {
    final tokens = _tokenize(query).toSet();
    if (tokens.isEmpty) return const [];
    Set<String>? acc;
    for (final t in tokens) {
      final hits = _index[t];
      if (hits == null) return const [];
      acc = acc == null ? hits : acc.intersection(hits);
    }
    return acc?.toList() ?? const [];
  }

  static List<String> _tokenize(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-zäöüß0-9]+'))
      .where((t) => t.length > 1)
      .toList();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
