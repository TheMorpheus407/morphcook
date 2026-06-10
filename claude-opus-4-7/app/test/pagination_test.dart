import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/pagination/pagination_controller.dart';

void main() {
  group('PaginationController', () {
    test('offset mode paginates and stops at end', () async {
      final data = List.generate(45, (i) => 'item-$i');
      final ctrl = PaginationController<String>(
        mode: PaginationMode.offset,
        pageSize: 20,
        prefetchThreshold: 5,
        maxRendered: 50,
        fetcher: (req) async {
          final slice = data.skip(req.offset).take(req.limit).toList();
          return PageResult(
            items: slice,
            hasMore: req.offset + slice.length < data.length,
          );
        },
      );
      await ctrl.loadMore();
      expect(ctrl.items.length, 20);
      expect(ctrl.hasMore, isTrue);
      await ctrl.loadMore();
      expect(ctrl.items.length, 40);
      await ctrl.loadMore();
      expect(ctrl.items.length, 45);
      expect(ctrl.hasMore, isFalse);
    });

    test('shouldLoadMore respects prefetch threshold', () async {
      final ctrl = PaginationController<int>(
        mode: PaginationMode.offset,
        pageSize: 10,
        prefetchThreshold: 3,
        maxRendered: 50,
        fetcher: (req) async => PageResult(
          items: List.generate(10, (i) => req.offset + i),
          hasMore: true,
        ),
      );
      await ctrl.loadMore();
      expect(ctrl.shouldLoadMore(6), isFalse);
      expect(ctrl.shouldLoadMore(7), isTrue);
    });

    test('maxRendered caps the live list', () async {
      final ctrl = PaginationController<int>(
        mode: PaginationMode.cursor,
        pageSize: 20,
        prefetchThreshold: 5,
        maxRendered: 30,
        fetcher: (req) async => PageResult(
          items: List.generate(20, (i) => (req.offset) + i),
          hasMore: true,
        ),
      );
      await ctrl.loadMore();
      await ctrl.loadMore();
      expect(ctrl.items.length, lessThanOrEqualTo(30));
    });
  });
}
