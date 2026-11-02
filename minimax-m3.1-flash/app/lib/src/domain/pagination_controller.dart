import 'package:flutter/foundation.dart';

/// The pagination strategy a list uses.
enum PaginationType {
  /// `nextCursor` tokens — stable when the dataset shifts under you.
  cursor,

  /// `offset + limit` — predictable, good for sorted user data.
  offset,

  /// Time buckets (a week at a time) — good for history.
  time,

  /// Natural weeks — good for the meal plan.
  weekly,
}

/// A page of results.
class PageResult<T> {
  const PageResult({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  });

  const PageResult.empty()
      : items = const <Never>[],
        nextCursor = null,
        hasMore = false;

  final List<T> items;

  /// Token for the next cursor-based page.
  final String? nextCursor;

  final bool hasMore;
}

/// What a page request asks for.
class PageRequest {
  const PageRequest({
    this.cursor,
    this.offset = 0,
    this.limit = 20,
    this.bucketStart,
  });

  final String? cursor;
  final int offset;
  final int limit;

  /// The start of the time bucket for time-based and weekly pagination.
  final DateTime? bucketStart;
}

/// Drives a paginated list.
///
/// Every list view in MorphCook uses this: search is cursor-based, the
/// cookbook is offset-based, history is time-based and the meal plan is
/// weekly. Off-screen items are never rendered and pages are prefetched
/// slightly before the user reaches the end.
class PaginationController<T> extends ChangeNotifier {
  PaginationController({
    required this.type,
    required this.fetchPage,
    this.pageSize = 20,
    this.prefetchThreshold = 10,
    this.maxRendered = 50,
  });

  final PaginationType type;
  final Future<PageResult<T>> Function(PageRequest request) fetchPage;
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;

  final List<T> _items = <T>[];
  bool _isLoading = false;
  bool _hasMore = true;
  Object? _error;
  String? _nextCursor;
  int _offset = 0;
  DateTime? _bucketStart;

  /// Everything fetched so far.
  List<T> get allItems => List<T>.unmodifiable(_items);

  /// The items that may be rendered — never more than [maxRendered].
  List<T> get items =>
      _items.length > maxRendered ? _items.sublist(0, maxRendered) : _items;

  bool get isLoading => _isLoading;

  bool get hasMore => _hasMore;

  Object? get error => _error;

  bool get isEmpty => _items.isEmpty && !_isLoading && _error == null;

  /// The token that will be sent with the next cursor-based request.
  String? get nextCursor => _nextCursor;

  int get length => _items.length;

  /// The offset the next offset-based request will use.
  int get offset => _offset;

  /// True when the list has reached its rendering cap.
  bool get isAtCapacity => _items.length >= maxRendered;

  /// Whether the next page should be requested because the user is within
  /// [prefetchThreshold] items of the end.
  bool shouldLoadMore(int index) {
    if (_isLoading || !_hasMore) return false;
    if (_items.isEmpty) return true;
    return index >= _items.length - prefetchThreshold;
  }

  /// Loads the first page.
  Future<void> loadInitial() async {
    reset();
    await loadMore();
  }

  /// Fetches the next page.
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final request = PageRequest(
        cursor: _nextCursor,
        offset: _offset,
        limit: pageSize,
        bucketStart: _bucketStart,
      );
      final page = await fetchPage(request);
      _items.addAll(page.items);
      _offset += page.items.length;
      _nextCursor = page.nextCursor;
      _hasMore = page.hasMore;
      if (type == PaginationType.weekly || type == PaginationType.time) {
        _bucketStart = _nextBucketStart(page);
      }
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DateTime? _nextBucketStart(PageResult<T> page) {
    final start = _bucketStart;
    if (start == null) return null;
    final step = type == PaginationType.weekly
        ? const Duration(days: 7)
        : const Duration(days: 7);
    return start.add(step);
  }

  /// Clears the list and reloads from the first page.
  Future<void> refresh() async {
    _items.clear();
    _offset = 0;
    _nextCursor = null;
    _hasMore = true;
    _error = null;
    _bucketStart = null;
    notifyListeners();
    await loadMore();
  }

  /// Clears everything and returns to the initial state.
  void reset() {
    _items.clear();
    _offset = 0;
    _nextCursor = null;
    _hasMore = true;
    _error = null;
    _bucketStart = null;
    _isLoading = false;
    notifyListeners();
  }
}
