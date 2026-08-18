import 'package:flutter/foundation.dart';

/// A page of results for any pagination type.
class PageSlice<T> {
  const PageSlice({required this.items, this.nextCursor, this.hasMore = false});

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  static PageSlice<T> offset<T>(List<T> all, int offset, int pageSize) {
    final slice = all.skip(offset).take(pageSize).toList();
    final more = offset + pageSize < all.length;
    return PageSlice(items: slice, hasMore: more);
  }

  static PageSlice<T> cursor<T>(List<T> all, int offset, int pageSize) {
    final slice = all.skip(offset).take(pageSize).toList();
    final more = offset + pageSize < all.length;
    return PageSlice(
      items: slice,
      hasMore: more,
      nextCursor: more ? (offset + pageSize).toString() : null,
    );
  }
}

enum PaginationType { cursor, offset, timeBased, weekly }

/// Shared pagination state for all list views.
///   loadMore()            — fetch the next page
///   refresh()             — reset and reload from page 1
///   reset()               — clear items, back to initial state
///   shouldLoadMore(index) — true when within the prefetch threshold
class PaginationController<T> extends ChangeNotifier {
  PaginationController({
    required this.pageSize,
    required this.prefetchThreshold,
    this.maxRendered = 50,
    required this.fetcher,
    this.type = PaginationType.cursor,
  });

  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;
  final PaginationType type;
  final Future<PageSlice<T>> Function(int offset, String? cursor) fetcher;

  List<T> _items = [];
  List<T> get items => List.unmodifiable(_items);

  bool _loading = false;
  bool get loading => _loading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  Object? _error;
  Object? get error => _error;
  bool get hasError => _error != null;

  int _offset = 0;
  String? _cursor;
  bool _initialized = false;

  /// Rendered window: never render more than [maxRendered] at once.
  int get renderedCount => _items.length.clamp(0, maxRendered);

  List<T> get renderedItems => _items.take(maxRendered).toList();

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await fetcher(_offset, _cursor);
      _items.addAll(page.items);
      _offset += page.items.length;
      _cursor = page.nextCursor;
      _hasMore = page.hasMore && _items.length < maxRendered + pageSize * 4;
    } catch (e) {
      _error = e;
      _hasMore = false;
    } finally {
      _loading = false;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_loading) return;
    _items = [];
    _offset = 0;
    _cursor = null;
    _hasMore = true;
    _error = null;
    notifyListeners();
    await loadMore();
  }

  void reset() {
    _items = [];
    _offset = 0;
    _cursor = null;
    _hasMore = true;
    _error = null;
    _loading = false;
    _initialized = false;
    notifyListeners();
  }

  bool shouldLoadMore(int index) {
    if (!_hasMore || _loading) return false;
    return _items.length - index <= prefetchThreshold;
  }

  bool get isInitialLoading => _loading && _items.isEmpty && !_initialized;
}
