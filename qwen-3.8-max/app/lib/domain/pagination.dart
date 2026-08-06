import 'package:flutter/foundation.dart';

/// Pagination state shared by all paginated views.
///
/// Each view picks the page size / prefetch threshold suited to its data
/// pattern (cursor-based search, offset cookbook, time-grouped history,
/// weekly plan); the controller mechanics are the same.
class PaginationController<T> extends ChangeNotifier {
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;

  /// Fetch one page. [offset] is item-based; sources with opaque cursors
  /// translate it internally.
  final Future<List<T>> Function(int offset, int limit) fetchPage;

  final List<T> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  bool _disposed = false;
  int _generation = 0;

  PaginationController({
    required this.fetchPage,
    this.pageSize = 20,
    this.prefetchThreshold = 10,
    this.maxRendered = 50,
  });

  List<T> get items => _items;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get isEmpty => _items.isEmpty && !_isLoading;

  /// True when [index] is within the prefetch window of the current end.
  bool shouldLoadMore(int index) =>
      _hasMore && !_isLoading && index >= _items.length - prefetchThreshold;

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore || _disposed) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    final generation = _generation;
    try {
      final page = await fetchPage(_items.length, pageSize);
      if (_disposed || generation != _generation) return;
      _items.addAll(page);
      if (_items.length > maxRendered) {
        _items.removeRange(0, _items.length - maxRendered);
      }
      _hasMore = page.length >= pageSize;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      _error = e.toString();
    } finally {
      if (!_disposed && generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Reset and reload from page 1.
  Future<void> refresh() async {
    _generation++;
    _items.clear();
    _hasMore = true;
    _error = null;
    notifyListeners();
    await loadMore();
  }

  /// Clear everything, back to initial state.
  void reset() {
    _generation++;
    _items.clear();
    _hasMore = true;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
