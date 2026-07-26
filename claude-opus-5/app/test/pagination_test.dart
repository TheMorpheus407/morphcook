import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/services/pagination.dart';

void main() {
  List<int> source(int n) => List<int>.generate(n, (i) => i);

  group('config matches the table in SPEC.md', () {
    test('search', () {
      const c = PaginationConfig.search;
      expect(c.type, PaginationType.cursor);
      expect(c.pageSize, 20);
      expect(c.prefetchThreshold, 10);
      expect(c.maxRendered, 50);
    });

    test('cookbook', () {
      const c = PaginationConfig.cookbook;
      expect(c.type, PaginationType.offset);
      expect(c.pageSize, 30);
      expect(c.prefetchThreshold, 10);
      expect(c.maxRendered, 50);
    });

    test('history', () {
      const c = PaginationConfig.history;
      expect(c.type, PaginationType.time);
      expect(c.pageSize, 7);
      expect(c.prefetchThreshold, 1);
      expect(c.maxRendered, 50);
    });

    test('meal plan', () {
      const c = PaginationConfig.mealPlan;
      expect(c.type, PaginationType.weekly);
      expect(c.pageSize, 1);
      expect(c.prefetchThreshold, 0);
      expect(c.maxRendered, 4);
    });
  });

  group('loadMore', () {
    test('pulls one page at a time and stops at the end', () async {
      final c = PaginationController<int>(
        config: PaginationConfig.search,
        fetcher: listFetcher(() => source(45)),
      );
      await c.loadMore();
      expect(c.items, hasLength(20));
      expect(c.hasMore, isTrue);
      expect(c.total, 45);

      await c.loadMore();
      expect(c.items, hasLength(40));

      await c.loadMore();
      expect(c.items, hasLength(45));
      expect(c.hasMore, isFalse);
      expect(c.status, PaginationStatus.ready);
    });

    test('an empty source reports empty, not ready', () async {
      final c = PaginationController<int>(
        config: PaginationConfig.search,
        fetcher: listFetcher(() => source(0)),
      );
      await c.loadMore();
      expect(c.items, isEmpty);
      expect(c.status, PaginationStatus.empty);
      expect(c.hasMore, isFalse);
    });

    test('a second call while loading is ignored', () async {
      var calls = 0;
      final c = PaginationController<int>(
        config: PaginationConfig.search,
        fetcher: (cursor, limit) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return PageResult<int>(items: source(limit), nextCursor: '1');
        },
      );
      final first = c.loadMore();
      await c.loadMore();
      await first;
      expect(calls, 1);
    });
  });

  group('render cap', () {
    test('never holds more than maxRendered items', () async {
      final c = PaginationController<int>(
        config: PaginationConfig.search,
        fetcher: listFetcher(() => source(200)),
      );
      for (var i = 0; i < 6; i++) {
        await c.loadMore();
      }
      expect(
        c.items.length,
        lessThanOrEqualTo(PaginationConfig.search.maxRendered),
      );
      expect(c.droppedFromHead, greaterThan(0));
    });

    test('the surviving window is the most recent one', () async {
      final c = PaginationController<int>(
        config: PaginationConfig.search,
        fetcher: listFetcher(() => source(80)),
      );
      await c.loadMore();
      await c.loadMore();
      await c.loadMore();
      expect(c.items.last, 59);
      expect(c.items.first, 60 - c.items.length);
    });
  });

  group('shouldLoadMore', () {
    test('fires within the prefetch threshold of the end', () async {
      final c = PaginationController<int>(
        config: PaginationConfig.search,
        fetcher: listFetcher(() => source(100)),
      );
      await c.loadMore(); // 20 items
      expect(c.shouldLoadMore(0), isFalse);
      expect(c.shouldLoadMore(8), isFalse);
      expect(c.shouldLoadMore(9), isTrue);
      expect(c.shouldLoadMore(19), isTrue);
    });

    test('never fires once the list is exhausted', () async {
      final c = PaginationController<int>(
        config: PaginationConfig.search,
        fetcher: listFetcher(() => source(5)),
      );
      await c.loadMore();
      expect(c.hasMore, isFalse);
      expect(c.shouldLoadMore(4), isFalse);
    });
  });

  group('reset and refresh', () {
    test('reset clears everything', () async {
      final c = PaginationController<int>(
        config: PaginationConfig.search,
        fetcher: listFetcher(() => source(100)),
      );
      await c.loadMore();
      c.reset();
      expect(c.items, isEmpty);
      expect(c.hasMore, isTrue);
      expect(c.droppedFromHead, 0);
      expect(c.status, PaginationStatus.idle);
    });

    test('refresh reloads from the first page', () async {
      var size = 10;
      final c = PaginationController<int>(
        config: PaginationConfig.search,
        fetcher: listFetcher(() => source(size)),
      );
      await c.loadMore();
      expect(c.items, hasLength(10));
      size = 3;
      await c.refresh();
      expect(c.items, hasLength(3));
    });

    test('a reset mid-flight discards the in-flight page', () async {
      final c = PaginationController<int>(
        config: PaginationConfig.search,
        fetcher: (cursor, limit) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return PageResult<int>(items: source(limit), nextCursor: null);
        },
      );
      final pending = c.loadMore();
      c.reset();
      await pending;
      expect(c.items, isEmpty);
    });
  });

  group('errors', () {
    test('a throwing fetcher lands in the error state and can retry', () async {
      var shouldFail = true;
      final c = PaginationController<int>(
        config: PaginationConfig.search,
        fetcher: (cursor, limit) async {
          if (shouldFail) throw StateError('nope');
          return PageResult<int>(items: source(3), nextCursor: null);
        },
      );
      await c.loadMore();
      expect(c.status, PaginationStatus.error);
      expect(c.error, isA<StateError>());

      shouldFail = false;
      await c.loadMore();
      expect(c.status, PaginationStatus.ready);
      expect(c.items, hasLength(3));
      expect(c.error, isNull);
    });
  });
}
