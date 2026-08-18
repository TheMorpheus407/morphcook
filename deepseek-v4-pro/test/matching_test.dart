import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/matching.dart' as engine;
import 'package:morphcook/models/ingredient.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';

Recipe recipe({
  String id = 'dish.variant',
  Set<String> contains = const {},
  List<String> ingredientIds = const [],
  Set<String> attributes = const {},
  String effort = 'easy',
  int time = 30,
  int calories = 500,
}) {
  return Recipe(
    id: id,
    dishId: 'dish',
    name: {'en': id},
    blurb: const {},
    contains: contains,
    ingredientIds: ingredientIds,
    attributes: attributes,
    effort: effort,
    timeMinutes: time,
    timeBucket: 'le30',
    caloriesPerServing: calories,
    calorieBucket: 'le600',
    servings: 2,
    cuisine: 'test',
    mealTypes: const {'dinner'},
    technique: const {},
    tags: const {},
    stripeColors: const [],
    caption: const {},
    ingredients: const [],
    steps: const [],
    nutrition: const Nutrition(),
  );
}

IngredientTree tree() => IngredientTree.fromJson(const {
      'tree': [
        {
          'id': 'produce',
          'name': {'en': 'Produce'},
          'children': [
            {'id': 'produce.garlic', 'name': {'en': 'garlic'}},
            {'id': 'produce.onion', 'name': {'en': 'onion'}},
          ],
        },
        {
          'id': 'nuts',
          'name': {'en': 'Nuts'},
          'children': [
            {
              'id': 'nuts.tree-nuts',
              'name': {'en': 'tree nuts'},
              'children': [
                {'id': 'nuts.tree-nuts.walnuts', 'name': {'en': 'walnuts'}},
                {'id': 'nuts.tree-nuts.almonds', 'name': {'en': 'almonds'}},
              ],
            },
            {'id': 'nuts.peanuts', 'name': {'en': 'peanuts'}},
          ],
        },
      ]
    });

const baseProfile = Profile();

void main() {
  group('Matcher.evaluate — the pure formula', () {
    final matcher = engine.Matcher(ingredientTree: tree());

    test('visible when nothing conflicts', () {
      final r = recipe();
      final result = matcher.evaluate(r, baseProfile);
      expect(result.visible, isTrue);
      expect(result.failures, isEmpty);
    });

    test('excluded when contains intersects avoid_flags', () {
      final r = recipe(contains: {'dairy'});
      final p = baseProfile.copyWith(avoidFlags: {'dairy'});
      final result = matcher.evaluate(r, p);
      expect(result.visible, isFalse);
      expect(result.failedFlag('dairy'), isTrue);
    });

    test('visible when avoid_flags does not intersect', () {
      final r = recipe(contains: {'egg'});
      final p = baseProfile.copyWith(avoidFlags: {'dairy', 'pork'});
      expect(matcher.evaluate(r, p).visible, isTrue);
    });

    test('excluded when an avoided ingredient appears', () {
      final r = recipe(ingredientIds: ['produce.garlic']);
      final p = baseProfile.copyWith(avoidIngredients: {'produce.garlic'});
      expect(matcher.evaluate(r, p).visible, isFalse);
    });

    test('avoidance propagates down the ingredient tree', () {
      final r = recipe(ingredientIds: ['nuts.tree-nuts.walnuts']);
      final p = baseProfile.copyWith(avoidIngredients: {'nuts'});
      expect(matcher.evaluate(r, p).visible, isFalse);
    });

    test('avoiding a parent excludes all descendants', () {
      final r = recipe(ingredientIds: ['nuts.tree-nuts.almonds']);
      final p = baseProfile.copyWith(avoidIngredients: {'nuts.tree-nuts'});
      expect(matcher.evaluate(r, p).visible, isFalse);
    });

    test('avoiding a leaf does not exclude the parent', () {
      final r = recipe(ingredientIds: ['nuts.tree-nuts.walnuts']);
      final p = baseProfile.copyWith(avoidIngredients: {'nuts.tree-nuts.almonds'});
      expect(matcher.evaluate(r, p).visible, isTrue);
    });

    test('required attributes must be a subset of recipe attributes', () {
      final r = recipe(attributes: {'halal-compatible'});
      final p = baseProfile.copyWith(requiredAttributes: {'halal-compatible'});
      expect(matcher.evaluate(r, p).visible, isTrue);

      final p2 = baseProfile.copyWith(requiredAttributes: {'kosher-compatible'});
      expect(matcher.evaluate(r, p2).visible, isFalse);
    });

    test('time budget is a hard filter', () {
      final r = recipe(time: 45);
      final p = baseProfile.copyWith(maxTimeMinutes: 30);
      final result = matcher.evaluate(r, p);
      expect(result.visible, isFalse);
      expect(result.failedTime, isTrue);
    });

    test('calorie target is a hard filter with tolerance', () {
      final r = recipe(calories: 700);
      final p = baseProfile.copyWith(calorieTarget: 600, calorieTolerance: 150);
      expect(matcher.evaluate(r, p).visible, isTrue);

      final r2 = recipe(calories: 900);
      expect(matcher.evaluate(r2, p).visible, isFalse);
    });

    test('calorie override bypasses the calorie filter only', () {
      final r = recipe(calories: 900, time: 90);
      final p = baseProfile.copyWith(
        calorieTarget: 600,
        calorieTolerance: 150,
        maxTimeMinutes: 30,
      );
      expect(matcher.evaluate(r, p).visible, isFalse);
      expect(
        matcher.evaluate(r, p, overrideCalories: true).visible,
        isFalse, // time still blocks
      );

      final r2 = recipe(calories: 900, time: 20);
      expect(
        matcher.evaluate(r2, p, overrideCalories: true).visible,
        isTrue,
      );
    });
  });

  group('Matcher.score — preference ordering', () {
    final matcher = engine.Matcher(ingredientTree: tree());

    test('required attributes exclude non-matching variants', () {
      final withAttr =
          recipe(id: 'a', attributes: {'halal-compatible'}, calories: 600);
      final withoutAttr = recipe(id: 'b', calories: 600);
      final p = baseProfile.copyWith(
        requiredAttributes: {'halal-compatible'},
        calorieTarget: 600,
        calorieTolerance: 100,
      );
      // withoutAttr fails the required attribute → invisible
      expect(matcher.evaluate(withoutAttr, p).visible, isFalse);
      // withAttr passes everything → chosen
      final best = matcher.bestVariant([withAttr, withoutAttr], p);
      expect(best!.id, 'a');
    });

    test('effort match beats time closeness', () {
      final r1 = recipe(id: 'a', effort: 'easy', time: 60, calories: 600);
      final r2 = recipe(id: 'b', effort: 'hard', time: 30, calories: 600);
      final p = baseProfile.copyWith(preferredEffort: 'easy', maxTimeMinutes: 120);
      final best = matcher.bestVariant([r1, r2], p);
      expect(best!.id, 'a');
    });

    test('closer calories win when effort matches', () {
      final r1 = recipe(id: 'a', effort: 'easy', calories: 640);
      final r2 = recipe(id: 'b', effort: 'easy', calories: 585);
      final p = baseProfile.copyWith(
        preferredEffort: 'easy',
        calorieTarget: 600,
        calorieTolerance: 150,
      );
      final best = matcher.bestVariant([r1, r2], p);
      expect(best!.id, 'b');
    });

    test('invisible variants are never picked', () {
      final hidden = recipe(contains: {'pork'});
      final visible = recipe(id: 'b');
      final p = baseProfile.copyWith(avoidFlags: {'pork'});
      final best = matcher.bestVariant([hidden, visible], p);
      expect(best!.id, 'b');
    });
  });

  group('Matcher.filter', () {
    final matcher = engine.Matcher(ingredientTree: tree());

    test('filters list by profile', () {
      final r1 = recipe(id: 'a');
      final r2 = recipe(id: 'b', contains: {'gluten'});
      final p = baseProfile.copyWith(avoidFlags: {'gluten'});
      final visible = matcher.filter([r1, r2], p);
      expect(visible.map((r) => r.id), ['a']);
    });
  });
}
