import 'package:flutter/foundation.dart';
import 'models.dart';

enum PaginationType { cursor, offset, time, weekly }

class PageRequest {
  final PaginationType type;
  final int offset;
  final int limit;
  final String? cursor;
  final DateTime? startDate;
  final DateTime? endDate;
  const PageRequest({
    required this.type,
    required this.offset,
    required this.limit,
    this.cursor,
    this.startDate,
    this.endDate,
  });
  String? get week => startDate == null ? null : weekKey(startDate!);
}

class PageResult<T> {
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  final DateTime? nextDate;
  const PageResult({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    this.nextDate,
  });
}

/// Retains lightweight records so lazily built lists can scroll backward safely.
/// The view disposes off-screen widgets; [renderedWindow] bounds explicit windows.
class PaginationController<T> extends ChangeNotifier {
  final Future<PageResult<T>> Function(PageRequest request) loader;
  final PaginationType type;
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;
  final DateTime? initialDate;
  List<T> _items = [];
  bool isLoading = false;
  bool hasMore = true;
  Object? error;
  String? nextCursor;
  int _offset = 0;
  int baseIndex = 0;
  int _generation = 0;
  bool _disposed = false;
  DateTime? _nextDate;

  PaginationController({
    required this.loader,
    this.type = PaginationType.cursor,
    this.pageSize = 20,
    this.prefetchThreshold = 10,
    this.maxRendered = 50,
    this.initialDate,
  }) : assert(pageSize > 0),
       assert(maxRendered > 0),
       assert(prefetchThreshold >= 0);

  List<T> get items => List.unmodifiable(_items);
  List<T> renderedWindow(int firstVisible) {
    final start = firstVisible.clamp(0, _items.length);
    final end = (start + maxRendered).clamp(0, _items.length);
    return List.unmodifiable(_items.sublist(start, end));
  }

  int get loadedCount => _offset;
  bool get isEmpty => _items.isEmpty;

  bool shouldLoadMore(int index) =>
      !isLoading &&
      hasMore &&
      error == null &&
      index >= _items.length - 1 - prefetchThreshold;

  Future<void> loadMore() async {
    if (_disposed || isLoading || !hasMore) return;
    final generation = _generation;
    isLoading = true;
    error = null;
    notifyListeners();
    final end =
        _nextDate ??
        initialDate ??
        _calendarShift(mondayOfWeek(DateTime.now()), 7);
    final start = _calendarShift(
      end,
      -7 * (type == PaginationType.weekly ? 1 : pageSize),
    );
    final dated = type == PaginationType.time || type == PaginationType.weekly;
    try {
      final page = await loader(
        PageRequest(
          type: type,
          offset: _offset,
          limit: pageSize,
          cursor: nextCursor,
          startDate: dated ? start : null,
          endDate: dated ? end : null,
        ),
      );
      if (_disposed || generation != _generation) return;
      _items.addAll(page.items);
      _offset += page.items.length;
      nextCursor = page.nextCursor;
      _nextDate = page.nextDate ?? (dated ? start : null);
      hasMore = page.hasMore;
    } catch (exception) {
      if (!_disposed && generation == _generation) error = exception;
    } finally {
      if (!_disposed && generation == _generation) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void reset() {
    if (_disposed) return;
    _generation++;
    _items = [];
    isLoading = false;
    hasMore = true;
    error = null;
    nextCursor = null;
    _nextDate = null;
    _offset = 0;
    baseIndex = 0;
    notifyListeners();
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

DateTime _calendarShift(DateTime date, int days) => date.isUtc
    ? DateTime.utc(date.year, date.month, date.day + days)
    : DateTime(date.year, date.month, date.day + days);

/// Recipe-id cursors are stable when earlier matches are inserted or removed.
PageResult<T> cursorPage<T>(
  List<T> data,
  PageRequest request,
  String Function(T) id,
) {
  final cursorIndex = request.cursor == null
      ? -1
      : data.indexWhere((e) => id(e) == request.cursor);
  final start = cursorIndex < 0 ? 0 : cursorIndex + 1;
  final end = (start + request.limit).clamp(0, data.length);
  final rows = data.sublist(start, end);
  return PageResult(
    items: rows,
    nextCursor: rows.isEmpty ? null : id(rows.last),
    hasMore: end < data.length,
  );
}

PageResult<T> offsetPage<T>(List<T> data, PageRequest request) {
  final start = request.offset.clamp(0, data.length);
  final end = (start + request.limit).clamp(0, data.length);
  return PageResult(
    items: data.sublist(start, end),
    hasMore: end < data.length,
  );
}
