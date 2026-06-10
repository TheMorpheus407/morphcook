import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/pagination.dart';

/// An in-memory fetcher slicing a list by int cursor — the pattern every
/// paginated view uses.
PageFetcher<int> sliceFetcher(List<int> data, int pageSize) {
  return (cursor) async {
    final start = (cursor as int?) ?? 0;
    final end = (start + pageSize).clamp(0, data.length);
    return Page<int>(
      items: data.sublist(start, end),
      nextCursor: end,
      hasMore: end < data.length,
    );
  };
}

void main() {
  test('loadMore accumulates pages and reports hasMore', () async {
    final c = PaginationController<int>(
      fetcher: sliceFetcher(List.generate(45, (i) => i), 20),
      type: PaginationType.cursor,
      pageSize: 20,
    );
    await c.loadMore();
    expect(c.items.length, 20);
    expect(c.hasMore, isTrue);
    await c.loadMore();
    expect(c.items.length, 40);
    await c.loadMore();
    expect(c.items.length, 45);
    expect(c.hasMore, isFalse);
  });

  test('maxRendered caps the rendered window', () async {
    final c = PaginationController<int>(
      fetcher: sliceFetcher(List.generate(200, (i) => i), 30),
      type: PaginationType.offset,
      pageSize: 30,
      maxRendered: 50,
    );
    for (var i = 0; i < 6; i++) {
      await c.loadMore();
    }
    expect(c.items.length, lessThanOrEqualTo(50));
  });

  test('shouldLoadMore fires inside the prefetch threshold', () async {
    final c = PaginationController<int>(
      fetcher: sliceFetcher(List.generate(100, (i) => i), 20),
      type: PaginationType.cursor,
      pageSize: 20,
      prefetchThreshold: 10,
    );
    await c.loadMore(); // 20 items
    expect(c.shouldLoadMore(8), isFalse); // 8 < 20-10
    expect(c.shouldLoadMore(12), isTrue); // within threshold
  });

  test('empty dataset reports isEmpty', () async {
    final c = PaginationController<int>(
      fetcher: sliceFetcher(<int>[], 20),
      type: PaginationType.cursor,
    );
    await c.loadMore();
    expect(c.isEmpty, isTrue);
    expect(c.hasMore, isFalse);
  });

  test('refresh resets and reloads', () async {
    final c = PaginationController<int>(
      fetcher: sliceFetcher(List.generate(10, (i) => i), 20),
      type: PaginationType.cursor,
    );
    await c.loadMore();
    expect(c.items.length, 10);
    await c.refresh();
    expect(c.items.length, 10);
    expect(c.isInitialLoaded, isTrue);
  });

  test('reset clears items', () async {
    final c = PaginationController<int>(
      fetcher: sliceFetcher(List.generate(10, (i) => i), 20),
      type: PaginationType.cursor,
    );
    await c.loadMore();
    c.reset();
    expect(c.items, isEmpty);
    expect(c.isInitialLoaded, isFalse);
  });
}
