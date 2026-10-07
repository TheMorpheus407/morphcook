import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/pagination.dart';

void main() {
  group('PaginationController', () {
    test('loadMore appends pages until the cursor is exhausted', () async {
      var calls = 0;
      final controller = PaginationController<int>(
        pageSize: 2,
        prefetchThreshold: 1,
        maxRendered: 50,
        fetcher: (page, cursor) async {
          calls++;
          final start = page * 2;
          final items = [start, start + 1];
          final hasMore = start + 2 < 6;
          return Page(items: items, nextCursor: hasMore ? '$start' : null);
        },
      );
      await controller.loadMore();
      expect(controller.items, [0, 1]);
      expect(controller.hasMore, true);
      await controller.loadMore();
      expect(controller.items, [0, 1, 2, 3]);
      await controller.loadMore();
      expect(controller.items, [0, 1, 2, 3, 4, 5]);
      expect(controller.hasMore, false);
      expect(calls, 3);
      // further calls are no-ops once exhausted
      await controller.loadMore();
      expect(calls, 3);
    });

    test('shouldLoadMore triggers within the prefetch threshold only', () async {
      final controller = PaginationController<int>(
        pageSize: 10,
        prefetchThreshold: 3,
        maxRendered: 50,
        fetcher: (page, cursor) async =>
            Page(items: List.generate(10, (i) => page * 10 + i), nextCursor: 'x'),
      );
      await controller.loadMore();
      expect(controller.loadedCount, 10);
      expect(controller.shouldLoadMore(6), false); // index 6, 4 from the end
      expect(controller.shouldLoadMore(7), true); // 3 from the end
      expect(controller.shouldLoadMore(9), true);
    });

    test('concurrent loadMore calls share one fetch', () async {
      var calls = 0;
      final controller = PaginationController<int>(
        pageSize: 2,
        prefetchThreshold: 1,
        maxRendered: 50,
        fetcher: (page, cursor) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return Page(items: [page], nextCursor: 'x');
        },
      );
      final f1 = controller.loadMore();
      final f2 = controller.loadMore();
      await Future.wait([f1, f2]);
      expect(calls, 1);
      expect(controller.items, [0]);
    });

    test('fetch errors are captured and retryable', () async {
      var fail = true;
      final controller = PaginationController<int>(
        pageSize: 2,
        prefetchThreshold: 1,
        maxRendered: 50,
        fetcher: (page, cursor) async {
          if (fail) throw StateError('boom');
          return Page(items: [1], nextCursor: null);
        },
      );
      await controller.loadMore();
      expect(controller.error, contains('boom'));
      expect(controller.items, isEmpty);
      expect(controller.isLoading, false);
      fail = false;
      await controller.loadMore();
      expect(controller.error, isNull);
      expect(controller.items, [1]);
    });

    test('refresh resets and reloads from page 1', () async {
      var offset = 0;
      final controller = PaginationController<int>(
        pageSize: 2,
        prefetchThreshold: 1,
        maxRendered: 50,
        fetcher: (page, cursor) async {
          final items = List.generate(2, (i) => offset + i);
          offset += 2;
          return Page(items: items, nextCursor: 'x');
        },
      );
      await controller.loadMore();
      await controller.loadMore();
      expect(controller.items.length, 4);
      offset = 100; // simulate changed underlying data
      await controller.refresh();
      expect(controller.items, [100, 101]);
      expect(controller.error, isNull);
    });

    test('reset clears items and restores the initial state', () async {
      final controller = PaginationController<int>(
        pageSize: 2,
        prefetchThreshold: 1,
        maxRendered: 50,
        fetcher: (page, cursor) async => Page(items: [page], nextCursor: 'x'),
      );
      await controller.loadMore();
      controller.reset();
      expect(controller.items, isEmpty);
      expect(controller.hasMore, true);
      expect(controller.isLoading, false);
      expect(controller.error, isNull);
      await controller.loadMore();
      expect(controller.items, [0]); // back to page 1
    });

    test('items are exposed as an unmodifiable list', () async {
      final controller = PaginationController<int>(
        pageSize: 2,
        prefetchThreshold: 1,
        maxRendered: 50,
        fetcher: (page, cursor) async => Page(items: [1], nextCursor: null),
      );
      await controller.loadMore();
      expect(() => controller.items.add(99), throwsUnsupportedError);
    });

    test('hasMore is capped by the max-rendered guardrail', () async {
      // maxRendered 2 → hard cap at 20 loaded items even if the fetcher
      // keeps returning cursors.
      final controller = PaginationController<int>(
        pageSize: 5,
        prefetchThreshold: 1,
        maxRendered: 2,
        fetcher: (page, cursor) async =>
            Page(items: List.generate(5, (i) => page * 5 + i), nextCursor: 'x'),
      );
      for (var i = 0; i < 10; i++) {
        await controller.loadMore();
      }
      expect(controller.items.length, 20);
      expect(controller.hasMore, false);
    });
  });

  group('SPEC pagination table', () {
    // | View | Type | Page size | Prefetch | Max rendered |
    // | Search | cursor | 20 | 10 | 50 |
    // | Cookbook | offset | 30 | 10 | 50 |
    // | History | time | 7 weeks | 1 week | 50 |
    // | Meal plan | weekly | 1 week | 0 | 4 weeks |

    test('search: cursor-based, 20 per page, prefetch 10, max 50', () {
      final controller = cursorPagination<int>(
        fetch: (cursor, pageSize) async => Page(items: const [1], nextCursor: null),
      );
      expect(controller.pageSize, 20);
      expect(controller.prefetchThreshold, 10);
      expect(controller.maxRendered, 50);
    });

    test('cookbook: offset-based, 30 per page, prefetch 10, max 50', () {
      final controller = offsetPagination<int>(
        fetch: (offset, limit) async => Page(items: const [1]),
      );
      expect(controller.pageSize, 30);
      expect(controller.prefetchThreshold, 10);
      expect(controller.maxRendered, 50);
    });

    test('history: time-window, 7-day pages, prefetch 1, max 50', () {
      final controller = timeWindowPagination<int>(
        fetch: (start, days) async => Page(items: const [1]),
      );
      expect(controller.pageSize, 7);
      expect(controller.prefetchThreshold, 1);
      expect(controller.maxRendered, 50);
    });

    test('meal plan: weekly, 1-week pages, no prefetch, max 4', () {
      final controller = weeklyPagination<int>(
        fetch: (weekId) async => Page(items: const [1]),
      );
      expect(controller.pageSize, 1);
      expect(controller.prefetchThreshold, 0);
      expect(controller.maxRendered, 4);
    });
  });

  group('offsetPagination', () {
    test('advances the offset by the number of items returned', () async {
      final offsets = <int>[];
      final controller = offsetPagination<int>(
        pageSize: 2,
        fetch: (offset, limit) async {
          offsets.add(offset);
          final full = offset < 4; // two full pages of 2, then a short one
          return Page(items: List.generate(full ? 2 : 1, (i) => offset + i));
        },
      );
      await controller.loadMore();
      await controller.loadMore();
      await controller.loadMore();
      expect(offsets, [0, 2, 4]);
      expect(controller.items, [0, 1, 2, 3, 4]);
      expect(controller.hasMore, false); // short page ends pagination
    });
  });

  group('cursorPagination', () {
    test('passes the cursor through and pages by pageSize', () async {
      final seen = <String?>[];
      final controller = cursorPagination<String>(
        pageSize: 2,
        fetch: (cursor, pageSize) async {
          seen.add(cursor);
          final start = cursor == null ? 0 : int.parse(cursor);
          final count = (5 - start).clamp(0, pageSize);
          return Page(
            items: List.generate(count, (i) => 'r${start + i}'),
            nextCursor: start + count < 5 ? (start + count).toString() : null,
          );
        },
      );
      await controller.loadMore();
      await controller.loadMore();
      await controller.loadMore();
      expect(seen, [null, '2', '4']);
      expect(controller.items, ['r0', 'r1', 'r2', 'r3', 'r4']);
      expect(controller.hasMore, false);
    });
  });

  group('timeWindowPagination', () {
    test('walks backwards in 7-day windows, capped at maxWeeks', () async {
      final windows = <DateTime>[];
      final controller = timeWindowPagination<int>(
        fetch: (start, days) async {
          windows.add(start);
          expect(days, 7);
          return Page(items: const [1]);
        },
        maxWeeks: 3,
      );
      await controller.loadMore();
      await controller.loadMore();
      await controller.loadMore();
      expect(windows.length, 3);
      // each window starts 7 days before the previous one
      expect(windows[0].difference(windows[1]).inDays, 7);
      expect(windows[1].difference(windows[2]).inDays, 7);
      expect(controller.hasMore, false);
    });
  });

  group('weeklyPagination', () {
    test('walks back week by week and stops at maxWeeks', () async {
      final weeks = <String>[];
      final controller = weeklyPagination<int>(
        fetch: (weekId) async {
          weeks.add(weekId);
          expect(RegExp(r'^\d{4}-W\d{2}$').hasMatch(weekId), true);
          return Page(items: const [1]);
        },
        maxWeeks: 2,
      );
      await controller.loadMore();
      await controller.loadMore();
      expect(weeks.length, 2);
      expect(weeks[0], isNot(weeks[1]));
      expect(controller.hasMore, false);
    });
  });
}
