import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// How a list pages through its data.
enum PaginationType {
  /// `nextCursor` token, stable while the data changes (search).
  cursor,

  /// `offset + limit`, predictable for lists sorted by saved date (cookbook).
  offset,

  /// Pages of weeks with section headers (cooking history).
  time,

  /// One week per page (meal plan).
  weekly,
}

/// Page size, prefetch threshold and the cap on what stays in memory.
///
/// | View      | Type   | Page size | Prefetch | Max rendered |
/// |-----------|--------|-----------|----------|--------------|
/// | Search    | cursor | 20 items  | 10 items | 50 items     |
/// | Cookbook  | offset | 30 items  | 10 items | 50 items     |
/// | History   | time   | 7 weeks   | 1 week   | 50 items     |
/// | Meal plan | weekly | 1 week    | 0        | 4 weeks      |
class PaginationConfig {
  const PaginationConfig({
    required this.type,
    required this.pageSize,
    required this.prefetchThreshold,
    required this.maxRendered,
  });

  final PaginationType type;

  /// Items per page (weeks for [PaginationType.time] and [PaginationType.weekly]).
  final int pageSize;

  /// Load more when the reader is this close to the end (items, or weeks for time-based lists).
  final int prefetchThreshold;

  /// Never keep more than this many items (weeks for the meal plan) in memory.
  final int maxRendered;

  static const PaginationConfig search = PaginationConfig(
    type: PaginationType.cursor,
    pageSize: 20,
    prefetchThreshold: 10,
    maxRendered: 50,
  );
  static const PaginationConfig cookbook = PaginationConfig(
    type: PaginationType.offset,
    pageSize: 30,
    prefetchThreshold: 10,
    maxRendered: 50,
  );
  static const PaginationConfig history = PaginationConfig(
    type: PaginationType.time,
    pageSize: 7,
    prefetchThreshold: 1,
    maxRendered: 50,
  );
  static const PaginationConfig mealPlan = PaginationConfig(
    type: PaginationType.weekly,
    pageSize: 1,
    prefetchThreshold: 0,
    maxRendered: 4,
  );
}

/// Opaque address of a page: a cursor string, an offset, a week number, ...
/// Wrapped so that "no page" (`null`) is distinct from a page whose key is null.
class PageKey {
  const PageKey(this.value);
  final Object? value;
}

class PageResult<T> {
  const PageResult({required this.items, this.next, this.previous});

  final List<T> items;

  /// Where the following page lives; `null` at the end.
  final PageKey? next;

  /// Where the preceding page lives; `null` at the start.
  final PageKey? previous;
}

typedef PageLoader<T> = Future<PageResult<T>> Function(PageKey key, int limit);

class CursorPage<T> {
  const CursorPage(this.items, {this.nextCursor});
  final List<T> items;
  final String? nextCursor;
}

class OffsetPage<T> {
  const OffsetPage(this.items, {this.total});
  final List<T> items;
  final int? total;
}

class TimePage<T> {
  const TimePage(this.items, {required this.hasMore});

  /// Newest first.
  final List<T> items;
  final bool hasMore;
}

enum PaginationStatus { idle, loading, ready, error }

/// What the last load did to the window, so a scroll view can keep its place.
class TrimEvent {
  const TrimEvent({this.front = 0, this.back = 0});
  final int front;
  final int back;
  bool get isEmpty => front == 0 && back == 0;
}

/// A page as the loader returned it, plus how much of it was trimmed off the
/// window. Trimming works item by item, so the window is exactly `maxRendered`
/// long, and [skipFront] / [skipBack] remember what a later reload has to put back.
class _LoadedPage<T> {
  _LoadedPage({required this.key, required this.items, this.next, this.previous});

  final PageKey key;
  List<T> items;
  PageKey? next;
  PageKey? previous;
  int skipFront = 0;
  int skipBack = 0;

  int get length => items.length - skipFront - skipBack;
  Iterable<T> get shown => items.getRange(skipFront, items.length - skipBack);
}

/// Loads a long list page by page and keeps at most `maxRendered` items alive.
///
/// * [loadMore] fetches the next page.
/// * [refresh] resets and reloads from page one.
/// * [reset] clears everything and returns to the initial state.
/// * [shouldLoadMore] tells a list builder when the reader is within the
///   prefetch threshold of the end.
///
/// When the window outgrows `maxRendered`, the oldest items fall off the far
/// end, never more than needed and never the ones the reader is looking at
/// (the `firstVisible` / `lastVisible` arguments of [loadMore] and
/// [loadPrevious]). Scrolling back towards them reloads them.
class PaginationController<T> extends ChangeNotifier {
  PaginationController({
    required this.config,
    required PageLoader<T> loader,
    PageKey initialKey = const PageKey(null),
    this.groupOf,
  }) : _loader = loader,
       _initialKey = initialKey;

  /// Cursor-based paging: the loader receives the previous page's `nextCursor`.
  factory PaginationController.cursor({
    PaginationConfig config = PaginationConfig.search,
    required Future<CursorPage<T>> Function(String? cursor, int limit) loader,
  }) {
    return PaginationController<T>(
      config: config,
      loader: (key, limit) async {
        final page = await loader(key.value as String?, limit);
        return PageResult<T>(items: page.items, next: page.nextCursor == null ? null : PageKey(page.nextCursor));
      },
    );
  }

  /// Offset-based paging, for lists sorted by saved date.
  factory PaginationController.offset({
    PaginationConfig config = PaginationConfig.cookbook,
    required Future<OffsetPage<T>> Function(int offset, int limit) loader,
  }) {
    return PaginationController<T>(
      config: config,
      initialKey: const PageKey(0),
      loader: (key, limit) async {
        final offset = key.value as int;
        final page = await loader(offset, limit);
        final end = offset + page.items.length;
        final more = page.total != null ? end < page.total! : page.items.length >= limit;
        return PageResult<T>(
          items: page.items,
          next: more && page.items.isNotEmpty ? PageKey(end) : null,
          previous: offset > 0 ? PageKey((offset - limit).clamp(0, offset)) : null,
        );
      },
    );
  }

  /// Time-based paging: page `n` covers `weeksPerPage` weeks, `n` pages back.
  /// [groupOf] maps an item to its week ordinal (used for the prefetch rule).
  factory PaginationController.time({
    PaginationConfig config = PaginationConfig.history,
    required Future<TimePage<T>> Function(int pageIndex, int weeksPerPage) loader,
    required int Function(T item) groupOf,
  }) {
    return PaginationController<T>(
      config: config,
      initialKey: const PageKey(0),
      groupOf: groupOf,
      loader: (key, limit) async {
        final index = key.value as int;
        final page = await loader(index, limit);
        return PageResult<T>(
          items: page.items,
          next: page.hasMore ? PageKey(index + 1) : null,
          previous: index > 0 ? PageKey(index - 1) : null,
        );
      },
    );
  }

  /// Weekly paging: one item per week, unbounded in both directions. Page
  /// keys are week offsets from the first page.
  factory PaginationController.weekly({
    PaginationConfig config = PaginationConfig.mealPlan,
    int startOffset = 0,
    required Future<T> Function(int weekOffset) loader,
  }) {
    return PaginationController<T>(
      config: config,
      initialKey: PageKey(startOffset),
      loader: (key, limit) async {
        final offset = key.value as int;
        return PageResult<T>(items: [await loader(offset)], next: PageKey(offset + 1), previous: PageKey(offset - 1));
      },
    );
  }

  final PaginationConfig config;
  final PageLoader<T> _loader;
  final PageKey _initialKey;

  /// Week ordinal of an item, for time-based lists.
  final int Function(T item)? groupOf;

  final List<_LoadedPage<T>> _pages = <_LoadedPage<T>>[];
  List<T> _items = <T>[];
  PaginationStatus _status = PaginationStatus.idle;
  bool _loadingMore = false;
  Object? _error;
  int _generation = 0;
  int _epoch = 0;
  int _trimmedFront = 0;
  TrimEvent _lastTrim = const TrimEvent();
  bool _disposed = false;

  /// The items currently held in memory (never more than `maxRendered`).
  List<T> get items => _items;

  /// Absolute index of `items.first`: how many items fell off the front.
  int get trimmedFront => _trimmedFront;

  /// Grows on every [refresh] and [reset]; a list view uses it to tell a fresh
  /// start from a page that was appended or trimmed.
  int get epoch => _epoch;

  PaginationStatus get status => _status;

  /// First page is loading: show skeleton rows.
  bool get isInitialLoading => _status == PaginationStatus.loading && _pages.isEmpty;
  bool get isLoadingMore => _loadingMore;
  bool get hasError => _error != null;
  Object? get error => _error;

  /// Loaded successfully and there is nothing to show.
  bool get isEmpty => _status == PaginationStatus.ready && _items.isEmpty;

  bool get hasMore => _pages.isNotEmpty && (_pages.last.skipBack > 0 || _pages.last.next != null);
  bool get hasPrevious => _pages.isNotEmpty && (_pages.first.skipFront > 0 || _pages.first.previous != null);

  TrimEvent get lastTrim => _lastTrim;

  /// `true` when the reader at [index] is within the prefetch threshold of the
  /// end and another page is available.
  bool shouldLoadMore(int index) {
    if (!hasMore || _loadingMore || _status == PaginationStatus.loading || _error != null) return false;
    if (_items.isEmpty) return false;
    final group = groupOf;
    if (config.type == PaginationType.time && group != null) {
      final itemWeek = group(_items[index.clamp(0, _items.length - 1)]);
      final lastWeek = group(_items.last);
      return (itemWeek - lastWeek).abs() <= config.prefetchThreshold;
    }
    return index >= _items.length - 1 - config.prefetchThreshold;
  }

  /// Mirror of [shouldLoadMore] for the start of the window.
  bool shouldLoadPrevious(int index) {
    if (!hasPrevious || _loadingMore || _status == PaginationStatus.loading) return false;
    return index <= config.prefetchThreshold;
  }

  /// Loads the first page. Any earlier state is discarded.
  Future<void> refresh() async {
    _generation++;
    _epoch++;
    final generation = _generation;
    _pages.clear();
    _items = <T>[];
    _trimmedFront = 0;
    _error = null;
    _loadingMore = false;
    _lastTrim = const TrimEvent();
    _status = PaginationStatus.loading;
    _notify();
    try {
      final (usedKey, result) = await _fetch(_initialKey);
      if (generation != _generation) return;
      final skipped = !identical(usedKey, _initialKey) && usedKey.value != _initialKey.value;
      _pages.add(
        _LoadedPage<T>(
          key: usedKey,
          items: result.items,
          next: result.next,
          previous: skipped ? null : result.previous,
        ),
      );
      _status = PaginationStatus.ready;
      _rebuild();
    } catch (e) {
      if (generation != _generation) return;
      _error = e;
      _status = PaginationStatus.error;
    }
    _notify();
  }

  /// Fetches the next page (a no-op at the end or while another load runs).
  ///
  /// [firstVisible] is the index of the first item the reader can see. Items
  /// above it may be trimmed to respect `maxRendered`, the ones from it on stay.
  /// Without it, trimming is not held back.
  Future<void> loadMore({int? firstVisible}) async {
    if (_status == PaginationStatus.idle) return refresh();
    if (!hasMore || _loadingMore || _status == PaginationStatus.loading) return;
    final generation = _generation;
    final last = _pages.last;
    _loadingMore = true;
    _error = null;
    _notify();
    try {
      if (last.skipBack > 0) {
        // The tail of the last page was trimmed away earlier: read it again.
        final (_, result) = await _fetch(last.key);
        if (generation != _generation) return;
        last
          ..items = result.items
          ..skipBack = 0
          ..next = result.next;
      } else {
        final (usedKey, result) = await _fetch(last.next!);
        if (generation != _generation) return;
        _pages.add(_LoadedPage<T>(key: usedKey, items: result.items, next: result.next, previous: result.previous));
      }
      _trim(fromFront: true, keep: firstVisible);
      _rebuild();
    } catch (e) {
      if (generation != _generation) return;
      _error = e;
    }
    _loadingMore = false;
    _notify();
  }

  /// Reloads what lies before the window (trimmed items, or the previous week).
  ///
  /// [lastVisible] is the index of the last item the reader can see; items
  /// below it may be trimmed, the ones up to it stay.
  Future<void> loadPrevious({int? lastVisible}) async {
    if (!hasPrevious || _loadingMore || _status == PaginationStatus.loading) return;
    final generation = _generation;
    final first = _pages.first;
    _loadingMore = true;
    _error = null;
    _notify();
    try {
      var prepended = 0;
      if (first.skipFront > 0) {
        final (_, result) = await _fetch(first.key, forward: false);
        if (generation != _generation) return;
        prepended = first.skipFront;
        _trimmedFront -= prepended;
        first
          ..items = result.items
          ..skipFront = 0
          ..previous = result.previous;
      } else {
        final (usedKey, result) = await _fetch(first.previous!, forward: false);
        if (generation != _generation) return;
        _pages.insert(
          0,
          _LoadedPage<T>(key: usedKey, items: result.items, next: result.next, previous: result.previous),
        );
        // The window now starts earlier (possibly before the very first page for weekly lists).
        prepended = result.items.length;
        _trimmedFront -= prepended;
      }
      // [lastVisible] counted from the old start of the window.
      _trim(fromFront: false, keep: lastVisible == null ? null : _count() - 1 - (lastVisible + prepended));
      _rebuild();
    } catch (e) {
      if (generation != _generation) return;
      _error = e;
    }
    _loadingMore = false;
    _notify();
  }

  /// Retries after an error.
  Future<void> retry() {
    if (_pages.isEmpty) return refresh();
    return loadMore();
  }

  /// Clears everything and returns to the initial state without loading.
  void reset() {
    _generation++;
    _epoch++;
    _pages.clear();
    _items = <T>[];
    _trimmedFront = 0;
    _status = PaginationStatus.idle;
    _loadingMore = false;
    _error = null;
    _lastTrim = const TrimEvent();
    _notify();
  }

  /// Fetches [key]. A page without items that still has a neighbour in the
  /// reading direction (a quiet stretch of history) is skipped, so the list
  /// never stalls on a gap.
  Future<(PageKey, PageResult<T>)> _fetch(PageKey key, {bool forward = true}) async {
    var current = key;
    var result = await _loader(current, config.pageSize);
    var guard = 0;
    while (result.items.isEmpty && (forward ? result.next : result.previous) != null && guard++ < 200) {
      current = (forward ? result.next : result.previous)!;
      result = await _loader(current, config.pageSize);
    }
    return (current, result);
  }

  int _count() => _pages.fold<int>(0, (sum, p) => sum + p.length);

  /// Drops the oldest items until the window fits `maxRendered`: from the front
  /// after a page was appended, from the back after one was put in front. At
  /// most [keep] items are dropped when given, so the reader's own rows stay,
  /// and the last item of the window is never dropped.
  void _trim({required bool fromFront, required int? keep}) {
    var excess = _count() - config.maxRendered;
    if (keep != null) excess = math.min(excess, keep);
    var removed = 0;
    while (excess > 0 && _count() > 1) {
      final page = fromFront ? _pages.first : _pages.last;
      final take = math.min(excess, page.length);
      if (take == page.length && _pages.length > 1) {
        // The whole page goes; its neighbour remembers where to reload it from.
        if (fromFront) {
          _pages.removeAt(0);
          _pages.first.previous = page.key;
        } else {
          _pages.removeLast();
          _pages.last.next = page.key;
        }
      } else if (fromFront) {
        page.skipFront += math.min(take, page.length - 1);
      } else {
        page.skipBack += math.min(take, page.length - 1);
      }
      removed += take;
      excess -= take;
    }
    if (fromFront) _trimmedFront += removed;
    _lastTrim = fromFront ? TrimEvent(front: removed) : TrimEvent(back: removed);
  }

  void _rebuild() {
    _items = List<T>.unmodifiable([for (final p in _pages) ...p.shown]);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
