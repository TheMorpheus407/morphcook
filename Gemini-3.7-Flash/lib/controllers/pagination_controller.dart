import 'package:flutter/foundation.dart';

enum PaginationType {
  cursor,
  offset,
  time,
  weekly,
}

typedef PageFetchCallback<T> = Future<PaginationResult<T>> Function(PaginationRequest request);

class PaginationRequest {
  final int offset;
  final int limit;
  final String? cursor;
  final DateTime? timeAnchor;

  const PaginationRequest({
    this.offset = 0,
    this.limit = 20,
    this.cursor,
    this.timeAnchor,
  });
}

class PaginationResult<T> {
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  const PaginationResult({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
  });
}

class PaginationController<T> extends ChangeNotifier {
  final PaginationType type;
  final int pageSize;
  final int prefetchThreshold;
  final int maxRendered;
  final PageFetchCallback<T> fetchPage;

  List<T> _items = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _nextCursor;
  int _currentOffset = 0;
  String? _error;

  PaginationController({
    required this.type,
    this.pageSize = 20,
    this.prefetchThreshold = 10,
    this.maxRendered = 50,
    required this.fetchPage,
  });

  List<T> get items => _items.length > maxRendered ? _items.sublist(0, maxRendered) : _items;
  List<T> get rawItems => _items;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  int get totalLoaded => _items.length;

  Future<void> loadInitial() async {
    reset();
    await loadMore();
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final request = PaginationRequest(
        offset: _currentOffset,
        limit: pageSize,
        cursor: _nextCursor,
      );

      final result = await fetchPage(request);
      _items.addAll(result.items);
      _currentOffset += result.items.length;
      _nextCursor = result.nextCursor;
      _hasMore = result.hasMore && (_items.length < maxRendered || type == PaginationType.weekly);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool shouldLoadMore(int currentIndex) {
    if (_isLoading || !_hasMore) return false;
    return currentIndex >= _items.length - prefetchThreshold;
  }

  Future<void> refresh() async {
    reset();
    await loadMore();
  }

  void reset() {
    _items = [];
    _isLoading = false;
    _hasMore = true;
    _nextCursor = null;
    _currentOffset = 0;
    _error = null;
    notifyListeners();
  }
}
