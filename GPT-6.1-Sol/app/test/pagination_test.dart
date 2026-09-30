import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/pagination.dart';

void main() {
  test('offset pagination loads exact page sizes and finishes', () async {
    final source = List.generate(64, (i) => i);
    final controller = PaginationController<int>(
      pageSize: 30,
      type: PaginationType.offset,
      loader: (cursor, limit) async => offsetPage(source, cursor, limit),
    );
    await controller.loadMore();
    expect(controller.items.length, 30);
    expect(controller.shouldLoadMore(19), isFalse);
    expect(controller.shouldLoadMore(20), isTrue);
    await controller.loadMore();
    expect(controller.items.length, 60);
    await controller.loadMore();
    expect(controller.items, source);
    expect(controller.hasMore, isFalse);
    await controller.refresh();
    expect(controller.items.length, 30);
    controller.reset();
    expect(controller.items, isEmpty);
    expect(controller.nextCursor, isNull);
    controller.dispose();
  });
  test('ID cursors survive insertions ahead of the previous page', () {
    final source = List.generate(30, (i) => 'recipe-$i');
    final first = cursorPage(source, null, 20, (id) => id);
    source.insert(0, 'new-recipe');
    final second = cursorPage(source, first.nextCursor, 20, (id) => id);
    expect(second.items.first, 'recipe-20');
    expect(second.items.length, 10);
    expect(second.nextCursor, isNull);
  });
  test('a reset discards stale async pages', () async {
    final pending = Completer<PageResult<int>>();
    int calls = 0;
    final controller = PaginationController<int>(
      loader: (cursor, limit) {
        calls++;
        return calls == 1
            ? pending.future
            : Future.value(PageResult([2], null));
      },
    );
    final stale = controller.loadMore();
    await controller.refresh();
    pending.complete(PageResult([1], null));
    await stale;
    expect(controller.items, [2]);
    expect(controller.loading, isFalse);
    controller.dispose();
  });
  test('concurrent loadMore coalesces; failures can be retried', () async {
    int calls = 0;
    final pending = Completer<PageResult<int>>();
    final controller = PaginationController<int>(
      loader: (_, limit) {
        calls++;
        return calls == 1
            ? pending.future
            : Future.value(PageResult([1], null));
      },
    );
    final load = controller.loadMore();
    await controller.loadMore();
    expect(calls, 1);
    pending.completeError(StateError('read failed'));
    await load;
    expect(controller.error, isNotNull);
    expect(controller.loading, isFalse);
    await controller.loadMore();
    expect(controller.items, [1]);
    expect(controller.error, isNull);
    controller.dispose();
  });
  test('disposed controllers ignore late completions', () async {
    final pending = Completer<PageResult<int>>();
    final controller = PaginationController<int>(
      loader: (_, limit) => pending.future,
    );
    final load = controller.loadMore();
    controller.dispose();
    pending.complete(PageResult([1], null));
    await load;
    expect(controller.items, isEmpty);
  });
}
