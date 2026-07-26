import 'package:flutter/foundation.dart';

/// Pagination strategies from SPEC.md. The type is chosen per view because the
/// data patterns genuinely differ — search results shift under you, saved
/// recipes do not.
enum PaginationType {
  /// Stable `nextCursor` token. Search.
  cursor,

  /// `offset + limit`. Cookbook.
  offset,

  /// Grouped into periods with section headers. History.
  time,

  /// One natural week at a time. Meal plan.
  weekly,
}

class PaginationConfig {
  const PaginationConfig({
    required this.type,
    required this.pageSize,
    required this.prefetchThreshold,
    required this.maxRendered,
  });

  /// Search — cursor, 20 per page, prefetch at 10, cap 50 rendered.
  static const PaginationConfig search = PaginationConfig(
    type: PaginationType.cursor,
    pageSize: 20,
    prefetchThreshold: 10,
    maxRendered: 50,
  );

  /// Cookbook — offset, 30 per page, prefetch at 10, cap 50 rendered.
  static const PaginationConfig cookbook = PaginationConfig(
    type: PaginationType.offset,
    pageSize: 30,
    prefetchThreshold: 10,
    maxRendered: 50,
  );

  /// History — time-based, 7 weeks per page, prefetch 1 week out, cap 50.
  static const PaginationConfig history = PaginationConfig(
    type: PaginationType.time,
    pageSize: 7,
    prefetchThreshold: 1,
    maxRendered: 50,
  );

  /// Meal plan — one week per page, no prefetch, keep 4 weeks alive.
  static const PaginationConfig mealPlan = PaginationConfig(
    type: PaginationType.weekly,
    pageSize: 1,
    prefetchThreshold: 0,
    maxRendered: 4,
  );

  final PaginationType type;
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;
}

/// One page handed back by a fetcher.
class PageResult<T> {
  const PageResult({required this.items, this.nextCursor, this.totalHint});

  final List<T> items;

  /// null means "no more pages".
  final String? nextCursor;

  /// Optional total, purely for the UI to show "of N".
  final int? totalHint;

  static PageResult<T> empty<T>() =>
      PageResult<T>(items: const [], nextCursor: null);
}

typedef PageFetcher<T> =
    Future<PageResult<T>> Function(String? cursor, int limit);

enum PaginationStatus { idle, loading, loadingMore, error, empty, ready }

/// Drives every paginated list in the app.
///
/// Never holds more than [PaginationConfig.maxRendered] items: older pages are
/// dropped from the head once the cap is passed, which is why the lists stay
/// responsive as user data grows.
class PaginationController<T> extends ChangeNotifier {
  PaginationController({required this.config, required PageFetcher<T> fetcher})
    : _fetcher = fetcher;

  final PaginationConfig config;
  PageFetcher<T> _fetcher;

  final List<T> _items = [];
  String? _cursor;
  bool _hasMore = true;
  int _droppedFromHead = 0;
  int? _total;
  Object? _error;
  PaginationStatus _status = PaginationStatus.idle;
  int _generation = 0;

  List<T> get items => List.unmodifiable(_items);
  PaginationStatus get status => _status;
  Object? get error => _error;
  bool get hasMore => _hasMore;
  int? get total => _total;

  /// How many items scrolled off the top and were disposed to honour the cap.
  int get droppedFromHead => _droppedFromHead;

  bool get isLoading =>
      _status == PaginationStatus.loading ||
      _status == PaginationStatus.loadingMore;

  /// True when the user has scrolled within [PaginationConfig.prefetchThreshold]
  /// of the end and another page is worth starting.
  bool shouldLoadMore(int index) {
    if (!_hasMore || isLoading) return false;
    return index >= _items.length - config.prefetchThreshold - 1;
  }

  void replaceFetcher(PageFetcher<T> fetcher) {
    _fetcher = fetcher;
  }

  Future<void> loadMore() async {
    if (!_hasMore || isLoading) return;
    final generation = _generation;
    _status = _items.isEmpty
        ? PaginationStatus.loading
        : PaginationStatus.loadingMore;
    _error = null;
    notifyListeners();

    try {
      final page = await _fetcher(_cursor, config.pageSize);
      if (generation != _generation) return; // reset() happened mid-flight
      _items.addAll(page.items);
      _cursor = page.nextCursor;
      _hasMore = page.nextCursor != null && page.items.isNotEmpty;
      _total = page.totalHint ?? _total;
      _enforceRenderCap();
      _status = _items.isEmpty
          ? PaginationStatus.empty
          : PaginationStatus.ready;
    } on Object catch (err) {
      if (generation != _generation) return;
      _error = err;
      _status = PaginationStatus.error;
    }
    notifyListeners();
  }

  void _enforceRenderCap() {
    final excess = _items.length - config.maxRendered;
    if (excess > 0) {
      _items.removeRange(0, excess);
      _droppedFromHead += excess;
    }
  }

  /// Clears everything and pulls page one again.
  Future<void> refresh() async {
    reset();
    await loadMore();
  }

  void reset() {
    _generation++;
    _items.clear();
    _cursor = null;
    _hasMore = true;
    _droppedFromHead = 0;
    _total = null;
    _error = null;
    _status = PaginationStatus.idle;
    notifyListeners();
  }
}

/// Turns any in-memory list into a cursor-paginated source. The cursor is the
/// offset encoded as a string, which keeps the contract identical to a real
/// backend cursor without pretending to be one.
PageFetcher<T> listFetcher<T>(List<T> Function() supplier) {
  return (String? cursor, int limit) async {
    final all = supplier();
    final start = int.tryParse(cursor ?? '0') ?? 0;
    if (start >= all.length) {
      return PageResult<T>(items: const [], totalHint: all.length);
    }
    final end = (start + limit).clamp(0, all.length);
    return PageResult<T>(
      items: all.sublist(start, end),
      nextCursor: end < all.length ? end.toString() : null,
      totalHint: all.length,
    );
  };
}
