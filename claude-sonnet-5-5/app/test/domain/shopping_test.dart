import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/domain/shopping/aggregator.dart';
import 'package:morphcook/domain/shopping/amounts.dart';
import 'package:morphcook/domain/shopping/insights.dart';

import '../support/fixtures.dart';

void main() {
  late Corpus corpus;
  late ShoppingAggregator aggregator;

  setUpAll(() async {
    corpus = await loadCorpus();
    aggregator = ShoppingAggregator(corpus.ontology, corpus.ingredients);
  });

  ShoppingSource source(String id, List<(String, double?, String)> lines, {int servings = 2, double? cookFor}) {
    return ShoppingSource(
      recipe: recipeFixture(id: id, servings: servings, ingredients: [for (final l in lines) line(l.$1, l.$2, l.$3)]),
      servings: cookFor ?? servings.toDouble(),
    );
  }

  ShoppingLine only(List<ShoppingLine> lines, String ingredientId) =>
      lines.singleWhere((l) => l.ingredientId == ingredientId);

  group('amount formatting', () {
    test('spoons, cups and counts use kitchen fractions', () {
      expect(AmountFormatter.format(1.5, 'tbsp', 'en'), '1½');
      expect(AmountFormatter.format(0.25, 'tsp', 'en'), '¼');
      expect(AmountFormatter.format(0.5, 'piece', 'en'), '½');
      expect(AmountFormatter.format(2.75, 'cup', 'en'), '2¾');
      expect(AmountFormatter.format(0.333, 'cup', 'en'), '⅓');
      expect(AmountFormatter.format(2, 'clove', 'en'), '2');
    });

    test('grams and millilitres round like a cook would', () {
      expect(AmountFormatter.format(187.5, 'g', 'en'), '190');
      expect(AmountFormatter.format(203, 'g', 'en'), '205');
      expect(AmountFormatter.format(45.4, 'ml', 'en'), '45');
      expect(AmountFormatter.format(7.46, 'g', 'en'), '7.5');
      expect(AmountFormatter.format(1.25, 'kg', 'en'), '1.25');
    });

    test('German uses the decimal comma', () {
      expect(AmountFormatter.format(7.5, 'g', 'de'), '7,5');
      expect(AmountFormatter.format(1.25, 'kg', 'de'), '1,25');
      expect(AmountFormatter.format(120, 'g', 'de'), '120');
    });

    test('roundFor leaves counts alone', () {
      expect(AmountFormatter.roundFor(2.5, 'clove'), 2.5);
      expect(AmountFormatter.isNice(2.25), isTrue);
      expect(AmountFormatter.isNice(2.3), isFalse);
    });
  });

  group('unit-aware aggregation', () {
    test('garlic 2 cloves + garlic 3 cloves = 5 cloves', () {
      final lines = aggregator.aggregate([
        source('a', [('garlic', 2, 'clove')]),
        source('b', [('garlic', 3, 'clove')]),
      ]);
      final garlic = only(lines, 'garlic');
      expect(garlic.quantities, [const Quantity(5, 'clove')]);
      expect(garlic.amountText(corpus.ontology, corpus.ingredients, 'en'), '5 cloves');
      expect(garlic.amountText(corpus.ontology, corpus.ingredients, 'de'), '5 Zehen');
      expect(garlic.recipeIds, {'a', 'b'});
    });

    test('a single clove reads in the singular', () {
      final lines = aggregator.aggregate([
        source('a', [('garlic', 1, 'clove')]),
      ]);
      expect(only(lines, 'garlic').amountText(corpus.ontology, corpus.ingredients, 'en'), '1 clove');
    });

    test('ml and tbsp convert into one volume', () {
      final lines = aggregator.aggregate([
        source('a', [('olive-oil', 2, 'tbsp')]),
        source('b', [('olive-oil', 30, 'ml')]),
      ]);
      expect(only(lines, 'olive-oil').quantities, [const Quantity(60, 'ml')]);
    });

    test('kitchen units stay in kitchen units', () {
      var lines = aggregator.aggregate([
        source('a', [('olive-oil', 1, 'tbsp')]),
        source('b', [('olive-oil', 3, 'tsp')]),
      ]);
      expect(only(lines, 'olive-oil').quantities, [const Quantity(2, 'tbsp')]);

      lines = aggregator.aggregate([
        source('a', [('olive-oil', 2, 'tbsp')]),
        source('b', [('olive-oil', 1, 'tsp')]),
      ]);
      expect(only(lines, 'olive-oil').quantities, [const Quantity(7, 'tsp')]);
    });

    test('tsp and cup merge as volume as well', () {
      final lines = aggregator.aggregate([
        source('a', [('olive-oil', 1, 'cup')]),
        source('b', [('olive-oil', 8, 'tsp')]),
      ]);
      // 240 ml + 40 ml = 280 ml; the largest unit that reads naturally is 1 1/6 cup: not nice, so tsp.
      expect(only(lines, 'olive-oil').quantities.single.unit, 'tsp');
      expect(only(lines, 'olive-oil').quantities.single.amount, closeTo(56, 1e-9));
    });

    test('grams add up and switch to kilograms past 1000', () {
      final lines = aggregator.aggregate([
        source('a', [('wheat-flour', 500, 'g')]),
        source('b', [('wheat-flour', 0.7, 'kg')]),
      ]);
      final flour = only(lines, 'wheat-flour');
      expect(flour.quantities.single.unit, 'kg');
      expect(flour.quantities.single.amount, closeTo(1.2, 1e-9));
    });

    test('mass and volume merge when the ingredient has a known density', () {
      expect(corpus.ingredients.densityOf('whole-milk'), isNotNull);
      final lines = aggregator.aggregate([
        source('a', [('whole-milk', 200, 'g')]),
        source('b', [('whole-milk', 100, 'ml')]),
      ]);
      final milk = only(lines, 'whole-milk');
      expect(milk.quantities, hasLength(1));
      expect(milk.quantities.single.unit, 'g');
      expect(milk.quantities.single.amount, closeTo(200 + 100 * corpus.ingredients.densityOf('whole-milk')!, 1e-9));
    });

    test('mass and volume stay separate without a density', () {
      final id = corpus.ingredients.all
          .firstWhere((n) => corpus.ingredients.densityOf(n.id) == null && corpus.ingredients.isLeaf(n.id))
          .id;
      final lines = aggregator.aggregate([
        source('a', [(id, 100, 'g')]),
        source('b', [(id, 2, 'tbsp')]),
      ]);
      expect(only(lines, id).quantities, hasLength(2));
    });

    test('count units only merge with themselves', () {
      final lines = aggregator.aggregate([
        source('a', [('onion', 2, 'piece')]),
        source('b', [('onion', 1, 'piece')]),
        source('c', [('onion', 1, 'bunch')]),
      ]);
      final onion = only(lines, 'onion');
      expect(onion.quantities, hasLength(2));
      expect(onion.quantities, contains(const Quantity(3, 'piece')));
      expect(onion.quantities, contains(const Quantity(1, 'bunch')));
    });

    test('cooking for more people scales the amounts', () {
      final lines = aggregator.aggregate([
        source('a', [('garlic', 2, 'clove'), ('wheat-flour', 150, 'g')], servings: 2, cookFor: 6),
      ]);
      expect(only(lines, 'garlic').quantities.single.amount, 6);
      expect(only(lines, 'wheat-flour').quantities.single.amount, 450);
    });

    test('the same recipe twice buys it twice', () {
      final lines = aggregator.aggregate([
        source('a', [('garlic', 2, 'clove')]),
        source('a', [('garlic', 2, 'clove')]),
      ]);
      expect(only(lines, 'garlic').quantities.single.amount, 4);
    });

    test('lines without an amount are "to taste" and never hide a real amount', () {
      var lines = aggregator.aggregate([
        source('a', [('salt', null, 'to-taste')]),
      ]);
      expect(only(lines, 'salt').toTaste, isTrue);
      expect(only(lines, 'salt').quantities, isEmpty);

      lines = aggregator.aggregate([
        source('a', [('salt', null, 'to-taste')]),
        source('b', [('salt', 1, 'tsp')]),
      ]);
      expect(only(lines, 'salt').toTaste, isFalse);
      expect(only(lines, 'salt').quantities, [const Quantity(1, 'tsp')]);
    });

    test('ingredients that never go on a list (water) are left out', () {
      final lines = aggregator.aggregate([
        source('a', [('water', 500, 'ml'), ('garlic', 1, 'clove')]),
      ]);
      expect(lines.map((l) => l.ingredientId), ['garlic']);
    });

    test('quantities are exact, so 1 + 1 stays 2 and amounts never drift', () {
      final lines = aggregator.aggregate([
        for (var i = 0; i < 10; i++) source('r$i', [('garlic', 0.1, 'clove')], cookFor: 2),
      ]);
      expect(only(lines, 'garlic').quantities.single.amount, closeTo(1, 1e-9));
    });
  });

  group('manual items', () {
    test('a manual item with a dictionary id merges into the ingredient line', () {
      final lines = aggregator.aggregate(
        [
          source('a', [('garlic', 2, 'clove')]),
        ],
        manual: const [ManualItem(id: 'm1', label: 'garlic', ingredientId: 'garlic', amount: 1, unit: 'clove')],
      );
      expect(only(lines, 'garlic').quantities, [const Quantity(3, 'clove')]);
    });

    test('free text becomes its own line in the "other" aisle', () {
      final lines = aggregator.aggregate(
        const [],
        manual: const [ManualItem(id: 'm2', label: 'birthday candles')],
      );
      expect(lines, hasLength(1));
      expect(lines.single.key, 'manual:m2');
      expect(lines.single.aisle, 'other');
      expect(lines.single.label, 'birthday candles');
      expect(lines.single.toTaste, isTrue);
    });

    test('manual items survive a JSON round trip', () {
      const item = ManualItem(id: 'x', label: 'oat milk', ingredientId: 'oat-milk', amount: 2, unit: 'l');
      final back = ManualItem.fromJson(item.toJson());
      expect((back.id, back.label, back.ingredientId, back.amount, back.unit), ('x', 'oat milk', 'oat-milk', 2.0, 'l'));
    });
  });

  group('aisles', () {
    test('lines group by aisle in shopping-route order, alphabetical inside', () {
      final lines = aggregator.aggregate([
        source('a', [
          ('garlic', 2, 'clove'),
          ('whole-milk', 200, 'ml'),
          ('onion', 1, 'piece'),
          ('cumin', 1, 'tsp'),
          ('carrot', 2, 'piece'),
        ]),
      ]);
      final groups = aggregator.group(lines, 'en');
      final order = [for (final g in groups) g.aisle.id];
      final expectedOrder = [for (final a in corpus.ontology.aisles) a.id].where(order.contains).toList();
      expect(order, expectedOrder);
      final produce = groups.firstWhere((g) => g.aisle.id == 'produce');
      final names = [for (final l in produce.lines) corpus.ingredients.nameOf(l.ingredientId!, 'en')];
      expect(names, [...names]..sort());
      expect(names, containsAll(['carrot', 'garlic', 'onion']));
    });

    test('display names use the plural for counted pieces', () {
      final lines = aggregator.aggregate([
        source('a', [('onion', 3, 'piece'), ('egg', 1, 'piece')]),
      ]);
      expect(only(lines, 'onion').nameText(corpus.ingredients, corpus.ontology, 'en'), 'onions');
      expect(only(lines, 'egg').nameText(corpus.ingredients, corpus.ontology, 'en'), 'egg');
    });
  });

  group('shopping insights', () {
    ShoppingEvent event(String id, DateTime at) => ShoppingEvent(ingredientId: id, at: at);

    test('an empty log gives an empty dashboard with twelve months', () {
      final insights = InsightsCalculator.compute(const <ShoppingEvent>[]);
      expect(insights.isEmpty, isTrue);
      expect(insights.varietyScore, 0);
      expect(insights.months, hasLength(12));
      expect(insights.months.map((m) => m.month), [for (var m = 1; m <= 12; m++) m]);
      expect(insights.level, 'starting');
    });

    test('variety score is the number of unique ingredients ever added', () {
      final insights = InsightsCalculator.compute([
        event('garlic', DateTime(2026, 1, 3)),
        event('garlic', DateTime(2026, 2, 3)),
        event('onion', DateTime(2026, 2, 4)),
      ]);
      expect(insights.varietyScore, 2);
      expect(insights.totalAdds, 3);
    });

    test('top ingredients carry frequency counts, most first, ties by id', () {
      final insights = InsightsCalculator.compute([
        for (var i = 0; i < 3; i++) event('garlic', DateTime(2026, 1, 3 + i)),
        for (var i = 0; i < 2; i++) event('onion', DateTime(2026, 1, 3 + i)),
        for (var i = 0; i < 2; i++) event('carrot', DateTime(2026, 1, 3 + i)),
        event('salt', DateTime(2026, 1, 9)),
      ]);
      expect(
        [for (final t in insights.topIngredients) (t.ingredientId, t.count)],
        [('garlic', 3), ('carrot', 2), ('onion', 2), ('salt', 1)],
      );
    });

    test('at most ten top ingredients', () {
      final insights = InsightsCalculator.compute([for (var i = 0; i < 15; i++) event('ing-$i', DateTime(2026, 5, 1))]);
      expect(insights.topIngredients, hasLength(10));
    });

    test('the seasonal breakdown groups by calendar month across years', () {
      final insights = InsightsCalculator.compute([
        event('tomato', DateTime(2025, 8, 3)),
        event('tomato', DateTime(2026, 8, 9)),
        event('basil', DateTime(2026, 8, 9)),
        event('pumpkin', DateTime(2025, 10, 20)),
      ]);
      final august = insights.months[7];
      expect(august.month, 8);
      expect(august.count, 3);
      expect(august.top.first.ingredientId, 'tomato');
      expect(august.top.first.count, 2);
      expect(insights.months[9].count, 1);
      expect(insights.months[0].count, 0);
      expect(insights.busiestMonthCount, 3);
    });

    test('the level words follow the score', () {
      ShoppingInsights withVariety(int n) =>
          InsightsCalculator.compute([for (var i = 0; i < n; i++) event('i$i', DateTime(2026, 3, 1))]);
      expect(withVariety(9).level, 'starting');
      expect(withVariety(10).level, 'growing');
      expect(withVariety(24).level, 'growing');
      expect(withVariety(25).level, 'varied');
      expect(withVariety(49).level, 'varied');
      expect(withVariety(50).level, 'adventurous');
    });

    test('events survive a JSON round trip', () {
      final e = ShoppingEvent(ingredientId: 'garlic', at: DateTime(2026, 4, 5, 10), recipeId: 'doener-vegan');
      final back = ShoppingEvent.fromJson(e.toJson());
      expect(back.ingredientId, 'garlic');
      expect(back.recipeId, 'doener-vegan');
      expect(back.at.millisecondsSinceEpoch, e.at.millisecondsSinceEpoch);
    });
  });
}
