import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/services/pagination.dart';

void main() {
  test(
    'cursor pagination loads 20, prefetches at 10 and caps rendered items at 50',
    () async {
      final values = List.generate(55, (index) => index);
      late PaginationController<int> pages;
      pages = PaginationController<int>(
        pageSize: 20,
        prefetchThreshold: 10,
        maxRendered: 50,
        loader: (cursor, offset) async {
          final start = cursor == null ? 0 : int.parse(cursor);
          final end = (start + 20).clamp(0, values.length);
          return PaginationPage(
            items: values.sublist(start, end),
            nextCursor: end < values.length ? '$end' : null,
          );
        },
      );
      await pages.loadMore();
      expect(pages.items, values.sublist(0, 20));
      expect(pages.nextCursor, '20');
      expect(pages.shouldLoadMore(9), isFalse);
      expect(pages.shouldLoadMore(10), isTrue);
      await pages.loadMore();
      expect(pages.items.length, 40);
      await pages.loadMore();
      expect(pages.items.length, 50);
      expect(pages.items.first, 5);
      expect(pages.items.last, 54);
      expect(pages.hasMore, isFalse);
      pages.reset();
      expect(pages.items, isEmpty);
      expect(pages.initialized, isFalse);
      await pages.loadMore();
      expect(pages.items.length, 20);
      pages.dispose();
    },
  );

  test(
    'offset pagination uses predictable offsets and short terminal page',
    () async {
      final values = List.generate(35, (index) => index);
      final pages = PaginationController<int>(
        pageSize: 30,
        useOffset: true,
        loader: (cursor, offset) async {
          final end = (offset + 30).clamp(0, values.length);
          return PaginationPage(
            items: values.sublist(offset, end),
            offset: offset,
          );
        },
      );
      await pages.loadMore();
      expect(pages.offset, 30);
      expect(pages.hasMore, isTrue);
      await pages.loadMore();
      expect(pages.offset, 35);
      expect(pages.items.length, 35);
      expect(pages.hasMore, isFalse);
      pages.dispose();
    },
  );

  test('a failed page keeps an actionable error and can retry', () async {
    var fail = true;
    final pages = PaginationController<int>(
      loader: (cursor, offset) async {
        if (fail) throw StateError('smudged');
        return const PaginationPage(items: [1], nextCursor: null);
      },
    );
    await pages.loadMore();
    expect(pages.error, isA<StateError>());
    expect(pages.initialized, isTrue);
    fail = false;
    await pages.loadMore();
    expect(pages.items, [1]);
    expect(pages.error, isNull);
    pages.dispose();
  });

  test('a stale page cannot overwrite results from a newer query', () async {
    final pending = <Completer<PaginationPage<int>>>[];
    final pages = PaginationController<int>(
      loader: (cursor, offset) {
        final completer = Completer<PaginationPage<int>>();
        pending.add(completer);
        return completer.future;
      },
    );
    final oldLoad = pages.loadMore();
    final refreshed = pages.refresh();
    pending[1].complete(const PaginationPage(items: [2], nextCursor: null));
    await refreshed;
    pending[0].complete(const PaginationPage(items: [1], nextCursor: null));
    await oldLoad;
    expect(pages.items, [2]);
    expect(pages.hasMore, isFalse);
    pages.dispose();
  });
}
