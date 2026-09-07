import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus_repository.dart';
import 'package:morphcook/data/models/ltext.dart';
import 'package:morphcook/data/models/recipe.dart';
import 'package:morphcook/data/models/shopping.dart';
import 'package:morphcook/domain/shopping_aggregator.dart';
import 'package:morphcook/domain/shopping_insights.dart';

import 'helpers.dart';

Recipe fake(String id, List<RecipeIngredient> ings, {int servings = 2}) => Recipe(
      id: id,
      dishId: 'x',
      title: const LText({'en': 't'}),
      marginNote: LText.empty,
      intro: LText.empty,
      variant: const {},
      contains: const {},
      attributes: const {},
      technique: const [],
      timeMinutes: 10,
      servings: servings,
      caloriesPerServing: 100,
      macros: const Macros(proteinG: 0, carbsG: 0, fatG: 0),
      mealTypes: const [],
      tags: const [],
      ingredients: ings,
      steps: const [],
      partitionId: 'core',
    );

void main() {
  late CorpusRepository repo;
  late ShoppingAggregator agg;
  setUpAll(() async {
    repo = await loadRepo();
    agg = ShoppingAggregator(ontology: repo.ontology, dictionary: repo.ingredients);
  });

  test('garlic 2 cloves + garlic 3 cloves = 5 cloves', () {
    final a = fake('a', const [RecipeIngredient(id: 'garlic', amount: 2, unit: 'clove')]);
    final b = fake('b', const [RecipeIngredient(id: 'garlic', amount: 3, unit: 'clove')]);
    final lines = agg.aggregate([ShoppingInput(recipe: a, servings: 2), ShoppingInput(recipe: b, servings: 2)]);
    expect(lines.length, 1);
    expect(lines.first.displayAmount, 5);
    expect(lines.first.displayUnit, 'clove');
    expect(lines.first.sourceRecipeIds, {'a', 'b'});
  });

  test('ml ↔ tbsp conversion inside the volume class', () {
    final a = fake('a', const [RecipeIngredient(id: 'olive-oil', amount: 2, unit: 'tbsp')]);
    final b = fake('b', const [RecipeIngredient(id: 'olive-oil', amount: 30, unit: 'ml')]);
    final lines = agg.aggregate([ShoppingInput(recipe: a, servings: 2), ShoppingInput(recipe: b, servings: 2)]);
    expect(lines.length, 1);
    expect(lines.first.baseAmount, 60);
    expect(lines.first.displayUnit, 'ml');
    expect(lines.first.displayAmount, 60);
  });

  test('spoon-only totals stay in spoons; large volumes become litres', () {
    final a = fake('a', const [RecipeIngredient(id: 'soy-sauce', amount: 1, unit: 'tbsp')]);
    final b = fake('b', const [RecipeIngredient(id: 'soy-sauce', amount: 2, unit: 'tsp')]);
    final lines = agg.aggregate([ShoppingInput(recipe: a, servings: 2), ShoppingInput(recipe: b, servings: 2)]);
    expect(lines.first.displayUnit, 'tbsp');
    expect(lines.first.displayAmount, closeTo(1.7, 0.01));
    final big = fake('c', const [RecipeIngredient(id: 'vegetable-stock', amount: 750, unit: 'ml'), RecipeIngredient(id: 'vegetable-stock', amount: 1, unit: 'cup')]);
    final l2 = agg.aggregate([ShoppingInput(recipe: big, servings: 4)]);
    expect(l2.first.displayUnit, 'l');
    expect(l2.first.displayAmount, closeTo(1.98, 0.01));
  });

  test('mass converts to kg over 1000 g and scales with servings', () {
    final a = fake('a', const [RecipeIngredient(id: 'ground-beef', amount: 400, unit: 'g')], servings: 2);
    final lines = agg.aggregate([ShoppingInput(recipe: a, servings: 6)]);
    expect(lines.first.displayAmount, 1.2);
    expect(lines.first.displayUnit, 'kg');
  });

  test('count units of different kinds stay separate; to-taste has no amount', () {
    final a = fake('a', const [
      RecipeIngredient(id: 'lemon', amount: 1, unit: 'piece'),
      RecipeIngredient(id: 'lemon', amount: 2, unit: 'slice'),
      RecipeIngredient(id: 'salt', amount: null, unit: 'to-taste'),
      RecipeIngredient(id: 'salt', amount: 1, unit: 'pinch'),
    ]);
    final lines = agg.aggregate([ShoppingInput(recipe: a, servings: 2)]);
    expect(lines.where((l) => l.ingredientId == 'lemon').length, 2);
    final salt = lines.where((l) => l.ingredientId == 'salt').toList();
    expect(salt.any((l) => l.displayAmount == null), isTrue);
  });

  test('lines group by aisle in ontology order', () {
    final a = fake('a', const [
      RecipeIngredient(id: 'cumin', amount: 1, unit: 'tsp'),
      RecipeIngredient(id: 'chicken-thigh', amount: 400, unit: 'g'),
      RecipeIngredient(id: 'fresh-tomato', amount: 1, unit: 'piece'),
    ]);
    final groups = agg.groupByAisle(agg.aggregate([ShoppingInput(recipe: a, servings: 2)]));
    expect(groups.map((g) => g.aisle.id), ['produce', 'meat', 'spices']);
  });

  test('real recipes aggregate without unknown units', () {
    final inputs = [for (final r in repo.loadedRecipes.take(40)) ShoppingInput(recipe: r, servings: r.servings)];
    final lines = agg.aggregate(inputs);
    expect(lines, isNotEmpty);
    for (final l in lines) {
      expect(repo.ontology.unitById.containsKey(l.displayUnit), isTrue, reason: l.displayUnit);
    }
  });

  test('formatAmount writes fractions the handwritten way', () {
    expect(formatAmount(0.5), '½');
    expect(formatAmount(1.5), '1½');
    expect(formatAmount(2), '2');
    expect(formatAmount(250), '250');
    expect(formatAmount(1.25), '1¼');
    expect(formatAmount(0.33), '⅓');
    expect(formatAmount(1.7), '1.7');
    expect(formatAmount(null), '');
  });

  test('insights: variety, top ingredients, months', () {
    final log = [
      ShoppingLogEntry(ingredientId: 'garlic', addedAt: DateTime(2026, 8, 3)),
      ShoppingLogEntry(ingredientId: 'garlic', addedAt: DateTime(2026, 8, 9)),
      ShoppingLogEntry(ingredientId: 'lemon', addedAt: DateTime(2026, 8, 9)),
      ShoppingLogEntry(ingredientId: 'garlic', addedAt: DateTime(2026, 9, 1)),
      ShoppingLogEntry(ingredientId: 'basil', addedAt: DateTime(2026, 9, 1)),
    ];
    final ins = computeInsights(log, topN: 2);
    expect(ins.totalAdds, 5);
    expect(ins.varietyScore, 3);
    expect(ins.topIngredients.map((t) => t.ingredientId), ['garlic', 'basil']);
    expect(ins.topIngredients.first.count, 3);
    expect(ins.months.map((m) => m.monthKey), ['2026-09', '2026-08']);
    expect(ins.months.last.adds, 3);
    expect(ins.months.last.uniqueIngredients, 2);
    expect(ins.since, DateTime(2026, 8, 3));
    expect(computeInsights(const []).isEmpty, isTrue);
  });
}
