import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/l10n.dart';
import 'package:morphcook/data/models.dart';
import 'package:morphcook/domain/shopping.dart';

IngredientDictionary _dictionary() => IngredientDictionary.fromJson({
      'aisles': [
        {
          'id': 'produce',
          'name': {'en': 'produce', 'de': 'Gemüse'},
          'order': 0
        },
        {
          'id': 'pantry',
          'name': {'en': 'pantry', 'de': 'Vorrat'},
          'order': 1
        },
      ],
      'tree': [
        {
          'id': 'garlic',
          'name': {'en': 'garlic', 'de': 'Knoblauch'},
          'aisle': 'produce',
          'form': 'count',
        },
        {
          'id': 'olive-oil',
          'name': {'en': 'olive oil', 'de': 'Olivenöl'},
          'aisle': 'pantry',
          'form': 'liquid',
        },
        {
          'id': 'soy-sauce',
          'name': {'en': 'soy sauce', 'de': 'Sojasauce'},
          'aisle': 'pantry',
          'form': 'liquid',
        },
        {
          'id': 'rice',
          'name': {'en': 'rice', 'de': 'Reis'},
          'aisle': 'pantry',
          'form': 'solid',
        },
      ],
    });

void main() {
  final aggregator = ShoppingAggregator(_dictionary());

  group('unit-aware aggregation', () {
    test('same unit sums: 2 cloves + 3 cloves = 5 cloves', () {
      final items = aggregator.aggregate([
        (id: 'garlic', qty: 2, unit: 'clove'),
        (id: 'garlic', qty: 3, unit: 'clove'),
      ]);
      expect(items, hasLength(1));
      expect(items.first.qty, 5);
      expect(items.first.unit, 'clove');
    });

    test('ml and tbsp convert for liquids', () {
      final items = aggregator.aggregate([
        (id: 'olive-oil', qty: 30, unit: 'ml'),
        (id: 'olive-oil', qty: 2, unit: 'tbsp'),
      ]);
      expect(items, hasLength(1));
      expect(items.first.unit, 'ml');
      expect(items.first.qty, 30 + 2 * tbspInMl); // 60 ml
    });

    test('tsp converts to ml too', () {
      final items = aggregator.aggregate([
        (id: 'soy-sauce', qty: 3, unit: 'tsp'),
      ]);
      expect(items.single.qty, 3 * tspInMl);
      expect(items.single.unit, 'ml');
    });

    test('solid ingredients keep mass units', () {
      final items = aggregator.aggregate([
        (id: 'rice', qty: 150, unit: 'g'),
        (id: 'rice', qty: 0.2, unit: 'kg'),
      ]);
      expect(items.single.qty, 350);
      expect(items.single.unit, 'g');
    });

    test('large gram totals roll up to kg', () {
      final items = aggregator.aggregate([
        (id: 'rice', qty: 800, unit: 'g'),
        (id: 'rice', qty: 400, unit: 'g'),
      ]);
      expect(items.single.qty, 1.2);
      expect(items.single.unit, 'kg');
    });

    test('different count units stay separate lines', () {
      final items = aggregator.aggregate([
        (id: 'garlic', qty: 2, unit: 'clove'),
        (id: 'garlic', qty: 1, unit: 'piece'),
      ]);
      expect(items, hasLength(2));
    });

    test('different ingredients never merge', () {
      final items = aggregator.aggregate([
        (id: 'garlic', qty: 2, unit: 'clove'),
        (id: 'rice', qty: 100, unit: 'g'),
      ]);
      expect(items, hasLength(2));
    });
  });

  group('aisle grouping', () {
    test('groups by aisle in dictionary order', () {
      final items = aggregator.aggregate([
        (id: 'rice', qty: 100, unit: 'g'),
        (id: 'garlic', qty: 2, unit: 'clove'),
        (id: 'olive-oil', qty: 15, unit: 'ml'),
      ]);
      final groups = aggregator.groupByAisle(items);
      expect(groups.map((g) => g.aisle.id).toList(),
          ['produce', 'pantry']);
      expect(groups[0].items.single.ingredientId, 'garlic');
      expect(groups[1].items.length, 2);
    });
  });

  group('insights', () {
    final events = [
      ShoppingEvent(
          ingredientId: 'garlic', at: DateTime(2026, 6, 1)),
      ShoppingEvent(
          ingredientId: 'garlic', at: DateTime(2026, 6, 8)),
      ShoppingEvent(
          ingredientId: 'rice', at: DateTime(2026, 7, 2)),
      ShoppingEvent(
          ingredientId: 'olive-oil', at: DateTime(2026, 7, 3)),
    ];

    test('variety score counts unique ingredients', () {
      expect(ShoppingInsights.varietyScore(events), 3);
    });

    test('top ingredients are frequency-ordered', () {
      final top = ShoppingInsights.topIngredients(events);
      expect(top.first.ingredientId, 'garlic');
      expect(top.first.count, 2);
    });

    test('monthly breakdown groups by yyyy-MM', () {
      final months = ShoppingInsights.byMonth(events);
      expect(months.map((m) => m.month).toList(), ['2026-06', '2026-07']);
      expect(months[0].count, 2);
      expect(months[1].count, 2);
    });
  });

  test('itemName resolves localized dictionary names', () {
    final item =
        ShoppingItem(ingredientId: 'garlic', qty: 2, unit: 'clove');
    expect(aggregator.itemName(item, AppLang.en), 'garlic');
    expect(aggregator.itemName(item, AppLang.de), 'Knoblauch');
  });
}
