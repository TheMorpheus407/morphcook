import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/services/pagination_controller.dart';

void main() {
  group('PaginationPolicy', () {
    test('encodes every required view policy', () {
      const search = PaginationPolicy.search();
      expect(search.type, PaginationType.cursor);
      expect(search.pageSize, 20);
      expect(search.prefetchThreshold, 10);
      expect(search.maxRendered, 50);

      const cookbook = PaginationPolicy.cookbook();
      expect(cookbook.type, PaginationType.offset);
      expect(cookbook.pageSize, 30);
      expect(cookbook.prefetchThreshold, 10);
      expect(cookbook.maxRendered, 50);

      const history = PaginationPolicy.history();
      expect(history.type, PaginationType.time);
      expect(history.pageSize, 7);
      expect(history.prefetchThreshold, 1);
      expect(history.maxRendered, 50);

      const mealPlan = PaginationPolicy.mealPlan();
      expect(mealPlan.type, PaginationType.weekly);
      expect(mealPlan.pageSize, 1);
      expect(mealPlan.prefetchThreshold, 0);
      expect(mealPlan.maxRendered, 4);
    });
  });

  test('cursor loading prefetches and retains at most 50 rows', () async {
    final requests = <PaginationRequest>[];
    final controller = PaginationController<int>(
      policy: const PaginationPolicy.search(),
      loader: (request) async {
        requests.add(request);
        return PaginationPage<int>(
          items: List<int>.generate(
            request.limit,
            (index) => request.offset + index,
          ),
          nextCursor: 'cursor-${request.pageIndex + 1}',
          hasMore: request.pageIndex < 2,
        );
      },
    );

    await controller.loadMore();
    expect(controller.items, hasLength(20));
    expect(controller.shouldLoadMore(8), isFalse);
    expect(controller.shouldLoadMore(9), isTrue);

    await controller.loadMore();
    await controller.loadMore();
    expect(controller.items, hasLength(50));
    expect(controller.items.first, 10);
    expect(controller.evictedCount, 10);
    expect(controller.fetchedItemCount, 60);
    expect(requests.map((request) => request.cursor), <String?>[
      null,
      'cursor-1',
      'cursor-2',
    ]);
    expect(controller.hasMore, isFalse);
  });

  test('weekly threshold and render window use week units', () async {
    final controller = PaginationController<String>(
      policy: const PaginationPolicy.mealPlan(),
      loader: (request) async => PaginationPage<String>(
        items: <String>['week-${request.pageIndex}'],
        nextAnchor: 'week-${request.pageIndex + 1}',
        unitsLoaded: 1,
        hasMore: request.pageIndex < 4,
      ),
    );

    await controller.loadMore();
    expect(controller.shouldLoadMore(0, visibleUnitIndex: 0), isTrue);
    for (var index = 0; index < 4; index++) {
      await controller.loadMore();
    }
    expect(controller.items, <String>['week-1', 'week-2', 'week-3', 'week-4']);
    expect(controller.evictedCount, 1);
  });

  test('refresh invalidates a stale in-flight page', () async {
    final first = Completer<PaginationPage<int>>();
    final second = Completer<PaginationPage<int>>();
    var calls = 0;
    final controller = PaginationController<int>(
      policy: const PaginationPolicy.search(),
      loader: (_) => calls++ == 0 ? first.future : second.future,
    );

    final staleLoad = controller.loadMore();
    controller.reset();
    final currentLoad = controller.loadMore();
    first.complete(PaginationPage<int>(items: <int>[1], hasMore: false));
    second.complete(PaginationPage<int>(items: <int>[2], hasMore: false));
    await Future.wait(<Future<void>>[staleLoad, currentLoad]);

    expect(controller.items, <int>[2]);
    expect(controller.isLoading, isFalse);
  });

  test('surfaces errors and retries the same page', () async {
    var calls = 0;
    final controller = PaginationController<int>(
      policy: const PaginationPolicy.cookbook(),
      loader: (request) async {
        if (calls++ == 0) throw StateError('disk busy');
        expect(request.pageIndex, 0);
        expect(request.offset, 0);
        return PaginationPage<int>(items: <int>[7], hasMore: false);
      },
    );

    await controller.loadMore();
    expect(controller.error, isA<StateError>());
    expect(controller.items, isEmpty);

    await controller.loadMore();
    expect(controller.error, isNull);
    expect(controller.items, <int>[7]);
  });

  test('disposing invalidates an in-flight page without notifying', () async {
    final pending = Completer<PaginationPage<int>>();
    final controller = PaginationController<int>(
      policy: const PaginationPolicy.search(),
      loader: (_) => pending.future,
    );
    final load = controller.loadMore();
    controller.dispose();
    pending.complete(PaginationPage<int>(items: <int>[1], hasMore: false));
    await expectLater(load, completes);
  });
}
