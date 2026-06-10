import 'package:flutter/material.dart' hide Page;

import '../../core/context_ext.dart';
import '../../logic/pagination.dart';
import '../../theme/app_theme.dart';
import '../../widgets/decor.dart';
import '../../widgets/recipe_card.dart';

/// The user's saved recipes — newest first, offset-paginated. Removals update
/// live via the cookbook service. Same quiet masthead language as home.
class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  final ScrollController _scrollController = ScrollController();

  PaginationController<String>? _controller;

  /// Signature of the saved set the controller was last built from, so we only
  /// rebuild when the actual contents change (not on unrelated notifications).
  String _savedSignature = '';

  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onScroll() {
    final c = _controller;
    if (c == null) return;
    final lastVisible = c.items.length - 1;
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 600 &&
        c.shouldLoadMore(lastVisible)) {
      c.loadMore();
    }
  }

  /// Build/rebuild the paginated controller from the current saved id list.
  void _rebuildController(List<String> savedIds) {
    _controller?.dispose();

    final controller = PaginationController<String>(
      type: PaginationType.offset,
      pageSize: _pageSize,
      prefetchThreshold: 10,
      maxRendered: 50,
      fetcher: (cursor) async {
        final offset = (cursor as int?) ?? 0;
        final end = (offset + _pageSize).clamp(0, savedIds.length);
        final slice = savedIds.sublist(offset, end);
        return Page<String>(
          items: slice,
          nextCursor: end,
          hasMore: end < savedIds.length,
        );
      },
    );

    _controller = controller;
    controller.addListener(() {
      if (mounted) setState(() {});
    });
    controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.scope;
    return ListenableBuilder(
      listenable: scope.services.cookbook,
      builder: (context, _) {
        final savedIds = scope.services.cookbook.savedIds();
        final signature = savedIds.join(',');

        // Rebuild the controller only when the saved set actually changed.
        if (signature != _savedSignature || _controller == null) {
          _savedSignature = signature;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _rebuildController(savedIds);
          });
        }

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: _CookbookMasthead()),
            if (savedIds.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: HandNote(context.tr('cookbook.empty'), size: 24),
                  ),
                ),
              )
            else
              _buildList(context),
          ],
        );
      },
    );
  }

  Widget _buildList(BuildContext context) {
    final c = _controller;
    final corpus = context.scope.corpus;

    if (c == null || (c.isLoading && !c.isInitialLoaded)) {
      return const SliverToBoxAdapter(child: _ListSkeleton());
    }

    final items = c.items;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i >= items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: _CardSkeleton(),
              );
            }
            final id = items[i];
            final recipe = corpus.recipe(id);
            final dish = corpus.dishOfRecipe(id);
            if (recipe == null || dish == null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 18),
              child: RecipeCard(
                recipe: recipe,
                dish: dish,
                rotation: i.isEven ? -0.01 : 0.012,
                trailing: IconButton(
                  icon: const Icon(Icons.bookmark, size: 20),
                  color: AppColors.terracotta,
                  visualDensity: VisualDensity.compact,
                  tooltip: context.tr('common.remove'),
                  onPressed: () =>
                      context.scope.services.cookbook.remove(id),
                ),
              ),
            );
          },
          childCount: items.length + (c.hasMore ? 1 : 0),
        ),
      ),
    );
  }
}

class _CookbookMasthead extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            context.tr('cookbook.title').toLowerCase(),
            style: const TextStyle(
              fontFamily: Fonts.display,
              fontStyle: FontStyle.italic,
              fontSize: 32,
              color: AppColors.ink,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          DashedRule(),
        ],
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          for (var i = 0; i < 4; i++) ...[
            const _CardSkeleton(),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    Color grey(double a) => AppColors.inkFaint.withValues(alpha: a);
    return PolaroidCard(
      rotation: -0.008,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 150, color: grey(0.35)),
          const SizedBox(height: 10),
          Container(height: 16, width: 180, color: grey(0.4)),
          const SizedBox(height: 8),
          Container(height: 10, width: 110, color: grey(0.3)),
        ],
      ),
    );
  }
}
