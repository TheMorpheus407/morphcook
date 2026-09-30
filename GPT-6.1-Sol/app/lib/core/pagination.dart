import 'package:flutter/foundation.dart';

enum PaginationType { cursor, offset, time, weekly }

class PageResult<T> {
  final List<T> items;
  final String? nextCursor;
  PageResult(this.items, this.nextCursor);
}

typedef PageLoader<T> =
    Future<PageResult<T>> Function(String? cursor, int limit);

/// Lists are built lazily; only the visible viewport creates widgets.
class PaginationController<T> extends ChangeNotifier {
  final PageLoader<T> loader;
  final int pageSize;
  final int prefetchThreshold;
  final PaginationType type;
  final List<T> items = [];
  String? nextCursor;
  bool loading = false;
  bool hasMore = true;
  Object? error;
  int _generation = 0;
  bool _disposed = false;

  PaginationController({
    required this.loader,
    this.pageSize = 20,
    this.prefetchThreshold = 10,
    this.type = PaginationType.cursor,
  });

  Future<void> loadMore() async {
    if (loading || !hasMore || _disposed) return;
    final generation = _generation;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await loader(nextCursor, pageSize);
      if (_disposed || generation != _generation) return;
      items.addAll(page.items);
      nextCursor = page.nextCursor;
      hasMore = nextCursor != null;
    } catch (e) {
      if (!_disposed && generation == _generation) error = e;
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  bool shouldLoadMore(int index) =>
      hasMore &&
      !loading &&
      error == null &&
      index >= items.length - prefetchThreshold;

  void reset() {
    _generation++;
    items.clear();
    nextCursor = null;
    loading = false;
    hasMore = true;
    error = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    reset();
    await loadMore();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

PageResult<T> offsetPage<T>(List<T> source, String? cursor, int limit) {
  final start = (int.tryParse(cursor ?? '') ?? 0).clamp(0, source.length);
  final end = (start + limit).clamp(0, source.length);
  return PageResult(
    source.sublist(start, end),
    end < source.length ? '$end' : null,
  );
}

/// A stable ID cursor survives insertions ahead of a previous page.
PageResult<T> cursorPage<T>(
  List<T> source,
  String? cursor,
  int limit,
  String Function(T) id,
) {
  final previous = cursor == null
      ? -1
      : source.indexWhere((item) => id(item) == cursor);
  final start = previous + 1;
  final end = (start + limit).clamp(0, source.length);
  final items = source.sublist(start, end);
  return PageResult(
    items,
    end < source.length && items.isNotEmpty ? id(items.last) : null,
  );
}
