import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/pagination.dart';

void main() {
  List<List<int>> pages(int count, int pageSize) =>
      [for (var p = 0; p * pageSize < count; p++)
        List.generate(
            (count - p * pageSize) > pageSize
                ? pageSize
                : count - p * pageSize,
            (i) => p * pageSize + i)];

  PaginationController<int> controllerFor(int total,
      {int pageSize = 20, int prefetch = 10, int maxRendered = 50}) {
    final source = pages(total, pageSize);
    return PaginationController<int>(
      pageSize: pageSize,
      prefetchThreshold: prefetch,
      maxRendered: maxRendered,
      fetchPage: (offset, limit) async {
        final pageIndex = offset ~/ limit;
        if (pageIndex >= source.length) return [];
        return source[pageIndex];
      },
    );
  }

  group('PaginationController', () {
    test('loadMore fetches sequential pages', () async {
      final c = controllerFor(45);
      await c.loadMore();
      expect(c.items.length, 20);
      await c.loadMore();
      expect(c.items.length, 40);
      await c.loadMore();
      expect(c.items.length, 45);
      expect(c.hasMore, isFalse);
      c.dispose();
    });

    test('shouldLoadMore fires within the prefetch window', () async {
      final c = controllerFor(100, prefetch: 10);
      await c.loadMore();
      expect(c.shouldLoadMore(0), isFalse);
      expect(c.shouldLoadMore(9), isFalse);
      expect(c.shouldLoadMore(10), isTrue); // 20 - 10
      expect(c.shouldLoadMore(19), isTrue);
      c.dispose();
    });

    test('refresh resets to page 1', () async {
      final c = controllerFor(45);
      await c.loadMore();
      await c.loadMore();
      expect(c.items.length, 40);
      await c.refresh();
      expect(c.items.length, 20);
      expect(c.items.first, 0);
      c.dispose();
    });

    test('reset clears everything', () async {
      final c = controllerFor(45);
      await c.loadMore();
      c.reset();
      expect(c.items, isEmpty);
      expect(c.hasMore, isTrue);
      expect(c.isLoading, isFalse);
      c.dispose();
    });

    test('never renders more than maxRendered items', () async {
      final c = controllerFor(200, pageSize: 20, maxRendered: 50);
      await c.loadMore();
      await c.loadMore();
      await c.loadMore();
      await c.loadMore(); // 80 fetched -> trimmed to 50
      expect(c.items.length, lessThanOrEqualTo(50));
      c.dispose();
    });

    test('errors surface and retry stays possible', () async {
      var calls = 0;
      final c = PaginationController<int>(
        pageSize: 20,
        fetchPage: (offset, limit) async {
          calls++;
          if (calls == 1) throw StateError('boom');
          return List.generate(20, (i) => i);
        },
      );
      await c.loadMore();
      expect(c.error, isNotNull);
      expect(c.items, isEmpty);
      await c.loadMore();
      expect(c.error, isNull);
      expect(c.items.length, 20);
      c.dispose();
    });

    test('isEmpty reflects state', () async {
      final c = controllerFor(0);
      expect(c.isEmpty, isTrue);
      await c.loadMore();
      expect(c.isEmpty, isTrue);
      c.dispose();
    });
  });
}
