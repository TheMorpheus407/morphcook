import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/engine/matching.dart';
import 'package:morphcook/core/models/dish.dart';
import 'package:morphcook/core/models/profile.dart';

import 'fixtures.dart';

void main() {
  final engine = MatchingEngine(testOntology(), testDictionary());

  group('visible()', () {
    test('passes a clean recipe with a default profile', () {
      expect(engine.visible(testRecipe(), const UserProfile()), isTrue);
    });

    test('excludes recipes whose contains-flags intersect avoid-flags', () {
      const profile = UserProfile(avoidFlags: {'dairy'});
      expect(
          engine.visible(testRecipe(contains: {'dairy'}), profile), isFalse);
      expect(
          engine.visible(testRecipe(contains: {'gluten'}), profile), isTrue);
    });

    test('expands compound flags (vegan excludes dairy + egg + honey)', () {
      const profile = UserProfile(avoidFlags: {'vegan'});
      expect(engine.visible(testRecipe(contains: {'egg'}), profile), isFalse);
      expect(
          engine.visible(testRecipe(contains: {'honey'}), profile), isFalse);
      expect(
          engine.visible(testRecipe(contains: {'gluten'}), profile), isTrue);
    });

    test('specific avoidance propagates to descendants', () {
      const profile = UserProfile(avoidIngredients: {'dairy'});
      // whole-milk is a descendant of dairy.
      expect(
          engine.visible(testRecipe(ingredientIds: ['whole-milk']), profile),
          isFalse);
      expect(engine.visible(testRecipe(ingredientIds: ['apple']), profile),
          isTrue);
    });

    test('specific avoidance of a leaf does not exclude its parent', () {
      const profile = UserProfile(avoidIngredients: {'whole-milk'});
      expect(engine.visible(testRecipe(ingredientIds: ['cheese']), profile),
          isTrue);
    });

    test('required_attributes must be a subset of recipe attributes', () {
      const profile = UserProfile(requiredAttributes: {'halal'});
      expect(
          engine.visible(
              testRecipe(attributes: {'easy', 'halal'}), profile),
          isTrue);
      expect(engine.visible(testRecipe(attributes: {'easy'}), profile),
          isFalse);
    });

    test('time budget is a hard filter', () {
      const profile = UserProfile(maxTimeMinutes: 30);
      expect(engine.visible(testRecipe(timeMinutes: 45), profile), isFalse);
      expect(engine.visible(testRecipe(timeMinutes: 30), profile), isTrue);
    });

    test('calorie target filters within tolerance (150)', () {
      const profile = UserProfile(calorieTarget: 600);
      expect(engine.visible(testRecipe(calories: 750), profile), isTrue);
      expect(engine.visible(testRecipe(calories: 751), profile), isFalse);
      expect(engine.visible(testRecipe(calories: 450), profile), isTrue);
    });

    test('per-dish override can ignore the calorie target', () {
      const profile = UserProfile(calorieTarget: 400);
      final r = testRecipe(calories: 800);
      expect(engine.visible(r, profile), isFalse);
      expect(engine.visible(r, profile, ignoreCalorieTarget: true), isTrue);
    });
  });

  group('bestVariant()', () {
    const dish = Dish(
      id: 'd1',
      name: {'en': 'döner'},
      heroText: {},
      capCaption: {},
      stripeColor: '#C4573B',
      variantIds: ['a', 'b', 'c'],
    );

    test('returns null when no variant passes', () {
      const profile = UserProfile(maxTimeMinutes: 10);
      final variants = [testRecipe(id: 'a', timeMinutes: 60)];
      expect(engine.bestVariant(dish, variants, profile), isNull);
    });

    test('prefers effort match, then calorie closeness', () {
      const profile =
          UserProfile(preferredEffort: 'hard', calorieTarget: 600);
      final easy = testRecipe(id: 'a', effort: 'easy', calories: 590);
      final hard = testRecipe(id: 'b', effort: 'hard', calories: 700);
      final best = engine.bestVariant(dish, [easy, hard], profile);
      expect(best?.id, 'b');
    });

    test('ignores variants of other dishes', () {
      final other = testRecipe(id: 'x', dishId: 'other');
      final own = testRecipe(id: 'a');
      expect(engine.bestVariant(dish, [other, own], const UserProfile())?.id,
          'a');
    });
  });

  group('contextBonus()', () {
    test('breakfast bonus 5am–11am', () {
      final r = testRecipe(mealTypes: ['breakfast']);
      final morning = DateTime(2026, 7, 20, 8);
      final noon = DateTime(2026, 7, 20, 12);
      expect(engine.contextBonus(r, morning, null) >= 200, isTrue);
      expect(engine.contextBonus(r, noon, null) < 200, isTrue);
    });

    test('dinner bonus 5pm–9pm', () {
      final r = testRecipe(mealTypes: ['dinner']);
      final evening = DateTime(2026, 7, 20, 19); // monday
      expect(engine.contextBonus(r, evening, null) >= 90, isTrue);
    });

    test('weekend bonus for medium/hard effort', () {
      final hard = testRecipe(effort: 'hard');
      final easy = testRecipe(effort: 'easy');
      final saturday = DateTime(2026, 7, 25, 12);
      final monday = DateTime(2026, 7, 20, 12);
      expect(engine.contextBonus(hard, saturday, null) >= 90, isTrue);
      expect(
          engine.contextBonus(easy, saturday, null) <
              engine.contextBonus(hard, saturday, null),
          isTrue);
      expect(engine.contextBonus(hard, monday, null),
          engine.contextBonus(easy, monday, null));
    });

    test('staleness bonus for recipes not cooked in 30+ days', () {
      final r = testRecipe();
      final now = DateTime(2026, 7, 20, 12, 0, 0);
      final old =
          now.subtract(const Duration(days: 45)).millisecondsSinceEpoch;
      final recent =
          now.subtract(const Duration(days: 5)).millisecondsSinceEpoch;
      final base = engine.contextBonus(r, now, null);
      expect(engine.contextBonus(r, now, old) - base, 50);
      expect(engine.contextBonus(r, now, recent) - base, 0);
    });
  });

  group('rankVisible()', () {
    test('orders by score desc and drops invisible recipes', () {
      const profile = UserProfile(calorieTarget: 600);
      final close = testRecipe(id: 'close', calories: 600);
      final far = testRecipe(id: 'far', calories: 700);
      final out = testRecipe(id: 'out', calories: 900);
      final ranked = engine.rankVisible([far, out, close], profile,
          now: DateTime(2026, 7, 20, 12));
      expect(ranked.map((r) => r.id).toList(), ['close', 'far']);
    });
  });
}
