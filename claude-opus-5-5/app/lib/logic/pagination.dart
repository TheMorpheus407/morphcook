import 'dart:async';

import 'package:flutter/foundation.dart';

/// Pagination flavours from the spec; each view picks the one that suits
/// its data.
enum PaginationType { cursor, offset, time, weekly }

class PaginationConfig {
  const PaginationConfig({
    required this.type,
    required this.pageSize,
    required this.prefetchThreshold,
    required this.maxRendered,
  });

  final PaginationType type;

  /// Items per page (cursor/offset), weeks per page (time/weekly).
  final int pageSize;

  /// Load more when the user is this many items from the end.
  final int prefetchThreshold;

  /// Upper bound of items held in the rendered window.
  final int maxRendered;

  static const search = PaginationConfig(
    type: PaginationType.cursor,
    pageSize: 20,
    prefetchThreshold: 10,
    maxRendered: 50,
  );
  static const cookbook = PaginationConfig(
    type: PaginationType.offset,
    pageSize: 30,
    prefetchThreshold: 10,
    maxRendered: 50,
  );

  /// 7 weeks per page, prefetch 1 week before the end.
  static const history = PaginationConfig(
    type: PaginationType.time,
    pageSize: 7,
    prefetchThreshold: 1,
    maxRendered: 50,
  );

  /// 1 week per page, no prefetch, at most 4 weeks rendered.
  static const mealPlan = PaginationConfig(
    type: PaginationType.weekly,
    pageSize: 1,
    prefetchThreshold: 0,
    maxRendered: 4,
  );
}

/// What a fetcher returns. [nextToken] is `null` at the end of the data.
class PageResult<T> {
  const PageResult(this.items, {this.nextToken});
  final List<T> items;
  final String? nextToken;
}

typedef PageFetcher<T> = Future<PageResult<T>> Function(String? token, int pageSize);

class _Page<T> {
  _Page(this.token, this.items, this.nextToken);
  final String? token;
  final List<T> items;
  final String? nextToken;
}

/// Generic pagination state as a [ChangeNotifier].
///
/// Pages are kept in a sliding window: when more than
/// [PaginationConfig.maxRendered] items are held, the oldest page is dropped
/// (its token remembered) and [hasPrevious] becomes true; [loadPrevious]
/// brings it back. Combined with `ListView.builder` this bounds both memory
/// and rendering as user data grows.
class PaginationController<T> extends ChangeNotifier {
  PaginationController({required this.config, required this.fetcher});

  final PaginationConfig config;
  PageFetcher<T> fetcher;

  final List<_Page<T>> _pages = [];
  final List<String?> _droppedTokens = [];
  bool _loading = false;
  bool _initialised = false;
  Object? _error;
  int _generation = 0;

  List<T> get items => [for (final p in _pages) ...p.items];
  int get length => _pages.fold(0, (n, p) => n + p.items.length);
  bool get isLoading => _loading;
  bool get isInitialised => _initialised;
  Object? get error => _error;
  bool get hasMore => _pages.isEmpty ? !_initialised : _pages.last.nextToken != null;
  bool get hasPrevious => _droppedTokens.isNotEmpty;
  bool get isEmpty => _initialised && length == 0 && !_loading && _error == null;

  /// Number of units (items, or weeks for weekly/time) held.
  int get _windowSize => config.type == PaginationType.weekly ? _pages.length : length;

  /// True when [index] is within the prefetch threshold of the end.
  bool shouldLoadMore(int index) => hasMore && !_loading && index >= length - 1 - config.prefetchThreshold;

  Future<void> loadMore() async {
    if (_loading || !hasMore) return;
    final token = _pages.isEmpty ? null : _pages.last.nextToken;
    await _fetch(token, append: true);
  }

  Future<void> loadPrevious() async {
    if (_loading || _droppedTokens.isEmpty) return;
    final token = _droppedTokens.removeLast();
    await _fetch(token, append: false);
  }

  /// Resets and reloads from page 1.
  Future<void> refresh() async {
    _generation++;
    _pages.clear();
    _droppedTokens.clear();
    _error = null;
    _initialised = false;
    _loading = false;
    notifyListeners();
    await loadMore();
  }

  /// Clears all items and returns to the initial state.
  void reset() {
    _generation++;
    _pages.clear();
    _droppedTokens.clear();
    _error = null;
    _loading = false;
    _initialised = false;
    notifyListeners();
  }

  Future<void> _fetch(String? token, {required bool append}) async {
    final gen = _generation;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await fetcher(token, config.pageSize);
      if (gen != _generation) return;
      final page = _Page<T>(token, result.items, result.nextToken);
      if (append) {
        _pages.add(page);
        while (_pages.length > 1 && _windowSize > config.maxRendered) {
          _droppedTokens.add(_pages.removeAt(0).token);
        }
      } else {
        _pages.insert(0, page);
        while (_pages.length > 1 && _windowSize > config.maxRendered) {
          _pages.removeLast();
        }
      }
      _initialised = true;
    } catch (e) {
      if (gen != _generation) return;
      _error = e;
      _initialised = true;
    } finally {
      if (gen == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }
}
