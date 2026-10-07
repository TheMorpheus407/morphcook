import 'package:flutter/foundation.dart';

import 'model/meal_plan.dart';

/// One page of results.
class Page<T> {
  final List<T> items;
  final String? nextCursor;

  const Page({required this.items, this.nextCursor});

  bool get hasMore => nextCursor != null;
}

/// Pagination state for every list view. Subclasses supply a [fetcher] that
/// maps a page index to a [Page]; the controller handles loading, error,
/// refresh, reset and prefetch decisions.
///
/// Guardrails: [prefetchThreshold] items before the end trigger a load;
/// [maxRendered] caps how many item widgets a list renders at once (the
/// paginated list view uses `ListView.builder` with zero cache extent, so
/// off-screen items are disposed).
class PaginationController<T> extends ChangeNotifier {
  final Future<Page<T>> Function(int page, String? cursor) fetcher;
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;

  PaginationController({
    required this.fetcher,
    required this.pageSize,
    required this.prefetchThreshold,
    required this.maxRendered,
  });

  final List<T> _items = [];
  String? _cursor;
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  int get loadedCount => _items.length;

  /// True when the user scrolled within [prefetchThreshold] of the end.
  bool shouldLoadMore(int index) =>
      index >= _items.length - prefetchThreshold && _hasMore && !_isLoading;

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await fetcher(_page, _cursor);
      _items.addAll(page.items);
      _cursor = page.nextCursor;
      _page += 1;
      _hasMore = page.hasMore && _items.length < maxRendered * 10;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset and reload from page 1.
  Future<void> refresh() async {
    reset();
    await loadMore();
  }

  /// Clear all items and return to the initial state.
  void reset() {
    _items.clear();
    _cursor = null;
    _page = 0;
    _isLoading = false;
    _hasMore = true;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _items.clear();
    super.dispose();
  }
}

/// Convenience factory for offset-based pagination (cookbook, saved recipes).
PaginationController<T> offsetPagination<T>({
  required Future<Page<T>> Function(int offset, int limit) fetch,
  int pageSize = 30,
  int prefetchThreshold = 10,
  int maxRendered = 50,
}) {
  var offset = 0;
  return PaginationController<T>(
    pageSize: pageSize,
    prefetchThreshold: prefetchThreshold,
    maxRendered: maxRendered,
    fetcher: (page, cursor) async {
      final result = await fetch(offset, pageSize);
      offset += result.items.length;
      final hasMore = result.items.length == pageSize;
      return Page(items: result.items, nextCursor: hasMore ? 'offset:$offset' : null);
    },
  );
}

/// Convenience factory for cursor-based pagination (search results).
PaginationController<T> cursorPagination<T>({
  required Future<Page<T>> Function(String? cursor, int pageSize) fetch,
  int pageSize = 20,
  int prefetchThreshold = 10,
  int maxRendered = 50,
}) =>
    PaginationController<T>(
      pageSize: pageSize,
      prefetchThreshold: prefetchThreshold,
      maxRendered: maxRendered,
      fetcher: (page, cursor) => fetch(cursor, pageSize),
    );

/// Convenience factory for time-window pagination (history, by week).
PaginationController<T> timeWindowPagination<T>({
  required Future<Page<T>> Function(DateTime windowStart, int windowDays) fetch,
  int windowDays = 7,
  int prefetchWeeks = 1,
  int maxWeeks = 4,
  int maxRendered = 50,
}) {
  var loadedWeeks = 0;
  return PaginationController<T>(
    pageSize: windowDays,
    prefetchThreshold: prefetchWeeks,
    maxRendered: maxRendered,
    fetcher: (page, cursor) async {
      final anchor = cursor != null ? DateTime.parse(cursor) : DateTime.now();
      final start = anchor.subtract(Duration(days: windowDays));
      final result = await fetch(start, windowDays);
      loadedWeeks += 1;
      final hasMore = loadedWeeks < maxWeeks;
      return Page(
        items: result.items,
        nextCursor: hasMore ? start.toIso8601String() : null,
      );
    },
  );
}

/// Convenience factory for weekly pagination (meal plan view).
PaginationController<T> weeklyPagination<T>({
  required Future<Page<T>> Function(String weekId) fetch,
  int maxWeeks = 4,
}) {
  var loadedWeeks = 0;
  return PaginationController<T>(
    pageSize: 1,
    prefetchThreshold: 0,
    maxRendered: maxWeeks,
    fetcher: (page, cursor) async {
      final result = await fetch(cursor ?? _currentWeekId());
      loadedWeeks += 1;
      final hasMore = loadedWeeks < maxWeeks;
      return Page(
        items: result.items,
        nextCursor: hasMore ? _nextWeekId(cursor ?? _currentWeekId()) : null,
      );
    },
  );
}

String _currentWeekId() => weekIdFor(DateTime.now());

String _nextWeekId(String weekId) {
  final match = RegExp(r'^(\d{4})-W(\d{2})$').firstMatch(weekId)!;
  final year = int.parse(match.group(1)!);
  final week = int.parse(match.group(2)!);
  if (week >= 52) return '${year + 1}-W01';
  return '$year-W${(week + 1).toString().padLeft(2, '0')}';
}
