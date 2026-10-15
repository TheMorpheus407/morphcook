import 'package:flutter/foundation.dart';

enum PaginationType {
  cursor,
  offset,
  timeBased,
  weekly,
}

class PaginatedPageResult<T> {
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  const PaginatedPageResult({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });
}

typedef PageFetcher<T> = Future<PaginatedPageResult<T>> Function({
  required int pageIndex,
  required int offset,
  required int pageSize,
  String? cursor,
});

/// Manages paginated list state as specified in SPEC.md:
/// - `loadMore()` — Fetches the next page
/// - `refresh()` — Resets and reloads from page 1
/// - `reset()` — Clears all items and returns to initial state
/// - `shouldLoadMore(index)` — Returns true when the user is within prefetch threshold
/// - Enforces `maxRendered` guardrail (default 50 items; 4 weeks for meal plan).
class PaginationController<T> extends ChangeNotifier {
  final PaginationType type;
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;
  final PageFetcher<T> fetcher;

  List<T> _items = <T>[];
  String? _nextCursor;
  int _currentOffset = 0;
  int _currentPageIndex = 0;
  bool _hasMore = true;
  bool _isLoading = false;
  Object? _error;

  PaginationController({
    required this.type,
    required this.pageSize,
    required this.prefetchThreshold,
    this.maxRendered = 50,
    required this.fetcher,
  });

  /// Factory for Search view (Cursor-based, 20 items, prefetch 10, max 50).
  factory PaginationController.search({required PageFetcher<T> fetcher}) {
    return PaginationController<T>(
      type: PaginationType.cursor,
      pageSize: 20,
      prefetchThreshold: 10,
      maxRendered: 50,
      fetcher: fetcher,
    );
  }

  /// Factory for Cookbook saved view (Offset-based, 30 items, prefetch 10, max 50).
  factory PaginationController.cookbook({required PageFetcher<T> fetcher}) {
    return PaginationController<T>(
      type: PaginationType.offset,
      pageSize: 30,
      prefetchThreshold: 10,
      maxRendered: 50,
      fetcher: fetcher,
    );
  }

  /// Factory for History view (Time-based, 7 weeks, prefetch 1, max 50).
  factory PaginationController.history({required PageFetcher<T> fetcher}) {
    return PaginationController<T>(
      type: PaginationType.timeBased,
      pageSize: 7,
      prefetchThreshold: 1,
      maxRendered: 50,
      fetcher: fetcher,
    );
  }

  /// Factory for Meal Plan view (Weekly, 1 week, prefetch 0, max 4 weeks).
  factory PaginationController.mealPlan({required PageFetcher<T> fetcher}) {
    return PaginationController<T>(
      type: PaginationType.weekly,
      pageSize: 1,
      prefetchThreshold: 0,
      maxRendered: 4,
      fetcher: fetcher,
    );
  }

  List<T> get items => List<T>.unmodifiable(_items);
  String? get nextCursor => _nextCursor;
  int get currentOffset => _currentOffset;
  int get currentPageIndex => _currentPageIndex;
  bool get hasMore => _hasMore;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  /// Returns true when the user scrolls within [prefetchThreshold] of the current end.
  bool shouldLoadMore(int index) {
    if (!_hasMore || _isLoading) return false;
    if (_items.isEmpty) return true;
    final triggerIndex = (_items.length - 1 - prefetchThreshold).clamp(0, _items.length - 1);
    return index >= triggerIndex;
  }

  /// Fetches the next page and enforces the `maxRendered` guardrail.
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await fetcher(
        pageIndex: _currentPageIndex,
        offset: _currentOffset,
        pageSize: pageSize,
        cursor: _nextCursor,
      );

      final combined = <T>[..._items, ...result.items];
      if (combined.length > maxRendered) {
        // Dispose oldest off-screen items to maintain maxRendered guardrail
        _items = combined.sublist(combined.length - maxRendered);
      } else {
        _items = combined;
      }

      _currentOffset += result.items.length;
      _currentPageIndex += 1;
      _nextCursor = result.nextCursor;
      _hasMore = result.hasMore;
    } catch (e) {
      _error = e;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Resets and reloads from page 1.
  Future<void> refresh() async {
    _items = <T>[];
    _nextCursor = null;
    _currentOffset = 0;
    _currentPageIndex = 0;
    _hasMore = true;
    _error = null;
    await loadMore();
  }

  /// Clears all items and returns to initial state without fetching.
  void reset() {
    _items = <T>[];
    _nextCursor = null;
    _currentOffset = 0;
    _currentPageIndex = 0;
    _hasMore = true;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
