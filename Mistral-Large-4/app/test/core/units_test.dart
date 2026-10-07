import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/model/localized.dart';
import 'package:morphcook/core/model/recipe.dart';
import 'package:morphcook/core/units.dart';

void main() {
  group('Units.familyOf', () {
    test('mass family', () {
      expect(Units.familyOf('g'), UnitFamily.mass);
      expect(Units.familyOf('kg'), UnitFamily.mass);
    });

    test('volume family', () {
      expect(Units.familyOf('ml'), UnitFamily.volume);
      expect(Units.familyOf('l'), UnitFamily.volume);
      expect(Units.familyOf('tbsp'), UnitFamily.volume);
      expect(Units.familyOf('tsp'), UnitFamily.volume);
    });

    test('count family', () {
      for (final u in [
        'clove', 'cloves', 'piece', 'pieces', 'slice', 'slices',
        'pinch', 'bunch', 'can', 'cans', 'pack', 'packs',
      ]) {
        expect(Units.familyOf(u), UnitFamily.count, reason: u);
      }
    });

    test('unknown units are "other" and never convert', () {
      expect(Units.familyOf('sheet'), UnitFamily.other);
      expect(Units.familyOf('to-taste'), UnitFamily.other);
      expect(Units.convertible('sheet', 'sheets'), false);
      expect(Units.convertible('g', 'sheet'), false);
    });
  });

  group('Units.convertible', () {
    test('same unit and same family convert', () {
      expect(Units.convertible('g', 'g'), true);
      expect(Units.convertible('g', 'kg'), true);
      expect(Units.convertible('ml', 'tbsp'), true);
      expect(Units.convertible('tsp', 'ml'), true);
      expect(Units.convertible('cloves', 'pieces'), true);
    });

    test('cross-family never converts', () {
      expect(Units.convertible('g', 'ml'), false);
      expect(Units.convertible('cloves', 'g'), false);
      expect(Units.convertible('tbsp', 'kg'), false);
    });
  });

  group('Units.convert', () {
    test('identity returns the amount', () {
      expect(Units.convert(2.5, 'g', 'g'), 2.5);
    });

    test('mass conversions', () {
      expect(Units.convert(1, 'kg', 'g'), 1000);
      expect(Units.convert(500, 'g', 'kg'), 0.5);
    });

    test('volume conversions (1 tbsp = 15 ml, 1 tsp = 5 ml)', () {
      expect(Units.convert(1, 'l', 'ml'), 1000);
      expect(Units.convert(2, 'tbsp', 'ml'), 30);
      expect(Units.convert(3, 'tsp', 'ml'), 15);
      expect(Units.convert(45, 'ml', 'tbsp'), 3);
      expect(Units.convert(1, 'tbsp', 'tsp'), 3);
    });

    test('count units convert 1:1 within the family', () {
      expect(Units.convert(2, 'cloves', 'pieces'), 2);
      expect(Units.convert(3, 'can', 'cans'), 3);
    });

    test('incompatible units throw ArgumentError', () {
      expect(() => Units.convert(100, 'g', 'ml'), throwsArgumentError);
      expect(() => Units.convert(1, 'cloves', 'kg'), throwsArgumentError);
      expect(() => Units.convert(1, 'sheet', 'sheets'), throwsArgumentError);
    });
  });

  group('Units display formatting', () {
    test('large masses upgrade to kg, large volumes to l', () {
      expect(Units.displayUnit(1500, 'g'), 'kg');
      expect(Units.displayAmount(1500, 'g'), 1.5);
      expect(Units.displayUnit(1200, 'ml'), 'l');
      expect(Units.displayAmount(1200, 'ml'), 1.2);
      expect(Units.displayUnit(999, 'g'), 'g');
      expect(Units.displayUnit(999, 'ml'), 'ml');
      expect(Units.displayUnit(5, 'cloves'), 'cloves');
    });

    test('formatAmount renders integers, halves and quarters', () {
      expect(Units.formatAmount(2), '2');
      expect(Units.formatAmount(0.5), '½');
      expect(Units.formatAmount(1.5), '1½');
      expect(Units.formatAmount(0.25), '¼');
      expect(Units.formatAmount(1.75), '1¾');
      expect(Units.formatAmount(2.3), '2.3');
    });

    test('format combines amount and display unit', () {
      expect(Units.format(1500, 'g'), '1.5 kg');
      expect(Units.format(2, 'cloves'), '2 cloves');
      expect(Units.format(0.5, 'tsp'), '½ tsp');
    });
  });

  group('ShoppingAggregator', () {
    const agg = ShoppingAggregator();
    final at = DateTime.utc(2026, 10, 7);

    test('garlic 2 cloves + garlic 3 cloves = 5 cloves', () {
      final items = agg.aggregate([
        (ingredientId: 'garlic', amount: 2, unit: 'cloves', recipeId: 'a'),
        (ingredientId: 'garlic', amount: 3, unit: 'cloves', recipeId: 'b'),
      ], addedAt: at);
      expect(items.length, 1);
      expect(items.first.ingredientId, 'garlic');
      expect(items.first.amount, 5);
      expect(items.first.unit, 'cloves');
      expect(items.first.sourceRecipeIds, ['a', 'b']);
    });

    test('ml ↔ tbsp conversion merges into the first unit', () {
      final items = agg.aggregate([
        (ingredientId: 'oil', amount: 100, unit: 'ml', recipeId: null),
        (ingredientId: 'oil', amount: 2, unit: 'tbsp', recipeId: null), // 30 ml
      ], addedAt: at);
      expect(items.length, 1);
      expect(items.first.amount, 130);
      expect(items.first.unit, 'ml');
    });

    test('kg and g merge and upgrade to kg for display', () {
      final items = agg.aggregate([
        (ingredientId: 'flour', amount: 1.2, unit: 'kg', recipeId: null),
        (ingredientId: 'flour', amount: 500, unit: 'g', recipeId: null),
      ], addedAt: at);
      expect(items.length, 1);
      expect(items.first.amount, 1.7);
      expect(items.first.unit, 'kg');
    });

    test('incompatible units keep the larger line and its unit', () {
      final items = agg.aggregate([
        (ingredientId: 'mystery', amount: 100, unit: 'ml', recipeId: null),
        (ingredientId: 'mystery', amount: 250, unit: 'g', recipeId: null),
      ], addedAt: at);
      expect(items.length, 1);
      expect(items.first.amount, 250);
      expect(items.first.unit, 'g');
    });

    test('different ingredients stay separate, in first-seen order', () {
      final items = agg.aggregate([
        (ingredientId: 'lamb', amount: 300, unit: 'g', recipeId: null),
        (ingredientId: 'garlic', amount: 2, unit: 'cloves', recipeId: null),
        (ingredientId: 'lamb', amount: 100, unit: 'g', recipeId: null),
      ], addedAt: at);
      expect(items.map((i) => i.ingredientId), ['lamb', 'garlic']);
      expect(items.first.amount, 400);
    });

    test('linesFromRecipe scales by the servings factor', () {
      final r = Recipe(
        id: 'r',
        dishId: 'd',
        title: const LocalizedText({'en': 't'}),
        subtitle: const LocalizedText({'en': 's'}),
        diet: 'classic',
        effort: 'easy',
        timeMinutes: 10,
        caloriesPerServing: 500,
        servings: 2,
        contains: const {},
        attributes: const {},
        tags: const [],
        mealType: 'lunch',
        ingredients: [
          const IngredientLine(ingredientId: 'lamb', amount: 300, unit: 'g'),
          const IngredientLine(ingredientId: 'garlic', amount: 2, unit: 'cloves'),
        ],
        steps: const [CookStep(text: LocalizedText({'en': 'cook'}))],
        macros: const Macros(kcal: 500, proteinG: 30, carbsG: 40, fatG: 15),
      );
      final lines = agg.linesFromRecipe(r, 4); // double the servings
      expect(lines.length, 2);
      expect(lines[0].amount, 600);
      expect(lines[1].amount, 4);
      expect(lines.every((l) => l.recipeId == 'r'), true);
    });
  });
}
