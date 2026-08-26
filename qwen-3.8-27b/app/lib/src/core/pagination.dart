import 'package:flutter/foundation.dart';

/// Generic pagination state (spec: cursor / offset / time / weekly collapse
/// to "page tokens" with a prefetch threshold and a max rendered count).
enum PgState { idle, loading, loaded, error, empty }

@unchecked
abstract class PaginationController<T> extends ChangeNotifier {
  PaginationController({
    required this.pageSize,
    this.prefetchThreshold = 10,
    this.maxRendered = 50,
  });

  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;

  final List<T> _items = [];
  String _cursor = '';
  bool _hasMore = true;
  bool _loading = false;
  PgState _state = PgState.idle;
  Object? _error;

  List<T> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore && _items.length < maxRendered;
  bool get loading => _loading;
  PgState get state => _state;
  Object? get error => _error;
  bool get isEmpty => _items.isEmpty && !loading && (state == PgState.empty || state == PgState.idle);

  /// Fetches one page. Empty page = no more pages.
  Future<List<T>> fetchPage(String cursorToken);

  /// Cursor token for the next page, derived from [page]; '' when none.
  String nextCursorOf(List<T> page);

  Future<void> loadInitial() async {
    if (_loading) return;
    _loading = true;
    _state = PgState.loading;
    _error = null;
    notifyListeners();
    try {
      final page = await fetchPage('');
      _items
        ..clear()
        ..addAll(page);
      _cursor = nextCursorOf(page);
      _hasMore = page.length == pageSize;
      _state = _items.isEmpty ? PgState.empty : PgState.loaded;
    } catch (e) {
      _error = e;
      _state = PgState.error;
    }
    _loading = false;
    notifyListeners();
  }

  bool shouldLoadMore(int index) =>
      hasMore && !_loading && index >= _items.length - prefetchThreshold;

  Future<void> loadMore() async {
    if (!_loading && hasMore) {
      _loading = true;
      notifyListeners();
      try {
        final page = await fetchPage(_cursor);
        _items.addAll(page);
        _cursor = nextCursorOf(page);
        _hasMore = page.length == pageSize;
      } catch (e) {
        _error = e;
      }
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _items
      ..clear();
    _cursor = '';
    _hasMore = true;
    await loadInitial();
  }

  void reset() {
    _items
      ..clear();
    _cursor = '';
    _hasMore = true;
    _state = PgState.idle;
    _error = null;
    _loading = false;
    notifyListeners();
  }
}
