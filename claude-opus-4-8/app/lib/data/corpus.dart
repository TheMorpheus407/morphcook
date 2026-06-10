import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/localized.dart';
import '../logic/matching.dart';
import '../logic/search_index.dart';
import '../models/dish.dart';
import '../models/faq.dart';
import '../models/ingredient_dict.dart';
import '../models/ingredient_guide.dart';
import '../models/ontology.dart';
import '../models/recipe.dart';
import 'partition_manifest.dart';

/// The immutable, bundled recipe corpus plus its companion data. Loaded once
/// at launch. There are no runtime network calls — everything ships in assets.
class Corpus {
  Corpus({
    required this.manifest,
    required this.ontology,
    required this.ingredients,
    required this.dishes,
    required this.recipes,
    required this.faqs,
    required this.faqCategories,
    required this.guide,
  })  : _dishById = {for (final d in dishes) d.id: d},
        _recipeById = {for (final r in recipes) r.id: r},
        _guideById = {for (final g in guide) g.ingredientId: g} {
    searchIndex = SearchIndex.build(recipes);
    matcher = Matcher(ontology: ontology, dict: ingredients);
  }

  final PartitionManifest manifest;
  final Ontology ontology;
  final IngredientDict ingredients;
  final List<Dish> dishes;
  final List<Recipe> recipes;
  final List<FaqEntry> faqs;
  final List<FaqCategory> faqCategories;
  final List<GuideEntry> guide;

  late final SearchIndex searchIndex;
  late final Matcher matcher;

  final Map<String, Dish> _dishById;
  final Map<String, Recipe> _recipeById;
  final Map<String, GuideEntry> _guideById;

  Dish? dish(String id) => _dishById[id];
  Recipe? recipe(String id) => _recipeById[id];
  Map<String, Recipe> get recipeById => _recipeById;
  GuideEntry? guideFor(String ingredientId) => _guideById[ingredientId];

  List<Recipe> variantsOf(String dishId) {
    final d = _dishById[dishId];
    if (d == null) return const [];
    return d.variantRecipeIds
        .map((id) => _recipeById[id])
        .whereType<Recipe>()
        .toList();
  }

  Dish? dishOfRecipe(String recipeId) {
    final r = _recipeById[recipeId];
    return r == null ? null : _dishById[r.dishId];
  }

  /// Recipe ids surfaced by a cuisine partition (cross-reference list).
  List<String> recipesInPartition(String partitionId) =>
      manifest.crossReferences[partitionId] ?? const [];

  // ---------------------------------------------------------------------------

  static Future<String> _load(String name) =>
      rootBundle.loadString('assets/data/$name');

  /// Load the full corpus. Reads the manifest, then the eager partitions, then
  /// lazily-declared recipe partitions (kept tiny in v1 so we just resolve them
  /// all up front — the manifest still drives what exists and how).
  static Future<Corpus> load() async {
    final manifest = PartitionManifest.fromJson(
        jsonDecode(await _load('partition-manifest.json')) as Map<String, dynamic>);

    final ontology = Ontology.fromJson(
        jsonDecode(await _load('ontology.json')) as Map<String, dynamic>);
    final ingredients = IngredientDict.fromJson(
        jsonDecode(await _load('ingredients.json')) as Map<String, dynamic>);

    final dishesJson = jsonDecode(await _load('dishes.json')) as Map<String, dynamic>;
    final dishes = (dishesJson['dishes'] as List)
        .map((e) => Dish.fromJson(e as Map<String, dynamic>))
        .toList();

    // Recipe-bearing partitions from the manifest.
    final recipes = <Recipe>[];
    for (final p in manifest.partitions.where((p) => p.kind == 'recipes')) {
      final data = jsonDecode(await _load(p.file)) as Map<String, dynamic>;
      recipes.addAll((data['recipes'] as List)
          .map((e) => Recipe.fromJson(e as Map<String, dynamic>)));
    }

    final faqsJson = jsonDecode(await _load('faqs.json')) as Map<String, dynamic>;
    final faqs = (faqsJson['entries'] as List)
        .map((e) => FaqEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    final faqCategories = (faqsJson['categories'] as List)
        .map((e) => FaqCategory.fromJson(e as Map<String, dynamic>))
        .toList();

    final guideJson =
        jsonDecode(await _load('ingredient-guide.json')) as Map<String, dynamic>;
    final guide = (guideJson['entries'] as List)
        .map((e) => GuideEntry.fromJson(e as Map<String, dynamic>))
        .toList();

    return Corpus(
      manifest: manifest,
      ontology: ontology,
      ingredients: ingredients,
      dishes: dishes,
      recipes: recipes,
      faqs: faqs,
      faqCategories: faqCategories,
      guide: guide,
    );
  }

  /// Variant-axis label lookup, resolving `values_from` to the attribute defs.
  String axisValueLabel(String axisId, String valueId, AppLang lang) {
    final axis = ontology.axis(axisId);
    if (axis == null) return valueId;
    if (axis.valuesFrom == 'effort') {
      return ontology.attribute(valueId)?.label.resolve(lang) ?? valueId;
    }
    if (axis.valuesFrom == 'calorie_bucket') {
      return ontology.bucket(valueId)?.label.resolve(lang) ?? valueId;
    }
    for (final v in axis.values) {
      if (v.id == valueId) return v.label.resolve(lang);
    }
    return valueId;
  }
}
