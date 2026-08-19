/// PaginationController (ChangeNotifier) per spec:
///   loadMore() / refresh() / reset() / shouldLoadMore(index)
/// with per-view page sizes, prefetch thresholds and max rendered items.
library;

import 'package:flutter/foundation.dart';

class PaginationPolicy {
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;
  const PaginationPolicy({
    required this.pageSize,
    required this.prefetchThreshold,
    required this.maxRendered,
  });

  // spec table: search 20/10/50, cookbook 30/10/50, history 7wk/1wk/50,
  // meal plan 1wk/0/4wk
  static const search = PaginationPolicy(pageSize: 20, prefetchThreshold: 10, maxRendered: 50);
  static const cookbook = PaginationPolicy(pageSize: 30, prefetchThreshold: 10, maxRendered: 50);
  static const history = PaginationPolicy(pageSize: 7, prefetchThreshold: 1, maxRendered: 50);
  static const weekly = PaginationPolicy(pageSize: 1, prefetchThreshold: 0, maxRendered: 4);
}

/// Generic page-fetcher: returns (items, nextCursor-or-null). For
/// offset-based lists return cursor = '${offset+page.length}'.
typedef PageFetcher<T> = Future<List<T>> Function(String? cursor);

enum PageStatus { idle, loading, loadingMore, error }

class PaginationController<T> extends ChangeNotifier {
  final PaginationPolicy policy;
  final PageFetcher<T> fetchPage;

  final List<T> items = [];
  String? _cursor;
  PageStatus status = PageStatus.idle;
  String? error;
  bool _exhausted = false;
  bool _disposed = false;

  PaginationController({required this.policy, required this.fetchPage});

  bool get isLoading => status == PageStatus.loading;
  bool get hasMore => !_exhausted;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// Load page 1 (fresh).
  Future<void> refresh() async {
    items.clear();
    _cursor = null;
    _exhausted = false;
    status = PageStatus.loading;
    error = null;
    _notify();
    try {
      final page = await fetchPage(null);
      if (_disposed) return;
      items.addAll(page.take(policy.maxRendered));
      _advanceCursor(page);
      status = PageStatus.idle;
    } catch (e) {
      error = e.toString();
      status = PageStatus.error;
    }
    _notify();
  }

  /// Fetch the next page (no-op when exhausted or already loading more).
  Future<void> loadMore() async {
    if (_exhausted || status == PageStatus.loadingMore ||
        status == PageStatus.loading) {
      return;
    }
    status = PageStatus.loadingMore;
    _notify();
    try {
      final page = await fetchPage(_cursor);
      if (_disposed) return;
      if (page.isEmpty) {
        _exhausted = true;
      } else {
        final room = policy.maxRendered - items.length;
        items.addAll(page.take(room));
        if (page.length < policy.pageSize) _exhausted = true;
        _advanceCursor(page);
        if (items.length >= policy.maxRendered) _exhausted = true;
      }
      status = PageStatus.idle;
    } catch (e) {
      error = e.toString();
      status = PageStatus.error;
    }
    _notify();
  }

  void _advanceCursor(List<T> page) {
    if (page.isEmpty) {
      _exhausted = true;
      _cursor = null;
    } else if (page.length < policy.pageSize) {
      _exhausted = true;
      _cursor = _cursor != null
          ? '${(int.tryParse(_cursor!) ?? 0) + page.length}'
          : '${page.length}';
    } else {
      _cursor = _cursor != null
          ? '${(int.tryParse(_cursor!) ?? 0) + page.length}'
          : '${page.length}';
    }
  }

  /// True when the index is within the prefetch threshold of the end.
  bool shouldLoadMore(int index) {
    if (_exhausted) return false;
    if (items.isEmpty) return false;
    return index >= items.length - policy.prefetchThreshold - 1;
  }

  /// Clear everything, return to initial state.
  void reset() {
    items.clear();
    _cursor = null;
    _exhausted = false;
    status = PageStatus.idle;
    error = null;
    _notify();
  }
}
