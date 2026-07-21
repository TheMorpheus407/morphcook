import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/services/pagination_controller.dart';

void main() {
  test('cursor controller loads, prefetches and caps rendered items', () async {
    final source = List.generate(80, (index) => index);
    final controller = PaginationController<int>(
      pageSize: 20,
      prefetchThreshold: 10,
      maxRendered: 50,
      loader: (cursor, limit) async {
        final start = int.tryParse(cursor ?? '0') ?? 0;
        final end = (start + limit).clamp(0, source.length);
        return PageChunk(
          items: source.sublist(start, end),
          nextCursor: end < source.length ? '$end' : null,
        );
      },
    );
    await controller.loadMore();
    expect(controller.items, hasLength(20));
    expect(controller.shouldLoadMore(9), isFalse);
    expect(controller.shouldLoadMore(10), isTrue);
    await controller.loadMore();
    await controller.loadMore();
    expect(controller.items, hasLength(50));
    expect(controller.hasMore, isFalse);
  });

  test('refresh resets cursor and errors remain recoverable', () async {
    var fail = true;
    final controller = PaginationController<int>(
      loader: (_, _) async {
        if (fail) throw StateError('temporary');
        return const PageChunk(items: [1, 2]);
      },
    );
    await controller.loadMore();
    expect(controller.error, isA<StateError>());
    fail = false;
    await controller.refresh();
    expect(controller.error, isNull);
    expect(controller.items, [1, 2]);
  });

  test('offset controller uses 30-item pages and a 50-item cap', () {
    final controller = OffsetPagination<int>(
      source: () => List.generate(90, (index) => index),
    );
    controller.loadMore();
    expect(controller.items, hasLength(30));
    controller.loadMore();
    expect(controller.items, hasLength(50));
    expect(controller.hasMore, isFalse);
  });
}
