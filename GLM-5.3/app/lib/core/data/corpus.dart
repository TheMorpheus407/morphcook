import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/dish.dart';
import '../models/faq.dart';
import '../models/ingredient.dart';
import '../models/ingredient_guide.dart';
import '../models/ontology.dart';
import '../models/recipe.dart';

/// Reads one bundled asset into a string. Injectable so tests can read the
/// corpus straight from disk (`flutter test` does not bundle assets).
typedef AssetReader = Future<String> Function(String path);

Future<String> defaultAssetReader(String path) => rootBundle.loadString(path);

/// A recipe partition definition from `partition-manifest.json`.
class PartitionDef {
  PartitionDef({
    required this.id,
    required this.file,
    required this.tier,
    required this.loadedAtLaunch,
    this.strategy,
    this.dishIds = const [],
    this.recipeCount = 0,
  });

  final String id;
  final String file;
  final String tier; // core | extended | cuisine
  final bool loadedAtLaunch;
  final String? strategy; // e.g. reference-partition
  final List<String> dishIds;
  final int recipeCount;

  static PartitionDef fromMap(Map<String, dynamic> map) => PartitionDef(
        id: map['id'] as String,
        file: map['file'] as String,
        tier: map['tier'] as String? ?? 'extended',
        loadedAtLaunch: map['loaded_at_launch'] as bool? ?? false,
        strategy: map['strategy'] as String?,
        dishIds: ((map['dish_ids'] as List?) ?? const []).map((e) => e.toString()).toList(),
        recipeCount: (map['recipe_count'] as num?)?.toInt() ?? 0,
      );
}

/// The bundled corpus. Meta data (ontology, dictionary, dishes, guide, FAQ)
/// is always loaded at construction; recipe partitions load lazily
/// (core at launch, the rest on demand) per the partition manifest.
class Corpus {
  Corpus._({
    required this.ontology,
    required this.ingredients,
    required this.guide,
    required this.faqs,
    required this.dishes,
    required this.partitions,
    required this.corpusVersion,
    required AssetReader reader,
  }) : _reader = reader;

  final Ontology ontology;
  final IngredientTree ingredients;
  final IngredientGuide guide;
  final FaqBook faqs;
  final Map<String, Dish> dishes;
  final Map<String, PartitionDef> partitions;
  final String corpusVersion;
  final AssetReader _reader;

  final Map<String, Recipe> _recipes = {};
  final Map<String, String> _recipePartition = {};
  final Set<String> _loadedPartitions = {};

  /// Loads meta data + the launch partitions (`core-recipes`).
  static Future<Corpus> load({AssetReader? reader}) async {
    final read = reader ?? defaultAssetReader;
    final ontology =
        Ontology.fromMap(jsonDecode(await read('assets/ontology.json')) as Map<String, dynamic>);
    final ingredients = IngredientTree.fromMap(
        jsonDecode(await read('assets/ingredients.json')) as Map<String, dynamic>);
    final guide = IngredientGuide.fromMap(
        jsonDecode(await read('assets/ingredient-guide.json')) as Map<String, dynamic>);
    final faqs =
        FaqBook.fromMap(jsonDecode(await read('assets/faqs.json')) as Map<String, dynamic>);
    final dishIndex = jsonDecode(await read('assets/dishes.json')) as Map<String, dynamic>;
    final dishes = <String, Dish>{};
    for (final raw in (dishIndex['dishes'] as List)) {
      final dish = Dish.fromMap(raw as Map<String, dynamic>);
      dishes[dish.id] = dish;
    }
    final manifestRaw =
        jsonDecode(await read('assets/partition-manifest.json')) as Map<String, dynamic>;
    final partitions = <String, PartitionDef>{};
    for (final raw in (manifestRaw['partitions'] as List)) {
      final def = PartitionDef.fromMap(raw as Map<String, dynamic>);
      partitions[def.id] = def;
    }
    final corpus = Corpus._(
      ontology: ontology,
      ingredients: ingredients,
      guide: guide,
      faqs: faqs,
      dishes: dishes,
      partitions: partitions,
      corpusVersion: manifestRaw['corpus_version'] as String? ?? '0',
      reader: read,
    );
    // Launch partitions load eagerly (SPEC: top ~80% recipes at launch).
    for (final def in partitions.values.where((p) => p.loadedAtLaunch)) {
      await corpus.ensurePartition(def.id);
    }
    return corpus;
  }
  /// Loads a single partition on demand. Safe to call repeatedly.
  Future<void> ensurePartition(String id) async {
    if (_loadedPartitions.contains(id)) return;
    final def = partitions[id];
    if (def == null) return;
    _loadedPartitions.add(id);
    final raw = jsonDecode(await _reader('assets/${def.file}')) as Map<String, dynamic>;
    for (final recipeRaw in ((raw['recipes'] as List?) ?? const [])) {
      final recipe = Recipe.fromMap(recipeRaw as Map<String, dynamic>);
      _recipes[recipe.id] = recipe;
      _recipePartition[recipe.id] = id;
    }
  }

  /// Loads every partition (used by search, which needs the whole corpus).
  Future<void> ensureAll() async {
    for (final id in partitions.keys) {
      await ensurePartition(id);
    }
  }

  /// Loads the partition that owns [dish] (and its secondary partitions).
  Future<void> ensureDish(Dish dish) async {
    await ensurePartition(dish.partition);
    for (final secondary in dish.secondaryPartitions) {
      await ensurePartition(secondary);
    }
  }

  bool isPartitionLoaded(String id) => _loadedPartitions.contains(id);

  /// A recipe by id, or null when its partition is not (yet) loaded.
  Recipe? recipe(String id) => _recipes[id];

  /// The partition id a recipe belongs to (once loaded).
  String? partitionOfRecipe(String id) => _recipePartition[id];

  /// All currently loaded recipes.
  List<Recipe> get loadedRecipes => _recipes.values.toList(growable: false);

  /// All variants of a dish that are currently loaded.
  List<Recipe> loadedVariantsOf(Dish dish) {
    return dish.variants.map((id) => _recipes[id]).whereType<Recipe>().toList();
  }

  /// Total dishes in the corpus (independent of partitions).
  int get dishCount => dishes.length;

  List<Dish> get allDishes => dishes.values.toList(growable: false);
}
