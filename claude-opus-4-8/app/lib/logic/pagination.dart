import 'package:flutter/foundation.dart';

/// Pagination strategy. Each view picks the type suited to its data pattern.
enum PaginationType { cursor, offset, time, weekly }

/// One page of results plus a token to fetch the next one.
class Page<T> {
  Page({required this.items, this.nextCursor, required this.hasMore});
  final List<T> items;

  /// Opaque continuation token (offset int, cursor string, week index…).
  final Object? nextCursor;
  final bool hasMore;
}

/// Fetches one page given the previous cursor (null for the first page).
typedef PageFetcher<T> = Future<Page<T>> Function(Object? cursor);

/// Generic pagination controller backing all paginated lists.
///
/// Performance guardrails (per SPEC): never render more than [maxRendered]
/// items; prefetch when the user scrolls within [prefetchThreshold] of the end.
class PaginationController<T> extends ChangeNotifier {
  PaginationController({
    required this.fetcher,
    required this.type,
    this.pageSize = 20,
    this.prefetchThreshold = 10,
    this.maxRendered = 50,
  });

  final PageFetcher<T> fetcher;
  final PaginationType type;
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;

  final List<T> _items = [];
  List<T> get items => List.unmodifiable(_items);

  Object? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _initialLoaded = false;
  Object? _error;

  bool get isLoading => _loading;
  bool get hasMore => _hasMore;
  bool get isEmpty => _initialLoaded && _items.isEmpty;
  bool get isInitialLoaded => _initialLoaded;
  Object? get error => _error;

  /// True when the user has scrolled within the prefetch window of the end.
  bool shouldLoadMore(int index) =>
      _hasMore && !_loading && index >= _items.length - prefetchThreshold;

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await fetcher(_cursor);
      _items.addAll(page.items);
      _cursor = page.nextCursor;
      _hasMore = page.hasMore;
      // Dispose off-screen items beyond the render cap (keep the tail).
      if (_items.length > maxRendered) {
        _items.removeRange(0, _items.length - maxRendered);
      }
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      _initialLoaded = true;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _cursor = null;
    _hasMore = true;
    _items.clear();
    _initialLoaded = false;
    _error = null;
    await loadMore();
  }

  void reset() {
    _cursor = null;
    _hasMore = true;
    _items.clear();
    _initialLoaded = false;
    _error = null;
    notifyListeners();
  }
}
