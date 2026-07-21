import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';

import '../domain/domain.dart';
import 'recipe_repository.dart';

typedef AssetStringLoader = Future<String> Function(String assetPath);

class CorpusLoadException implements Exception {
  const CorpusLoadException(this.assetPath, this.message, [this.cause]);

  final String assetPath;
  final String message;
  final Object? cause;

  @override
  String toString() => 'Could not load $assetPath: $message';
}

class CorpusIntegrityIssue {
  const CorpusIntegrityIssue({
    required this.code,
    required this.message,
    this.entityId,
  });

  final String code;
  final String message;
  final String? entityId;
}

class CorpusIntegrityReport {
  CorpusIntegrityReport(Iterable<CorpusIntegrityIssue> issues)
    : issues = UnmodifiableListView(List.of(issues));

  final List<CorpusIntegrityIssue> issues;

  bool get isValid => issues.isEmpty;
}

class BundledRecipeRepository implements RecipeRepository {
  BundledRecipeRepository({
    AssetBundle? assetBundle,
    AssetStringLoader? assetLoader,
    this.assetPrefix = 'assets',
  }) : assert(assetBundle == null || assetLoader == null),
       _loadString =
           assetLoader ??
           ((path) => (assetBundle ?? rootBundle).loadString(path));

  final String assetPrefix;
  final AssetStringLoader _loadString;

  final Map<String, Dish> _dishesById = {};
  final Map<String, Recipe> _recipesById = {};
  final Map<String, IngredientGuideEntry> _guideByIngredientId = {};
  final Map<String, FaqEntry> _faqsById = {};
  final Map<String, String> _recipeSourcePartition = {};
  final Map<String, int> _loadedRecipeCountByPartition = {};
  final Map<String, _PartitionSearchIndex> _searchIndexByPartition = {};
  final Set<String> _loadedPartitionIds = {};
  final Set<String> _duplicateRecipeIds = {};
  final Map<String, Future<void>> _partitionLoads = {};
  final ContentGapTracker contentGapTracker = ContentGapTracker();

  PartitionManifest? _manifest;
  Ontology? _ontology;
  IngredientDictionary? _ingredients;
  Future<void>? _initializing;
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  List<Dish> get dishes =>
      UnmodifiableListView(_dishesById.values.toList(growable: false));

  @override
  List<Recipe> get recipes =>
      UnmodifiableListView(_recipesById.values.toList(growable: false));

  @override
  Map<String, Dish> get dishesById => UnmodifiableMapView(_dishesById);

  @override
  Map<String, Recipe> get recipesById => UnmodifiableMapView(_recipesById);

  Map<String, IngredientGuideEntry> get ingredientGuideById =>
      UnmodifiableMapView(_guideByIngredientId);

  @override
  PartitionManifest get manifest => _manifest ?? _notInitialized('manifest');

  @override
  Ontology get ontology => _ontology ?? _notInitialized('ontology');

  @override
  IngredientDictionary get ingredients =>
      _ingredients ?? _notInitialized('ingredients');

  @override
  List<IngredientGuideEntry> get ingredientGuideEntries =>
      UnmodifiableListView(_guideByIngredientId.values.toList(growable: false));

  @override
  List<FaqEntry> get faqs =>
      UnmodifiableListView(_faqsById.values.toList(growable: false));

  Set<String> get loadedPartitionIds =>
      UnmodifiableSetView(_loadedPartitionIds);

  RecipeMatcher get matcher =>
      RecipeMatcher(ontology: ontology, ingredients: ingredients);

  RecipeRanker get ranker => RecipeRanker(matcher: matcher);

  @override
  Future<void> initialize({bool loadExtended = false}) async {
    if (!_initialized) {
      _initializing ??= _initializeCore();
      try {
        await _initializing;
      } finally {
        if (!_initialized) _initializing = null;
      }
    }
    if (loadExtended) {
      final deferred = manifest.partitions.values.where(
        (partition) => partition.kind == PartitionKind.extended,
      );
      await Future.wait(
        deferred.map((partition) => ensurePartitionLoaded(partition.id)),
      );
    }
  }

  Future<void> _initializeCore() async {
    final values = await Future.wait([
      _loadJson('partition-manifest.json'),
      _loadJson('dishes.json'),
      _loadJson('ontology.json'),
      _loadJson('ingredients.json'),
      _loadJson('ingredient-guide.json'),
      _loadJson('faqs.json'),
      _loadJson('search-index.json'),
    ]);
    _manifest = PartitionManifest.fromJson(_asMap(values[0]));
    for (final raw in _extractList(values[1], const ['dishes'])) {
      final dish = Dish.fromJson(_asMap(raw));
      _dishesById[dish.id] = dish;
    }
    _ontology = Ontology.fromJson(_asMap(values[2]));
    _ingredients = IngredientDictionary.fromJson(values[3]);
    for (final raw in _extractList(values[4], const [
      'entries',
      'ingredient_guide',
      'ingredients',
    ])) {
      final entry = IngredientGuideEntry.fromJson(_asMap(raw));
      _guideByIngredientId[entry.ingredientId] = entry;
    }
    for (final raw in _extractList(values[5], const ['faqs', 'entries'])) {
      final faq = FaqEntry.fromJson(_asMap(raw));
      _faqsById[faq.id] = faq;
    }
    for (final raw in _extractList(values[6], const ['partitions'])) {
      final index = _PartitionSearchIndex.fromJson(_asMap(raw));
      _searchIndexByPartition[index.partitionId] = index;
    }

    for (final partition in manifest.launchPartitions) {
      await ensurePartitionLoaded(partition.id);
    }
    _initialized = true;
  }

  @override
  Future<void> ensurePartitionLoaded(String partitionId) async {
    if (_loadedPartitionIds.contains(partitionId)) return;
    final inFlight = _partitionLoads[partitionId];
    if (inFlight != null) return inFlight;
    final load = _loadPartition(partitionId);
    _partitionLoads[partitionId] = load;
    try {
      await load;
    } finally {
      _partitionLoads.remove(partitionId);
    }
  }

  /// Loads only the content partitions that own the requested persisted IDs.
  ///
  /// This keeps the 80% core launch path small while ensuring saved, planned,
  /// and previously cooked extended recipes survive an app restart.
  Future<void> ensureRecipesLoaded(Iterable<String> recipeIds) async {
    await initialize();
    final unresolved = recipeIds
        .where((id) => id.isNotEmpty && !_recipesById.containsKey(id))
        .toSet();
    if (unresolved.isEmpty) return;
    final owners = manifest.partitions.values
        .where(
          (partition) =>
              partition.recipeCount > 0 &&
              partition.recipeIds.any(unresolved.contains),
        )
        .sortedBy<num>((partition) => partition.priority);
    for (final partition in owners) {
      await ensurePartitionLoaded(partition.id);
    }
  }

  Future<void> _loadPartition(String partitionId) async {
    final partition = manifest.partitions[partitionId];
    if (partition == null) {
      throw CorpusLoadException(
        'partition-manifest.json',
        'Unknown partition "$partitionId".',
      );
    }
    for (final dependency in partition.dependsOn) {
      await ensurePartitionLoaded(dependency);
    }
    final json = await _loadJsonPath(_assetPath(partition.asset));
    var partitionRecipeCount = 0;
    for (final raw in _extractList(json, const ['recipes'])) {
      final recipe = Recipe.fromJson(_asMap(raw));
      partitionRecipeCount++;
      if (_recipesById.containsKey(recipe.id)) {
        _duplicateRecipeIds.add(recipe.id);
      }
      _recipesById[recipe.id] = recipe;
      _recipeSourcePartition[recipe.id] = partitionId;
    }
    _loadedRecipeCountByPartition[partitionId] = partitionRecipeCount;
    _loadedPartitionIds.add(partitionId);
  }

  @override
  Dish? dishById(String id) => _dishesById[id];

  @override
  Recipe? recipeById(String id) => _recipesById[id];

  IngredientNode? ingredientById(String id) => ingredients[id];

  IngredientGuideEntry? ingredientGuideFor(String ingredientId) =>
      _guideByIngredientId[ingredientId];

  @override
  List<Recipe> recipesForDish(String dishId) {
    final dish = _dishesById[dishId];
    if (dish == null) return const [];
    return UnmodifiableListView(
      dish.variantRecipeIds.map((id) => _recipesById[id]).whereType<Recipe>(),
    );
  }

  @override
  Future<List<Recipe>> loadRecipesForDish(String dishId) async {
    final dish = _dishesById[dishId];
    if (dish == null) return const [];
    final partitions = <String>{dish.partitionId, ...dish.secondaryPartitions};
    final route = manifest.dishRoutes[dishId];
    if (route != null) {
      partitions.add(route.primaryPartition);
      partitions.addAll(route.secondaryPartitions);
    }
    for (final partition in partitions) {
      if (manifest.partitions.containsKey(partition)) {
        await ensurePartitionLoaded(partition);
      }
    }
    return recipesForDish(dishId);
  }

  Future<VariantMatrix> variantsForDish(String dishId) async =>
      VariantMatrix(await loadRecipesForDish(dishId));

  @override
  List<Recipe> visibleRecipes(
    UserProfile profile, {
    String? ignoreCaloriesForDishId,
  }) => matcher.visibleRecipes(
    _recipesById.values,
    profile,
    ignoreCaloriesForDishId: ignoreCaloriesForDishId,
  );

  @override
  List<RankedRecipe> rankedRecipes(
    UserProfile profile, {
    DateTime? now,
    Iterable<CookHistoryEntry> history = const [],
    String? ignoreCaloriesForDishId,
  }) => ranker.rank(
    _recipesById.values,
    profile,
    now: now,
    history: history,
    ignoreCaloriesForDishId: ignoreCaloriesForDishId,
  );

  @override
  Future<SearchPage> search(SearchQuery query, UserProfile profile) async {
    await initialize();
    final tokenizer = const BilingualTokenizer();
    final queryTokens = tokenizer.tokenize(query.text);
    final candidateIds = _searchIndexByPartition.values
        .where(
          (index) => index.matches(
            queryTokens: queryTokens,
            tags: query.tags,
            cuisineTags: query.cuisineTags,
            mealTypes: query.mealTypes,
          ),
        )
        .map((index) => index.partitionId)
        .where(manifest.partitions.containsKey)
        .toSet();
    final candidates = manifest.partitions.values
        .where(
          (partition) =>
              candidateIds.contains(partition.id) &&
              !_loadedPartitionIds.contains(partition.id),
        )
        .sortedBy<num>((partition) => partition.priority);
    for (final partition in candidates) {
      await ensurePartitionLoaded(partition.id);
    }
    final engine = RecipeSearchEngine(
      recipes: _recipesById.values,
      dishes: _dishesById.values,
      ingredients: ingredients,
      matcher: matcher,
    );
    final page = engine.search(
      query,
      profile,
      loadedPartitionIds: _loadedPartitionIds,
    );
    contentGapTracker.recordIfGap(query, page);
    return page;
  }

  List<FaqEntry> searchFaqs(
    String query, {
    String languageCode = 'en',
    String? category,
    int limit = 30,
  }) {
    final tokenizer = const BilingualTokenizer();
    final tokens = tokenizer.tokenize(query);
    final scored = <({FaqEntry faq, int score})>[];
    for (final faq in _faqsById.values) {
      if (category != null && faq.category != category) continue;
      final question = faq.question.resolve(languageCode);
      final corpus = tokenizer.tokenize(
        [
          question,
          faq.answer.resolve(languageCode),
          ...?faq.keywords[normalizeLanguageCode(languageCode)],
        ].join(' '),
      );
      if (!tokens.every(
        (token) => corpus.any(
          (candidate) => candidate == token || candidate.startsWith(token),
        ),
      )) {
        continue;
      }
      var score = 0;
      final foldedQuestion = tokenizer.fold(question);
      final foldedQuery = tokenizer.fold(query);
      if (foldedQuestion == foldedQuery) {
        score += 1000;
      } else if (foldedQuestion.contains(foldedQuery)) {
        score += 400;
      }
      score += tokens.length * 50;
      scored.add((faq: faq, score: score));
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.faq.id.compareTo(b.faq.id);
    });
    return scored.take(limit).map((entry) => entry.faq).toList();
  }

  CorpusIntegrityReport validateIntegrity({
    Set<String> requiredLanguages = const {'en', 'de'},
  }) {
    final issues = <CorpusIntegrityIssue>[];
    for (final duplicateId in _duplicateRecipeIds) {
      issues.add(
        CorpusIntegrityIssue(
          code: 'duplicate-recipe',
          entityId: duplicateId,
          message: 'Recipe ID occurs in more than one loaded partition.',
        ),
      );
    }
    for (final dish in _dishesById.values) {
      _validateLocalized(
        dish.name,
        requiredLanguages,
        issues,
        entityId: dish.id,
        field: 'canonical_name',
      );
      _validateLocalized(
        dish.heroText,
        requiredLanguages,
        issues,
        entityId: dish.id,
        field: 'hero_text',
      );
      _validateLocalized(
        dish.caption,
        requiredLanguages,
        issues,
        entityId: dish.id,
        field: 'caption',
      );
      for (final combination in dish.unavailableCombinations) {
        _validateLocalized(
          combination.note,
          requiredLanguages,
          issues,
          entityId: dish.id,
          field: 'unavailable_combination.note',
        );
      }
      if (dish.defaultRecipeId != null &&
          !dish.variantRecipeIds.contains(dish.defaultRecipeId)) {
        issues.add(
          CorpusIntegrityIssue(
            code: 'invalid-default-variant',
            entityId: dish.id,
            message: 'Default recipe is not listed as a dish variant.',
          ),
        );
      }
      for (final recipeId in dish.variantRecipeIds) {
        final recipe = _recipesById[recipeId];
        if (recipe == null && _allDishPartitionsLoaded(dish)) {
          issues.add(
            CorpusIntegrityIssue(
              code: 'missing-variant',
              entityId: dish.id,
              message: 'Dish references missing recipe $recipeId.',
            ),
          );
        } else if (recipe != null && recipe.dishId != dish.id) {
          issues.add(
            CorpusIntegrityIssue(
              code: 'wrong-dish-link',
              entityId: recipe.id,
              message: 'Recipe points to ${recipe.dishId}, not ${dish.id}.',
            ),
          );
        }
      }
    }
    final knownAttributes = {
      for (final dimension in ontology.dimensions.values)
        for (final value in dimension.values) value.id,
    };
    final linkedRecipeIds = {
      for (final dish in _dishesById.values) ...dish.variantRecipeIds,
    };
    final combinationsByDish = <String, Set<String>>{};
    for (final recipe in _recipesById.values) {
      _validateLocalized(
        recipe.name,
        requiredLanguages,
        issues,
        entityId: recipe.id,
        field: 'name',
      );
      _validateLocalized(
        recipe.description,
        requiredLanguages,
        issues,
        entityId: recipe.id,
        field: 'description',
      );
      for (final step in recipe.steps) {
        _validateLocalized(
          step.text,
          requiredLanguages,
          issues,
          entityId: recipe.id,
          field: 'step.${step.id}',
        );
      }
      if (!_dishesById.containsKey(recipe.dishId)) {
        issues.add(
          CorpusIntegrityIssue(
            code: 'missing-dish',
            entityId: recipe.id,
            message: 'Recipe references unknown dish ${recipe.dishId}.',
          ),
        );
      }
      if (!linkedRecipeIds.contains(recipe.id)) {
        issues.add(
          CorpusIntegrityIssue(
            code: 'unlinked-recipe',
            entityId: recipe.id,
            message: 'Recipe is not listed by its dish.',
          ),
        );
      }
      final sourcePartition = _recipeSourcePartition[recipe.id];
      if (sourcePartition != null && recipe.partitionId != sourcePartition) {
        issues.add(
          CorpusIntegrityIssue(
            code: 'wrong-partition',
            entityId: recipe.id,
            message:
                'Recipe declares ${recipe.partitionId}, loaded from $sourcePartition.',
          ),
        );
      }
      final combinationKey = recipe.variantDimensions.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final serializedCombination = combinationKey
          .map((entry) => '${entry.key}=${entry.value}')
          .join('|');
      if (!combinationsByDish
          .putIfAbsent(recipe.dishId, () => {})
          .add(serializedCombination)) {
        issues.add(
          CorpusIntegrityIssue(
            code: 'duplicate-variant-combination',
            entityId: recipe.id,
            message: 'Dish has two recipes for the same dimension selection.',
          ),
        );
      }
      for (final dimension in recipe.variantDimensions.entries) {
        final definition = ontology.dimensions[dimension.key];
        if (definition == null ||
            !definition.values.any((value) => value.id == dimension.value)) {
          issues.add(
            CorpusIntegrityIssue(
              code: 'unknown-variant-value',
              entityId: recipe.id,
              message: 'Unknown ${dimension.key} value ${dimension.value}.',
            ),
          );
        }
      }
      for (final attribute in recipe.attributes) {
        if (!knownAttributes.contains(attribute)) {
          issues.add(
            CorpusIntegrityIssue(
              code: 'unknown-attribute',
              entityId: recipe.id,
              message: 'Recipe uses unknown attribute $attribute.',
            ),
          );
        }
      }
      final flagsFromIngredients = <String>{};
      for (final ingredientId in recipe.ingredientIds) {
        final ingredient = ingredients[ingredientId];
        if (ingredient == null) {
          issues.add(
            CorpusIntegrityIssue(
              code: 'missing-ingredient',
              entityId: recipe.id,
              message: 'Recipe references unknown ingredient $ingredientId.',
            ),
          );
        } else {
          flagsFromIngredients.addAll(ingredient.containsFlags);
        }
      }
      final missingDerivedFlags = flagsFromIngredients.difference(
        recipe.contains,
      );
      if (missingDerivedFlags.isNotEmpty) {
        issues.add(
          CorpusIntegrityIssue(
            code: 'incomplete-contains-flags',
            entityId: recipe.id,
            message:
                'Recipe omits ingredient flags ${missingDerivedFlags.join(', ')}.',
          ),
        );
      }
      for (final flag in recipe.contains) {
        if (!ontology.isKnownContainsFlag(flag)) {
          issues.add(
            CorpusIntegrityIssue(
              code: 'unknown-contains-flag',
              entityId: recipe.id,
              message: 'Recipe uses unknown contains flag $flag.',
            ),
          );
        }
      }
      if (recipe.servings <= 0 ||
          recipe.timeMinutes <= 0 ||
          recipe.caloriesPerServing <= 0 ||
          recipe.ingredients.isEmpty ||
          recipe.steps.isEmpty) {
        issues.add(
          CorpusIntegrityIssue(
            code: 'incomplete-recipe',
            entityId: recipe.id,
            message: 'Recipe is missing required cooking data.',
          ),
        );
      }
    }
    for (final partitionId in _loadedPartitionIds) {
      final partition = manifest.partitions[partitionId];
      final expected = partition?.recipeCount ?? 0;
      final actual = _loadedRecipeCountByPartition[partitionId] ?? 0;
      if (expected > 0 && expected != actual) {
        issues.add(
          CorpusIntegrityIssue(
            code: 'partition-count-mismatch',
            entityId: partitionId,
            message: 'Manifest says $expected recipes; asset contains $actual.',
          ),
        );
      }
      if (partition != null &&
          partition.indexedRecipeCount > 0 &&
          partition.indexedRecipeCount != partition.recipeIds.length) {
        issues.add(
          CorpusIntegrityIssue(
            code: 'partition-index-count-mismatch',
            entityId: partitionId,
            message:
                'Manifest says ${partition.indexedRecipeCount} indexed recipes; '
                'lists ${partition.recipeIds.length}.',
          ),
        );
      }
    }
    if (_loadedPartitionIds.containsAll(manifest.partitions.keys)) {
      for (final partition in manifest.partitions.values) {
        final missingReferences = partition.recipeIds.difference(
          _recipesById.keys.toSet(),
        );
        if (missingReferences.isNotEmpty) {
          issues.add(
            CorpusIntegrityIssue(
              code: 'missing-partition-index-reference',
              entityId: partition.id,
              message:
                  'Index references unknown recipes ${missingReferences.join(', ')}.',
            ),
          );
        }
      }
    }
    for (final ingredient in ingredients.byId.values) {
      _validateLocalized(
        ingredient.name,
        requiredLanguages,
        issues,
        entityId: ingredient.id,
        field: 'ingredient.name',
      );
    }
    for (final faq in _faqsById.values) {
      _validateLocalized(
        faq.question,
        requiredLanguages,
        issues,
        entityId: faq.id,
        field: 'faq.question',
      );
      _validateLocalized(
        faq.answer,
        requiredLanguages,
        issues,
        entityId: faq.id,
        field: 'faq.answer',
      );
    }
    for (final guide in _guideByIngredientId.values) {
      for (final field in {
        'description': guide.description,
        'usage_tips': guide.usageTips,
        'storage': guide.storage,
        'where_to_find': guide.whereToFind,
      }.entries) {
        _validateLocalized(
          field.value,
          requiredLanguages,
          issues,
          entityId: guide.ingredientId,
          field: 'guide.${field.key}',
        );
      }
    }
    return CorpusIntegrityReport(issues);
  }

  void _validateLocalized(
    LocalizedText text,
    Set<String> requiredLanguages,
    List<CorpusIntegrityIssue> issues, {
    required String entityId,
    required String field,
  }) {
    final missing = requiredLanguages.where(
      (language) => (text.values[language] ?? '').trim().isEmpty,
    );
    if (missing.isNotEmpty) {
      issues.add(
        CorpusIntegrityIssue(
          code: 'missing-localization',
          entityId: entityId,
          message: '$field is missing ${missing.join(', ')}.',
        ),
      );
    }
  }

  bool _allDishPartitionsLoaded(Dish dish) {
    final route = manifest.dishRoutes[dish.id];
    return {
      dish.partitionId,
      ...dish.secondaryPartitions,
      if (route != null) route.primaryPartition,
      if (route != null) ...route.secondaryPartitions,
    }.every(_loadedPartitionIds.contains);
  }

  Future<Object?> _loadJson(String fileName) =>
      _loadJsonPath(_assetPath(fileName));

  Future<Object?> _loadJsonPath(String path) async {
    try {
      return jsonDecode(await _loadString(path));
    } on FormatException catch (error) {
      throw CorpusLoadException(path, 'Invalid JSON.', error);
    } catch (error) {
      if (error is CorpusLoadException) rethrow;
      throw CorpusLoadException(path, 'Asset is unavailable.', error);
    }
  }

  String _assetPath(String fileName) {
    if (fileName.startsWith('$assetPrefix/')) return fileName;
    return '$assetPrefix/${fileName.replaceFirst(RegExp(r'^/+'), '')}';
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Expected a JSON object.');
    }
    return {for (final entry in value.entries) '${entry.key}': entry.value};
  }

  List<Object?> _extractList(Object? value, List<String> wrapperKeys) {
    if (value is List) return List<Object?>.from(value);
    final map = _asMap(value);
    for (final key in wrapperKeys) {
      if (map[key] is List) return List<Object?>.from(map[key] as List);
    }
    return const [];
  }

  Never _notInitialized(String value) => throw StateError(
    '$value is not available before BundledRecipeRepository.initialize().',
  );
}

class _PartitionSearchIndex {
  _PartitionSearchIndex({
    required this.partitionId,
    required this.tokens,
    required this.tags,
    required this.cuisineTags,
    required this.mealTypes,
  });

  factory _PartitionSearchIndex.fromJson(Map<String, dynamic> json) {
    final text = _stringMap(json['text']);
    final tokenizer = const BilingualTokenizer();
    return _PartitionSearchIndex(
      partitionId: json['partition_id']?.toString() ?? '',
      tokens: <String>{
        for (final value in text.values) ...tokenizer.tokenize('$value'),
      },
      tags: _stringSet(json['tags']),
      cuisineTags: _stringSet(json['cuisine_tags']),
      mealTypes: _stringSet(json['meal_types']),
    );
  }

  final String partitionId;
  final Set<String> tokens;
  final Set<String> tags;
  final Set<String> cuisineTags;
  final Set<String> mealTypes;

  bool matches({
    required Iterable<String> queryTokens,
    required Set<String> tags,
    required Set<String> cuisineTags,
    required Set<String> mealTypes,
  }) =>
      this.tags.containsAll(tags) &&
      (cuisineTags.isEmpty ||
          this.cuisineTags.intersection(cuisineTags).isNotEmpty) &&
      (mealTypes.isEmpty ||
          this.mealTypes.intersection(mealTypes).isNotEmpty) &&
      queryTokens.every(
        (query) => tokens.any(
          (candidate) => candidate == query || candidate.startsWith(query),
        ),
      );
}

Set<String> _stringSet(Object? value) => value is List
    ? value.map((item) => item.toString()).toSet()
    : const <String>{};

Map<String, dynamic> _stringMap(Object? value) => value is Map
    ? {for (final entry in value.entries) '${entry.key}': entry.value}
    : const <String, dynamic>{};
