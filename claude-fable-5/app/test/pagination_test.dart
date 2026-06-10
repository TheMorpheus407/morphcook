import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/pagination.dart';

PageFetcher<int> rangeFetcher(int total) =>
    (cursor, pageSize) async {
      final offset = cursor == null ? 0 : int.parse(cursor);
      final items = [
        for (var i = offset; i < (offset + pageSize) && i < total; i++) i,
      ];
      final next = offset + items.length;
      return Page(items: items, nextCursor: next < total ? '$next' : null);
    };

void main() {
  group('PaginationController', () {
    test('loads pages of pageSize until exhausted', () async {
      final pager =
          PaginationController<int>(fetch: rangeFetcher(45), pageSize: 20);
      await pager.loadMore();
      expect(pager.items, hasLength(20));
      expect(pager.hasMore, isTrue);
      await pager.loadMore();
      expect(pager.items, hasLength(40));
      await pager.loadMore();
      expect(pager.items, hasLength(45));
      expect(pager.hasMore, isFalse);
      // Further loads are no-ops.
      await pager.loadMore();
      expect(pager.items, hasLength(45));
    });

    test('shouldLoadMore triggers within the prefetch threshold', () async {
      final pager = PaginationController<int>(
          fetch: rangeFetcher(100), pageSize: 20, prefetchThreshold: 10);
      await pager.loadMore();
      expect(pager.shouldLoadMore(5), isFalse);
      expect(pager.shouldLoadMore(9), isFalse);
      expect(pager.shouldLoadMore(10), isTrue);
      expect(pager.shouldLoadMore(19), isTrue);
    });

    test('never keeps more than maxRendered items (oldest disposed)',
        () async {
      final pager = PaginationController<int>(
          fetch: rangeFetcher(200), pageSize: 20, maxRendered: 50);
      for (var i = 0; i < 4; i++) {
        await pager.loadMore();
      }
      expect(pager.items.length, 50);
      expect(pager.disposedCount, 30);
      // The window holds the most recent items.
      expect(pager.items.last, 79);
      expect(pager.items.first, 30);
    });

    test('empty state only after the first load completes', () async {
      final pager =
          PaginationController<int>(fetch: rangeFetcher(0));
      expect(pager.isEmpty, isFalse);
      await pager.loadMore();
      expect(pager.isEmpty, isTrue);
    });

    test('refresh resets to page 1', () async {
      final pager =
          PaginationController<int>(fetch: rangeFetcher(60), pageSize: 20);
      await pager.loadMore();
      await pager.loadMore();
      expect(pager.items, hasLength(40));
      await pager.refresh();
      expect(pager.items, hasLength(20));
      expect(pager.items.first, 0);
    });

    test('reset clears everything', () async {
      final pager =
          PaginationController<int>(fetch: rangeFetcher(60), pageSize: 20);
      await pager.loadMore();
      pager.reset();
      expect(pager.items, isEmpty);
      expect(pager.hasMore, isTrue);
      expect(pager.disposedCount, 0);
      expect(pager.isEmpty, isFalse);
    });

    test('fetch errors are surfaced and retryable', () async {
      var failOnce = true;
      final pager = PaginationController<int>(
        fetch: (cursor, pageSize) async {
          if (failOnce) {
            failOnce = false;
            throw StateError('boom');
          }
          return rangeFetcher(10)(cursor, pageSize);
        },
      );
      await pager.loadMore();
      expect(pager.error, isA<StateError>());
      expect(pager.items, isEmpty);
      await pager.loadMore();
      expect(pager.error, isNull);
      expect(pager.items, hasLength(10));
    });

    test('guards against concurrent loads', () async {
      var calls = 0;
      final pager = PaginationController<int>(
        fetch: (cursor, pageSize) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return rangeFetcher(40)(cursor, pageSize);
        },
      );
      await Future.wait([pager.loadMore(), pager.loadMore()]);
      expect(calls, 1);
    });
  });
}
