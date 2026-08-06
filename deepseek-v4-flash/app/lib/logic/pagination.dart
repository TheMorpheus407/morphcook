import 'package:flutter/foundation.dart';

enum PageKind {
  /// Simple paged list: offset-based or plain (e.g. "recently cooked").
  offset,

  /// Date-windowed paging keyed by an ISO date (e.g. cookbook "saved this week").
  time,

  /// Weekly buckets (calendar weeks).
  weekly,
}

class PageResult<T> {
  final List<T> items;
  final bool hasMore;
  final Object? nextCursor;

  const PageResult({
    required this.items,
    this.hasMore = false,
    this.nextCursor,
  });

  const PageResult.empty({this.hasMore = false, this.nextCursor})
      : items = const [];
}

/// Deterministic pagination controller — the home feed, cookbook and history
/// feeds all page through this. Two triggers load more: scrolling near the
/// bottom (`shouldLoadMore`) and time-based staleness (offset > maxRendered
/// while rendered is below the threshold).
class PaginationController<T> extends ChangeNotifier {
  final PageKind kind;

  /// Items the user actually sees (matches the page renderer).
  final List<T> items = [];

  /// How many distinct pages were fetched so far (deterministic).
  int pageCount = 0;

  /// Last cursor returned by the fetcher.
  Object? _cursor;

  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  /// When the rendered count crosses this threshold, trigger `loadMore`
  /// proactively (keeps the list full).
  int prefetchThreshold;

  /// Soft cap on how many items are rendered from the list.
  int maxRendered;

  /// Backfill window: on refresh, keep [keepFirstN] of the currently
  /// visible items on top so the UI doesn't jump.
  int keepFirstN;

  Future<PageResult<T>> Function(Object? cursor, int page)? _fetcher;

  PaginationController({
    this.kind = PageKind.offset,
    this.prefetchThreshold = 12,
    this.maxRendered = 40,
    this.keepFirstN = 5,
  });

  bool get loading => _loading;
  bool get hasMore => _hasMore;
  Object? get error => _error;
  Object? get cursor => _cursor;

  void setFetcher(Future<PageResult<T>> Function(Object? cursor, int page) f) {
    _fetcher = f;
  }

  void reset() {
    items.clear();
    pageCount = 0;
    _cursor = null;
    _hasMore = true;
    _loading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_loading || !_hasMore || _fetcher == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _fetcher!(_cursor, pageCount + 1);
      pageCount++;
      items.addAll(res.items);
      _cursor = res.nextCursor;
      _hasMore = res.hasMore;
    } catch (e) {
      _error = e;
      _hasMore = false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Scroll-hint: called with the index of the last rendered widget.
  bool shouldLoadMore(int index) {
    if (index >= items.length - prefetchThreshold) {
      if (items.length < maxRendered) {
        // fire and forget; state notifies the UI
        loadMore();
        return true;
      }
    }
    return false;
  }

  /// Time-based staleness: once `rendered` (items the user saw) approaches
  /// the max, fetch more even without scrolling.
  bool shouldLoadMoreByStaleness(int rendered) {
    if (rendered >= maxRendered && hasMore && !_loading) {
      // fire and forget; state notifies the UI
      loadMore();
      return true;
    }
    return false;
  }

  Future<void> refresh() async {
    if (_fetcher == null) return;
    final keep = items.take(keepFirstN).toList();
    reset();
    items.addAll(keep);
    _loading = true;
    notifyListeners();
    final res = await _fetcher!(null, 1);
    _loading = false;
    pageCount = 1;
    _hasMore = res.hasMore;
    _cursor = res.nextCursor;
    for (final it in res.items) {
      if (!keep.contains(it)) items.add(it);
    }
    notifyListeners();
  }
}

/// Paged feed built from an in-memory list (e.g. cookbook, history).
List<T> paginate<T>(List<T> all, int page, {int pageSize = 10}) {
  final start = (page - 1) * pageSize;
  if (start >= all.length) return const [];
  final end = (start + pageSize).clamp(0, all.length);
  return all.sublist(start, end);
}

/// Day-window paging for time-based feeds: returns entries whose date falls
/// inside the requested window, moving back in time as `page` grows.
List<T> paginateByDate<T>(List<T> all, DateTime anchor, int page,
    {int pageSize = 10, required DateTime Function(T) dateOf}) {
  final target = anchor.subtract(Duration(days: (page - 1) * pageSize));
  return all
      .where((e) => !dateOf(e).isAfter(target))
      .take(pageSize)
      .toList();
}
