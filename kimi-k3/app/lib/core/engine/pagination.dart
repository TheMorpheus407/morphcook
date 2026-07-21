import 'package:flutter/foundation.dart';

/// Generic pagination state machine used by search (cursor), cookbook
/// (offset), history (time-based) and meal plan (weekly).
///
/// Guardrails from the spec: never render more than [maxRendered] items,
/// prefetch when the user scrolls within [prefetchThreshold] of the end.
class PaginationController<T> extends ChangeNotifier {
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;

  /// Fetches the page starting at [cursor]; returns the items plus the next
  /// cursor (null when exhausted).
  final Future<List<T>> Function(String? cursor) fetchPage;
  final String? Function(List<T> page)? nextCursorOf;

  final List<T> items = [];
  bool isLoading = false;
  bool hasMore = true;
  Object? error;
  String? _cursor;

  PaginationController({
    required this.fetchPage,
    this.nextCursorOf,
    this.pageSize = 20,
    this.prefetchThreshold = 10,
    this.maxRendered = 50,
  });

  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final page = await fetchPage(_cursor);
      items.addAll(page);
      _cursor = nextCursorOf?.call(page) ??
          (page.length >= pageSize ? items.length.toString() : null);
      hasMore = _cursor != null && page.isNotEmpty;
      // Enforce the render guardrail: drop the oldest items beyond the cap.
      if (items.length > maxRendered) {
        items.removeRange(0, items.length - maxRendered);
      }
    } catch (e) {
      error = e;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    reset();
    await loadMore();
  }

  void reset() {
    items.clear();
    _cursor = null;
    hasMore = true;
    isLoading = false;
    error = null;
    notifyListeners();
  }

  bool shouldLoadMore(int index) =>
      hasMore && !isLoading && index >= items.length - prefetchThreshold;
}
