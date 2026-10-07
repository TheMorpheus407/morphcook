import 'package:flutter/material.dart' hide Typography;

import '../core/pagination.dart';
import '../core/theme/palette.dart';
import '../core/theme/typography.dart';
import 'paper.dart';

/// A paginated list. Uses `ListView.builder` with zero cache extent, so at
/// most [PaginationController.maxRendered] item widgets are alive at once and
/// off-screen items are disposed. Loads more when the user scrolls within the
/// prefetch threshold of the end.
class PaginatedListView<T> extends StatefulWidget {
  final PaginationController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Widget? header;
  final Widget? footer;
  final Widget? emptyState;
  final EdgeInsets padding;
  final ScrollPhysics? physics;

  const PaginatedListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.header,
    this.footer,
    this.emptyState,
    this.padding = EdgeInsets.zero,
    this.physics,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStateChanged);
    if (widget.controller.items.isEmpty && !widget.controller.isLoading) {
      widget.controller.loadMore();
    }
  }

  @override
  void didUpdateWidget(covariant PaginatedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onStateChanged);
      widget.controller.addListener(_onStateChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() => setState(() {});

  void _onScroll(ScrollMetrics metrics) {
    final controller = widget.controller;
    if (controller.shouldLoadMore(controller.items.length - 1)) {
      controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final itemCount = controller.items.length + (controller.isLoading ? 1 : 0);

    if (controller.items.isEmpty && controller.isLoading) {
      return const _SkeletonList();
    }
    if (controller.items.isEmpty && controller.error != null) {
      return _ErrorState(message: controller.error!, onRetry: controller.refresh);
    }
    if (controller.items.isEmpty) {
      return widget.emptyState ?? const SizedBox.shrink();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _onScroll(notification.metrics);
        return false;
      },
      child: ListView.builder(
        physics: widget.physics,
        padding: widget.padding,
        cacheExtent: 0, // off-screen items are disposed
        itemCount: itemCount + (widget.header != null ? 1 : 0) + (widget.footer != null ? 1 : 0),
        itemBuilder: (context, index) {
          var i = index;
          if (widget.header != null) {
            if (i == 0) return widget.header!;
            i -= 1;
          }
          if (i < controller.items.length) {
            return widget.itemBuilder(context, controller.items[i], i);
          }
          i -= controller.items.length;
          if (i == 0 && controller.isLoading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return widget.footer ?? const SizedBox.shrink();
        },
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) => ListView.builder(
        cacheExtent: 0,
        itemCount: 6,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: Palette.paperDeep,
              border: Border.all(color: Palette.line),
            ),
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HandNote(message, size: 20),
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: Text('retry', style: Typography.mono(11, color: Palette.teal))),
            ],
          ),
        ),
      );
}
