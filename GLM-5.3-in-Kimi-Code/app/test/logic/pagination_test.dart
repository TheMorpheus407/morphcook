import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/pagination.dart';

void main() {
  group('PaginationController', () {
    test('refresh loads page 1', () async {
      final pager = PaginationController<int>(
        policy: PaginationPolicy.search,
        fetchPage: (cursor) async {
          final start = int.tryParse(cursor ?? '0') ?? 0;
          return List.generate(20, (i) => start + i);
        },
      );
      await pager.refresh();
      expect(pager.items.length, 20);
      expect(pager.items.first, 0);
      pager.dispose();
    });

    test('cursor advances across pages', () async {
      final pager = PaginationController<int>(
        policy: PaginationPolicy.search,
        fetchPage: (cursor) async {
          final start = int.tryParse(cursor ?? '0') ?? 0;
          return List.generate(20, (i) => start + i);
        },
      );
      await pager.refresh();
      expect(pager.items.length, 20);
      await pager.loadMore();
      expect(pager.items.length, 40);
      expect(pager.items[20], 20);
      pager.dispose();
    });

    test('short page marks exhausted', () async {
      final pager = PaginationController<int>(
        policy: PaginationPolicy.search,
        fetchPage: (cursor) async {
          final start = int.tryParse(cursor ?? '0') ?? 0;
          final remaining = 25 - start;
          return List.generate(
              remaining.clamp(0, 20), (i) => start + i);
        },
      );
      await pager.refresh();
      expect(pager.hasMore, isTrue);
      await pager.loadMore();
      expect(pager.items.length, 25);
      expect(pager.hasMore, isFalse);
      pager.dispose();
    });

    test('max rendered caps items at 50', () async {
      final pager = PaginationController<int>(
        policy: PaginationPolicy.search,
        fetchPage: (cursor) async {
          final start = int.tryParse(cursor ?? '0') ?? 0;
          return List.generate(20, (i) => start + i);
        },
      );
      await pager.refresh();
      await pager.loadMore();
      await pager.loadMore();
      expect(pager.items.length, 50);
      expect(pager.hasMore, isFalse);
      pager.dispose();
    });

    test('shouldLoadMore triggers within prefetch threshold', () async {
      final pager = PaginationController<int>(
        policy: PaginationPolicy.search,
        fetchPage: (cursor) async =>
            List.generate(20, (i) => (int.tryParse(cursor ?? '0') ?? 0) + i),
      );
      await pager.refresh();
      // policy: prefetch when within 10 of the end (20 items)
      expect(pager.shouldLoadMore(9), isTrue); // 20 - 10 - 1 = 9
      expect(pager.shouldLoadMore(5), isFalse);
      pager.dispose();
    });

    test('reset returns to initial state', () async {
      final pager = PaginationController<int>(
        policy: PaginationPolicy.search,
        fetchPage: (cursor) async =>
            List.generate(20, (i) => (int.tryParse(cursor ?? '0') ?? 0) + i),
      );
      await pager.refresh();
      pager.reset();
      expect(pager.items, isEmpty);
      expect(pager.status, PageStatus.idle);
      expect(pager.hasMore, isTrue);
      pager.dispose();
    });

    test('refresh clears previous items', () async {
      var total = 30;
      final pager = PaginationController<int>(
        policy: PaginationPolicy.search,
        fetchPage: (cursor) async {
          final start = int.tryParse(cursor ?? '0') ?? 0;
          final n = (total - start).clamp(0, 20);
          return List.generate(n, (i) => start + i);
        },
      );
      await pager.refresh();
      await pager.loadMore();
      expect(pager.items.length, 30);
      total = 10;
      await pager.refresh();
      expect(pager.items.length, 10);
      expect(pager.hasMore, isFalse);
      pager.dispose();
    });

    test('error state surfaces message', () async {
      final pager = PaginationController<int>(
        policy: PaginationPolicy.search,
        fetchPage: (cursor) async => throw Exception('boom'),
      );
      await pager.refresh();
      expect(pager.status, PageStatus.error);
      expect(pager.error, contains('boom'));
      pager.dispose();
    });

    test('policies match spec table', () {
      expect(PaginationPolicy.search.pageSize, 20);
      expect(PaginationPolicy.search.prefetchThreshold, 10);
      expect(PaginationPolicy.search.maxRendered, 50);
      expect(PaginationPolicy.cookbook.pageSize, 30);
      expect(PaginationPolicy.cookbook.prefetchThreshold, 10);
      expect(PaginationPolicy.history.pageSize, 7); // 7 weeks
      expect(PaginationPolicy.history.prefetchThreshold, 1);
      expect(PaginationPolicy.weekly.pageSize, 1);
      expect(PaginationPolicy.weekly.maxRendered, 4); // 4 weeks
    });
  });
}
