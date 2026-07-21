import 'package:flutter/foundation.dart';

class PageChunk<T> {
  const PageChunk({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;
}

typedef PageLoader<T> =
    Future<PageChunk<T>> Function(String? cursor, int limit);

class PaginationController<T> extends ChangeNotifier {
  PaginationController({
    required PageLoader<T> loader,
    this.pageSize = 20,
    this.prefetchThreshold = 10,
    this.maxRendered = 50,
  }) : _loader = loader;

  final PageLoader<T> _loader;
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;

  final List<T> _items = [];
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  List<T> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get isLoading => _loading;
  Object? get error => _error;

  Future<void> loadMore() async {
    if (_loading || !_hasMore || _items.length >= maxRendered) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final chunk = await _loader(_cursor, pageSize);
      final room = maxRendered - _items.length;
      _items.addAll(chunk.items.take(room));
      _cursor = chunk.nextCursor;
      _hasMore = chunk.nextCursor != null && _items.length < maxRendered;
    } catch (error) {
      _error = error;
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
    _cursor = null;
    _hasMore = true;
    _loading = false;
    _error = null;
    notifyListeners();
  }

  bool shouldLoadMore(int index) =>
      _hasMore && index >= _items.length - prefetchThreshold;
}

class OffsetPagination<T> extends ChangeNotifier {
  OffsetPagination({
    required List<T> Function() source,
    this.pageSize = 30,
    this.prefetchThreshold = 10,
    this.maxRendered = 50,
  }) : _source = source;

  final List<T> Function() _source;
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;
  final List<T> _items = [];

  List<T> get items => List.unmodifiable(_items);
  bool get hasMore =>
      _items.length < _source().length && _items.length < maxRendered;

  void loadMore() {
    if (!hasMore) return;
    final source = _source();
    final end = (_items.length + pageSize).clamp(0, source.length);
    final room = maxRendered - _items.length;
    _items.addAll(source.sublist(_items.length, end).take(room));
    notifyListeners();
  }

  void refresh() {
    _items.clear();
    loadMore();
  }

  bool shouldLoadMore(int index) =>
      hasMore && index >= _items.length - prefetchThreshold;
}
