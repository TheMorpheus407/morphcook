import 'package:flutter/foundation.dart';

class PaginationPage<T> {
  const PaginationPage({required this.items, this.nextCursor, this.offset = 0});
  final List<T> items;
  final String? nextCursor;
  final int offset;
}

class PaginationController<T> extends ChangeNotifier {
  PaginationController({
    required this.loader,
    this.pageSize = 20,
    this.prefetchThreshold = 10,
    this.maxRendered = 50,
    this.useOffset = false,
  });

  final Future<PaginationPage<T>> Function(String? cursor, int offset) loader;
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;
  final bool useOffset;
  final List<T> items = [];
  String? nextCursor;
  int offset = 0;
  bool isLoading = false;
  bool hasMore = true;
  Object? error;
  bool initialized = false;
  int _generation = 0;

  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;
    final generation = _generation;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final page = await loader(nextCursor, offset);
      if (generation != _generation) return;
      items.addAll(page.items);
      if (items.length > maxRendered) {
        items.removeRange(0, items.length - maxRendered);
      }
      offset = useOffset ? offset + page.items.length : offset;
      nextCursor = useOffset
          ? (page.items.length < pageSize ? null : '$offset')
          : page.nextCursor;
      hasMore = useOffset
          ? page.items.length >= pageSize
          : page.nextCursor != null;
      initialized = true;
    } catch (exception) {
      if (generation != _generation) return;
      error = exception;
      initialized = true;
    } finally {
      if (generation == _generation) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    reset();
    await loadMore();
  }

  void reset() {
    _generation++;
    items.clear();
    nextCursor = null;
    offset = 0;
    isLoading = false;
    hasMore = true;
    error = null;
    initialized = false;
    notifyListeners();
  }

  bool shouldLoadMore(int index) =>
      hasMore && !isLoading && index >= items.length - prefetchThreshold;
}

class HistoryWeek<T> {
  const HistoryWeek({required this.start, required this.items});
  final DateTime start;
  final List<T> items;
}

class HistoryPaginationController<T> extends ChangeNotifier {
  HistoryPaginationController({required this.loader, this.maxRendered = 50});
  final List<HistoryWeek<T>> Function(DateTime before, int weeks) loader;
  final int maxRendered;
  final List<HistoryWeek<T>> weeks = [];
  DateTime? oldestWeek;
  bool isLoading = false;
  bool hasMore = true;

  Future<void> loadMore() async {
    if (isLoading || !hasMore) return;
    isLoading = true;
    notifyListeners();
    final before = oldestWeek ?? DateTime.now();
    final loaded = loader(before, 7);
    if (loaded.isEmpty) {
      hasMore = false;
    } else {
      weeks.addAll(loaded);
      oldestWeek = loaded.last.start;
      final total = weeks.fold<int>(0, (sum, week) => sum + week.items.length);
      if (total > maxRendered) {
        var remove = total - maxRendered;
        while (remove > 0 && weeks.isNotEmpty) {
          if (weeks.last.items.length <= remove) {
            remove -= weeks.last.items.length;
            weeks.removeLast();
          } else {
            weeks.last.items.removeRange(0, remove);
            remove = 0;
          }
        }
      }
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    reset();
    await loadMore();
  }

  bool shouldLoadMore(int weekIndex) =>
      hasMore && !isLoading && weekIndex >= weeks.length - 2;

  void reset() {
    weeks.clear();
    oldestWeek = null;
    hasMore = true;
    isLoading = false;
    notifyListeners();
  }
}
