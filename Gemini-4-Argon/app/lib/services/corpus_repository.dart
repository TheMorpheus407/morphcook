import 'dart:convert';
import 'package:flutter/services.dart';

import '../models/dish.dart';
import '../models/faq.dart';
import '../models/ingredient_dictionary.dart';
import '../models/ingredient_guide.dart';
import '../models/ontology.dart';
import '../models/profile.dart';
import '../models/recipe.dart';
import 'matching_engine.dart';
import 'pagination_controller.dart';

class PartitionDefinition {
  final String id;
  final String file;
  final String tier;
  final int recipeCount;
  final List<String> dishIds;

  const PartitionDefinition({
    required this.id,
    required this.file,
    required this.tier,
    required this.recipeCount,
    required this.dishIds,
  });

  factory PartitionDefinition.fromJson(Map<String, dynamic> json) {
    return PartitionDefinition(
      id: json['id']?.toString() ?? '',
      file: json['file']?.toString() ?? '',
      tier: json['tier']?.toString() ?? 'core',
      recipeCount: (json['recipe_count'] as num?)?.toInt() ?? 0,
      dishIds: ((json['dish_ids'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class PartitionManifest {
  final int schemaVersion;
  final String corpusVersion;
  final List<String> startupPartitions;
  final List<String> lazyPartitions;
  final Map<String, PartitionDefinition> partitions;

  const PartitionManifest({
    required this.schemaVersion,
    required this.corpusVersion,
    required this.startupPartitions,
    required this.lazyPartitions,
    required this.partitions,
  });

  factory PartitionManifest.fromJson(Map<String, dynamic> json) {
    final strategy = json['loading_strategy'] as Map<String, dynamic>? ?? {};
    final rawParts = json['partitions'] as Map<String, dynamic>? ?? {};
    return PartitionManifest(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      corpusVersion: json['corpus_version']?.toString() ?? '1.0.0',
      startupPartitions:
          ((strategy['startup_partitions'] as List<dynamic>?) ?? const ['core'])
              .map((e) => e.toString())
              .toList(),
      lazyPartitions:
          ((strategy['lazy_partitions'] as List<dynamic>?) ?? const [])
              .map((e) => e.toString())
              .toList(),
      partitions: rawParts.map(
        (key, value) => MapEntry(
          key,
          PartitionDefinition.fromJson(value as Map<String, dynamic>),
        ),
      ),
    );
  }
}

/// Manages partitioned asset loading and bilingual search indexing.
class CorpusRepository {
  final AssetBundle _bundle;

  PartitionManifest? _manifest;
  Ontology _ontology = Ontology.empty();
  IngredientDictionary _ingredients = IngredientDictionary.empty();
  IngredientGuide _ingredientGuide = IngredientGuide.empty();
  FaqCatalog _faqs = FaqCatalog.empty();
  final Map<String, Dish> _dishesById = {};
  final Map<String, Recipe> _recipesById = {};
  final Set<String> _loadedPartitions = {};
  final Map<String, Set<String>> _invertedIndex = {};

  CorpusRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  PartitionManifest? get manifest => _manifest;
  Ontology get ontology => _ontology;
  IngredientDictionary get ingredients => _ingredients;
  IngredientGuide get ingredientGuide => _ingredientGuide;
  FaqCatalog get faqs => _faqs;
  List<Dish> get dishes => _dishesById.values.toList();
  List<Recipe> get allLoadedRecipes => _recipesById.values.toList();
  Set<String> get loadedPartitions => Set<String>.unmodifiable(_loadedPartitions);

  Dish? dishById(String id) => _dishesById[id];
  Recipe? recipeById(String id) => _recipesById[id];

  /// Initializes startup assets (`partition-manifest.json`, `ontology.json`,
  /// `ingredients.json`, `ingredient-guide.json`, `faqs.json`, `dishes.json`,
  /// and `core-recipes.json`).
  Future<void> initialize() async {
    final manifestStr = await _bundle.loadString('assets/partition-manifest.json');
    _manifest = PartitionManifest.fromJson(
      jsonDecode(manifestStr) as Map<String, dynamic>,
    );

    final ontologyStr = await _bundle.loadString('assets/ontology.json');
    _ontology = Ontology.fromJson(
      jsonDecode(ontologyStr) as Map<String, dynamic>,
    );

    final ingredientsStr = await _bundle.loadString('assets/ingredients.json');
    _ingredients = IngredientDictionary.fromJson(
      jsonDecode(ingredientsStr) as Map<String, dynamic>,
    );

    final guideStr = await _bundle.loadString('assets/ingredient-guide.json');
    _ingredientGuide = IngredientGuide.fromJson(
      jsonDecode(guideStr) as Map<String, dynamic>,
    );

    final faqsStr = await _bundle.loadString('assets/faqs.json');
    _faqs = FaqCatalog.fromJson(
      jsonDecode(faqsStr) as Map<String, dynamic>,
    );

    final dishesStr = await _bundle.loadString('assets/dishes.json');
    final dishesJson = jsonDecode(dishesStr) as Map<String, dynamic>;
    final rawDishes = dishesJson['dishes'] as List<dynamic>? ?? const [];
    for (final d in rawDishes) {
      final dish = Dish.fromJson(d as Map<String, dynamic>);
      _dishesById[dish.id] = dish;
    }

    for (final partId in _manifest!.startupPartitions) {
      await loadPartition(partId);
    }
  }

  /// Initializes directly from in-memory models (convenient for fast unit/widget tests).
  void initializeInMemory({
    required Ontology ontology,
    required IngredientDictionary ingredients,
    IngredientGuide? ingredientGuide,
    FaqCatalog? faqs,
    required List<Dish> dishes,
    required List<Recipe> recipes,
  }) {
    _ontology = ontology;
    _ingredients = ingredients;
    _ingredientGuide = ingredientGuide ?? IngredientGuide.empty();
    _faqs = faqs ?? FaqCatalog.empty();
    _dishesById.clear();
    for (final d in dishes) {
      _dishesById[d.id] = d;
    }
    _recipesById.clear();
    _invertedIndex.clear();
    for (final r in recipes) {
      _registerRecipe(r);
    }
    _loadedPartitions.addAll(['core', 'extended']);
  }

  /// Loads a specific partition (e.g. `extended`, `cuisine-italian`,
  /// `cuisine-asian`, `cuisine-middle-eastern`) on demand.
  Future<void> loadPartition(String partitionId) async {
    if (_loadedPartitions.contains(partitionId)) return;
    final def = _manifest?.partitions[partitionId];
    final assetPath = def?.file ?? 'assets/$partitionId.json';

    final jsonStr = await _bundle.loadString(assetPath);
    final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
    final rawRecipes = decoded['recipes'] as List<dynamic>? ?? const [];
    for (final item in rawRecipes) {
      final recipe = Recipe.fromJson(item as Map<String, dynamic>);
      _registerRecipe(recipe);
    }
    _loadedPartitions.add(partitionId);
  }

  /// Ensures all partitions are loaded (e.g. before a full-corpus search or dish lookup).
  Future<void> ensureAllPartitionsLoaded() async {
    final lazy = _manifest?.lazyPartitions ?? const ['extended'];
    for (final partId in lazy) {
      if (!_loadedPartitions.contains(partId)) {
        await loadPartition(partId);
      }
    }
  }

  /// Returns all variants for [dishId], loading its partition on demand if needed.
  Future<List<Recipe>> variantsForDish(String dishId) async {
    final dish = _dishesById[dishId];
    if (dish != null && !_loadedPartitions.contains(dish.partitionId)) {
      await loadPartition(dish.partitionId);
    }
    return _recipesById.values.where((r) => r.dishId == dishId).toList();
  }

  /// Synchronous variant lookup for already-loaded partitions.
  List<Recipe> loadedVariantsForDish(String dishId) {
    return _recipesById.values.where((r) => r.dishId == dishId).toList();
  }

  void _registerRecipe(Recipe recipe) {
    _recipesById[recipe.id] = recipe;
    final dish = _dishesById[recipe.dishId];

    // Tokenize title, subtitle, dish canonical name, tags, ingredient names (EN + DE)
    final tokens = <String>{
      ..._tokenize(recipe.title.resolve('en')),
      ..._tokenize(recipe.title.resolve('de')),
      ..._tokenize(recipe.subtitle.resolve('en')),
      ..._tokenize(recipe.subtitle.resolve('de')),
      recipe.dietDimension.toLowerCase(),
      recipe.effort.toLowerCase(),
      ...recipe.techniques.map((t) => t.toLowerCase()),
      ...recipe.attributes.map((a) => a.toLowerCase()),
    };

    if (dish != null) {
      tokens.addAll(_tokenize(dish.canonicalName.resolve('en')));
      tokens.addAll(_tokenize(dish.canonicalName.resolve('de')));
      tokens.addAll(dish.cuisineTags.map((c) => c.toLowerCase()));
    }

    for (final tagList in recipe.tags.values) {
      for (final tag in tagList) {
        tokens.addAll(_tokenize(tag));
      }
    }

    for (final ing in recipe.ingredients) {
      tokens.addAll(_tokenize(ing.name.resolve('en')));
      tokens.addAll(_tokenize(ing.name.resolve('de')));
      tokens.addAll(_tokenize(ing.id));
    }

    for (final token in tokens) {
      _invertedIndex.putIfAbsent(token, () => <String>{}).add(recipe.id);
    }
  }

  static Set<String> _tokenize(String input) {
    final normalized = input
        .toLowerCase()
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');
    final rawParts = input
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9äöüß]+'))
        .where((s) => s.length >= 2);
    final normParts = normalized
        .split(RegExp(r'[^a-z0-9]+'))
        .where((s) => s.length >= 2);
    return {...rawParts, ...normParts};
  }

  /// Searches recipes by free text + optional tag/attribute/cuisine filters,
  /// applying profile visibility filters post-match, and returning a cursor-paginated page.
  Future<PaginatedPageResult<Recipe>> searchRecipes({
    required String query,
    required UserProfile profile,
    Set<String> tagFilters = const {},
    String? cuisineFilter,
    String? effortFilter,
    String? cursor,
    int pageSize = 20,
    DateTime? now,
    Map<String, DateTime>? lastCookedByRecipeId,
  }) async {
    await ensureAllPartitionsLoaded();

    final queryTokens = _tokenize(query);
    Iterable<Recipe> candidates = _recipesById.values;

    if (queryTokens.isNotEmpty) {
      final matchedIds = <String>{};
      for (final recipe in _recipesById.values) {
        final dish = _dishesById[recipe.dishId];
        bool allMatch = true;
        for (final qToken in queryTokens) {
          bool tokenFound = false;
          for (final entry in _invertedIndex.entries) {
            if (entry.key.contains(qToken) && entry.value.contains(recipe.id)) {
              tokenFound = true;
              break;
            }
          }
          if (!tokenFound && dish != null) {
            final dEn = dish.canonicalName.resolve('en').toLowerCase();
            final dDe = dish.canonicalName.resolve('de').toLowerCase();
            if (dEn.contains(qToken) || dDe.contains(qToken)) {
              tokenFound = true;
            }
          }
          if (!tokenFound) {
            allMatch = false;
            break;
          }
        }
        if (allMatch) {
          matchedIds.add(recipe.id);
        }
      }
      candidates = candidates.where((r) => matchedIds.contains(r.id));
    }

    if (cuisineFilter != null && cuisineFilter.isNotEmpty) {
      candidates = candidates.where((r) {
        final dish = _dishesById[r.dishId];
        if (dish == null) return false;
        return dish.cuisineTags.contains(cuisineFilter) ||
            dish.secondaryPartitions.contains('cuisine-$cuisineFilter') ||
            dish.secondaryPartitions.contains(cuisineFilter);
      });
    }

    if (effortFilter != null && effortFilter.isNotEmpty) {
      candidates = candidates.where((r) => r.effort == effortFilter);
    }

    if (tagFilters.isNotEmpty) {
      candidates = candidates.where((r) {
        final allTags = <String>{
          r.dietDimension.toLowerCase(),
          r.effort.toLowerCase(),
          ...r.techniques.map((t) => t.toLowerCase()),
          ...r.attributes.map((a) => a.toLowerCase()),
          for (final list in r.tags.values) ...list.map((t) => t.toLowerCase()),
        };
        return tagFilters.every((f) => allTags.contains(f.toLowerCase()));
      });
    }

    // Apply profile visibility filter post-match
    final visibleMatches = candidates
        .where(
          (r) => MatchingEngine.visible(
            r,
            profile,
            ontology: _ontology,
            dictionary: _ingredients,
          ),
        )
        .toList();

    visibleMatches.sort((a, b) {
      final scoreA = MatchingEngine.scoreRecipe(
        a,
        profile,
        now: now,
        lastCookedAt: lastCookedByRecipeId?[a.id],
        dish: _dishesById[a.dishId],
      );
      final scoreB = MatchingEngine.scoreRecipe(
        b,
        profile,
        now: now,
        lastCookedAt: lastCookedByRecipeId?[b.id],
        dish: _dishesById[b.dishId],
      );
      final cmp = scoreB.compareTo(scoreA);
      if (cmp != 0) return cmp;
      return a.id.compareTo(b.id);
    });

    int startIndex = 0;
    if (cursor != null && cursor.isNotEmpty) {
      final idx = visibleMatches.indexWhere((r) => r.id == cursor);
      if (idx >= 0) {
        startIndex = idx + 1;
      }
    }

    if (startIndex >= visibleMatches.length) {
      return const PaginatedPageResult(
        items: [],
        nextCursor: null,
        hasMore: false,
      );
    }

    final endIndex = (startIndex + pageSize).clamp(0, visibleMatches.length);
    final slice = visibleMatches.sublist(startIndex, endIndex);
    final hasMore = endIndex < visibleMatches.length;
    final nextCursor = hasMore && slice.isNotEmpty ? slice.last.id : null;

    return PaginatedPageResult(
      items: slice,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }
}
