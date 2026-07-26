import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/collections.dart';
import 'package:morphcook/services/insights_service.dart';

import 'support/fixtures.dart';

void main() {
  late InsightsService service;

  setUp(() => service = InsightsService(testIngredients()));

  ShoppingEntry at(String id, DateTime when) => ShoppingEntry(
    ingredientId: id,
    qty: 1,
    unit: 'piece',
    addedAt: when,
    sourceRecipeIds: const [],
  );

  test('an empty list yields the empty insights', () {
    expect(service.analyse(const []).isEmpty, isTrue);
    expect(service.analyse(const []).varietyScore, 0);
  });

  test('the variety score counts distinct ingredients, not additions', () {
    final now = DateTime(2026, 7, 26);
    final insights = service.analyse([
      at('garlic', now),
      at('garlic', now),
      at('apple', now),
    ]);
    expect(insights.varietyScore, 2);
    expect(insights.totalAdditions, 3);
    expect(insights.repeatRate, closeTo(1.5, 0.001));
  });

  test('top ingredients are ordered by frequency, ties broken by id', () {
    final now = DateTime(2026, 7, 26);
    final insights = service.analyse([
      at('garlic', now),
      at('garlic', now),
      at('garlic', now),
      at('apple', now),
      at('apple', now),
      at('feta', now),
    ]);
    expect(
      insights.topIngredients.map((e) => e.ingredientId).take(3),
      orderedEquals(<String>['garlic', 'apple', 'feta']),
    );
    expect(insights.topIngredients.first.count, 3);
  });

  test('topCount caps the list', () {
    final now = DateTime(2026, 7, 26);
    final insights = service.analyse([
      for (final id in ['garlic', 'apple', 'feta', 'parmesan']) at(id, now),
    ], topCount: 2);
    expect(insights.topIngredients, hasLength(2));
  });

  test('the seasonal breakdown groups by month in chronological order', () {
    final insights = service.analyse([
      at('garlic', DateTime(2026, 5, 3)),
      at('apple', DateTime(2026, 5, 20)),
      at('feta', DateTime(2026, 7, 1)),
      at('garlic', DateTime(2026, 6, 15)),
    ]);
    expect(
      insights.byMonth.map((b) => b.key),
      orderedEquals(<String>['2026-05', '2026-06', '2026-07']),
    );
    expect(insights.byMonth.first.total, 2);
    expect(insights.byMonth.first.uniqueIngredients, 2);
  });

  test('a month with repeats separates total from unique', () {
    final insights = service.analyse([
      at('garlic', DateTime(2026, 5, 3)),
      at('garlic', DateTime(2026, 5, 20)),
    ]);
    expect(insights.byMonth.single.total, 2);
    expect(insights.byMonth.single.uniqueIngredients, 1);
  });

  test('the aisle spread counts additions per aisle', () {
    final now = DateTime(2026, 7, 26);
    final insights = service.analyse([
      at('garlic', now),
      at('apple', now),
      at('feta', now),
    ]);
    expect(insights.aisleSpread['produce'], 2);
    expect(insights.aisleSpread['dairy'], 1);
  });

  test('firstAddedAt is the earliest entry, not the first in the list', () {
    final insights = service.analyse([
      at('garlic', DateTime(2026, 7, 26)),
      at('apple', DateTime(2026, 3, 2)),
    ]);
    expect(insights.firstAddedAt, DateTime(2026, 3, 2));
  });

  test(
    'an unknown ingredient falls into the "other" aisle rather than crashing',
    () {
      final insights = service.analyse([
        at('does-not-exist', DateTime(2026, 7, 26)),
      ]);
      expect(insights.aisleSpread['other'], 1);
      expect(insights.topIngredients.single.label('en'), 'does-not-exist');
    },
  );
}
