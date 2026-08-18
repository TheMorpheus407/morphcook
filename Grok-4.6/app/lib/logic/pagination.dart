import 'package:flutter/foundation.dart';

class Page<T> {
  final List<T> items;
  final String? nextCursor;

  const Page({required this.items, this.nextCursor});
}

typedef PageFetcher<T> = Future<Page<T>> Function(String? cursor, int pageSize);

class PaginationController<T> extends ChangeNotifier {
  final PageFetcher<T> fetch;
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;

  PaginationController({
    required this.fetch,
    this.pageSize = 20,
    this.prefetchThreshold = 10,
    this.maxRendered = 50,
  });

  final List<T> _items = [];
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _loadedOnce = false;
  Object? _error;
  int _disposedCount = 0;
  bool _disposed = false;

  List<T> get items => List.unmodifiable(_items);
  bool get isLoading => _loading;
  bool get hasMore => _hasMore;
  Object? get error => _error;
  bool get isEmpty => _loadedOnce && _items.isEmpty && !_hasMore;
  int get disposedCount => _disposedCount;

  bool shouldLoadMore(int index) =>
      _hasMore && !_loading && index >= _items.length - prefetchThreshold;

  Future<void> loadMore() async {
    if (_loading || !_hasMore) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await fetch(_cursor, pageSize);
      if (_disposed) return;
      _items.addAll(page.items);
      _cursor = page.nextCursor;
      _hasMore = page.nextCursor != null && page.items.isNotEmpty;
      if (_items.length > maxRendered) {
        final overflow = _items.length - maxRendered;
        _items.removeRange(0, overflow);
        _disposedCount += overflow;
      }
    } catch (e) {
      if (_disposed) return;
      _error = e;
    } finally {
      if (!_disposed) {
        _loading = false;
        _loadedOnce = true;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    reset();
    await loadMore();
  }

  void reset() {
    _items.clear();
    _cursor = null;
    _hasMore = true;
    _loading = false;
    _loadedOnce = false;
    _error = null;
    _disposedCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

PageFetcher<T> offsetPager<T>(List<T> source) {
  return (cursor, pageSize) async {
    final offset = cursor == null ? 0 : int.parse(cursor);
    final slice = source.skip(offset).take(pageSize).toList();
    final next = offset + slice.length;
    return Page(
      items: slice,
      nextCursor: next < source.length ? '$next' : null,
    );
  };
}
