import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/content.dart';
import '../models/localized_text.dart';
import '../models/recipe.dart';
import 'ontology_service.dart';

class ContentRepository {
  ContentRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Map<String, Recipe> _recipes = {};
  final Map<String, Dish> _dishes = {};
  final Set<String> _loadedPartitions = {};
  final Map<String, IngredientGuideEntry> _guides = {};
  List<FaqEntry> _faqs = const [];
  List<IngredientNode> _ingredientNodes = const [];
  Map<String, Set<String>> _compoundFlags = const {};
  Map<String, Map<String, String>> _labels = const {};
  Map<String, String> _partitionFiles = const {};

  bool get allLoaded => _loadedPartitions.containsAll(_partitionFiles.keys);
  List<Recipe> get recipes => List.unmodifiable(_recipes.values);
  List<Dish> get dishes => List.unmodifiable(_dishes.values);
  List<FaqEntry> get faqs => _faqs;
  List<IngredientNode> get ingredientNodes => _ingredientNodes;
  OntologyService get ontology => OntologyService(
    compoundFlags: _compoundFlags,
    ingredients: _ingredientNodes,
    labels: _labels,
  );

  Recipe? recipeById(String id) => _recipes[id];
  Dish? dishById(String id) => _dishes[id];
  IngredientGuideEntry? guideFor(String ingredientId) => _guides[ingredientId];

  Future<void> loadCore() async {
    final results = await Future.wait([
      _json('assets/partition-manifest.json'),
      _json('assets/dishes.json'),
      _json('assets/ontology.json'),
      _json('assets/ingredients.json'),
      _json('assets/ingredient-guide.json'),
      _json('assets/faqs.json'),
    ]);
    final manifest = Map<String, dynamic>.from(results[0] as Map);
    _partitionFiles = {
      for (final raw in manifest['partitions'] as List)
        (raw as Map)['id'] as String: raw['file'] as String,
    };
    for (final raw in results[1] as List) {
      final dish = Dish.fromJson(Map<String, dynamic>.from(raw as Map));
      _dishes[dish.id] = dish;
    }
    final ontologyJson = Map<String, dynamic>.from(results[2] as Map);
    _compoundFlags = {
      for (final entry in (ontologyJson['compound_flags'] as Map).entries)
        '${entry.key}': (entry.value as List).map((item) => '$item').toSet(),
    };
    final rawLabels = <String, dynamic>{
      ...Map<String, dynamic>.from(
        ontologyJson['user_labels'] as Map? ?? const {},
      ),
      ...Map<String, dynamic>.from(ontologyJson['labels'] as Map? ?? const {}),
    };
    _labels = {
      for (final entry in rawLabels.entries)
        entry.key: Map<String, String>.from(entry.value as Map),
    };
    _ingredientNodes = (results[3] as List)
        .map(
          (raw) =>
              IngredientNode.fromJson(Map<String, dynamic>.from(raw as Map)),
        )
        .toList(growable: false);
    for (final raw in results[4] as List) {
      final guide = IngredientGuideEntry.fromJson(
        Map<String, dynamic>.from(raw as Map),
      );
      _guides[guide.id] = guide;
    }
    _faqs = (results[5] as List)
        .map((raw) => FaqEntry.fromJson(Map<String, dynamic>.from(raw as Map)))
        .toList(growable: false);
    await loadPartition('core');
  }

  Future<void> loadPartition(String id) async {
    if (_loadedPartitions.contains(id)) return;
    final file = _partitionFiles[id];
    if (file == null) return;
    final data = await _json('assets/$file');
    for (final raw in data as List) {
      final recipe = Recipe.fromJson(Map<String, dynamic>.from(raw as Map));
      _recipes[recipe.id] = recipe;
    }
    _loadedPartitions.add(id);
  }

  Future<void> loadAll() async {
    for (final id in _partitionFiles.keys) {
      await loadPartition(id);
    }
  }

  Future<void> ensureDish(String dishId) async {
    final dish = _dishes[dishId];
    if (dish == null) return;
    await loadPartition(dish.partitionId);
    for (final partition in dish.secondaryPartitions) {
      await loadPartition(partition);
    }
  }

  List<Recipe> recipesForDish(String dishId) => recipes
      .where((recipe) => recipe.dishId == dishId)
      .toList(growable: false);

  List<Recipe> search(String query, String language, Set<String> tags) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();
    return recipes
        .where((recipe) {
          if (tags.difference(recipe.tags).isNotEmpty) {
            return false;
          }
          if (terms.isEmpty) return true;
          final ingredientNames = recipe.ingredients
              .map((item) => item.name.value(language))
              .join(' ');
          final haystack = [
            recipe.title.value(language),
            recipe.subtitle.value(language),
            ingredientNames,
            recipe.tags.join(' '),
            recipe.cuisine,
          ].join(' ').toLowerCase();
          return terms.every(haystack.contains);
        })
        .toList(growable: false);
  }

  Future<Object?> _json(String path) async =>
      jsonDecode(await _bundle.loadString(path));
}
