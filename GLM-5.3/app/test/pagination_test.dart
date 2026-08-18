import 'package:flutter_test/flutter_test.dart';

import 'package:morphcook/core/pagination/pagination_controller.dart';

void main() {
  group('PaginationController', () {
    test('loads pages until exhausted with cursor tokens', () async {
      final pager = PaginationController<int>(
        pageSize: 2,
        fetch: (cursor) async {
          final offset = int.parse(cursor ?? '0');
          final slice = [1, 2, 3, 4, 5].skip(offset).take(2).toList();
          final next = offset + slice.length;
          return Page(items: slice, nextCursor: next < 5 ? '$next' : null);
        },
      );
      await pager.loadMore();
      expect(pager.items, [1, 2]);
      expect(pager.hasMore, isTrue);
      await pager.loadMore();
      await pager.loadMore();
      expect(pager.items, [1, 2, 3, 4, 5]);
      expect(pager.hasMore, isFalse);
      // Further loadMore is a no-op.
      await pager.loadMore();
      expect(pager.items.length, 5);
    });

    test('shouldLoadMore triggers within the prefetch threshold', () async {
      final pager = PaginationController<int>(
        pageSize: 20,
        prefetchThreshold: 10,
        maxItems: 100,
        fetch: (cursor) async =>
            Page(items: List.generate(20, (i) => i), nextCursor: 'x'),
      );
      await pager.loadMore();
      expect(pager.items.length, 20);
      expect(pager.shouldLoadMore(9), isTrue);
      expect(pager.shouldLoadMore(8), isFalse);
      expect(pager.shouldLoadMore(25), isTrue);
    });

    test('max rendered guardrail caps items and ends pagination', () async {
      final pager = PaginationController<int>(
        pageSize: 30,
        maxItems: 50,
        fetch: (cursor) async {
          final offset = int.parse(cursor ?? '0');
          final slice = List.generate(30, (i) => offset + i);
          return Page(items: slice, nextCursor: '${offset + 30}');
        },
      );
      await pager.loadMore(); // 30
      await pager.loadMore(); // capped at 50
      expect(pager.items.length, 50);
      expect(pager.hasMore, isFalse);
    });

    test('refresh resets and reloads from page 1', () async {
      var counter = 0;
      final pager = PaginationController<String>(
        pageSize: 1,
        maxItems: 10,
        fetch: (cursor) async {
          counter++;
          return Page(items: ['v$counter'], nextCursor: null);
        },
      );
      await pager.loadMore();
      expect(pager.items, ['v1']);
      await pager.refresh();
      expect(pager.items, ['v2']);
      expect(pager.hasMore, isFalse);
    });

    test('reset clears to initial state', () async {
      final pager = PaginationController<int>(
        fetch: (cursor) async => Page(items: [1], nextCursor: 'more'),
      );
      await pager.loadMore();
      expect(pager.items, isNotEmpty);
      pager.reset();
      expect(pager.items, isEmpty);
      expect(pager.hasMore, isTrue);
      expect(pager.isInitial, isTrue);
    });

    test('errors surface without killing the controller', () async {
      final pager = PaginationController<int>(
        fetch: (cursor) async => throw Exception('shelf collapsed'),
      );
      await pager.loadMore();
      expect(pager.error, isNotNull);
      expect(pager.items, isEmpty);
      expect(pager.isLoading, isFalse);
    });
  });
}
