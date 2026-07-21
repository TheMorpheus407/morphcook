import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Pagination strategies used by MorphCook's list views.
enum PaginationType { cursor, offset, time, weekly }

/// Immutable performance and loading policy for one paginated view.
class PaginationPolicy {
  const PaginationPolicy({
    required this.type,
    required this.pageSize,
    required this.prefetchThreshold,
    required this.maxRendered,
    this.thresholdUsesUnits = false,
  }) : assert(pageSize > 0),
       assert(prefetchThreshold >= 0),
       assert(maxRendered > 0);

  const PaginationPolicy.search()
    : this(
        type: PaginationType.cursor,
        pageSize: 20,
        prefetchThreshold: 10,
        maxRendered: 50,
      );

  const PaginationPolicy.cookbook()
    : this(
        type: PaginationType.offset,
        pageSize: 30,
        prefetchThreshold: 10,
        maxRendered: 50,
      );

  const PaginationPolicy.history()
    : this(
        type: PaginationType.time,
        pageSize: 7,
        prefetchThreshold: 1,
        maxRendered: 50,
        thresholdUsesUnits: true,
      );

  const PaginationPolicy.mealPlan()
    : this(
        type: PaginationType.weekly,
        pageSize: 1,
        prefetchThreshold: 0,
        maxRendered: 4,
        thresholdUsesUnits: true,
      );

  final PaginationType type;

  /// Items for item-based policies, weeks for history/meal-plan policies.
  final int pageSize;
  final int prefetchThreshold;

  /// Items for search/cookbook/history and weeks for meal plan.
  final int maxRendered;
  final bool thresholdUsesUnits;
}

class PaginationRequest {
  const PaginationRequest({
    required this.type,
    required this.pageIndex,
    required this.limit,
    required this.offset,
    this.cursor,
    this.anchor,
  });

  final PaginationType type;
  final int pageIndex;
  final int limit;
  final int offset;
  final String? cursor;

  /// A repository-defined ISO date/week token for time and weekly pagination.
  final String? anchor;
}

class PaginationPage<T> {
  PaginationPage({
    required Iterable<T> items,
    required this.hasMore,
    this.nextCursor,
    this.nextAnchor,
    this.unitsLoaded = 1,
  }) : items = List<T>.unmodifiable(items),
       assert(unitsLoaded >= 0);

  final List<T> items;
  final bool hasMore;
  final String? nextCursor;
  final String? nextAnchor;

  /// Weeks/periods represented by this page. Item policies normally use 1.
  final int unitsLoaded;
}

typedef PaginationLoader<T> =
    Future<PaginationPage<T>> Function(PaginationRequest request);

/// A reusable, race-safe controller for all list pagination policies.
///
/// The controller deliberately retains no more than [policy.maxRendered]
/// entries (or weeks for a weekly policy). Repositories own the full data set;
/// this object only owns the current render window.
class PaginationController<T> extends ChangeNotifier {
  PaginationController({
    required this.policy,
    required PaginationLoader<T> loader,
    String? initialCursor,
    String? initialAnchor,
  }) : _loader = loader,
       _initialCursor = initialCursor,
       _initialAnchor = initialAnchor,
       _cursor = initialCursor,
       _anchor = initialAnchor;

  final PaginationPolicy policy;
  final PaginationLoader<T> _loader;
  final String? _initialCursor;
  final String? _initialAnchor;
  final List<T> _items = <T>[];

  bool _isLoading = false;
  bool _hasMore = true;
  Object? _error;
  StackTrace? _errorStackTrace;
  int _pageIndex = 0;
  int _nextOffset = 0;
  int _loadedUnits = 0;
  int _evictedCount = 0;
  int _generation = 0;
  bool _disposed = false;
  String? _cursor;
  String? _anchor;

  UnmodifiableListView<T> get items => UnmodifiableListView<T>(_items);
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  Object? get error => _error;
  StackTrace? get errorStackTrace => _errorStackTrace;
  bool get isEmpty => _items.isEmpty && !_isLoading;
  bool get isInitialLoading => _isLoading && _items.isEmpty;
  int get loadedUnits => _loadedUnits;
  int get evictedCount => _evictedCount;
  int get fetchedItemCount => _nextOffset;

  /// True when the current position is inside this view's prefetch window.
  ///
  /// History and meal-plan callers should preferably pass [remainingUnits]
  /// (weeks after the visible week). They may instead pass an absolute
  /// [visibleUnitIndex] across all fetched units. Item-based callers only pass
  /// [index].
  bool shouldLoadMore(int index, {int? visibleUnitIndex, int? remainingUnits}) {
    if (!_hasMore || _isLoading) return false;
    if (_items.isEmpty) return true;

    if (policy.thresholdUsesUnits && remainingUnits != null) {
      return remainingUnits <= policy.prefetchThreshold;
    }

    if (policy.thresholdUsesUnits && visibleUnitIndex != null) {
      final trigger = (_loadedUnits - policy.prefetchThreshold - 1).clamp(
        0,
        _loadedUnits,
      );
      return visibleUnitIndex >= trigger;
    }

    final trigger = (_items.length - policy.prefetchThreshold - 1).clamp(
      0,
      _items.length,
    );
    return index >= trigger;
  }

  Future<void> loadMore() =>
      _disposed ? Future<void>.value() : _loadMore(_generation);

  Future<void> _loadMore(int generation) async {
    if (_isLoading || !_hasMore) return;
    _isLoading = true;
    _error = null;
    _errorStackTrace = null;
    if (!_disposed) notifyListeners();

    final request = PaginationRequest(
      type: policy.type,
      pageIndex: _pageIndex,
      limit: policy.pageSize,
      offset: _nextOffset,
      cursor: _cursor,
      anchor: _anchor,
    );

    try {
      final page = await _loader(request);
      if (_disposed || generation != _generation) return;

      _items.addAll(page.items);
      _nextOffset += page.items.length;
      _loadedUnits += page.unitsLoaded;
      _pageIndex++;
      _cursor = page.nextCursor;
      _anchor = page.nextAnchor;
      _hasMore = page.hasMore;
      _trimRenderWindow();
    } catch (exception, stackTrace) {
      if (_disposed || generation != _generation) return;
      _error = exception;
      _errorStackTrace = stackTrace;
    } finally {
      if (!_disposed && generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _trimRenderWindow() {
    // Weekly pages are represented by one T per week. For history, T is an
    // individual rendered row and the general 50-item guardrail applies.
    final limit = policy.maxRendered;
    if (_items.length <= limit) return;
    final removeCount = _items.length - limit;
    _items.removeRange(0, removeCount);
    _evictedCount += removeCount;
  }

  /// Discards the render window and reloads page one.
  Future<void> refresh() async {
    reset();
    await loadMore();
  }

  /// Clears all items and invalidates any page currently in flight.
  void reset() {
    if (_disposed) return;
    _generation++;
    _items.clear();
    _isLoading = false;
    _hasMore = true;
    _error = null;
    _errorStackTrace = null;
    _pageIndex = 0;
    _nextOffset = 0;
    _loadedUnits = 0;
    _evictedCount = 0;
    _cursor = _initialCursor;
    _anchor = _initialAnchor;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
