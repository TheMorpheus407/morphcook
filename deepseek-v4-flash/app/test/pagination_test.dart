import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/pagination.dart';

void main() {
  group('paginate', () {
    final items = List.generate(25, (i) => 'item$i');

    test('first page', () {
      expect(paginate(items, 1), ['item0', 'item1', 'item2', 'item3', 'item4',
          'item5', 'item6', 'item7', 'item8', 'item9']);
    });

    test('middle page', () {
      expect(paginate(items, 2).first, 'item10');
      expect(paginate(items, 2).length, 10);
    });

    test('last partial page and out-of-range page', () {
      expect(paginate(items, 3).length, 5);
      expect(paginate(items, 4), isEmpty);
    });
  });

  group('paginateByDate', () {
    test('pages walk back in time from the anchor', () {
      final now = DateTime(2026, 8, 5);
      final entries = [
        (id: 'd0', at: now.subtract(const Duration(days: 0))),
        (id: 'd1', at: now.subtract(const Duration(days: 1))),
        (id: 'd2', at: now.subtract(const Duration(days: 2))),
        (id: 'd3', at: now.subtract(const Duration(days: 3))),
        (id: 'd4', at: now.subtract(const Duration(days: 4))),
      ];
      String dateOf(({String id, DateTime at}) e) => e.at.toIso8601String();
      DateTime parse(String s) => DateTime.parse(s);

      final page1 = paginateByDate(entries, now, 1,
          pageSize: 3, dateOf: (e) => parse(dateOf(e)));
      expect(page1.map((e) => e.id), ['d0', 'd1', 'd2']);

      final page2 = paginateByDate(entries, now, 2,
          pageSize: 3, dateOf: (e) => parse(dateOf(e)));
      expect(page2.map((e) => e.id), ['d3', 'd4']);
    });
  });

  group('PaginationController', () {
    test('loadMore appends pages until hasMore is false', () async {
      final controller = PaginationController<String>();
      final all = List.generate(23, (i) => 'r$i');
      controller.setFetcher((cursor, page) async {
        final items = paginate(all, page, pageSize: 10);
        return PageResult(
          items: items,
          hasMore: page * 10 < all.length,
          nextCursor: page * 10,
        );
      });

      await controller.loadMore();
      expect(controller.items.length, 10);
      expect(controller.hasMore, isTrue);
      expect(controller.pageCount, 1);

      await controller.loadMore();
      await controller.loadMore();
      expect(controller.items.length, 23);
      expect(controller.hasMore, isFalse);
    });

    test('loadMore is idempotent while loading', () async {
      final controller = PaginationController<String>();
      var calls = 0;
      controller.setFetcher((cursor, page) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return PageResult(items: ['x'], hasMore: true, nextCursor: 1);
      });
      final futures = [controller.loadMore(), controller.loadMore()];
      await Future.wait(futures);
      expect(calls, 1);
    });

    test('shouldLoadMore triggers near the bottom of the visible list', () async {
      final controller = PaginationController<String>();
      final all = List.generate(60, (i) => 'r$i');
      controller.setFetcher((cursor, page) async {
        return PageResult(
          items: paginate(all, page, pageSize: 10),
          hasMore: page * 10 < all.length,
        );
      });
      await controller.loadMore(); // 10 items
      // index 8 of a 10-item visible list = 2 from the end < prefetchThreshold
      controller.shouldLoadMore(8);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.items.length, 20);
    });

    test('staleness: rendered near maxRendered triggers a fetch', () async {
      final controller = PaginationController<String>(
        maxRendered: 12,
        prefetchThreshold: 3,
      );
      final all = List.generate(30, (i) => 'r$i');
      controller.setFetcher((cursor, page) async {
        return PageResult(
          items: paginate(all, page, pageSize: 10),
          hasMore: page * 10 < all.length,
        );
      });
      await controller.loadMore();
      await controller.loadMore(); // 20 items
      expect(controller.shouldLoadMoreByStaleness(11), isFalse);
      expect(controller.shouldLoadMoreByStaleness(13), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.items.length, 30);
    });

    test('refresh keeps a backfill window of first items', () async {
      final controller = PaginationController<String>(keepFirstN: 2);
      final all = List.generate(25, (i) => 'r$i');
      controller.setFetcher((cursor, page) async {
        return PageResult(
          items: paginate(all, page, pageSize: 10),
          hasMore: page * 10 < all.length,
        );
      });
      await controller.loadMore();
      await controller.loadMore();
      expect(controller.items, hasLength(20));

      await controller.refresh();
      // kept window (r0,r1) stays on top, remaining page items are appended
      expect(controller.items.first, 'r0');
      expect(controller.items.last, 'r9');
      expect(controller.items.length, 10);
    });

    test('fetcher errors surface as error and stop paging', () async {
      final controller = PaginationController<String>();
      controller.setFetcher((cursor, page) async {
        throw Exception('boom');
      });
      await controller.loadMore();
      expect(controller.error, isNotNull);
      expect(controller.loading, isFalse);
      expect(controller.hasMore, isFalse);
    });
  });
}