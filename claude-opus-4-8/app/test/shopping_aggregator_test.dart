import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/localized.dart';
import 'package:morphcook/logic/shopping_aggregator.dart';
import 'package:morphcook/models/ingredient_dict.dart';
import 'package:morphcook/models/recipe.dart';

LocalizedText _lt(String s) => LocalizedText({'en': s});

IngredientDict _dict() => IngredientDict([
      IngredientNode(id: 'vegetables', label: _lt('Vegetables'), children: [
        IngredientNode(id: 'garlic', label: _lt('Garlic'), children: []),
      ]),
      IngredientNode(id: 'pantry', label: _lt('Pantry'), children: [
        IngredientNode(id: 'olive-oil', label: _lt('Olive oil'), children: []),
      ]),
    ]);

Recipe _recipe(String id, int servings, List<(String, double, String)> ings) =>
    Recipe(
      id: id,
      dishId: 'd',
      name: _lt(id),
      blurb: _lt(''),
      mealType: 'lunch',
      servings: servings,
      timeMinutes: 20,
      contains: const {},
      attributes: const {},
      variantAxes: const {},
      macros: const Macros(calories: 0, protein: 0, carbs: 0, fat: 0),
      ingredients: [
        for (final (iid, qty, unit) in ings)
          RecipeIngredient(ingredientId: iid, qty: qty, unit: unit, name: _lt(iid)),
      ],
      steps: const {'en': ['s']},
      stepTimers: const [null],
    );

void main() {
  final agg = ShoppingAggregator(_dict());

  test('same-unit counts sum: garlic 2 cloves + 3 cloves = 5 cloves', () {
    final groups = agg.aggregate([
      ShoppingRequest(_recipe('a', 2, [('garlic', 2, 'clove')]), 2),
      ShoppingRequest(_recipe('b', 2, [('garlic', 3, 'clove')]), 2),
    ], AppLang.en);
    final garlic = groups
        .expand((g) => g.lines)
        .firstWhere((l) => l.ingredientId == 'garlic');
    expect(garlic.quantities, ['5 clove']);
    expect(garlic.recipeNames.length, 2);
  });

  test('compatible volume units merge: 1 tbsp + 30 ml', () {
    final groups = agg.aggregate([
      ShoppingRequest(_recipe('a', 2, [('olive-oil', 1, 'tbsp')]), 2),
      ShoppingRequest(_recipe('b', 2, [('olive-oil', 30, 'ml')]), 2),
    ], AppLang.en);
    final oil = groups
        .expand((g) => g.lines)
        .firstWhere((l) => l.ingredientId == 'olive-oil');
    // 14.7868 + 30 = 44.79 ml
    expect(oil.quantities.single, startsWith('44.79'));
    expect(oil.quantities.single, endsWith('ml'));
  });

  test('incompatible units stay as separate sub-lines', () {
    final groups = agg.aggregate([
      ShoppingRequest(_recipe('a', 2, [('garlic', 2, 'clove')]), 2),
      ShoppingRequest(_recipe('b', 2, [('garlic', 100, 'g')]), 2),
    ], AppLang.en);
    final garlic = groups
        .expand((g) => g.lines)
        .firstWhere((l) => l.ingredientId == 'garlic');
    expect(garlic.quantities.length, 2);
    expect(garlic.quantities.any((q) => q.contains('clove')), isTrue);
    expect(garlic.quantities.any((q) => q.contains('g')), isTrue);
  });

  test('servings scale quantities', () {
    final groups = agg.aggregate([
      ShoppingRequest(_recipe('a', 2, [('garlic', 2, 'clove')]), 4), // double
    ], AppLang.en);
    final garlic = groups
        .expand((g) => g.lines)
        .firstWhere((l) => l.ingredientId == 'garlic');
    expect(garlic.quantities, ['4 clove']);
  });

  test('grouped by aisle in store-walk order', () {
    final groups = agg.aggregate([
      ShoppingRequest(
          _recipe('a', 2, [('garlic', 1, 'clove'), ('olive-oil', 1, 'tbsp')]), 2),
    ], AppLang.en);
    expect(groups.map((g) => g.aisleId).toList(), ['produce', 'pantry']);
  });
}
