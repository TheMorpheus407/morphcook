import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/src/domain/pagination_controller.dart';

void main() {
  group('offset pagination', () {
    test('loads pages of the configured size', () async {
      final controller = PaginationController<int>(
        type: PaginationType.offset,
        pageSize: 10,
        fetchPage: (request) async {
          final start = request.offset;
          final end = (start + request.limit).clamp(0, 35);
          return PageResult<int>(
            items: List<int>.generate(end - start, (index) => start + index),
            hasMore: end < 35,
          );
        },
      );

      await controller.loadMore();

      expect(controller.items.length, 10);
      expect(controller.hasMore, isTrue);
    });

    test('stops when the source runs out', () async {
      final controller = PaginationController<int>(
        type: PaginationType.offset,
        pageSize: 10,
        fetchPage: (request) async {
          final start = request.offset;
          if (start >= 5) {
            return const PageResult<int>(items: <int>[], hasMore: false);
          }
          return PageResult<int>(
            items: List<int>.generate(5, (index) => start + index),
            hasMore: false,
          );
        },
      );

      await controller.loadMore();
      await controller.loadMore();

      expect(controller.items.length, 5);
      expect(controller.hasMore, isFalse);
    });

    test('refresh restarts from the first page', () async {
      var call = 0;
      final controller = PaginationController<int>(
        type: PaginationType.offset,
        pageSize: 5,
        fetchPage: (request) async {
          call++;
          return PageResult<int>(
            items: List<int>.generate(5, (index) => call * 100 + index),
            hasMore: true,
          );
        },
      );

      await controller.loadMore();
      await controller.loadMore();
      expect(controller.items.length, 10);

      await controller.refresh();

      expect(controller.items.length, 5);
      expect(controller.offset, 5);
    });

    test('reset clears everything', () async {
      final controller = PaginationController<int>(
        type: PaginationType.offset,
        pageSize: 5,
        fetchPage: (request) async =>
            PageResult<int>(items: <int>[1, 2, 3], hasMore: true),
      );

      await controller.loadMore();
      controller.reset();

      expect(controller.items, isEmpty);
      expect(controller.hasMore, isTrue);
      expect(controller.isLoading, isFalse);
    });
  });

  group('cursor pagination', () {
    test('passes the cursor back to the fetcher', () async {
      final seen = <String?>[];
      final controller = PaginationController<int>(
        type: PaginationType.cursor,
        pageSize: 3,
        fetchPage: (request) async {
          seen.add(request.cursor);
          final offset = int.parse(request.cursor ?? '0');
          return PageResult<int>(
            items: <int>[offset, offset + 1, offset + 2],
            nextCursor: '${offset + 3}',
            hasMore: offset + 3 < 9,
          );
        },
      );

      await controller.loadMore();
      await controller.loadMore();

      expect(seen, <String?>[null, '3']);
      expect(controller.items.length, 6);
    });

    test('the cursor token is exposed', () async {
      final controller = PaginationController<int>(
        type: PaginationType.cursor,
        fetchPage: (request) async => const PageResult<int>(
          items: <int>[1],
          nextCursor: 'abc',
          hasMore: true,
        ),
      );

      await controller.loadMore();

      expect(controller.nextCursor, 'abc');
    });
  });

  group('prefetching', () {
    test('loads more when the user nears the end', () async {
      final controller = PaginationController<int>(
        type: PaginationType.offset,
        pageSize: 20,
        prefetchThreshold: 10,
        fetchPage: (request) async =>
            PageResult<int>(items: List<int>.filled(20, 1), hasMore: true),
      );

      await controller.loadMore();

      expect(controller.shouldLoadMore(0), isFalse);
      expect(controller.shouldLoadMore(10), isTrue);
      expect(controller.shouldLoadMore(19), isTrue);
    });

    test('does not load more when there is nothing more', () async {
      final controller = PaginationController<int>(
        type: PaginationType.offset,
        fetchPage: (request) async =>
            const PageResult<int>(items: <int>[1], hasMore: false),
      );

      await controller.loadMore();

      expect(controller.shouldLoadMore(0), isFalse);
    });
  });

  group('render cap', () {
    test('never renders more than the maximum', () async {
      final controller = PaginationController<int>(
        type: PaginationType.offset,
        pageSize: 30,
        maxRendered: 50,
        fetchPage: (request) async => PageResult<int>(
          items: List<int>.filled(request.limit, 1),
          hasMore: true,
        ),
      );

      await controller.loadMore();
      await controller.loadMore();

      expect(controller.allItems.length, 60);
      expect(controller.items.length, 50);
      expect(controller.isAtCapacity, isTrue);
    });
  });

  group('errors', () {
    test('an error is captured, not thrown', () async {
      final controller = PaginationController<int>(
        type: PaginationType.offset,
        fetchPage: (request) async => throw StateError('boom'),
      );

      await controller.loadMore();

      expect(controller.error, isA<StateError>());
      expect(controller.isLoading, isFalse);
    });
  });
}
