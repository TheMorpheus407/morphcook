import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/l10n.dart';
import 'package:morphcook/data/models.dart';
import 'package:morphcook/data/profile.dart';
import 'package:morphcook/domain/matching.dart';

Recipe _recipe({
  String id = 'r1',
  List<String> contains = const [],
  List<String> attributes = const [],
  List<String> ingredientIds = const [],
  int timeMinutes = 30,
  int calories = 550,
  String effort = 'easy',
  String diet = 'classic',
}) =>
    Recipe(
      id: id,
      dishId: 'd1',
      title: {'en': id, 'de': id},
      blurb: const {},
      handwritten: const {},
      dietAxis: diet,
      effortAxis: effort,
      calorieLevelAxis: 'standard',
      contains: contains,
      attributes: attributes,
      techniques: const [],
      effort: effort,
      timeMinutes: timeMinutes,
      timeBucket: 't30',
      calorieBucket: 'c600',
      servings: 2,
      caloriesPerServing: calories,
      proteinG: 10,
      carbsG: 10,
      fatG: 10,
      mealSlots: const ['dinner'],
      tags: const [],
      ingredients: const [],
      ingredientIds: ingredientIds,
      steps: const [],
    );

Ontology _ontology() => Ontology.fromJson({
      'contains_flags': {
        'dairy': {'label': {'en': 'dairy', 'de': 'Milch'}},
        'gluten': {'label': {'en': 'gluten', 'de': 'Gluten'}},
        'pork': {'label': {'en': 'pork', 'de': 'Schwein'}},
        'alcohol': {'label': {'en': 'alcohol', 'de': 'Alkohol'}},
        'egg': {'label': {'en': 'egg', 'de': 'Ei'}},
      },
      'compound_flags': {
        'vegan': {
          'label': {'en': 'vegan', 'de': 'vegan'},
          'expands_to': ['pork', 'dairy', 'egg', 'alcohol'],
        },
        'halal': {
          'label': {'en': 'halal', 'de': 'halal'},
          'expands_to': ['pork', 'alcohol'],
        },
      },
      'attributes': {},
      'effort': {'labels': {}},
      'time_bucket': {'labels': {}},
      'calorie_bucket': {'labels': {}},
      'techniques': {'labels': {}},
      'dimensions': {},
    });

IngredientDictionary _dictionary() => IngredientDictionary.fromJson({
      'aisles': [
        {
          'id': 'produce',
          'name': {'en': 'produce', 'de': 'Gemüse'},
          'order': 0
        },
      ],
      'tree': [
        {
          'id': 'dairy',
          'name': {'en': 'dairy', 'de': 'Milchprodukte'},
          'aisle': 'produce',
          'form': 'solid',
          'children': [
            {
              'id': 'cow-milk',
              'name': {'en': "cow's milk", 'de': 'Kuhmilch'},
              'aisle': 'produce',
              'form': 'liquid',
              'children': [
                {
                  'id': 'whole-milk',
                  'name': {'en': 'whole milk', 'de': 'Vollmilch'},
                  'aisle': 'produce',
                  'form': 'liquid',
                },
              ],
            },
            {
              'id': 'cheese',
              'name': {'en': 'cheese', 'de': 'Käse'},
              'aisle': 'produce',
              'form': 'solid',
              'children': [
                {
                  'id': 'parmesan',
                  'name': {'en': 'parmesan', 'de': 'Parmesan'},
                  'aisle': 'produce',
                  'form': 'solid',
                },
              ],
            },
          ],
        },
        {
          'id': 'cilantro',
          'name': {'en': 'cilantro', 'de': 'Koriandergrün'},
          'aisle': 'produce',
          'form': 'count',
        },
      ],
    });

void main() {
  final ontology = _ontology();
  final dictionary = _dictionary();

  group('visible()', () {
    test('empty profile sees everything', () {
      final recipe = _recipe(contains: ['dairy', 'gluten']);
      expect(
        isRecipeVisible(recipe, Profile(),
            ontology: ontology, dictionary: dictionary),
        isTrue,
      );
    });

    test('class avoid-flag hides recipe with intersecting contains-flag', () {
      final recipe = _recipe(contains: ['dairy']);
      final profile = Profile(avoidFlags: {'dairy'});
      expect(
        isRecipeVisible(recipe, profile,
            ontology: ontology, dictionary: dictionary),
        isFalse,
      );
    });

    test('compound avoid-flag expands to base flags', () {
      final recipe = _recipe(contains: ['egg']);
      final profile = Profile(avoidFlags: {'vegan'});
      expect(
        isRecipeVisible(recipe, profile,
            ontology: ontology, dictionary: dictionary),
        isFalse,
      );
      // halal expands to pork + alcohol only; egg stays visible
      final halalProfile = Profile(avoidFlags: {'halal'});
      expect(
        isRecipeVisible(recipe, halalProfile,
            ontology: ontology, dictionary: dictionary),
        isTrue,
      );
    });

    test('specific ingredient avoidance propagates down the tree', () {
      final recipe = _recipe(ingredientIds: ['whole-milk']);
      // avoiding the grandparent `dairy` excludes the leaf
      final profile = Profile(avoidIngredients: {'dairy'});
      expect(
        isRecipeVisible(recipe, profile,
            ontology: ontology, dictionary: dictionary),
        isFalse,
      );
      // avoiding a sibling branch does not
      final sibling = Profile(avoidIngredients: {'cheese'});
      expect(
        isRecipeVisible(recipe, sibling,
            ontology: ontology, dictionary: dictionary),
        isTrue,
      );
      // leaf avoidance only hides that leaf
      final leaf = Profile(avoidIngredients: {'parmesan'});
      expect(
        isRecipeVisible(recipe, leaf,
            ontology: ontology, dictionary: dictionary),
        isTrue,
      );
    });

    test('class + specific avoidance combine', () {
      final recipe =
          _recipe(contains: ['gluten'], ingredientIds: ['cilantro']);
      final profile = Profile(
        avoidFlags: {'dairy'},
        avoidIngredients: {'cilantro'},
      );
      expect(
        isRecipeVisible(recipe, profile,
            ontology: ontology, dictionary: dictionary),
        isFalse,
      );
    });

    test('required attributes must be a subset of recipe attributes', () {
      final recipe = _recipe(attributes: ['comfort']);
      final profile = Profile(requiredAttributes: {'halal'});
      expect(
        isRecipeVisible(recipe, profile,
            ontology: ontology, dictionary: dictionary),
        isFalse,
      );
      final withAttribute = _recipe(attributes: ['halal']);
      expect(
        isRecipeVisible(withAttribute, profile,
            ontology: ontology, dictionary: dictionary),
        isTrue,
      );
    });

    test('time budget is a hard filter', () {
      final recipe = _recipe(timeMinutes: 45);
      final profile = Profile(maxTimeMinutes: 30);
      expect(
        isRecipeVisible(recipe, profile,
            ontology: ontology, dictionary: dictionary),
        isFalse,
      );
      final quick = _recipe(timeMinutes: 20);
      expect(
        isRecipeVisible(quick, profile,
            ontology: ontology, dictionary: dictionary),
        isTrue,
      );
    });

    test('calorie target is a hard filter within tolerance', () {
      final profile = Profile(calorieTarget: 500);
      final inside = _recipe(calories: 500 + calorieTolerance);
      final outside = _recipe(calories: 500 + calorieTolerance + 1);
      expect(
        isRecipeVisible(inside, profile,
            ontology: ontology, dictionary: dictionary),
        isTrue,
      );
      expect(
        isRecipeVisible(outside, profile,
            ontology: ontology, dictionary: dictionary),
        isFalse,
      );
      // override lifts only the calorie filter
      expect(
        isRecipeVisible(outside, profile,
            ontology: ontology,
            dictionary: dictionary,
            overrideCalorieTarget: true),
        isTrue,
      );
    });

    test('visibilityReasons reports each failing filter', () {
      final recipe = _recipe(
          contains: ['dairy'], timeMinutes: 90, calories: 900);
      final profile = Profile(
        avoidFlags: {'dairy'},
        maxTimeMinutes: 30,
        calorieTarget: 500,
      );
      final reasons = visibilityReasons(recipe, profile,
          ontology: ontology, dictionary: dictionary);
      expect(reasons, containsAll(['flag:dairy', 'time', 'calories']));
    });
  });

  group('variant scoring', () {
    test('required-attribute matches dominate the score', () {
      final withHalal = _recipe(id: 'a', attributes: ['halal']);
      final without = _recipe(id: 'b');
      final profile = Profile(requiredAttributes: {'halal'});
      expect(
        variantScore(withHalal, profile) > variantScore(without, profile),
        isTrue,
      );
    });

    test('effort closeness beats distance', () {
      final easy = _recipe(id: 'easy', effort: 'easy');
      final hard = _recipe(id: 'hard', effort: 'hard');
      final profile = Profile(preferredEffort: 'easy');
      expect(
        variantScore(easy, profile) > variantScore(hard, profile),
        isTrue,
      );
    });

    test('bestVariant picks the highest scoring visible variant', () {
      final easy = _recipe(id: 'easy', effort: 'easy');
      final hard = _recipe(id: 'hard', effort: 'hard');
      final profile = Profile(preferredEffort: 'easy');
      expect(bestVariant([hard, easy], profile)!.id, 'easy');
      expect(bestVariant([], profile), isNull);
    });
  });

  group('l10n', () {
    test('tx falls back to en, then any language', () {
      expect(tx({'en': 'hello', 'de': 'hallo'}, AppLang.de), 'hallo');
      expect(tx({'en': 'hello'}, AppLang.de), 'hello');
      expect(tx({'fr': 'bonjour'}, AppLang.de), 'bonjour');
      expect(tx(null, AppLang.en), '');
    });
  });
}
