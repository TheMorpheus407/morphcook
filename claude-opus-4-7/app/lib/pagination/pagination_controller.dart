import 'package:flutter/foundation.dart';

enum PageState { idle, loading, error, empty }

enum PaginationMode { cursor, offset, time, weekly }

/// PaginationController per SPEC §Pagination.
/// - cursor: search results
/// - offset: cookbook (saved)
/// - time: history (week buckets)
/// - weekly: meal plan
class PaginationController<T> extends ChangeNotifier {
  final PaginationMode mode;
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;

  final Future<PageResult<T>> Function(PageRequest req) fetcher;

  final List<T> _items = [];
  PageState _state = PageState.idle;
  Object? _error;
  String? _cursor;
  int _offset = 0;
  bool _hasMore = true;

  PaginationController({
    required this.mode,
    required this.fetcher,
    this.pageSize = 20,
    this.prefetchThreshold = 10,
    this.maxRendered = 50,
  });

  List<T> get items => List.unmodifiable(_items);
  PageState get state => _state;
  Object? get error => _error;
  bool get hasMore => _hasMore;

  bool shouldLoadMore(int index) =>
      _hasMore &&
      _state != PageState.loading &&
      index >= _items.length - prefetchThreshold;

  Future<void> refresh() async {
    reset();
    await loadMore();
  }

  void reset() {
    _items.clear();
    _cursor = null;
    _offset = 0;
    _hasMore = true;
    _state = PageState.idle;
    _error = null;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_state == PageState.loading || !_hasMore) return;
    _state = PageState.loading;
    notifyListeners();
    try {
      final req = PageRequest(
        cursor: _cursor,
        offset: _offset,
        limit: pageSize,
      );
      final res = await fetcher(req);
      _items.addAll(res.items);
      _cursor = res.nextCursor;
      _offset += res.items.length;
      _hasMore = res.hasMore;
      // Cap rendered items: drop the head.
      if (_items.length > maxRendered) {
        _items.removeRange(0, _items.length - maxRendered);
      }
      _state = _items.isEmpty ? PageState.empty : PageState.idle;
      _error = null;
    } catch (e) {
      _error = e;
      _state = PageState.error;
    }
    notifyListeners();
  }
}

class PageRequest {
  final String? cursor;
  final int offset;
  final int limit;
  const PageRequest({this.cursor, required this.offset, required this.limit});
}

class PageResult<T> {
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  const PageResult({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });
}
