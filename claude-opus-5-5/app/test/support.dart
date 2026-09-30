import 'dart:convert';
import 'dart:io';

import 'package:morphcook/data/search_index.dart';
import 'package:morphcook/logic/matching.dart';
import 'package:morphcook/models/ingredient_tree.dart';
import 'package:morphcook/models/ontology.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';
import 'package:morphcook/models/reference.dart';

/// The real bundled corpus, read straight from `assets/` for pure-Dart tests.
class Corpus {
  Corpus._();

  static final Corpus instance = Corpus._().._load();

  late final Ontology ontology;
  late final IngredientTree tree;
  late final Map<String, Dish> dishes;
  late final Map<String, Recipe> recipes;
  late final Map<String, dynamic> manifest;
  late final SearchIndex searchIndex;
  late final FaqCatalog faqs;
  late final IngredientGuide guide;
  late final Map<String, dynamic> rawOntology;

  static Map<String, dynamic> json(String name) =>
      jsonDecode(File('assets/$name').readAsStringSync()) as Map<String, dynamic>;

  void _load() {
    rawOntology = json('ontology.json');
    ontology = Ontology.fromJson(rawOntology);
    tree = IngredientTree.fromJson(json('ingredients.json'));
    dishes = {
      for (final d in json('dishes.json')['dishes'] as List)
        (d as Map<String, dynamic>)['id'] as String: Dish.fromJson(d),
    };
    manifest = json('partition-manifest.json');
    recipes = {};
    for (final p in manifest['partitions'] as List) {
      final file = (p['file'] as String).replaceFirst('assets/', '');
      for (final r in json(file)['recipes'] as List) {
        final recipe = Recipe.fromJson(r as Map<String, dynamic>, partitionId: p['id'] as String);
        recipes[recipe.id] = recipe;
      }
    }
    searchIndex = SearchIndex.fromJson(json('search-index.json'));
    faqs = FaqCatalog.fromJson(json('faqs.json'));
    guide = IngredientGuide.fromJson(json('ingredient-guide.json'));
  }

  Recipe r(String id) => recipes[id] ?? (throw StateError('no recipe $id'));

  List<Recipe> variants(String dishId) => [for (final id in dishes[dishId]!.variants) r(id)];

  MatchContext ctx(Profile p) => MatchContext.fromProfile(p, ontology, tree);
}
