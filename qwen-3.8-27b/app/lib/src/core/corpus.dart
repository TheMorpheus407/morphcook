import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

class CorpusError implements Exception {
  const CorpusError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Loads the bundled recipe corpus (dishes, recipes, ontology, ingredients,
/// faqs, ingredient guide, partition manifest) with chunked partition loading.
class Corpus {
  Corpus._({
    required this.dishes,
    required this.recipes,
    required this.ontology,
    required this.ingredientsRoots,
    required this.faq,
    required this.guide,
    required this.manifest,
  });

  final List<Dish> dishes;
  final List<Recipe> recipes;
  final Ontology ontology;
  final List<IngredientNode> ingredientsRoots;
  final FaqBook faq;

  /// Educational ingredient content, keyed by ingredient id.
  final Map<String, Map<String, String>> guide;
  final Map<String, Object> manifest;

  late final Map<String, Dish> dishById = {for (final d in dishes) d.id: d};
  late final Map<String, Recipe> recipeById = {for (final r in recipes) r.id: r};
  late final Map<String, List<Recipe>> recipesByDish = {
    for (final d in dishes) d.id: recipes.where((r) => r.dishId == d.id).toList(),
  };

  /// id -> node, for the whole ingredient tree.
  final Map<String, IngredientNode> _ingredientById = {};
  final Map<String, String> _ingredientParent = {};

  void _indexIngredients(IngredientNode n, String? parent) {
    _ingredientById[n.id] = n;
    _ingredientParent[n.id] = parent;
    for (final c in n.children) {
      _indexIngredients(c, n.id);
    }
  }

  List<IngredientNode> get ingredientTree => ingredientsRoots;
  IngredientNode? ingredient(String id) => _ingredientById[id];

  /// A leaf node (no children) used for typeahead display & guide links.
  Iterable<IngredientNode> get leaves {
    return _ingredientById.values.where((n) => n.children.isEmpty);
  }

  /// All ingredient ids under [id] (inclusive), via the hierarchy.
  Set<String> closureSet(String id) {
    final node = _ingredientById[id];
    if (node == null) return {id};
    return node.closureIds().toSet();
  }

  /// Resolve the leaf (most specific) ingredient id used by a recipe into its
  /// guide entry (guide may be attached at any ancestor).
  Map<String, String>? guideFor(String leafId) {
    var String? cur = leafId;
    while (cur != null) {
      final g = guide[cur];
      if (g != null) return g;
      cur = _ingredientParent[cur];
    }
    return null;
  }

  Dish? dish(String id) => dishById[id];
  Recipe? recipe(String id) => recipeById[id];
  List<Recipe> variantsOf(String dishId) {
    final dish = dishById[dishId];
    if (dish == null) return const [];
    return dish.recipeIds
        .map((id) => recipeById[id])
        .where((r) => r != null)
        .map((r) => r!)
        .toList();
  }

  /// Partition registry from the manifest (cuisine partitions & core/extended).
  List<Map<String, Object>> get partitions =>
      ((manifest['partitions'] as List? ?? const []) as List)
          .map((e) => (e as Map).cast<String, Object>())
          .toList(growable: false);

  String get version => (manifest['version'] as String?) ?? '1.0.0';

  bool contains(String recipeId) => recipeById.containsKey(recipeId);

  static Future<Corpus> load() async {
    final manifestRaw = await _asset('assets/partition-manifest.json');
    final manifest = jsonDecode(manifestRaw) as Map<String, dynamic>;

    Future<Map<String, dynamic>> part(String path) async {
      try {
        final raw = await rootBundle.loadString(path);
        return jsonDecode(raw) as Map<String, dynamic>;
      } on Exception catch (e) {
        throw CorpusError('missing corpus file $path: $e');
      }
    }

    final files = [
      'assets/core-recipes.json',
      'assets/extended-recipes.json',
      'assets/cuisine-italian.json',
      'assets/cuisine-asian.json',
      'assets/cuisine-middle-eastern.json',
    ];

    final allRecipes = <Recipe>[];
    final seen = <String>{};
    for (final f in files) {
      final m = await part(f);
      for (final r in (m['recipes'] as List? ?? const [])) {
        final recipe = Recipe.fromJson((r as Map).cast<String, dynamic>());
        if (seen.add(recipe.id)) {
          allRecipes.add(recipe);
        }
      }
    }

    final dishesM = await part('assets/dishes.json');
    final dishes = ((dishesM['dishes'] as List? ?? const []) as List)
        .map((e) => Dish.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    final ontologyM = await part('assets/ontology.json');
    final ontology = Ontology.fromJson(ontologyM);

    final ingsM = await part('assets/ingredients.json');
    final roots = ((ingsM['tree'] as List? ?? const []) as List)
        .map((e) => IngredientNode.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    final faqM = (await part('assets/faqs.json'));
    final faq = FaqBook.fromJson(faqM);

    Map<String, Map<String, String>> guide = const {};
    try {
      final gM = (await part('assets/ingredient-guide.json'));
      guide = (gM['guide'] as Map? ?? const {}).map(
            (k, v) =>
                MapEntry(k.toString(), (v as Map).cast<String, String>()),
          );
    } on Exception {
      // guide is optional
    }

    var corpus = Corpus._(
      dishes: dishes,
      recipes: allRecipes,
      ontology: ontology,
      ingredientsRoots: roots,
      faq: faq,
      guide: guide,
      manifest: manifest.cast<String, Object>(),
    );
    for (final r in roots) {
      corpus._indexIngredients(r, null);
    }
    return corpus;
  }

  static Future<String> _asset(String path) async {
    try {
      return await rootBundle.loadString(path);
    } on Exception catch (e) {
      throw CorpusError('missing corpus file $path: $e');
    }
  }
}
