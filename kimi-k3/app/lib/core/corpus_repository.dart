import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'models/dish.dart';
import 'models/faq.dart';
import 'models/ingredient_guide.dart';
import 'models/ingredient_node.dart';
import 'models/ontology.dart';
import 'models/recipe.dart';

/// Loads the bundled recipe corpus from assets. Partitions: core recipes are
/// loaded eagerly at launch; extended/cuisine partitions lazily on demand.
class CorpusRepository {
  static const _dataDir = 'assets/data';

  final List<Dish> dishes = [];
  final Map<String, Recipe> recipes = {};
  late Ontology ontology;
  late IngredientDictionary ingredientDictionary;
  final List<FaqEntry> faqs = [];
  final Map<String, IngredientGuideEntry> ingredientGuide = {};
  final Map<String, List<String>> searchIndex = {}; // recipe_id -> tokens (all langs)
  final Set<String> _loadedPartitions = {};
  Map<String, dynamic> _manifest = const {};

  bool _coreLoaded = false;

  Map<String, dynamic> get manifest => _manifest;

  Future<Map<String, dynamic>> _loadJson(String file) async {
    final raw = await rootBundle.loadString('$_dataDir/$file');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  void _ingestRecipes(Map<String, dynamic> json, String partitionId) {
    for (final e in (json['recipes'] as List? ?? [])) {
      final recipe = Recipe.fromJson(e as Map<String, dynamic>);
      recipes[recipe.id] = recipe;
    }
    _loadedPartitions.add(partitionId);
  }

  /// Loads the manifest, ontology, dictionaries and the core partition.
  Future<void> loadCore() async {
    if (_coreLoaded) return;
    _manifest = await _loadJson('partition-manifest.json');

    ontology = Ontology.fromJson(await _loadJson('ontology.json'));

    final ingredientsJson = await _loadJson('ingredients.json');
    ingredientDictionary = IngredientDictionary(
      (ingredientsJson['ingredients'] as List? ?? [])
          .map((e) => IngredientNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

    final dishesJson = await _loadJson('dishes.json');
    dishes.addAll((dishesJson['dishes'] as List? ?? [])
        .map((e) => Dish.fromJson(e as Map<String, dynamic>)));

    faqs.addAll(((await _loadJson('faqs.json'))['faqs'] as List? ?? [])
        .map((e) => FaqEntry.fromJson(e as Map<String, dynamic>)));

    for (final e
        in ((await _loadJson('ingredient-guide.json'))['guide'] as List? ??
            [])) {
      final entry =
          IngredientGuideEntry.fromJson(e as Map<String, dynamic>);
      ingredientGuide[entry.ingredientId] = entry;
    }

    final indexJson = await _loadJson('search-index.json');
    for (final e in (indexJson['index'] as List? ?? [])) {
      final m = e as Map<String, dynamic>;
      final tokens = <String>{
        ...(m['tokens_en'] as List? ?? []).cast<String>(),
        ...(m['tokens_de'] as List? ?? []).cast<String>(),
      }.toList();
      searchIndex[m['recipe_id'] as String] = tokens;
    }

    // Eager partitions.
    for (final p in (_manifest['partitions'] as List? ?? [])) {
      final m = p as Map<String, dynamic>;
      if (m['load_strategy'] == 'eager') {
        _ingestRecipes(await _loadJson(m['file'] as String), m['id'] as String);
      }
    }
    _coreLoaded = true;
  }

  /// Lazily loads a partition by id (e.g. 'extended', 'cuisine-italian').
  Future<void> ensurePartition(String partitionId) async {
    if (_loadedPartitions.contains(partitionId)) return;
    for (final p in (_manifest['partitions'] as List? ?? [])) {
      final m = p as Map<String, dynamic>;
      if (m['id'] == partitionId) {
        _ingestRecipes(await _loadJson(m['file'] as String), partitionId);
        return;
      }
    }
  }

  /// Ensures every recipe of [dish] (primary + secondary partitions) is loaded.
  Future<void> ensureDishLoaded(Dish dish) async {
    await ensurePartition(dish.partitionId == 'core' ? 'core' : 'extended');
    for (final p in dish.secondaryPartitions) {
      await ensurePartition(p);
    }
  }

  /// Ensures all lazy partitions are loaded (e.g. for global search).
  Future<void> ensureAllLoaded() async {
    for (final p in (_manifest['partitions'] as List? ?? [])) {
      final m = p as Map<String, dynamic>;
      await ensurePartition(m['id'] as String);
    }
  }

  Dish? dishById(String id) {
    for (final d in dishes) {
      if (d.id == id) return d;
    }
    return null;
  }

  Recipe? recipeById(String id) => recipes[id];

  List<Recipe> variantsOf(Dish dish) => dish.variantIds
      .map((id) => recipes[id])
      .whereType<Recipe>()
      .toList();
}
