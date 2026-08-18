import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/dish.dart';
import '../models/recipe.dart';
import '../models/ontology.dart';
import '../models/ingredient_node.dart';
import '../models/ingredient_guide.dart';
import '../models/faq.dart';

class CorpusService {
  Ontology? ontology;
  IngredientDictionary? ingredientDictionary;
  List<Dish> dishes = [];
  Map<String, Dish> dishMap = {};
  List<Recipe> recipes = [];
  Map<String, Recipe> recipeMap = {};
  List<IngredientGuideEntry> ingredientGuide = [];
  Map<String, IngredientGuideEntry> guideMap = {};
  List<FaqItem> faqs = [];
  final Set<String> _loadedPartitions = {};
  Map<String, dynamic> partitionManifest = {};

  bool isLoaded = false;

  /// Loads bundled launch corpus
  Future<void> init() async {
    if (isLoaded) return;

    // 1. Load Ontology
    final ontologyStr = await rootBundle.loadString('assets/ontology.json');
    ontology = Ontology.fromJson(jsonDecode(ontologyStr) as Map<String, dynamic>);

    // 2. Load Ingredients Dictionary
    final ingredientsStr = await rootBundle.loadString('assets/ingredients.json');
    ingredientDictionary = IngredientDictionary.fromJsonList(jsonDecode(ingredientsStr) as List<dynamic>);

    // 3. Load Dishes
    final dishesStr = await rootBundle.loadString('assets/dishes.json');
    final dishesJson = jsonDecode(dishesStr) as List<dynamic>;
    dishes = dishesJson.map((e) => Dish.fromJson(e as Map<String, dynamic>)).toList();
    dishMap = {for (final d in dishes) d.id: d};

    // 4. Load Partition Manifest
    try {
      final manifestStr = await rootBundle.loadString('assets/partition-manifest.json');
      partitionManifest = jsonDecode(manifestStr) as Map<String, dynamic>;
    } catch (_) {
      partitionManifest = {'partitions': []};
    }

    // 5. Load Core Recipes
    final coreStr = await rootBundle.loadString('assets/core-recipes.json');
    final coreJson = jsonDecode(coreStr) as List<dynamic>;
    recipes = coreJson.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
    _loadedPartitions.add('core');

    // Also load recipes.json if there are additional recipes not in core
    try {
      final allStr = await rootBundle.loadString('assets/recipes.json');
      final allJson = jsonDecode(allStr) as List<dynamic>;
      final allRecipes = allJson.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
      for (final r in allRecipes) {
        if (!recipes.any((existing) => existing.id == r.id)) {
          recipes.add(r);
        }
      }
    } catch (_) {}

    recipeMap = {for (final r in recipes) r.id: r};

    // 6. Load Ingredient Guide
    try {
      final guideStr = await rootBundle.loadString('assets/ingredient-guide.json');
      final guideJson = jsonDecode(guideStr) as List<dynamic>;
      ingredientGuide = guideJson.map((e) => IngredientGuideEntry.fromJson(e as Map<String, dynamic>)).toList();
      guideMap = {for (final g in ingredientGuide) g.id: g};
    } catch (_) {}

    // 7. Load FAQs
    try {
      final faqStr = await rootBundle.loadString('assets/faqs.json');
      final faqJson = jsonDecode(faqStr) as List<dynamic>;
      faqs = faqJson.map((e) => FaqItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}

    isLoaded = true;
  }

  /// Load on-demand partition
  Future<void> loadPartition(String partitionId) async {
    if (_loadedPartitions.contains(partitionId)) return;

    final partitionsList = partitionManifest['partitions'] as List<dynamic>? ?? [];
    final partition = partitionsList.firstWhere(
      (p) => p['id'] == partitionId,
      orElse: () => null,
    );

    if (partition != null && partition['file'] != null) {
      try {
        final content = await rootBundle.loadString(partition['file'] as String);
        final list = jsonDecode(content) as List<dynamic>;
        final newRecipes = list.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
        for (final r in newRecipes) {
          if (!recipeMap.containsKey(r.id)) {
            recipes.add(r);
            recipeMap[r.id] = r;
          }
        }
        _loadedPartitions.add(partitionId);
      } catch (_) {}
    }
  }

  Dish? getDish(String id) => dishMap[id];
  Recipe? getRecipe(String id) => recipeMap[id];
  List<Recipe> getVariantsForDish(String dishId) {
    return recipes.where((r) => r.dishId == dishId).toList();
  }
}
