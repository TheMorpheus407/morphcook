import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/pagination.dart';

void main() {
  group('PageSlice', () {
    test('offset slicing with hasMore', () {
      final all = List.generate(55, (i) => i);
      final page = PageSlice.offset(all, 0, 20);
      expect(page.items.length, 20);
      expect(page.hasMore, isTrue);

      final page2 = PageSlice.offset(all, 20, 20);
      expect(page2.items.first, 20);

      final last = PageSlice.offset(all, 40, 20);
      expect(last.items.length, 15);
      expect(last.hasMore, isFalse);
    });

    test('cursor slicing with nextCursor', () {
      final all = List.generate(45, (i) => i);
      final page = PageSlice.cursor(all, 0, 20);
      expect(page.nextCursor, '20');
      expect(page.hasMore, isTrue);
      final page2 = PageSlice.cursor(all, 20, 20);
      expect(page2.nextCursor, '40');
      final last = PageSlice.cursor(all, 40, 20);
      expect(last.nextCursor, isNull);
      expect(last.hasMore, isFalse);
    });
  });

  group('PaginationController', () {
    test('loadMore fetches pages and appends', () async {
      final all = List.generate(50, (i) => i);
      final c = PaginationController<int>(
        pageSize: 20,
        prefetchThreshold: 10,
        fetcher: (offset, _) async => PageSlice.offset(all, offset, 20),
      );
      await c.loadMore();
      expect(c.items.length, 20);
      expect(c.hasMore, isTrue);
      await c.loadMore();
      expect(c.items.length, 40);
      await c.loadMore();
      expect(c.items.length, 50);
      expect(c.hasMore, isFalse);
    });

    test('shouldLoadMore triggers within prefetch threshold', () async {
      final all = List.generate(100, (i) => i);
      final c = PaginationController<int>(
        pageSize: 20,
        prefetchThreshold: 10,
        fetcher: (offset, _) async => PageSlice.offset(all, offset, 20),
      );
      await c.loadMore();
      expect(c.items.length, 20);
      expect(c.shouldLoadMore(9), isFalse); // 20-9=11 > 10
      expect(c.shouldLoadMore(10), isTrue); // 20-10=10 ≤ 10
      expect(c.shouldLoadMore(19), isTrue);
    });

    test('refresh resets and reloads from page 1', () async {
      final all = List.generate(30, (i) => i);
      var requests = 0;
      final c = PaginationController<int>(
        pageSize: 20,
        prefetchThreshold: 10,
        fetcher: (offset, _) async {
          requests++;
          return PageSlice.offset(all, offset, 20);
        },
      );
      await c.loadMore();
      await c.loadMore();
      expect(c.items.length, 30);
      await c.refresh();
      expect(c.items.length, 20);
      expect(requests, 3);
    });

    test('reset clears everything', () async {
      final all = List.generate(30, (i) => i);
      final c = PaginationController<int>(
        pageSize: 20,
        prefetchThreshold: 10,
        fetcher: (offset, _) async => PageSlice.offset(all, offset, 20),
      );
      await c.loadMore();
      c.reset();
      expect(c.items, isEmpty);
      expect(c.hasMore, isTrue);
    });

    test('error is surfaced', () async {
      final c = PaginationController<int>(
        pageSize: 20,
        prefetchThreshold: 10,
        fetcher: (_, _) async => throw Exception('boom'),
      );
      await c.loadMore();
      expect(c.hasError, isTrue);
      expect(c.error, isA<Exception>());
    });

    test('max rendered window is respected', () async {
      final all = List.generate(200, (i) => i);
      final c = PaginationController<int>(
        pageSize: 20,
        prefetchThreshold: 10,
        maxRendered: 50,
        fetcher: (offset, _) async => PageSlice.offset(all, offset, 20),
      );
      await c.loadMore();
      await c.loadMore();
      await c.loadMore();
      expect(c.items.length, 60);
      expect(c.renderedItems.length, 50);
    });
  });
}
