import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../domain/collections.dart';
import '../../l10n/strings.dart';
import '../../services/pagination.dart';
import '../../state/app_state.dart';
import '../history/history_screen.dart';
import '../widgets/recipe_card.dart';

/// Offset pagination, 30 a page, prefetching ten items out, never more than
/// fifty rows alive at once.
class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key, this.onPick, this.title});

  final ValueChanged<String>? onPick;
  final String? title;

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  late final PaginationController<SavedRecipe> _pagination =
      PaginationController(
        config: PaginationConfig.cookbook,
        fetcher: listFetcher(() => _sorted),
      );

  bool _byName = false;
  int _revision = -1;

  List<SavedRecipe> get _sorted => context.read<AppState>().savedSorted(
    byName: _byName,
    lang: context.read<AppState>().lang,
  );

  @override
  void dispose() {
    _pagination.dispose();
    super.dispose();
  }

  /// The saved list is owned by AppState, so the controller has to be told when
  /// it changed underneath it.
  void _syncWith(AppState state) {
    final revision = Object.hash(state.saved.length, _byName, state.lang);
    if (revision == _revision) return;
    _revision = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) => _pagination.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;
    _syncWith(state);

    if (state.saved.isEmpty) {
      return Scaffold(
        appBar: widget.title == null
            ? null
            : AppBar(title: Text(widget.title!)),
        body: SafeArea(
          child: EmptyNote(
            headline: s.cookbookEmptyTitle,
            body: s.cookbookEmptyBody,
            hand: s.cookbookEmptyHand,
            icon: Icons.bookmark_border,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: widget.title == null
          ? null
          : AppBar(title: Text(widget.title!.toLowerCase())),
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: _pagination,
          builder: (context, _) {
            final items = _pagination.items;
            if (items.isEmpty && _pagination.isLoading) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                children: [
                  _header(s, state),
                  const SkeletonCard(),
                  const SkeletonCard(),
                  const SkeletonCard(),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              itemCount: items.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) return _header(s, state);
                if (index == items.length + 1) {
                  return PaginationFooter(
                    loading: _pagination.isLoading,
                    hasMore: _pagination.hasMore,
                    endLabel: s.thatIsEverything,
                    droppedFromHead: _pagination.droppedFromHead,
                    droppedLabel: s.itemsCount(_pagination.droppedFromHead),
                    error: _pagination.error,
                    onRetry: _pagination.loadMore,
                    retryLabel: s.retry,
                  );
                }
                final i = index - 1;
                if (_pagination.shouldLoadMore(i)) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _pagination.loadMore(),
                  );
                }
                final saved = items[i];
                final recipe = state.repository.recipe(saved.recipeId);
                if (recipe == null) {
                  return _MissingRow(recipeId: saved.recipeId, s: s);
                }
                return Column(
                  children: [
                    RecipeRow(
                      recipe: recipe,
                      onTap: widget.onPick == null
                          ? null
                          : () => widget.onPick!(recipe.id),
                      trailing: widget.onPick != null
                          ? null
                          : IconButton(
                              icon: Icon(
                                Icons.bookmark,
                                color: colors.accent,
                                size: 18,
                              ),
                              tooltip: s.remove,
                              onPressed: () async {
                                await state.toggleSaved(recipe.id);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(s.cookbookRemoved)),
                                );
                              },
                            ),
                    ),
                    DashedRule(color: colors.edge),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _header(S s, AppState state) {
    if (widget.title != null) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  s.cookbookTitle.toLowerCase(),
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ),
              IconButton(
                tooltip: s.historyTitle,
                icon: const Icon(Icons.history),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HistoryScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.cookbookSubtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              InkChip(
                label: s.cookbookSortRecent,
                dense: true,
                selected: !_byName,
                onTap: () => setState(() => _byName = false),
              ),
              const SizedBox(width: 8),
              InkChip(
                label: s.cookbookSortName,
                dense: true,
                selected: _byName,
                onTap: () => setState(() => _byName = true),
              ),
              const Spacer(),
              Text(
                s.recipesCount(state.saved.length),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A saved id whose partition is not resident yet. Loading it is a tap away
/// rather than a spinner that blocks the whole list.
class _MissingRow extends StatelessWidget {
  const _MissingRow({required this.recipeId, required this.s});

  final String recipeId;
  final S s;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(recipeId, style: Theme.of(context).textTheme.bodySmall),
      trailing: TextButton(
        onPressed: () => state.repository.ensureRecipeLoaded(recipeId),
        child: Text(s.loading),
      ),
    );
  }
}
