import 'dart:convert';

import 'package:flutter/services.dart';

import 'models.dart';

class RecipeRepository {
  RecipeRepository._({
    required this.dishes,
    required this.ingredients,
    required this.ontology,
    required this.faqs,
    required this.manifest,
    required this.searchIndex,
    required this.recipes,
  }) : ingredientIndex = IngredientIndex(ingredients);

  final Map<String, Dish> dishes;
  final Map<String, Ingredient> ingredients;
  final Map<String, dynamic> ontology;
  final List<FaqEntry> faqs;
  final Map<String, dynamic> manifest;
  final Map<String, dynamic> searchIndex;
  final Map<String, Recipe> recipes;
  final IngredientIndex ingredientIndex;
  final Set<String> _loadedPartitions = {'core'};

  static Future<RecipeRepository> load() async {
    final files = await Future.wait([
      rootBundle.loadString('assets/dishes.json'),
      rootBundle.loadString('assets/ingredients.json'),
      rootBundle.loadString('assets/ingredient-guide.json'),
      rootBundle.loadString('assets/ontology.json'),
      rootBundle.loadString('assets/faqs.json'),
      rootBundle.loadString('assets/partition-manifest.json'),
      rootBundle.loadString('assets/search-index.json'),
      rootBundle.loadString('assets/core-recipes.json'),
    ]);
    final rawDishes = _jsonObject(files[0]);
    final rawIngredients = _jsonObject(files[1]);
    final rawGuide = _jsonObject(files[2]);
    final rawOntology = _jsonObject(files[3]);
    final rawFaqs = _jsonObject(files[4]);
    final rawManifest = _jsonObject(files[5]);
    final rawSearchIndex = _jsonObject(files[6]);
    final rawCore = _jsonObject(files[7]);

    final guideById = <String, Map<String, dynamic>>{
      for (final item in _jsonList(rawGuide['ingredients']))
        '${item['id']}': item,
    };
    final ingredients = <String, Ingredient>{
      for (final item in _jsonList(rawIngredients['ingredients']))
        '${item['id']}': Ingredient.fromJson({
          ...item,
          ...?guideById['${item['id']}'],
        }),
    };
    final repository = RecipeRepository._(
      dishes: {
        for (final item in _jsonList(rawDishes['dishes']))
          '${item['id']}': Dish.fromJson(item),
      },
      ingredients: ingredients,
      ontology: rawOntology,
      faqs: _jsonList(rawFaqs['faqs']).map(FaqEntry.fromJson).toList(),
      manifest: rawManifest,
      searchIndex: rawSearchIndex,
      recipes: {
        for (final item in _jsonList(rawCore['recipes']))
          '${item['id']}': Recipe.fromJson(item),
      },
    );
    return repository;
  }

  static Map<String, dynamic> _jsonObject(String source) =>
      (jsonDecode(source) as Map).map((key, value) => MapEntry('$key', value));

  static List<Map<String, dynamic>> _jsonList(dynamic raw) =>
      (raw as List? ?? const [])
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry('$key', value)))
          .toList();

  Set<String> expandAvoidFlags(Set<String> flags) {
    final compounds = ontology['compound_avoid_flags'] as Map? ?? const {};
    final expanded = <String>{};
    void add(String flag) {
      if (!expanded.add(flag)) return;
      final children = compounds[flag];
      if (children is Iterable) {
        for (final child in children) {
          add('$child');
        }
      }
    }

    for (final flag in flags) {
      add(flag);
    }
    return expanded;
  }

  List<String> get classAvoidFlags => stringList(ontology['contains_flags']);

  Future<void> ensurePartition(String partitionId) async {
    if (_loadedPartitions.contains(partitionId)) return;
    final definitions = manifest['partitions'] as Map? ?? const {};
    final definition = definitions[partitionId] as Map?;
    final asset = definition?['asset'];
    if (asset is! String) return;
    final raw = _jsonObject(await rootBundle.loadString(asset));
    for (final item in _jsonList(raw['recipes'])) {
      recipes['${item['id']}'] = Recipe.fromJson(item);
    }
    _loadedPartitions.add(partitionId);
  }

  Future<void> ensureSearchPartitions() async {
    final definitions = manifest['partitions'] as Map? ?? const {};
    for (final entry in definitions.entries) {
      await ensurePartition('${entry.key}');
    }
  }

  List<Recipe> recipesForDish(String dishId) => recipes.values
      .where((recipe) => recipe.dishId == dishId)
      .toList(growable: false);

  Future<List<Recipe>> search(
    String query,
    String lang, {
    Set<String> tags = const {},
  }) async {
    await ensureSearchPartitions();
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((token) => token.isNotEmpty)
        .toList();
    final languageIndex =
        searchIndex[lang] as Map? ?? searchIndex['en'] as Map?;
    Set<String>? indexedCandidates;
    if (languageIndex != null && tokens.isNotEmpty) {
      for (final token in tokens) {
        final ids = stringSet(languageIndex[token]);
        if (ids.isEmpty) continue;
        indexedCandidates = indexedCandidates == null
            ? ids
            : indexedCandidates.intersection(ids);
      }
    }
    final matching = recipes.values.where((recipe) {
      if (indexedCandidates != null && !indexedCandidates.contains(recipe.id)) {
        return false;
      }
      if (tags.isNotEmpty &&
          !tags.any(
            (tag) =>
                recipe.tags.contains(tag) || recipe.mealTypes.contains(tag),
          )) {
        return false;
      }
      if (tokens.isEmpty) return true;
      final haystack = <String>[
        ...recipe.title.values,
        ...recipe.subtitle.values,
        ...recipe.description.values,
        ...recipe.tags,
        ...recipe.mealTypes,
        ...recipe.ingredients.expand(
          (item) => ingredients[item.id]?.name.values ?? const <String>[],
        ),
      ].join(' ').toLowerCase();
      return tokens.every(haystack.contains);
    }).toList();
    matching.sort((a, b) => a.titleFor(lang).compareTo(b.titleFor(lang)));
    return matching;
  }
}
