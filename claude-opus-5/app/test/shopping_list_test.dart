import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/collections.dart';
import 'package:morphcook/domain/units.dart';
import 'package:morphcook/services/shopping_list_service.dart';

import 'support/fixtures.dart';

void main() {
  final now = DateTime(2026, 7, 26, 12);
  late ShoppingListService service;

  setUp(() => service = ShoppingListService(testIngredients()));

  ShoppingEntry entry(
    String id,
    double? qty,
    String unit, {
    List<String> sources = const ['r1'],
  }) => ShoppingEntry(
    ingredientId: id,
    qty: qty,
    unit: unit,
    addedAt: now,
    sourceRecipeIds: sources,
  );

  group('unit arithmetic', () {
    test('cloves add to cloves', () {
      final sum = const Quantity(2, 'clove').tryAdd(const Quantity(3, 'clove'));
      expect(sum, const Quantity(5, 'clove'));
    });

    test('ml and tbsp merge into a single volume', () {
      final sum = const Quantity(15, 'ml').tryAdd(const Quantity(1, 'tbsp'));
      expect(sum?.inBaseUnits, 30);
    });

    test('tsp and tbsp merge', () {
      final sum = const Quantity(1, 'tsp').tryAdd(const Quantity(1, 'tbsp'));
      expect(sum?.inBaseUnits, 20);
    });

    test('grams and millilitres refuse to merge', () {
      expect(
        const Quantity(100, 'g').tryAdd(const Quantity(100, 'ml')),
        isNull,
      );
    });

    test('different countable units refuse to merge', () {
      expect(
        const Quantity(1, 'clove').tryAdd(const Quantity(1, 'piece')),
        isNull,
      );
    });

    test('a large mass total is expressed in kg', () {
      final sum = const Quantity(600, 'g').tryAdd(const Quantity(600, 'g'));
      expect(sum!.unit, 'kg');
      expect(sum.amount, 1.2);
    });

    test('a large volume total is expressed in litres', () {
      final sum = const Quantity(700, 'ml').tryAdd(const Quantity(500, 'ml'));
      expect(sum!.unit, 'l');
      expect(sum.amount, 1.2);
    });
  });

  group('merge', () {
    test('two recipes contributing garlic produce one line', () {
      var list = service.merge(<ShoppingEntry>[], [
        entry('garlic', 2, 'clove'),
      ]);
      list = service.merge(list, [
        entry('garlic', 3, 'clove', sources: const ['r2']),
      ]);
      expect(list, hasLength(1));
      expect(list.single.qty, 5);
      expect(list.single.unit, 'clove');
      expect(list.single.sourceRecipeIds, containsAll(<String>['r1', 'r2']));
    });

    test('re-adding the same recipe does not double the quantities', () {
      var list = service.merge(<ShoppingEntry>[], [
        entry('garlic', 2, 'clove'),
      ]);
      list = service.merge(list, [entry('garlic', 2, 'clove')]);
      expect(list.single.qty, 2);
    });

    test('incompatible units for the same ingredient stay on two entries', () {
      var list = service.merge(<ShoppingEntry>[], [
        entry('parmesan', 100, 'g'),
      ]);
      list = service.merge(list, [
        entry('parmesan', 2, 'tbsp', sources: const ['r2']),
      ]);
      expect(list, hasLength(2));
    });
  });

  group('grouping', () {
    test('lines are grouped by aisle in the dictionary order', () {
      final list = service.merge(<ShoppingEntry>[], [
        entry('parmesan', 100, 'g'),
        entry('garlic', 2, 'clove'),
        entry('olive-oil', 30, 'ml'),
      ]);
      final groups = service.group(list, 'en');
      expect(
        groups.map((g) => g.aisle),
        orderedEquals(<String>['produce', 'dairy', 'dry-goods']),
      );
    });

    test('a split-unit ingredient reports itself as split', () {
      final list = [
        entry('parmesan', 100, 'g'),
        entry('parmesan', 2, 'tbsp', sources: const ['r2']),
      ];
      final line = service.group(list, 'en').single.lines.single;
      expect(line.isSplitByUnit, isTrue);
      expect(line.format('en'), contains('+'));
    });

    test('a line counts as checked only when every entry is', () {
      final list = [
        entry('garlic', 1, 'clove').copyWith(checked: true),
        entry('garlic', 1, 'clove', sources: const ['r2']),
      ];
      expect(service.group(list, 'en').single.lines.single.checked, isFalse);
    });

    test('remaining counts unchecked lines per aisle', () {
      final list = [
        entry('garlic', 1, 'clove'),
        entry('apple', 1, 'piece').copyWith(checked: true),
      ];
      final produce = service.group(list, 'en').single;
      expect(produce.lines, hasLength(2));
      expect(produce.remaining, 1);
    });
  });

  group('entriesForRecipes', () {
    test('scales quantities to the requested servings', () {
      final recipe = makeRecipe(id: 'r', ingredientIds: {'garlic'});
      final entries = service.entriesForRecipes(
        [recipe],
        now: now,
        servingsOverride: {'r': 4},
      );
      // The fixture recipe serves 2 with 1 clove of garlic.
      expect(entries.single.qty, 2);
    });

    test('optional ingredients are skipped by default', () {
      final recipe = makeRecipe(id: 'r', ingredientIds: {'garlic'});
      expect(service.entriesForRecipes([recipe], now: now), hasLength(1));
    });
  });

  group('label formatting', () {
    test('countable units pluralise in English', () {
      expect(UnitLabels.format(const Quantity(1, 'clove'), 'en'), '1 clove');
      expect(UnitLabels.format(const Quantity(5, 'clove'), 'en'), '5 cloves');
    });

    test('countable units use the German word', () {
      expect(UnitLabels.format(const Quantity(5, 'clove'), 'de'), '5 Zehen');
    });

    test('measured units keep their symbol', () {
      expect(UnitLabels.format(const Quantity(250, 'g'), 'de'), '250 g');
    });

    test('fractional amounts round to something readable', () {
      expect(const Quantity(0.5, 'piece').formatAmount(), '0.5');
      expect(const Quantity(2.0, 'piece').formatAmount(), '2');
      expect(const Quantity(12.4, 'g').formatAmount(), '12');
    });
  });
}
