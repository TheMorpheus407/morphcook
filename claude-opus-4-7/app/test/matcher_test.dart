import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/matching/matcher.dart' as morph;
import 'package:morphcook/models/ingredient_dict.dart';
import 'package:morphcook/models/localized.dart';
import 'package:morphcook/models/ontology.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';

Ontology _ontology() => Ontology(
      containsFlags: const {},
      compoundFlags: const {
        'vegan': [
          'meat',
          'pork',
          'beef',
          'lamb',
          'poultry',
          'fish',
          'shellfish',
          'molluscs',
          'egg',
          'dairy',
          'honey'
        ],
        'vegetarian': ['meat', 'pork', 'beef', 'lamb', 'poultry', 'fish'],
        'halal': ['pork', 'alcohol'],
      },
      compoundFlagNames: const {},
      attributes: const {},
      efforts: const {},
      techniques: const {},
      timeBuckets: const {},
      calorieBuckets: const {},
    );

IngredientDict _dict() => IngredientDict({
      'dairy': const IngredientNode(
          id: 'dairy', name: Localized({'en': 'dairy'}), childIds: ['milk']),
      'milk': const IngredientNode(
          id: 'milk', name: Localized({'en': 'milk'}), parentId: 'dairy'),
      'apples': const IngredientNode(
          id: 'apples', name: Localized({'en': 'apples'})),
      'lamb': const IngredientNode(
          id: 'lamb', name: Localized({'en': 'lamb'})),
    });

Recipe _r({
  String id = 'r',
  List<String> contains = const [],
  List<String> ingredientIds = const [],
  List<String> attributes = const [],
  String effort = 'easy',
  int time = 20,
  int calories = 500,
}) {
  return Recipe(
    id: id,
    dishId: 'd',
    name: const Localized({'en': 'r'}),
    description: const Localized({'en': ''}),
    variantTag: const Localized({'en': 'classic'}),
    contains: contains,
    attributes: attributes,
    effort: effort,
    timeMinutes: time,
    caloriesPerServing: calories,
    servings: 2,
    ingredients: const [],
    steps: const [],
    cuisineTags: const [],
    partitionId: 'core',
    secondaryPartitions: const [],
    frequencyTier: 1,
    ingredientIds: ingredientIds.toSet(),
  );
}

void main() {
  group('Matcher', () {
    final matcher = morph.Matcher(ontology: _ontology(), dict: _dict());

    test('vegan profile hides recipes with dairy', () {
      final profile = const Profile(avoidFlags: {'vegan'});
      final r = _r(contains: ['dairy']);
      expect(matcher.evaluate(r, profile).visible, isFalse);
    });

    test('vegan profile allows recipes without animal flags', () {
      final profile = const Profile(avoidFlags: {'vegan'});
      final r = _r(contains: ['gluten', 'soy']);
      expect(matcher.evaluate(r, profile).visible, isTrue);
    });

    test('halal profile hides pork', () {
      final profile = const Profile(avoidFlags: {'halal'});
      final r = _r(contains: ['pork']);
      expect(matcher.evaluate(r, profile).visible, isFalse);
    });

    test('avoiding parent ingredient hides children', () {
      final profile = const Profile(avoidIngredients: {'dairy'});
      final r = _r(ingredientIds: ['milk']);
      expect(matcher.evaluate(r, profile).visible, isFalse);
    });

    test('specific ingredient avoidance', () {
      final profile = const Profile(avoidIngredients: {'apples'});
      final r = _r(ingredientIds: ['apples']);
      expect(matcher.evaluate(r, profile).visible, isFalse);
      final r2 = _r(ingredientIds: ['lamb']);
      expect(matcher.evaluate(r2, profile).visible, isTrue);
    });

    test('time budget hard filter', () {
      final profile = const Profile(maxTimeMinutes: 20);
      final r = _r(time: 25);
      expect(matcher.evaluate(r, profile).visible, isFalse);
    });

    test('calorie hard filter outside tolerance', () {
      final profile = const Profile(
          calorieTarget: 500, calorieTolerance: 100, calorieHardFilter: true);
      expect(matcher.evaluate(_r(calories: 700), profile).visible, isFalse);
      expect(matcher.evaluate(_r(calories: 550), profile).visible, isTrue);
    });

    test('calorie filter disabled', () {
      final profile = const Profile(
          calorieTarget: 500, calorieTolerance: 50, calorieHardFilter: false);
      expect(matcher.evaluate(_r(calories: 900), profile).visible, isTrue);
    });

    test('required attribute must be present', () {
      final profile = const Profile(requiredAttributes: {'breakfast'});
      expect(
          matcher.evaluate(_r(attributes: ['breakfast']), profile).visible,
          isTrue);
      expect(matcher.evaluate(_r(attributes: ['dinner']), profile).visible,
          isFalse);
    });

    test('multiple compound flags combine', () {
      final profile =
          const Profile(avoidFlags: {'vegan', 'halal'});
      // pork is covered by halal but not by vegan's standard set
      expect(matcher.evaluate(_r(contains: ['pork']), profile).visible,
          isFalse);
    });
  });
}
