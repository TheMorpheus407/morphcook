import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/pagination/pagination_controller.dart';

/// 0..total-1 served in cursor pages.
PaginationController<int> cursorOver(int total, {List<(String?, int)>? calls, PaginationConfig? config}) {
  return PaginationController<int>.cursor(
    config: config ?? PaginationConfig.search,
    loader: (cursor, limit) async {
      calls?.add((cursor, limit));
      final start = cursor == null ? 0 : int.parse(cursor);
      final end = (start + limit).clamp(0, total);
      return CursorPage<int>([for (var i = start; i < end; i++) i], nextCursor: end < total ? '$end' : null);
    },
  );
}

void main() {
  group('configuration follows the spec table', () {
    test('search: cursor, 20 per page, prefetch 10, at most 50', () {
      const c = PaginationConfig.search;
      expect((c.type, c.pageSize, c.prefetchThreshold, c.maxRendered), (PaginationType.cursor, 20, 10, 50));
    });

    test('cookbook: offset, 30 per page, prefetch 10, at most 50', () {
      const c = PaginationConfig.cookbook;
      expect((c.type, c.pageSize, c.prefetchThreshold, c.maxRendered), (PaginationType.offset, 30, 10, 50));
    });

    test('history: time based, 7 weeks per page, prefetch 1 week, at most 50', () {
      const c = PaginationConfig.history;
      expect((c.type, c.pageSize, c.prefetchThreshold, c.maxRendered), (PaginationType.time, 7, 1, 50));
    });

    test('meal plan: weekly, 1 week per page, prefetch 0, at most 4 weeks', () {
      const c = PaginationConfig.mealPlan;
      expect((c.type, c.pageSize, c.prefetchThreshold, c.maxRendered), (PaginationType.weekly, 1, 0, 4));
    });
  });

  group('cursor based (search)', () {
    test('starts idle and empty', () {
      final c = cursorOver(100);
      expect(c.status, PaginationStatus.idle);
      expect(c.items, isEmpty);
      expect(c.hasMore, isFalse);
      expect(c.isEmpty, isFalse, reason: 'nothing has loaded yet');
    });

    test('refresh loads the first page of 20 with the stored cursor', () async {
      final calls = <(String?, int)>[];
      final c = cursorOver(100, calls: calls);
      await c.refresh();
      expect(c.items, hasLength(20));
      expect(c.items.first, 0);
      expect(c.hasMore, isTrue);
      expect(c.status, PaginationStatus.ready);
      expect(calls, [(null, 20)]);
    });

    test('loadMore follows the nextCursor', () async {
      final calls = <(String?, int)>[];
      final c = cursorOver(100, calls: calls);
      await c.refresh();
      await c.loadMore();
      expect(c.items, hasLength(40));
      expect(c.items.last, 39);
      expect(calls, [(null, 20), ('20', 20)]);
    });

    test('loadMore on a fresh controller loads the first page', () async {
      final c = cursorOver(30);
      await c.loadMore();
      expect(c.items, hasLength(20));
    });

    test('the last page ends the list', () async {
      final c = cursorOver(25);
      await c.refresh();
      await c.loadMore();
      expect(c.items, hasLength(25));
      expect(c.hasMore, isFalse);
      await c.loadMore();
      expect(c.items, hasLength(25), reason: 'no request past the end');
    });

    test('shouldLoadMore is true within 10 items of the end', () async {
      final c = cursorOver(100);
      await c.refresh();
      expect(c.items, hasLength(20));
      expect(c.shouldLoadMore(8), isFalse);
      expect(c.shouldLoadMore(9), isTrue, reason: 'index 9 leaves 10 items after it');
      expect(c.shouldLoadMore(19), isTrue);
    });

    test('shouldLoadMore is false at the end, while loading and before any data', () async {
      final short = cursorOver(15);
      expect(short.shouldLoadMore(0), isFalse);
      await short.refresh();
      expect(short.shouldLoadMore(14), isFalse, reason: 'everything is loaded');

      final gate = Completer<void>();
      final slow = PaginationController<int>.cursor(
        loader: (cursor, limit) async {
          if (cursor != null) await gate.future;
          return CursorPage<int>([for (var i = 0; i < limit; i++) i], nextCursor: cursor == null ? '20' : null);
        },
      );
      await slow.refresh();
      final pending = slow.loadMore();
      expect(slow.isLoadingMore, isTrue);
      expect(slow.shouldLoadMore(19), isFalse, reason: 'a load is already running');
      gate.complete();
      await pending;
    });

    test('a second loadMore while one is running does not fetch twice', () async {
      var loads = 0;
      final gate = Completer<void>();
      final c = PaginationController<int>.cursor(
        loader: (cursor, limit) async {
          loads++;
          if (cursor != null) await gate.future;
          return CursorPage<int>([for (var i = 0; i < limit; i++) i], nextCursor: '${loads * 20}');
        },
      );
      await c.refresh();
      final first = c.loadMore();
      final second = c.loadMore();
      gate.complete();
      await Future.wait([first, second]);
      expect(loads, 2);
      expect(c.items, hasLength(40));
    });

    test('never keeps more than 50 items: the oldest fall off the front, only as many as needed', () async {
      final c = cursorOver(200);
      await c.refresh();
      await c.loadMore();
      expect(c.items, hasLength(40));
      expect(c.lastTrim.isEmpty, isTrue);
      await c.loadMore();
      expect(c.items, hasLength(50), reason: '60 loaded, exactly the 10 oldest were dropped');
      expect(c.items.first, 10);
      expect(c.items.last, 59);
      expect(c.trimmedFront, 10);
      expect(c.lastTrim.front, 10);
      expect(c.hasPrevious, isTrue);
      for (var i = 0; i < 5; i++) {
        await c.loadMore();
        expect(c.items.length, lessThanOrEqualTo(50));
        expect(c.items.first, c.trimmedFront, reason: 'trimmedFront is the absolute index of items.first');
      }
      expect(c.trimmedFront, greaterThan(10));
    });

    test('a reader guard keeps the rows on screen: trimming stops at the first visible item', () async {
      final c = cursorOver(200);
      await c.refresh();
      await c.loadMore();
      await c.loadMore(firstVisible: 3);
      expect(c.items.first, 3, reason: 'only the 3 items above the reader may go');
      expect(c.items, hasLength(57));
      expect(c.trimmedFront, 3);
      // Once the reader has moved on, the next load catches up.
      await c.loadMore(firstVisible: 30);
      expect(c.items.length, lessThanOrEqualTo(50));
      expect(c.items.first, c.trimmedFront);
    });

    test('loadPrevious puts the trimmed items back and trims the far end instead', () async {
      final c = cursorOver(200);
      await c.refresh();
      await c.loadMore();
      await c.loadMore();
      expect(c.items.first, 10);
      expect(c.shouldLoadPrevious(3), isTrue);
      await c.loadPrevious();
      expect(c.items.first, 0);
      expect(c.trimmedFront, 0);
      expect(c.items, hasLength(50));
      expect(c.items.last, 49);
      expect(c.lastTrim.back, 10);
      expect(c.hasPrevious, isFalse);
      expect(c.hasMore, isTrue);
    });

    test('loadPrevious with a reader guard never trims the rows on screen', () async {
      final c = cursorOver(200);
      await c.refresh();
      await c.loadMore();
      await c.loadMore();
      expect(c.items.first, 10);
      // The reader sees window rows 40..48 (items 50..58) when the head is put back.
      await c.loadPrevious(lastVisible: 48);
      expect(c.items.first, 0);
      expect(c.items.last, greaterThanOrEqualTo(58), reason: 'item 58 was on screen and stays');
      await c.loadPrevious(lastVisible: 0);
      expect(c.items.length, lessThanOrEqualTo(60));
    });

    test('loadMore reads the trimmed tail again before moving on', () async {
      final calls = <(String?, int)>[];
      final c = cursorOver(200, calls: calls);
      await c.refresh();
      await c.loadMore();
      await c.loadMore();
      await c.loadPrevious();
      expect(c.items.last, 49);
      calls.clear();
      await c.loadMore();
      expect(calls, [('40', 20)], reason: 'the page that was cut short is fetched again');
      expect(c.items.last, 59);
      expect(c.items.length, lessThanOrEqualTo(50));
    });

    test('however you scroll, the window is one unbroken run of the list', () async {
      final c = cursorOver(500);
      await c.refresh();
      final random = Random(42);
      for (var step = 0; step < 200; step++) {
        final action = random.nextInt(3);
        if (action == 0 && c.hasMore) {
          await c.loadMore(firstVisible: random.nextBool() ? null : random.nextInt(c.items.length));
        } else if (action == 1 && c.hasPrevious) {
          await c.loadPrevious(lastVisible: random.nextBool() ? null : random.nextInt(c.items.length));
        } else if (action == 2) {
          await c.loadMore();
        }
        for (var i = 1; i < c.items.length; i++) {
          expect(c.items[i], c.items[i - 1] + 1, reason: 'step $step');
        }
        expect(c.items.first, c.trimmedFront, reason: 'step $step');
      }
    });

    test('refresh restarts from the first page and bumps the epoch', () async {
      final c = cursorOver(100);
      await c.refresh();
      await c.loadMore();
      final epoch = c.epoch;
      await c.refresh();
      expect(c.items, hasLength(20));
      expect(c.items.first, 0);
      expect(c.epoch, greaterThan(epoch));
    });

    test('reset clears everything and returns to the initial state', () async {
      final c = cursorOver(100);
      await c.refresh();
      final epoch = c.epoch;
      c.reset();
      expect(c.items, isEmpty);
      expect(c.status, PaginationStatus.idle);
      expect(c.hasMore, isFalse);
      expect(c.hasError, isFalse);
      expect(c.trimmedFront, 0);
      expect(c.epoch, greaterThan(epoch));
    });

    test('a slow response that arrives after reset is ignored', () async {
      final gate = Completer<CursorPage<int>>();
      final c = PaginationController<int>.cursor(loader: (cursor, limit) => gate.future);
      final loading = c.refresh();
      expect(c.isInitialLoading, isTrue);
      c.reset();
      gate.complete(const CursorPage<int>([1, 2, 3]));
      await loading;
      expect(c.items, isEmpty);
      expect(c.status, PaginationStatus.idle);
    });

    test('a slow response for an outdated refresh does not overwrite the newer one', () async {
      final first = Completer<CursorPage<int>>();
      var call = 0;
      final c = PaginationController<int>.cursor(
        loader: (cursor, limit) {
          call++;
          if (call == 1) return first.future;
          return Future<CursorPage<int>>.value(const CursorPage<int>([7, 8]));
        },
      );
      final a = c.refresh();
      final b = c.refresh();
      await b;
      first.complete(const CursorPage<int>([1]));
      await a;
      expect(c.items, [7, 8]);
    });

    test('an empty result is an empty state, not an error', () async {
      final c = cursorOver(0);
      await c.refresh();
      expect(c.isEmpty, isTrue);
      expect(c.hasError, isFalse);
      expect(c.hasMore, isFalse);
    });

    test('an error is kept, and retry recovers', () async {
      var fail = true;
      final c = PaginationController<int>.cursor(
        loader: (cursor, limit) async {
          if (fail) throw StateError('offline');
          return const CursorPage<int>([1, 2]);
        },
      );
      await c.refresh();
      expect(c.hasError, isTrue);
      expect(c.status, PaginationStatus.error);
      expect(c.items, isEmpty);
      fail = false;
      await c.retry();
      expect(c.hasError, isFalse);
      expect(c.items, [1, 2]);
    });

    test('an error while loading more keeps what is already there', () async {
      var call = 0;
      final c = PaginationController<int>.cursor(
        loader: (cursor, limit) async {
          call++;
          if (call == 2) throw StateError('boom');
          return CursorPage<int>([for (var i = 0; i < 20; i++) i + (call - 1) * 20], nextCursor: '${call * 20}');
        },
      );
      await c.refresh();
      await c.loadMore();
      expect(c.hasError, isTrue);
      expect(c.items, hasLength(20));
      expect(c.shouldLoadMore(19), isFalse, reason: 'no automatic retry loop while in error');
      await c.retry();
      expect(c.hasError, isFalse);
      expect(c.items, hasLength(40));
    });

    test('notifies listeners and stays silent after dispose', () async {
      final c = cursorOver(30);
      var notified = 0;
      c.addListener(() => notified++);
      await c.refresh();
      expect(notified, greaterThanOrEqualTo(2), reason: 'loading, then ready');
      final gate = Completer<CursorPage<int>>();
      final d = PaginationController<int>.cursor(loader: (cursor, limit) => gate.future);
      final pending = d.refresh();
      d.dispose();
      gate.complete(const CursorPage<int>([1]));
      await pending;
    });
  });

  group('offset based (cookbook)', () {
    PaginationController<int> offsetOver(int total, List<(int, int)> calls) {
      return PaginationController<int>.offset(
        loader: (offset, limit) async {
          calls.add((offset, limit));
          final end = (offset + limit).clamp(0, total);
          return OffsetPage<int>([for (var i = offset; i < end; i++) i], total: total);
        },
      );
    }

    test('pages of 30 by offset and limit', () async {
      final calls = <(int, int)>[];
      final c = offsetOver(100, calls);
      await c.refresh();
      await c.loadMore();
      expect(calls, [(0, 30), (30, 30)]);
      // 60 items would exceed the 50 that may stay in memory: the 10 oldest fall off.
      expect(c.items, hasLength(50));
      expect(c.items.first, 10);
      expect(c.trimmedFront, 10);
      expect(c.hasPrevious, isTrue);
    });

    test('stops at the total', () async {
      final calls = <(int, int)>[];
      final c = offsetOver(45, calls);
      await c.refresh();
      await c.loadMore();
      expect(c.items, hasLength(45));
      expect(c.hasMore, isFalse);
      await c.loadMore();
      expect(calls, hasLength(2));
    });

    test('without a total a short page ends the list', () async {
      final c = PaginationController<int>.offset(
        loader: (offset, limit) async {
          return OffsetPage<int>([for (var i = 0; i < (offset == 0 ? limit : 5); i++) offset + i]);
        },
      );
      await c.refresh();
      await c.loadMore();
      expect(c.items, hasLength(35));
      expect(c.hasMore, isFalse);
    });

    test('prefetches within 10 items and never holds more than 50', () async {
      final c = offsetOver(500, <(int, int)>[]);
      await c.refresh();
      expect(c.shouldLoadMore(18), isFalse);
      expect(c.shouldLoadMore(19), isTrue);
      await c.loadMore();
      await c.loadMore();
      expect(c.items.length, lessThanOrEqualTo(50));
      expect(c.trimmedFront, greaterThan(0));
      expect(c.items.first, c.trimmedFront);
    });

    test('an empty cookbook is an empty state', () async {
      final c = offsetOver(0, <(int, int)>[]);
      await c.refresh();
      expect(c.isEmpty, isTrue);
    });
  });

  group('time based (history)', () {
    // An item is (week ordinal, label). Week 0 is the newest.
    PaginationController<(int, String)> historyOver(
      Map<int, List<(int, String)>> byPage,
      List<(int, int)> calls, {
      int pages = 10,
    }) {
      return PaginationController<(int, String)>.time(
        loader: (pageIndex, weeksPerPage) async {
          calls.add((pageIndex, weeksPerPage));
          return TimePage<(int, String)>(byPage[pageIndex] ?? const <(int, String)>[], hasMore: pageIndex < pages - 1);
        },
        groupOf: (item) => item.$1,
      );
    }

    test('loads seven weeks per page, newest first', () async {
      final calls = <(int, int)>[];
      final c = historyOver({
        0: [(0, 'a'), (0, 'b'), (2, 'c'), (6, 'd')],
        1: [(8, 'e'), (12, 'f')],
      }, calls);
      await c.refresh();
      expect(calls, [(0, 7)]);
      expect(c.items.map((e) => e.$2), ['a', 'b', 'c', 'd']);
      await c.loadMore();
      expect(calls.last, (1, 7));
      expect(c.items, hasLength(6));
    });

    test('prefetches when the reader is within one week of the last loaded week', () async {
      final c = historyOver({
        0: [(0, 'a'), (2, 'b'), (5, 'c'), (6, 'd')],
      }, <(int, int)>[]);
      await c.refresh();
      expect(c.shouldLoadMore(0), isFalse, reason: 'six weeks away from the end');
      expect(c.shouldLoadMore(1), isFalse, reason: 'four weeks away');
      expect(c.shouldLoadMore(2), isTrue, reason: 'one week away');
      expect(c.shouldLoadMore(3), isTrue);
    });

    test('a quiet stretch without cooking is skipped instead of stalling the list', () async {
      final calls = <(int, int)>[];
      final c = historyOver({
        0: [(1, 'a')],
        // pages 1 and 2 are empty
        3: [(23, 'z')],
      }, calls);
      await c.refresh();
      await c.loadMore();
      expect(c.items.map((e) => e.$2), ['a', 'z']);
      expect(calls.map((e) => e.$1), [0, 1, 2, 3]);
    });

    test('never holds more than 50 items', () async {
      final byPage = {
        for (var p = 0; p < 10; p++) p: [for (var i = 0; i < 20; i++) (p * 7 + i % 7, 'p$p-$i')],
      };
      final c = historyOver(byPage, <(int, int)>[]);
      await c.refresh();
      for (var i = 0; i < 5; i++) {
        await c.loadMore();
        expect(c.items.length, lessThanOrEqualTo(50));
      }
      expect(c.trimmedFront, greaterThan(0));
    });

    test('an empty history is an empty state', () async {
      final c = historyOver(<int, List<(int, String)>>{}, <(int, int)>[], pages: 1);
      await c.refresh();
      expect(c.isEmpty, isTrue);
    });
  });

  group('weekly (meal plan)', () {
    PaginationController<int> weeksOver(List<int> calls) {
      return PaginationController<int>.weekly(
        loader: (offset) async {
          calls.add(offset);
          return offset;
        },
      );
    }

    test('one week per page, unbounded forward', () async {
      final calls = <int>[];
      final c = weeksOver(calls);
      await c.refresh();
      expect(c.items, [0]);
      await c.loadMore();
      await c.loadMore();
      expect(c.items, [0, 1, 2]);
      expect(calls, [0, 1, 2]);
      expect(c.hasMore, isTrue);
    });

    test('keeps at most 4 weeks in memory', () async {
      final c = weeksOver(<int>[]);
      await c.refresh();
      for (var i = 0; i < 8; i++) {
        await c.loadMore();
        expect(c.items.length, lessThanOrEqualTo(4));
      }
      expect(c.items, [5, 6, 7, 8]);
      expect(c.trimmedFront, 5);
    });

    test('loadPrevious steps back one week, also before the first page', () async {
      final c = PaginationController<int>.weekly(startOffset: 0, loader: (offset) async => offset);
      await c.refresh();
      expect(c.hasPrevious, isTrue);
      await c.loadPrevious();
      await c.loadPrevious();
      expect(c.items, [-2, -1, 0]);
    });

    test('a prefetch threshold of 0 loads only at the last week', () async {
      final c = weeksOver(<int>[]);
      await c.refresh();
      await c.loadMore();
      expect(c.items, [0, 1]);
      expect(c.shouldLoadMore(0), isFalse);
      expect(c.shouldLoadMore(1), isTrue);
    });
  });
}
