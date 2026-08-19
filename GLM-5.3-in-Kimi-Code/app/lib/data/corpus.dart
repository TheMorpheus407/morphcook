/// Loads the bundled corpus from assets/ using the partition manifest.
///
/// core + extended partitions load eagerly at launch (they hold every dish
/// in v1); cuisine partitions are views over the same recipes and load
/// on demand — recipes are deduped by id, so overlapping partitions are safe.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

class Corpus {
  final CorpusManifest manifest;
  final Ontology ontology;
  final IngredientIndex ingredients;
  final Map<String, Dish> dishes;
  final Map<String, Recipe> recipes; // id -> recipe
  final Map<String, List<Recipe>> byDish; // dish id -> variants
  final List<FaqEntry> faqs;
  final Map<String, GuideEntry> guide;

  const Corpus({
    required this.manifest,
    required this.ontology,
    required this.ingredients,
    required this.dishes,
    required this.recipes,
    required this.byDish,
    required this.faqs,
    required this.guide,
  });

  static Future<Corpus> load() async {
    Future<Map<String, dynamic>> loadJson(String path) async {
      final raw = await rootBundle.loadString('assets/$path');
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    final manifest =
        CorpusManifest.fromJson(await loadJson('partition-manifest.json'));
    final ontology = Ontology.fromJson(await loadJson('ontology.json'));
    final ingredientsRaw = await loadJson('ingredients.json');
    final ingredients =
        IngredientIndex.fromJson(ingredientsRaw['nodes'] as List);
    final dishesRaw = await loadJson('dishes.json');

    final recipes = <String, Recipe>{};
    // core + extended load at launch; cuisine views fill any gaps later.
    for (final file in const ['core-recipes.json', 'extended-recipes.json']) {
      final data = await loadJson(file);
      _mergeRecipes(recipes, data);
    }

    final dishes = <String, Dish>{};
    final byDish = <String, List<Recipe>>{};
    for (final d in (dishesRaw['dishes'] as List)) {
      final dish = Dish.fromJson(d as Map<String, dynamic>);
      dishes[dish.id] = dish;
      byDish[dish.id] = <Recipe>[];
    }
    for (final r in recipes.values) {
      byDish.putIfAbsent(r.dishId, () => []).add(r);
    }

    final faqsRaw = await loadJson('faqs.json');
    final faqs = (faqsRaw['faqs'] as List)
        .map((e) => FaqEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    final guideRaw = await loadJson('ingredient-guide.json');
    final guide = <String, GuideEntry>{};
    for (final e in (guideRaw['entries'] as List)) {
      final g = GuideEntry.fromJson(e as Map<String, dynamic>);
      guide[g.id] = g;
    }

    return Corpus(
      manifest: manifest,
      ontology: ontology,
      ingredients: ingredients,
      dishes: dishes,
      recipes: recipes,
      byDish: byDish,
      faqs: faqs,
      guide: guide,
    );
  }

  static void _mergeRecipes(
      Map<String, Recipe> into, Map<String, dynamic> data) {
    for (final e in (data['recipes'] as List)) {
      final r = Recipe.fromJson(e as Map<String, dynamic>);
      into[r.id] = r; // dedupe by id across partitions
    }
  }

  /// On-demand partition fetch (cuisine views over the same corpus).
  Future<void> loadPartition(String partitionId) async {
    final info = manifest.partitions[partitionId];
    if (info == null) return;
    // Already covered? cuisine partitions reference core/extended recipes.
    final needAny =
        byDish.entries.any((e) => info.dishIds.contains(e.key) && e.value.isEmpty);
    if (!needAny) return;
    final raw = await rootBundle.loadString('assets/${info.file}');
    _mergeRecipes(recipes, jsonDecode(raw) as Map<String, dynamic>);
    for (final r in recipes.values) {
      final list = byDish.putIfAbsent(r.dishId, () => []);
      if (!list.any((x) => x.id == r.id)) list.add(r);
    }
  }

  List<Recipe> variantsOf(String dishId) => byDish[dishId] ?? const [];

  /// Ingredient display helper with guide lookup.
  GuideEntry? guideFor(String ingredientId) => guide[ingredientId];
}
