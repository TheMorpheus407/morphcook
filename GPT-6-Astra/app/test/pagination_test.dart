import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/models.dart';
import 'package:morphcook/core/pagination.dart';

void main() {
  test('cursor pages remain stable when an earlier item is inserted', () async {
    final data = List.generate(65, (i) => 'recipe-$i');
    final controller = PaginationController<String>(
      loader: (request) async => cursorPage(data, request, (id) => id),
    );
    await controller.loadMore();
    expect(controller.items.length, 20);
    expect(controller.nextCursor, 'recipe-19');
    data.insert(0, 'new-first');
    await controller.loadMore();
    expect(controller.items.skip(20).first, 'recipe-20');
    expect(controller.items.toSet().length, 40);
    controller.dispose();
  });

  test(
    'rendering window caps at 50 and cached records allow seamless backward scroll',
    () async {
      final requests = <PageRequest>[];
      final data = List.generate(95, (i) => i);
      final controller = PaginationController<int>(
        type: PaginationType.offset,
        pageSize: 30,
        loader: (request) async {
          requests.add(request);
          return offsetPage(data, request);
        },
      );
      await controller.loadMore();
      expect(controller.shouldLoadMore(18), isFalse);
      expect(controller.shouldLoadMore(19), isTrue);
      await controller.loadMore();
      expect(controller.items.length, 60);
      expect(controller.renderedWindow(0).length, 50);
      expect(controller.baseIndex, 0);
      await controller.loadMore();
      expect(requests.map((r) => r.offset), [0, 30, 60]);
      expect(controller.items.first, 0);
      await controller.loadMore();
      expect(controller.loadedCount, 95);
      expect(controller.hasMore, isFalse);
      await controller.loadMore();
      expect(requests.length, 4);
      controller.dispose();
    },
  );

  test('concurrent loads coalesce and reset discards stale pages', () async {
    final old = Completer<PageResult<int>>();
    var calls = 0;
    final controller = PaginationController<int>(
      loader: (_) {
        calls++;
        return calls == 1
            ? old.future
            : Future.value(const PageResult(items: [42]));
      },
    );
    final pending = controller.loadMore();
    await controller.loadMore();
    expect(calls, 1);
    controller.reset();
    await controller.loadMore();
    old.complete(const PageResult(items: [1, 2]));
    await pending;
    expect(controller.items, [42]);
    controller.dispose();
  });

  test('errors retain loaded data and can be retried', () async {
    var fail = true;
    final controller = PaginationController<int>(
      loader: (_) async {
        if (fail) throw StateError('offline fixture failure');
        return const PageResult(items: [1]);
      },
    );
    await controller.loadMore();
    expect(controller.error, isA<StateError>());
    expect(controller.isLoading, isFalse);
    expect(controller.shouldLoadMore(0), isFalse);
    fail = false;
    await controller.loadMore();
    expect(controller.error, isNull);
    expect(controller.items, [1]);
    await controller.refresh();
    expect(controller.items, [1]);
    controller.dispose();
  });

  test('time history requests seven-week half-open windows', () async {
    final requests = <PageRequest>[];
    final controller = PaginationController<int>(
      type: PaginationType.time,
      pageSize: 7,
      prefetchThreshold: 1,
      initialDate: DateTime(2026, 9, 14),
      loader: (request) async {
        requests.add(request);
        return const PageResult(items: [1], hasMore: true);
      },
    );
    await controller.loadMore();
    await controller.loadMore();
    expect(
      requests.first.endDate!.difference(requests.first.startDate!).inDays,
      49,
    );
    expect(requests[1].endDate, requests[0].startDate);
    controller.dispose();
  });

  test(
    'weekly pagination renders at most four weeks with backscroll cache',
    () async {
      final controller = PaginationController<String>(
        type: PaginationType.weekly,
        pageSize: 1,
        maxRendered: 4,
        prefetchThreshold: 0,
        initialDate: DateTime(2026, 9, 14),
        loader: (request) async =>
            PageResult(items: [request.week!], hasMore: true),
      );
      for (var i = 0; i < 5; i++) {
        await controller.loadMore();
      }
      expect(controller.renderedWindow(1).length, 4);
      expect(controller.items.first, '2026-W37');
      controller.dispose();
    },
  );

  test('ISO week key handles year boundaries', () {
    expect(weekKey(DateTime(2021, 1, 1)), '2020-W53');
    expect(weekKey(DateTime(2024, 12, 30)), '2025-W01');
    expect(mondayOfWeek(DateTime(2026, 9, 13, 23)), DateTime(2026, 9, 7));
  });
}
