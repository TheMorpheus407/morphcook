// Pagination primitives shared by search (cursor), cookbook (offset),
// history (time-based) and the meal plan (weekly).
import 'package:flutter/foundation.dart';

class Page<T, C> {
  const Page({required this.items, this.nextCursor});
  final List<T> items;

  /// Null when there is nothing more to load.
  final C? nextCursor;
}

typedef PageLoader<T, C> = Future<Page<T, C>> Function(C? cursor, int pageSize);

/// ChangeNotifier that owns the loaded items of one paginated view.
///
/// Guardrails: never more than [maxRendered] items; [shouldLoadMore]
/// triggers when the user is within [prefetchThreshold] of the end.
class PaginationController<T, C> extends ChangeNotifier {
  PaginationController({
    required this.loader,
    this.pageSize = 20,
    this.prefetchThreshold = 10,
    this.maxRendered = 50,
  });

  final PageLoader<T, C> loader;
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;

  final List<T> _items = [];
  List<T> get items => List.unmodifiable(_items);

  bool _loading = false;
  bool get isLoading => _loading;

  Object? _error;
  Object? get error => _error;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  bool _capReached = false;
  bool get capReached => _capReached;

  bool _loadedOnce = false;
  bool get loadedOnce => _loadedOnce;
  bool get isEmpty => _loadedOnce && _items.isEmpty && !_loading;

  C? _cursor;
  C? get cursor => _cursor;

  int _generation = 0;

  bool shouldLoadMore(int index) =>
      !_loading && _hasMore && !_capReached && index >= _items.length - prefetchThreshold;

  Future<void> loadMore() async {
    if (_loading || !_hasMore || _capReached) return;
    final gen = _generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await loader(_cursor, pageSize);
      if (gen != _generation) return;
      _items.addAll(page.items);
      _cursor = page.nextCursor;
      _hasMore = page.nextCursor != null && page.items.isNotEmpty;
      if (_items.length >= maxRendered) {
        _items.removeRange(maxRendered, _items.length);
        _capReached = true;
        _hasMore = false;
      }
    } catch (e) {
      if (gen != _generation) return;
      _error = e;
    } finally {
      if (gen == _generation) {
        _loading = false;
        _loadedOnce = true;
        notifyListeners();
      }
    }
  }

  /// Resets and reloads from page 1.
  Future<void> refresh() async {
    reset();
    await loadMore();
  }

  /// Clears all items and returns to the initial state.
  void reset() {
    _generation++;
    _items.clear();
    _cursor = null;
    _hasMore = true;
    _capReached = false;
    _loading = false;
    _error = null;
    _loadedOnce = false;
    notifyListeners();
  }
}

/// Offset pagination over an in-memory list (cookbook).
Page<T, int> offsetPage<T>(List<T> all, int? cursor, int pageSize) {
  final start = cursor ?? 0;
  if (start >= all.length) return const Page(items: []);
  final end = (start + pageSize).clamp(0, all.length);
  return Page(items: all.sublist(start, end), nextCursor: end < all.length ? end : null);
}

/// Time-based pagination: items sorted newest-first, pages of [weeks]
/// whole weeks. The cursor is the exclusive upper bound of the next window.
/// Empty windows are skipped so a quiet month never stalls the list.
Page<T, DateTime> timePage<T>(
  List<T> newestFirst,
  DateTime Function(T) timeOf,
  DateTime? cursor,
  int weeks, {
  required DateTime Function() now,
}) {
  if (newestFirst.isEmpty) return const Page(items: []);
  var upper = cursor ?? now().add(const Duration(days: 1));
  for (var guard = 0; guard < 520; guard++) {
    final lower = upper.subtract(Duration(days: 7 * weeks));
    final items = [for (final e in newestFirst) if (timeOf(e).isBefore(upper) && !timeOf(e).isBefore(lower)) e];
    final remaining = newestFirst.any((e) => timeOf(e).isBefore(lower));
    if (items.isNotEmpty || !remaining) return Page(items: items, nextCursor: remaining ? lower : null);
    upper = lower;
  }
  return const Page(items: []);
}
