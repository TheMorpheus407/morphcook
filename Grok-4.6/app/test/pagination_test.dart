import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/pagination.dart';

void main() {
  test('loadMore pages and stops', () async {
    final source = List.generate(45, (i) => i);
    final pager = PaginationController<int>(
      fetch: offsetPager(source),
      pageSize: 20,
      prefetchThreshold: 10,
      maxRendered: 50,
    );
    await pager.loadMore();
    expect(pager.items, hasLength(20));
    expect(pager.hasMore, isTrue);
    await pager.loadMore();
    expect(pager.items, hasLength(40));
    await pager.loadMore();
    expect(pager.items, hasLength(45));
    expect(pager.hasMore, isFalse);
    pager.dispose();
  });

  test('maxRendered disposes oldest items', () async {
    final source = List.generate(80, (i) => i);
    final pager = PaginationController<int>(
      fetch: offsetPager(source),
      pageSize: 20,
      maxRendered: 50,
    );
    await pager.loadMore();
    await pager.loadMore();
    await pager.loadMore();
    expect(pager.items.length, lessThanOrEqualTo(50));
    expect(pager.disposedCount, greaterThan(0));
    pager.dispose();
  });

  test('shouldLoadMore respects prefetch threshold', () async {
    final pager = PaginationController<int>(
      fetch: offsetPager(List.generate(40, (i) => i)),
      pageSize: 20,
      prefetchThreshold: 10,
    );
    await pager.loadMore();
    expect(pager.shouldLoadMore(5), isFalse);
    expect(pager.shouldLoadMore(11), isTrue);
    pager.dispose();
  });

  test('refresh resets then reloads', () async {
    final pager = PaginationController<int>(
      fetch: offsetPager(List.generate(5, (i) => i)),
      pageSize: 2,
    );
    await pager.loadMore();
    await pager.refresh();
    expect(pager.items, [0, 1]);
    pager.dispose();
  });
}
