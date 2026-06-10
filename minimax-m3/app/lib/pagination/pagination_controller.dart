import 'package:flutter/foundation.dart';

/// A generic pagination controller. Backed by a callback that fetches a page
/// asynchronously. Supports cursor-based, offset-based, and time-based
/// pagination by letting the callback decide how to compute its cursor.
class PaginationController<T> extends ChangeNotifier {
  PaginationController({
    required this.pageSize,
    required this.maxRendered,
    required this.prefetchThreshold,
    required PaginationFetcher<T> fetcher,
  }) : _fetcher = fetcher;

  final int pageSize;
  final int maxRendered;
  final int prefetchThreshold;
  final PaginationFetcher<T> _fetcher;

  final List<T> _items = [];
  bool _loading = false;
  bool _exhausted = false;
  Object? _error;
  int _pageIndex = 0;
  int _totalFetched = 0;
  Object? _nextCursor; // opaque cursor token, type-erased

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _loading;
  bool get isExhausted => _exhausted;
  Object? get error => _error;
  int get length => _items.length;

  bool shouldLoadMore(int currentIndex) {
    if (_loading || _exhausted) return false;
    return currentIndex >= _items.length - prefetchThreshold;
  }

  Future<void> loadMore() async {
    if (_loading || _exhausted) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _fetcher(
        offset: _totalFetched,
        pageIndex: _pageIndex,
        pageSize: pageSize,
        cursor: _nextCursor,
      );
      _items.addAll(page.items);
      _totalFetched += page.items.length;
      _pageIndex += 1;
      _nextCursor = page.nextCursor;
      if (!page.hasMore || page.items.isEmpty) {
        _exhausted = true;
      }
      // Trim to maxRendered, keeping the most recent (i.e. the tail).
      if (_items.length > maxRendered) {
        _items.removeRange(0, _items.length - maxRendered);
      }
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    reset();
    await loadMore();
  }

  void reset() {
    _items.clear();
    _loading = false;
    _exhausted = false;
    _error = null;
    _pageIndex = 0;
    _totalFetched = 0;
    _nextCursor = null;
    notifyListeners();
  }
}

class PageResult<T> {
  final List<T> items;
  final bool hasMore;
  final Object? nextCursor;
  const PageResult({required this.items, required this.hasMore, this.nextCursor});
}

typedef PaginationFetcher<T> = Future<PageResult<T>> Function({
  required int offset,
  required int pageIndex,
  required int pageSize,
  Object? cursor,
});
