import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/pagination/pagination_controller.dart';

void main() {
  group('PaginationController', () {
    test('loads pages until exhausted', () async {
      var calls = 0;
      final all = List.generate(85, (i) => i);
      final ctrl = PaginationController<int>(
        pageSize: 20,
        maxRendered: 200,
        prefetchThreshold: 5,
        fetcher: ({required offset, required pageIndex, required pageSize, cursor}) async {
          calls++;
          final page = all.skip(offset).take(pageSize).toList();
          return PageResult(items: page, hasMore: offset + page.length < all.length);
        },
      );

      await ctrl.loadMore();
      expect(ctrl.length, equals(20));
      expect(ctrl.isExhausted, isFalse);
      await ctrl.loadMore();
      await ctrl.loadMore();
      await ctrl.loadMore();
      await ctrl.loadMore(); // page 5 — only 5 left
      expect(ctrl.length, equals(85));
      expect(ctrl.isExhausted, isTrue);
      expect(calls, equals(5));
    });

    test('maxRendered trims old items', () async {
      final all = List.generate(60, (i) => i);
      final ctrl = PaginationController<int>(
        pageSize: 20,
        maxRendered: 30,
        prefetchThreshold: 5,
        fetcher: ({required offset, required pageIndex, required pageSize, cursor}) async {
          final page = all.skip(offset).take(pageSize).toList();
          return PageResult(items: page, hasMore: offset + page.length < all.length);
        },
      );
      await ctrl.loadMore();
      await ctrl.loadMore();
      await ctrl.loadMore();
      expect(ctrl.length, equals(30));
      // Items should be the tail (most recent)
      expect(ctrl.items.first, equals(30));
      expect(ctrl.items.last, equals(59));
    });

    test('shouldLoadMore respects prefetchThreshold', () async {
      final all = List.generate(50, (i) => i);
      final ctrl = PaginationController<int>(
        pageSize: 20,
        maxRendered: 100,
        prefetchThreshold: 5,
        fetcher: ({required offset, required pageIndex, required pageSize, cursor}) async {
          final page = all.skip(offset).take(pageSize).toList();
          return PageResult(items: page, hasMore: offset + page.length < all.length);
        },
      );
      await ctrl.loadMore();
      expect(ctrl.shouldLoadMore(10), isFalse); // far from end
      expect(ctrl.shouldLoadMore(15), isTrue); // within 5 of end
    });

    test('refresh resets state', () async {
      final all = List.generate(20, (i) => i);
      final ctrl = PaginationController<int>(
        pageSize: 10,
        maxRendered: 100,
        prefetchThreshold: 5,
        fetcher: ({required offset, required pageIndex, required pageSize, cursor}) async {
          final page = all.skip(offset).take(pageSize).toList();
          return PageResult(items: page, hasMore: offset + page.length < all.length);
        },
      );
      await ctrl.loadMore();
      expect(ctrl.length, equals(10));
      await ctrl.refresh();
      expect(ctrl.length, equals(10)); // refresh reloads page 1
    });
  });
}
