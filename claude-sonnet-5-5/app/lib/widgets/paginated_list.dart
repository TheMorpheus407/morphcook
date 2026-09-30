import 'package:flutter/material.dart';

import '../core/pagination/pagination_controller.dart';
import 'skeleton.dart';

/// A paginated list on top of [PaginationController].
///
/// * `ListView.builder` with an unknown item count: only the rows on screen
///   exist, and a footer row stands in for "more".
/// * Prefetches when the reader gets within the controller's threshold of the
///   end (or the start, after pages were trimmed).
/// * Skeleton rows while the first page loads, an empty state, and an error
///   state with retry.
/// * When the controller drops items from the far end to respect `maxRendered`
///   (never the ones on screen), the scroll position is corrected so the rows
///   on screen do not jump.
class PaginatedList<T> extends StatefulWidget {
  const PaginatedList({
    super.key,
    required this.controller,
    required this.itemBuilder,
    required this.itemExtent,
    required this.emptyBuilder,
    this.skeletonBuilder,
    this.errorBuilder,
    this.footerBuilder,
    this.footerExtent = 72,
    this.padding = EdgeInsets.zero,
    this.scrollController,
  });

  final PaginationController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Height of the row for `items[index]`. Rows have known extents so trimming
  /// can keep the reader's place.
  final double Function(int index, List<T> items) itemExtent;
  final WidgetBuilder emptyBuilder;
  final WidgetBuilder? skeletonBuilder;
  final Widget Function(BuildContext context, VoidCallback retry)? errorBuilder;
  final WidgetBuilder? footerBuilder;
  final double footerExtent;
  final EdgeInsets padding;
  final ScrollController? scrollController;

  @override
  State<PaginatedList<T>> createState() => _PaginatedListState<T>();
}

class _PaginatedListState<T> extends State<PaginatedList<T>> {
  late final ScrollController _scroll = widget.scrollController ?? ScrollController();
  List<T> _lastItems = <T>[];
  int _lastTrimmedFront = 0;
  int _lastEpoch = 0;
  bool _prefetchScheduled = false;

  @override
  void initState() {
    super.initState();
    _snapshot();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(PaginatedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _snapshot();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    if (widget.scrollController == null) _scroll.dispose();
    super.dispose();
  }

  void _snapshot() {
    _lastItems = widget.controller.items;
    _lastTrimmedFront = widget.controller.trimmedFront;
    _lastEpoch = widget.controller.epoch;
  }

  double _sumExtent(int count, List<T> items) {
    var total = 0.0;
    for (var i = 0; i < count && i < items.length; i++) {
      total += widget.itemExtent(i, items);
    }
    return total;
  }

  void _onChanged() {
    if (!mounted) return;
    final controller = widget.controller;
    if (controller.epoch != _lastEpoch) {
      // A fresh start: back to the top.
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } else if (_scroll.hasClients) {
      final trimmed = controller.trimmedFront;
      final before = _lastItems;
      final after = controller.items;
      if (trimmed > _lastTrimmedFront && after.isNotEmpty) {
        // Rows fell off the top: pull the offset up by their height. The row that
        // is now first may have changed height (a history row starts a week heading).
        final removed = trimmed - _lastTrimmedFront;
        final headChange = removed < before.length
            ? widget.itemExtent(0, after) - widget.itemExtent(removed, before)
            : 0.0;
        // ignore: invalid_use_of_protected_member
        _scroll.position.correctBy(headChange - _sumExtent(removed, before));
      } else if (trimmed < _lastTrimmedFront && after.isNotEmpty) {
        // Rows were put back on top: push the offset down by their height.
        final added = _lastTrimmedFront - trimmed;
        final headChange = added < after.length && before.isNotEmpty
            ? widget.itemExtent(added, after) - widget.itemExtent(0, before)
            : 0.0;
        // ignore: invalid_use_of_protected_member
        _scroll.position.correctBy(_sumExtent(added, after) + headChange);
      }
    }
    _snapshot();
    setState(() {});
  }

  /// The first and last item the reader can see right now (a few rows more are
  /// built as a cache, but only these must never be trimmed away).
  ({int first, int last}) _visibleRange(List<T> items) {
    if (items.isEmpty) return (first: 0, last: 0);
    if (!_scroll.hasClients) return (first: 0, last: items.length - 1);
    final top = _scroll.offset - widget.padding.top;
    final bottom = top + _scroll.position.viewportDimension;
    var y = 0.0;
    var first = -1;
    var last = items.length - 1;
    for (var i = 0; i < items.length; i++) {
      final height = widget.itemExtent(i, items);
      if (first < 0 && y + height > top) first = i;
      if (y >= bottom) {
        last = i - 1;
        break;
      }
      y += height;
    }
    return (first: first < 0 ? items.length - 1 : first, last: last.clamp(0, items.length - 1));
  }

  void _prefetch(int index) {
    final controller = widget.controller;
    final more = controller.shouldLoadMore(index);
    final previous = controller.shouldLoadPrevious(index);
    if ((!more && !previous) || _prefetchScheduled) return;
    _prefetchScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchScheduled = false;
      if (!mounted) return;
      final visible = _visibleRange(controller.items);
      if (more) controller.loadMore(firstVisible: visible.first);
      if (previous) controller.loadPrevious(lastVisible: visible.last);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller.isInitialLoading || controller.status == PaginationStatus.idle) {
      return widget.skeletonBuilder?.call(context) ?? const SingleChildScrollView(child: SkeletonList());
    }
    if (controller.hasError && controller.items.isEmpty) {
      return widget.errorBuilder?.call(context, controller.retry) ?? const SizedBox.shrink();
    }
    if (controller.isEmpty) return widget.emptyBuilder(context);

    final items = controller.items;
    final showFooter = controller.hasMore || controller.isLoadingMore || controller.hasError;
    return ListView.builder(
      controller: _scroll,
      padding: widget.padding,
      itemCount: items.length + (showFooter ? 1 : 0),
      itemExtentBuilder: (index, dimensions) =>
          index < items.length ? widget.itemExtent(index, items) : widget.footerExtent,
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return widget.footerBuilder?.call(context) ?? const SkeletonRow(height: 72);
        }
        _prefetch(index);
        return widget.itemBuilder(context, items[index], index);
      },
    );
  }
}
