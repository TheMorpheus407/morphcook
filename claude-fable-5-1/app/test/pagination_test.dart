import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/pagination.dart';

void main() {
  Future<Page<int, int>> loader(int? cursor, int size) async {
    final start = cursor ?? 0;
    final items = List.generate(size, (i) => start + i);
    return Page(items: items, nextCursor: start + size);
  }

  test('loadMore appends pages and shouldLoadMore respects the threshold', () async {
    final c = PaginationController<int, int>(loader: loader, pageSize: 20, prefetchThreshold: 10, maxRendered: 50);
    expect(c.shouldLoadMore(0), isTrue);
    await c.loadMore();
    expect(c.items.length, 20);
    expect(c.shouldLoadMore(5), isFalse);
    expect(c.shouldLoadMore(10), isTrue);
    await c.loadMore();
    expect(c.items.length, 40);
  });

  test('never renders more than maxRendered', () async {
    final c = PaginationController<int, int>(loader: loader, pageSize: 20, prefetchThreshold: 10, maxRendered: 50);
    await c.loadMore();
    await c.loadMore();
    await c.loadMore();
    expect(c.items.length, 50);
    expect(c.capReached, isTrue);
    expect(c.hasMore, isFalse);
    expect(c.shouldLoadMore(49), isFalse);
  });

  test('reset clears and ignores stale loads', () async {
    var gate = Future<void>.value();
    Future<Page<int, int>> slow(int? cursor, int size) async {
      await gate;
      return loader(cursor, size);
    }

    final c = PaginationController<int, int>(loader: slow, pageSize: 5);
    final completer = Future<void>.delayed(const Duration(milliseconds: 20));
    gate = completer;
    final pending = c.loadMore();
    c.reset();
    await pending;
    expect(c.items, isEmpty);
    expect(c.isLoading, isFalse);
    gate = Future.value();
    await c.refresh();
    expect(c.items, [0, 1, 2, 3, 4]);
  });

  test('loader errors surface without losing state', () async {
    var fail = true;
    Future<Page<int, int>> flaky(int? cursor, int size) async {
      if (fail) throw StateError('boom');
      return loader(cursor, size);
    }

    final c = PaginationController<int, int>(loader: flaky, pageSize: 3);
    await c.loadMore();
    expect(c.error, isA<StateError>());
    fail = false;
    await c.loadMore();
    expect(c.error, isNull);
    expect(c.items, [0, 1, 2]);
  });

  test('offsetPage', () {
    final all = List.generate(7, (i) => i);
    final p1 = offsetPage(all, null, 3);
    expect(p1.items, [0, 1, 2]);
    expect(p1.nextCursor, 3);
    final p3 = offsetPage(all, 6, 3);
    expect(p3.items, [6]);
    expect(p3.nextCursor, isNull);
    expect(offsetPage(all, 99, 3).items, isEmpty);
  });

  test('timePage windows by weeks, newest first', () {
    final now = DateTime(2026, 9, 1);
    final entries = [
      now.subtract(const Duration(days: 1)),
      now.subtract(const Duration(days: 20)),
      now.subtract(const Duration(days: 60)),
      now.subtract(const Duration(days: 200)),
    ];
    final p1 = timePage<DateTime>(entries, (e) => e, null, 7, now: () => now);
    expect(p1.items.length, 2);
    expect(p1.nextCursor, isNotNull);
    final p2 = timePage<DateTime>(entries, (e) => e, p1.nextCursor, 7, now: () => now);
    expect(p2.items.length, 1);
    // The 97..146-day window is empty and gets skipped.
    final p3 = timePage<DateTime>(entries, (e) => e, p2.nextCursor, 7, now: () => now);
    expect(p3.items.length, 1);
    expect(p3.items.first, now.subtract(const Duration(days: 200)));
    expect(p3.nextCursor, isNull);
  });
}
