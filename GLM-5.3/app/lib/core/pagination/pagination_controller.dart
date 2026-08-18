import 'package:flutter/foundation.dart';

/// One page of a cursor-paginated result set.
class Page<T> {
  Page({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;
}

typedef PageFetcher<T> = Future<Page<T>> Function(String? cursor);

/// Cursor-based pagination controller (SPEC): `loadMore()`, `refresh()`,
/// `reset()`, `shouldLoadMore(index)` with page size, prefetch threshold and
/// a max-rendered-items guardrail. Offset-based and time-based strategies
/// express their cursors as strings (offset number / week index).
class PaginationController<T> extends ChangeNotifier {
  PaginationController({
    required this.fetch,
    this.pageSize = 20,
    this.prefetchThreshold = 10,
    this.maxItems = 50,
  });

  final PageFetcher<T> fetch;
  final int pageSize;
  final int prefetchThreshold;
  final int maxItems;

  final List<T> items = [];
  String? _cursor;
  bool isLoading = false;
  bool hasMore = true;
  String? error;

  /// True when a fetch is needed but nothing has been loaded yet.
  bool get isInitial => items.isEmpty && !isLoading && hasMore && _cursor == null;

  /// Fetches the next page (no-op while a fetch is in flight, when the max
  /// rendered guardrail is reached, or when no more pages exist).
  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;
    if (items.length >= maxItems) {
      hasMore = false;
      notifyListeners();
      return;
    }
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final page = await fetch(_cursor);
      items.addAll(page.items.take(maxItems - items.length));
      _cursor = page.nextCursor;
      hasMore = page.nextCursor != null && items.length < maxItems;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Resets and reloads from page 1.
  Future<void> refresh() {
    reset();
    return loadMore();
  }

  /// Clears all items and returns to the initial state.
  void reset() {
    items.clear();
    _cursor = null;
    hasMore = true;
    error = null;
    isLoading = false;
    notifyListeners();
  }

  /// True when the user scrolled within the prefetch threshold of the end.
  bool shouldLoadMore(int index) =>
      hasMore && !isLoading && index >= items.length - prefetchThreshold;
}
