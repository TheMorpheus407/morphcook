import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/insights.dart';
import 'package:morphcook/logic/quantities.dart';
import 'package:morphcook/logic/shopping.dart';
import 'package:morphcook/models/localized.dart';
import 'package:morphcook/models/recipe.dart';

import 'support.dart';

Recipe withIngredients(String id, int servings, List<RecipeIngredient> ings) => Recipe(
  id: id,
  dishId: 'd',
  title: LText.empty,
  blurb: LText.empty,
  note: LText.empty,
  cuisine: '',
  diet: 'classic',
  effort: 'easy',
  timeMinutes: 10,
  timeBucket: '',
  servings: servings,
  calories: 100,
  calorieBucket: '',
  protein: 0,
  carbs: 0,
  fat: 0,
  contains: const {},
  attributes: const {},
  techniques: const [],
  mealTypes: const [],
  tags: const [],
  dimensions: const {},
  ingredientIds: [for (final i in ings) i.id],
  ingredients: ings,
  steps: const [],
);

ShoppingSource src(String recipeId, int servings) =>
    ShoppingSource(id: '$recipeId-$servings', recipeId: recipeId, servings: servings, addedAt: DateTime(2026, 9, 1));

void main() {
  final c = Corpus.instance;
  final agg = ShoppingAggregator(c.ontology, c.tree);

  List<ShoppingLine> run(List<Recipe> recipes, List<ShoppingSource> sources) {
    final byId = {for (final r in recipes) r.id: r};
    return agg.aggregate(sources, (id) => byId[id]);
  }

  ShoppingLine line(List<ShoppingLine> lines, String id) => lines.singleWhere((l) => l.ingredientId == id);

  String shown(ShoppingLine l) {
    final (q, u) = agg.display(l);
    return formatAmount(q, u, c.ontology, 'en');
  }

  test('garlic 2 cloves + garlic 3 cloves = 5 cloves', () {
    final a = withIngredients('a', 2, [const RecipeIngredient(id: 'garlic', qty: 2, unit: 'clove')]);
    final b = withIngredients('b', 2, [const RecipeIngredient(id: 'garlic', qty: 3, unit: 'clove')]);
    final lines = run([a, b], [src('a', 2), src('b', 2)]);
    expect(lines, hasLength(1));
    expect(shown(line(lines, 'garlic')), '5 cloves');
    expect(line(lines, 'garlic').recipeIds, {'a', 'b'});
  });

  test('ml ↔ tbsp convert for liquids and oils', () {
    final a = withIngredients('a', 1, [const RecipeIngredient(id: 'olive-oil', qty: 2, unit: 'tbsp')]);
    final b = withIngredients('b', 1, [const RecipeIngredient(id: 'olive-oil', qty: 30, unit: 'ml')]);
    final lines = run([a, b], [src('a', 1), src('b', 1)]);
    expect(lines, hasLength(1));
    final l = line(lines, 'olive-oil');
    expect(l.total, 60); // 30 ml + 30 ml
    expect(shown(l), '4 tbsp');
  });

  test('large volumes display in ml / l', () {
    final a = withIngredients('a', 1, [const RecipeIngredient(id: 'vegetable-stock', qty: 1.2, unit: 'l')]);
    final b = withIngredients('b', 1, [const RecipeIngredient(id: 'vegetable-stock', qty: 150, unit: 'ml')]);
    expect(shown(line(run([a, b], [src('a', 1), src('b', 1)]), 'vegetable-stock')), '1.35 l');
  });

  test('mass converts g ↔ kg', () {
    final a = withIngredients('a', 1, [const RecipeIngredient(id: 'potato', qty: 800, unit: 'g')]);
    final b = withIngredients('b', 1, [const RecipeIngredient(id: 'potato', qty: 400, unit: 'g')]);
    expect(shown(line(run([a, b], [src('a', 1), src('b', 1)]), 'potato')), '1.2 kg');
  });

  test('incompatible units stay on separate lines', () {
    final a = withIngredients('a', 1, [const RecipeIngredient(id: 'tomato', qty: 2, unit: 'pc')]);
    final b = withIngredients('b', 1, [const RecipeIngredient(id: 'tomato', qty: 300, unit: 'g')]);
    final lines = run([a, b], [src('a', 1), src('b', 1)]);
    expect(lines.where((l) => l.ingredientId == 'tomato'), hasLength(2));
  });

  test('volume of solid ingredients is not converted', () {
    // cheddar is a solid: tbsp and cup must not be merged blindly
    final a = withIngredients('a', 1, [const RecipeIngredient(id: 'cheddar', qty: 2, unit: 'tbsp')]);
    final b = withIngredients('b', 1, [const RecipeIngredient(id: 'cheddar', qty: 1, unit: 'cup')]);
    expect(run([a, b], [src('a', 1), src('b', 1)]).where((l) => l.ingredientId == 'cheddar'), hasLength(2));
  });

  test('to-taste items dedupe into one line', () {
    final a = withIngredients('a', 1, [const RecipeIngredient(id: 'salt', unit: 'to-taste')]);
    final b = withIngredients('b', 1, [const RecipeIngredient(id: 'salt', unit: 'to-taste')]);
    final lines = run([a, b], [src('a', 1), src('b', 1)]);
    expect(lines, hasLength(1));
    expect(shown(lines.single), 'to taste');
  });

  test('servings scale the amounts', () {
    final r = c.r('doener-classic'); // serves 4, 600 g beef
    final lines = run([r], [src(r.id, 2)]);
    expect(line(lines, 'beef-sirloin').total, 300);
  });

  test('real recipes: garlic across two dishes sums, grouped by aisle in store order', () {
    final a = c.r('doener-classic'); // 3 cloves
    final b = c.r('chili-classic'); // 3 cloves
    final lines = run([a, b], [src(a.id, a.servings), src(b.id, b.servings)]);
    expect(shown(line(lines, 'garlic')), '6 cloves');
    final parts = agg.groupByAisle(lines, 'en');
    final order = [for (final a in c.ontology.aisles) a.id];
    final idx = parts.map((p) => order.indexOf(p.aisle)).toList();
    expect(idx, [...idx]..sort());
    expect(parts.first.aisle, 'produce');
  });

  group('formatQty', () {
    test('fractions and rounding', () {
      expect(formatQty(0.5), '½');
      expect(formatQty(1.5), '1½');
      expect(formatQty(0.25), '¼');
      expect(formatQty(2), '2');
      expect(formatQty(123, unit: 'g'), '125');
      expect(formatQty(1.25, unit: 'kg'), '1.25');
    });
  });

  group('insights', () {
    test('variety score, top ingredients, monthly breakdown', () {
      final log = [
        ShoppingLogEntry('garlic', DateTime(2026, 8, 3)),
        ShoppingLogEntry('garlic', DateTime(2026, 9, 3)),
        ShoppingLogEntry('lemon', DateTime(2026, 9, 4)),
        ShoppingLogEntry('salt', DateTime(2026, 9, 4)), // ignored
        ShoppingLogEntry('garlic', DateTime(2026, 9, 5)),
      ];
      final i = computeInsights(log);
      expect(i.varietyScore, 2);
      expect(i.totalAdded, 4);
      expect(i.top.first.ingredientId, 'garlic');
      expect(i.top.first.count, 3);
      expect(i.months.map((m) => m.month), ['2026-09', '2026-08']);
      expect(i.months.first.total, 3);
      expect(i.months.first.unique, 2);
    });

    test('empty log', () {
      expect(computeInsights(const []).isEmpty, isTrue);
    });
  });
}
