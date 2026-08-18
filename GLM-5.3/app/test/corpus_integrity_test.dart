import 'package:flutter_test/flutter_test.dart';

import 'package:morphcook/core/data/corpus.dart';
import 'package:morphcook/core/models/localized_text.dart';

import 'helpers.dart';

void main() {
  late Corpus corpus;

  setUpAll(() async {
    corpus = await loadTestCorpus();
    await corpus.ensureAll();
  });

  test('launch partition loads eagerly, the rest on demand', () async {
    // A fresh corpus only loads the launch partition.
    final fresh = await loadTestCorpus();
    expect(fresh.isPartitionLoaded('core-recipes'), isTrue);
    expect(fresh.isPartitionLoaded('extended-recipes'), isFalse);
    expect(fresh.recipe('lasagna-classic'), isNull);
    // On-demand fetch brings it in.
    await fresh.ensurePartition('extended-recipes');
    expect(fresh.recipe('lasagna-classic'), isNotNull);
    // Reference partition (cuisine-asian) loads without recipes of its own.
    await fresh.ensurePartition('cuisine-asian');
    expect(fresh.isPartitionLoaded('cuisine-asian'), isTrue);
  });

  test('manifest counts match the actual corpus', () {
    expect(corpus.dishCount, 11);
    expect(corpus.loadedRecipes.length, 43);
  });

  test('every dish variant id resolves to a recipe', () {
    for (final dish in corpus.allDishes) {
      expect(dish.variants, isNotEmpty, reason: dish.id);
      for (final variantId in dish.variants) {
        expect(corpus.recipe(variantId), isNotNull,
            reason: '$variantId of dish ${dish.id}');
      }
    }
  });

  test('every recipe references a known dish', () {
    for (final recipe in corpus.loadedRecipes) {
      expect(corpus.dishes.containsKey(recipe.dish), isTrue,
          reason: recipe.id);
    }
  });

  test('every ingredient id exists in the dictionary', () {
    for (final recipe in corpus.loadedRecipes) {
      for (final id in recipe.ingredientIds) {
        expect(corpus.ingredients.contains(id), isTrue,
            reason: '$id in ${recipe.id}');
      }
    }
  });

  test('every contains-flag exists in the ontology', () {
    for (final recipe in corpus.loadedRecipes) {
      for (final flag in recipe.contains) {
        expect(corpus.ontology.isFlag(flag), isTrue,
            reason: '$flag in ${recipe.id}');
      }
    }
  });

  test('contains ⊇ flags derivable from ingredients (SPEC cross-check)', () {
    const meatFlags = {'beef', 'pork', 'lamb', 'poultry', 'fish', 'shellfish', 'molluscs'};
    for (final recipe in corpus.loadedRecipes) {
      final derived = <String>{};
      for (final ingredient in recipe.ingredients) {
        derived.addAll(corpus.ingredients.flagsOf(ingredient.id));
      }
      // meat-dairy is inferable when meat and dairy co-occur.
      final hasMeat = derived.any(meatFlags.contains);
      final hasDairy = derived.contains('dairy');
      if (hasMeat && hasDairy) derived.add('meat-dairy');
      for (final flag in derived) {
        expect(recipe.contains.contains(flag), isTrue,
            reason: '$flag derivable but missing in ${recipe.id}');
      }
    }
  });

  test('vegan variants are truly free of animal-derived flags', () {
    const animal = {
      'pork', 'beef', 'lamb', 'poultry', 'fish', 'shellfish', 'molluscs',
      'egg', 'dairy', 'lactose', 'honey', 'gelatin-non-halal',
      'gelatin-non-kosher', 'meat-dairy'
    };
    for (final recipe in corpus.loadedRecipes.where((r) => r.diet == 'vegan')) {
      for (final flag in recipe.contains) {
        expect(animal.contains(flag), isFalse,
            reason: '$flag in vegan ${recipe.id}');
      }
    }
    expect(corpus.loadedRecipes.where((r) => r.diet == 'vegan').length, greaterThanOrEqualTo(5));
  });

  test('all user-visible text is bilingual (en + de)', () {
    void expectBilingual(LocalizedText text, String where) {
      expect(text.containsKey('en'), isTrue, reason: where);
      expect(text.containsKey('de'), isTrue, reason: where);
      expect(text['en']!.trim(), isNotEmpty, reason: where);
      expect(text['de']!.trim(), isNotEmpty, reason: where);
    }

    for (final dish in corpus.allDishes) {
      expectBilingual(dish.name, 'dish name ${dish.id}');
      expectBilingual(dish.hero, 'dish hero ${dish.id}');
      expectBilingual(dish.cap, 'dish cap ${dish.id}');
    }
    for (final recipe in corpus.loadedRecipes) {
      expectBilingual(recipe.title, 'recipe title ${recipe.id}');
      for (var i = 0; i < recipe.steps.length; i++) {
        expectBilingual(recipe.steps[i].text, 'step $i of ${recipe.id}');
      }
    }
    for (final node in corpus.ingredients.allNodes) {
      expectBilingual(node.name, 'ingredient ${node.id}');
    }
    for (final faq in corpus.faqs.faqs) {
      expectBilingual(faq.question, 'faq ${faq.id}');
      expectBilingual(faq.answer, 'faq ${faq.id}');
    }
  });

  test('halal-labelled recipes carry the halal attribute', () {
    for (final recipe in corpus.loadedRecipes.where((r) => r.diet == 'halal')) {
      expect(recipe.attr.contains('halal'), isTrue, reason: recipe.id);
    }
  });
}
