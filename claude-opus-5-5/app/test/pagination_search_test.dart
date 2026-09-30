import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/search_index.dart';
import 'package:morphcook/logic/pagination.dart';
import 'package:morphcook/logic/search_engine.dart';
import 'package:morphcook/logic/text_normalize.dart';
import 'package:morphcook/models/recipe.dart';

import 'support.dart';

Future<PageResult<int>> numbers(String? token, int size, {int total = 95}) async {
  final start = int.parse(token ?? '0');
  final end = (start + size).clamp(0, total);
  return PageResult([for (var i = start; i < end; i++) i], nextToken: end < total ? '$end' : null);
}

void main() {
  group('PaginationController', () {
    test('configs match the spec table', () {
      expect(PaginationConfig.search.type, PaginationType.cursor);
      expect(PaginationConfig.search.pageSize, 20);
      expect(PaginationConfig.search.prefetchThreshold, 10);
      expect(PaginationConfig.search.maxRendered, 50);
      expect(PaginationConfig.cookbook.type, PaginationType.offset);
      expect(PaginationConfig.cookbook.pageSize, 30);
      expect(PaginationConfig.history.type, PaginationType.time);
      expect(PaginationConfig.history.pageSize, 7);
      expect(PaginationConfig.history.prefetchThreshold, 1);
      expect(PaginationConfig.mealPlan.type, PaginationType.weekly);
      expect(PaginationConfig.mealPlan.pageSize, 1);
      expect(PaginationConfig.mealPlan.prefetchThreshold, 0);
      expect(PaginationConfig.mealPlan.maxRendered, 4);
    });

    test('loadMore appends pages until the end', () async {
      final p = PaginationController<int>(
        config: const PaginationConfig(
          type: PaginationType.offset,
          pageSize: 30,
          prefetchThreshold: 10,
          maxRendered: 1000,
        ),
        fetcher: numbers,
      );
      await p.loadMore();
      expect(p.length, 30);
      expect(p.hasMore, isTrue);
      await p.loadMore();
      await p.loadMore();
      await p.loadMore();
      expect(p.length, 95);
      expect(p.hasMore, isFalse);
      await p.loadMore(); // no-op at the end
      expect(p.length, 95);
    });

    test('shouldLoadMore respects the prefetch threshold', () async {
      final p = PaginationController<int>(config: PaginationConfig.search, fetcher: numbers);
      await p.loadMore(); // 20 items
      expect(p.shouldLoadMore(8), isFalse);
      expect(p.shouldLoadMore(9), isTrue); // within 10 of the end (index 19)
    });

    test('never holds more than maxRendered; earlier pages can be reloaded', () async {
      final p = PaginationController<int>(config: PaginationConfig.search, fetcher: numbers);
      for (var i = 0; i < 4; i++) {
        await p.loadMore();
      }
      expect(p.length, lessThanOrEqualTo(50));
      expect(p.items.first, 40);
      expect(p.hasPrevious, isTrue);
      await p.loadPrevious();
      expect(p.items.first, 20);
      expect(p.length, lessThanOrEqualTo(50));
    });

    test('weekly window caps at four weeks', () async {
      final p = PaginationController<int>(config: PaginationConfig.mealPlan, fetcher: numbers);
      for (var i = 0; i < 6; i++) {
        await p.loadMore();
      }
      expect(p.items, [2, 3, 4, 5]);
    });

    test('refresh reloads from page 1, reset clears', () async {
      var total = 10;
      final p = PaginationController<int>(
        config: PaginationConfig.search,
        fetcher: (t, s) => numbers(t, s, total: total),
      );
      await p.loadMore();
      expect(p.length, 10);
      total = 25;
      await p.refresh();
      expect(p.length, 20);
      p.reset();
      expect(p.length, 0);
      expect(p.isInitialised, isFalse);
    });

    test('errors surface and can be retried', () async {
      var fail = true;
      final p = PaginationController<int>(
        config: PaginationConfig.search,
        fetcher: (t, s) async {
          if (fail) throw StateError('boom');
          return numbers(t, s);
        },
      );
      await p.loadMore();
      expect(p.error, isA<StateError>());
      fail = false;
      await p.refresh();
      expect(p.error, isNull);
      expect(p.length, 20);
    });
  });

  group('search index', () {
    final c = Corpus.instance;
    final SearchIndex index = c.searchIndex;

    test('normalisation folds umlauts and case', () {
      expect(tokenize('Döner & Ölig'), ['doner', 'olig']);
      expect(tokenize('Straße'), ['strasse']);
    });

    test('covers every recipe in the corpus', () {
      expect(index.allRecipeIds.toSet(), c.recipes.keys.toSet());
      for (final id in index.allRecipeIds) {
        expect(index.partitionOf(id), c.r(id).partitionId);
      }
    });

    test('title, tag and ingredient tokens in both languages', () {
      expect(index.match('döner', 'en').keys, containsAll(['doener-classic', 'doener-vegan']));
      expect(index.match('doner', 'de').keys, contains('doener-vegan'));
      expect(index.match('linsen', 'en').keys, contains('bolognese-lentil')); // German word from EN mode
      expect(index.match('lentil', 'en').keys, contains('lentil-soup-classic'));
      expect(index.match('tahini', 'en').keys, contains('falafel-classic')); // ingredient
      expect(index.match('street food', 'en').keys, contains('pad-thai-classic')); // tag
    });

    test('prefix matching and AND semantics', () {
      expect(index.match('pan', 'en').keys, contains('pancakes-classic'));
      final both = index.match('vegan pad', 'en').keys;
      expect(both, contains('pad-thai-vegan'));
      expect(both, isNot(contains('pad-thai-classic')));
      expect(index.match('sushi', 'en'), isEmpty);
    });

    test('cursor pagination is stable across list changes', () {
      final list = [for (final id in c.recipes.keys.take(45)) c.r(id)];
      final p1 = SearchEngine.page(list, null, 20);
      expect(p1.items, hasLength(20));
      final p2 = SearchEngine.page(list, p1.nextToken, 20);
      expect(p2.items.first.id, list[20].id);
      // an item before the cursor disappears: the next page still starts after the last seen id
      final shrunk = [...list]..removeAt(3);
      final p2b = SearchEngine.page(shrunk, p1.nextToken, 20);
      expect(p2b.items.first.id, list[20].id);
      final p3 = SearchEngine.page(list, p2.nextToken, 20);
      expect(p3.items, hasLength(5));
      expect(p3.nextToken, isNull);
    });

    test('filters: OR within a group, AND across groups', () {
      const f = SearchFilters(diets: {'vegan', 'gluten-free'}, maxMinutes: 30);
      final accepted = c.recipes.values.where(f.accepts).toList();
      expect(accepted, isNotEmpty);
      for (final Recipe r in accepted) {
        expect(['vegan', 'gluten-free'], contains(r.diet));
        expect(r.timeMinutes, lessThanOrEqualTo(30));
      }
      expect(f.toggle('diet', 'vegan').diets, {'gluten-free'});
      expect(f.count, 3);
    });
  });
}
