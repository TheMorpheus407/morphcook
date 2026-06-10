import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/dish.dart';
import 'package:morphcook/models/ingredient.dart';
import 'package:morphcook/models/ingredient_guide.dart';
import 'package:morphcook/models/ontology.dart';
import 'package:morphcook/models/recipe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Map<String, dynamic>> loadAsset(String path) async {
    final raw = await rootBundle.loadString(path);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  test('ontology.json parses cleanly', () async {
    final json = await loadAsset('assets/ontology.json');
    final o = Ontology.fromJson(json);
    expect(o.containsFlags, isNotEmpty);
    expect(o.compoundFlags.keys, contains('vegan'));
    expect(o.compoundFlags['vegan']!.expandsTo, contains('pork'));
    expect(o.attributes.keys, contains('effort'));
  });

  test('dishes.json parses and every variant has a recipe id', () async {
    final json = await loadAsset('assets/dishes.json');
    final dishes = (json['dishes'] as List).map((e) => Dish.fromJson(e as Map<String, dynamic>)).toList();
    expect(dishes, isNotEmpty);
    for (final d in dishes) {
      expect(d.id, isNotEmpty);
      expect(d.name.values, isNotEmpty);
      expect(d.variantRecipeIds, isNotEmpty,
          reason: 'dish ${d.id} has no variants');
    }
  });

  test('core + extended recipes parse and link back to dishes', () async {
    final dishesJson = await loadAsset('assets/dishes.json');
    final core = await loadAsset('assets/core-recipes.json');
    final ext = await loadAsset('assets/extended-recipes.json');
    final allRecipes = <Recipe>[
      ...(core['recipes'] as List).map((e) => Recipe.fromJson(e as Map<String, dynamic>)),
      ...(ext['recipes'] as List).map((e) => Recipe.fromJson(e as Map<String, dynamic>)),
    ];
    final dishes = (dishesJson['dishes'] as List)
        .map((e) => Dish.fromJson(e as Map<String, dynamic>))
        .toList();
    final dishIds = dishes.map((d) => d.id).toSet();

    for (final r in allRecipes) {
      expect(dishIds, contains(r.dishId),
          reason: 'recipe ${r.id} references unknown dish ${r.dishId}');
      expect(r.name.values, isNotEmpty);
      expect(r.ingredients, isNotEmpty,
          reason: '${r.id} has no ingredients');
      expect(r.steps, isNotEmpty, reason: '${r.id} has no steps');
    }

    // Every variant_recipe_id from a dish exists in the corpus
    final recipeIds = allRecipes.map((r) => r.id).toSet();
    for (final d in dishes) {
      for (final id in d.variantRecipeIds) {
        expect(recipeIds, contains(id),
            reason: 'dish ${d.id} references unknown recipe $id');
      }
    }
  });

  test('ingredients.json parses; aisle lookup works', () async {
    final json = await loadAsset('assets/ingredients.json');
    final tree = IngredientTree.fromJson(json);
    expect(tree.find('garlic'), isNotNull);
    expect(tree.find('parmesan'), isNotNull);
    expect(tree.aisleFor('garlic'), equals('produce'));
    expect(tree.aisleFor('parmesan'), equals('dairy'));
    // descendants
    expect(tree.descendantsOf('cheese'), contains('parmesan'));
  });

  test('ingredient-guide.json parses', () async {
    final json = await loadAsset('assets/ingredient-guide.json');
    final entries = (json['entries'] as List)
        .map((e) => IngredientGuideEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    expect(entries, isNotEmpty);
    expect(entries.first.name.values['en'], isNotEmpty);
    expect(entries.first.name.values['de'], isNotEmpty);
  });

  test('faqs.json parses', () async {
    final json = await loadAsset('assets/faqs.json');
    final entries = (json['entries'] as List);
    expect(entries.length, greaterThanOrEqualTo(15));
    final categories = (json['categories'] as List);
    expect(categories, isNotEmpty);
  });

  test('every recipe ingredient has bilingual name', () async {
    final core = await loadAsset('assets/core-recipes.json');
    final ext = await loadAsset('assets/extended-recipes.json');
    for (final list in [core['recipes'] as List, ext['recipes'] as List]) {
      for (final raw in list) {
        final r = Recipe.fromJson(raw as Map<String, dynamic>);
        for (final ing in r.ingredients) {
          expect(ing.name.values['en'], isNotNull,
              reason: '${r.id} ingredient ${ing.id} missing en name');
          expect(ing.name.values['de'], isNotNull,
              reason: '${r.id} ingredient ${ing.id} missing de name');
        }
        for (final step in r.steps) {
          expect(step.text.values['en'], isNotNull,
              reason: '${r.id} step missing en');
          expect(step.text.values['de'], isNotNull,
              reason: '${r.id} step missing de');
        }
      }
    }
  });
}
