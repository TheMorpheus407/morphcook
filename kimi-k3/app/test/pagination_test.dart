import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/engine/pagination.dart';

void main() {
  group('PaginationController', () {
    PaginationController<int> makeController(int total,
            {int pageSize = 20, int maxRendered = 50}) =>
        PaginationController<int>(
          pageSize: pageSize,
          maxRendered: maxRendered,
          prefetchThreshold: 10,
          fetchPage: (cursor) async {
            final start = cursor == null ? 0 : int.parse(cursor);
            if (start >= total) return const [];
            return List.generate(
                (start + pageSize).clamp(0, total) - start, (i) => start + i);
          },
          nextCursorOf: null, // offset fallback
        );

    test('loads pages until exhausted', () async {
      final c = makeController(45, pageSize: 20);
      await c.loadMore();
      expect(c.items, hasLength(20));
      expect(c.hasMore, isTrue);
      await c.loadMore();
      expect(c.items, hasLength(40));
      await c.loadMore();
      expect(c.items, hasLength(45));
      expect(c.hasMore, isFalse);
      await c.loadMore(); // no-op
      expect(c.items, hasLength(45));
    });

    test('never renders more than maxRendered', () async {
      final c = makeController(200, pageSize: 30, maxRendered: 50);
      await c.loadMore();
      await c.loadMore();
      await c.loadMore();
      expect(c.items.length, lessThanOrEqualTo(50));
    });

    test('shouldLoadMore fires within the prefetch threshold', () {
      final c = makeController(100);
      c.items.addAll(List.generate(20, (i) => i));
      expect(c.shouldLoadMore(5), isFalse);
      expect(c.shouldLoadMore(10), isTrue);
      expect(c.shouldLoadMore(19), isTrue);
    });

    test('refresh resets to the first page', () async {
      final c = makeController(45);
      await c.loadMore();
      await c.loadMore();
      await c.refresh();
      expect(c.items, hasLength(20));
      expect(c.items.first, 0);
    });

    test('reset clears all state', () async {
      final c = makeController(45);
      await c.loadMore();
      c.reset();
      expect(c.items, isEmpty);
      expect(c.hasMore, isTrue);
      expect(c.isLoading, isFalse);
    });

    test('errors are captured, loading flag cleared', () async {
      final c = PaginationController<int>(
        fetchPage: (_) async => throw StateError('boom'),
      );
      await c.loadMore();
      expect(c.error, isA<StateError>());
      expect(c.isLoading, isFalse);
    });
  });
}
