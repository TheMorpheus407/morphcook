import 'package:flutter_test/flutter_test.dart';

import 'package:morphcook/core/models/recipe.dart';
import 'package:morphcook/core/shopping/aggregator.dart';
import 'package:morphcook/core/shopping/insights.dart';
import 'package:morphcook/core/shopping/units.dart';

Recipe _recipe(String id, List<Map<String, Object>> ingredients) =>
    Recipe.fromMap({
      'id': id,
      'dish': 'test',
      'title': {'en': id, 'de': id},
      'diet': 'classic',
      'effort': 'easy',
      'time': 10,
      'cal': 100,
      'p': 1,
      'c': 1,
      'f': 1,
      'servings': 2,
      'contains': [],
      'attr': [],
      'tech': [],
      'ing': ingredients,
      'steps': [
        {'t': {'en': 'x', 'de': 'x'}}
      ],
    });

void main() {
  test('converts between compatible volume units (ml ↔ tbsp, SPEC)', () {
    final tbsp = convertUnit(1, 'tbsp', 'ml')!;
    expect(tbsp, closeTo(14.7868, 0.001));
    final back = convertUnit(tbsp, 'ml', 'tbsp')!;
    expect(back, closeTo(1, 0.0001));
    final tsp = convertUnit(3, 'tsp', 'tbsp')!;
    expect(tsp, closeTo(1, 0.001));
  });

  test('refuses conversion across families', () {
    expect(convertUnit(100, 'g', 'ml'), isNull);
    expect(convertUnit(2, 'clove', 'tbsp'), isNull);
  });

  test('formatAmount picks friendly display units', () {
    expect(formatAmount(1250, 'g'), '1.25 kg');
    expect(formatAmount(850, 'ml'), '850 ml');
    expect(formatAmount(29.57, 'ml'), '2 tbsp');
    expect(formatAmount(9.86, 'ml'), '2 tsp');
    expect(formatAmount(3, 'clove'), '3 clove');
  });

  test('formatQty trims trailing zeros', () {
    expect(formatQty(2), '2');
    expect(formatQty(2.5), '2.5');
    expect(formatQty(0.25), '0.25');
  });

  test('SPEC example: garlic 2 cloves + 3 cloves = 5 cloves', () {
    final items = ShoppingAggregator.aggregate([
      _recipe('a', [
        {'id': 'garlic', 'q': 2, 'u': 'clove'},
      ]),
      _recipe('b', [
        {'id': 'garlic', 'q': 3, 'u': 'clove'},
      ]),
    ]);
    final garlic = items.singleWhere((i) => i.ingredientId == 'garlic');
    expect(garlic.display(), '5 clove');
  });

  test('aggregates mass across recipes and merges units per family', () {
    final items = ShoppingAggregator.aggregate([
      _recipe('a', [
        {'id': 'ground-beef', 'q': 250, 'u': 'g'},
        {'id': 'olive-oil', 'q': 1, 'u': 'tbsp'},
      ]),
      _recipe('b', [
        {'id': 'ground-beef', 'q': 400, 'u': 'g'},
        {'id': 'olive-oil', 'q': 2, 'u': 'tbsp'},
      ]),
    ]);
    final beef = items.singleWhere((i) => i.ingredientId == 'ground-beef');
    expect(beef.display(), '650 g');
    final oil = items.singleWhere((i) => i.ingredientId == 'olive-oil');
    expect(oil.display(), '3 tbsp'); // 3 tbsp ≈ 44.36 ml → 3 tbsp
  });

  test('incompatible count units stay separate lines ("2 cloves + 1 tsp")', () {
    final items = ShoppingAggregator.aggregate([
      _recipe('a', [
        {'id': 'garlic', 'q': 2, 'u': 'clove'},
        {'id': 'garlic', 'q': 1, 'u': 'tsp'},
      ]),
    ]);
    final garlic = items.single;
    expect(garlic.lines.length, 2);
    expect(garlic.display(), '2 clove + 1 tsp');
  });

  test('dedups ingredients across recipes', () {
    final items = ShoppingAggregator.aggregate([
      _recipe('a', [
        {'id': 'onion', 'q': 1, 'u': 'pc'},
      ]),
      _recipe('b', [
        {'id': 'onion', 'q': 1, 'u': 'pc'},
      ]),
    ]);
    expect(items.length, 1);
    expect(items.single.display(), '2 pc');
  });

  test('mergeInto preserves checked state and sums quantities', () {
    final existing = ShoppingAggregator.aggregate([
      _recipe('a', [
        {'id': 'garlic', 'q': 2, 'u': 'clove'},
      ]),
    ]);
    existing.single.checked = true;
    final incoming = ShoppingAggregator.aggregate([
      _recipe('b', [
        {'id': 'garlic', 'q': 3, 'u': 'clove'},
        {'id': 'tofu', 'q': 200, 'u': 'g'},
      ]),
    ]);
    final merged = ShoppingAggregator.mergeInto(existing, incoming);
    final garlic = merged.singleWhere((i) => i.ingredientId == 'garlic');
    expect(garlic.checked, isTrue);
    expect(garlic.display(), '5 clove');
    expect(merged.any((i) => i.ingredientId == 'tofu'), isTrue);
  });

  test('items round-trip through json', () {
    final items = ShoppingAggregator.aggregate([
      _recipe('a', [
        {'id': 'garlic', 'q': 2, 'u': 'clove'},
        {'id': 'rice', 'q': 300, 'u': 'g'},
      ]),
    ]);
    final restored =
        items.map((i) => ShoppingItem.fromJson(i.toJson())).toList();
    expect(restored.first.display(), items.first.display());
    expect(restored.first.lines.length, items.first.lines.length);
  });

  test('insights compute variety, top frequencies and seasonality', () {
    final additions = [
      ShoppingAddition(
          at: DateTime(2026, 7, 2),
          ingredientIds: ['garlic', 'onion', 'rice']),
      ShoppingAddition(
          at: DateTime(2026, 7, 9),
          ingredientIds: ['garlic', 'onion']),
      ShoppingAddition(
          at: DateTime(2026, 3, 3),
          ingredientIds: ['tofu']),
    ];
    final insights = ShoppingInsights.fromAdditions(additions);
    expect(insights.varietyScore, 4);
    expect(insights.topIngredients.first.ingredientId, 'garlic');
    expect(insights.topIngredients.first.count, 2);
    expect(insights.seasonal[6], 2); // july
    expect(insights.seasonal[2], 1); // march
    expect(insights.seasonal[0], 0); // january
  });
}
