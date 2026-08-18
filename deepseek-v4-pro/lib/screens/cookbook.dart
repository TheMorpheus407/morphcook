import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../core/paper.dart';
import '../core/stripes.dart';
import '../logic/pagination.dart';
import '../models/recipe.dart';
import '../state/app_state.dart';
import '../widgets/recipe_card.dart';
import 'home.dart';

/// Cookbook (saved recipes) — offset-based pagination, 30/page,
/// prefetch 10, max rendered 50. Sorted by saved date, newest first.
class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  late final PaginationController<Recipe> _pagination;

  @override
  void initState() {
    super.initState();
    _pagination = PaginationController<Recipe>(
      pageSize: 30,
      prefetchThreshold: 10,
      maxRendered: 50,
      type: PaginationType.offset,
      fetcher: (offset, _) async {
        final store = context.read<AppStore>();
        final corpus = context.read<Corpus>();
        final matcher = context.read<Matcher>();
        await corpus.loadPartition('extended');
        final saved = store.savedIds.toList()
          ..sort((a, b) {
            final at = store.savedAt;
            return (at[b] ?? DateTime(1970)).compareTo(at[a] ?? DateTime(1970));
          });
        final visible = matcher
            .filter(
              [for (final id in saved) if (corpus.recipe(id) != null) corpus.recipe(id)!],
              store.profile,
            )
            .toList();
        return PageSlice.offset(visible, offset, 30);
      },
    )..loadMore();
  }

  @override
  void dispose() {
    _pagination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PaperBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Masthead(
                subtitle: context.t('tabCookbook'),
              ),
            ),
            HistorySection(),
            Expanded(
              child: ListenableBuilder(
                listenable: _pagination,
                builder: (context, _) {
                  context.watch<AppStore>(); // react to save/unsave changes
                  if (_pagination.isInitialLoading) {
                    return _gridSkeletons();
                  }
                  final items = _pagination.renderedItems;
                  if (items.isEmpty) {
                    return _empty(context);
                  }
                  return NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.axis == Axis.vertical &&
                          n.metrics.pixels >=
                              n.metrics.maxScrollExtent - 200) {
                        _pagination.loadMore();
                      }
                      return false;
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        mainAxisExtent: 330,
                      ),
                      itemCount: items.length +
                          (_pagination.hasMore ? 2 : 0),
                      itemBuilder: (context, i) {
                        if (i >= items.length) {
                          return const RecipeCardSkeleton();
                        }
                        final recipe = items[i];
                        return RecipeCard(
                          recipe: recipe,
                          rotation: _rot(recipe.id),
                          onTap: () => openDish(context, recipe.dishId),
                          trailing: IconButton(
                            onPressed: () =>
                                context.read<AppStore>().unsaveRecipe(recipe.id),
                            icon: const Icon(Icons.favorite,
                                size: 16, color: MC.coral),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 40, color: MC.inkFaint),
            const SizedBox(height: 12),
            Text(
              context.t('cbEmpty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridSkeletons() => GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          mainAxisExtent: 330,
        ),
        itemCount: 6,
        itemBuilder: (_, i) => RecipeCardSkeleton(rotation: _rot('$i')),
      );

  double _rot(String id) {
    const rot = [0.9, -0.7, 1.1, -1.0, 0.5];
    return rot[id.codeUnits.fold<int>(0, (a, b) => a + b) % rot.length];
  }
}

/// Cooking history — time-based pagination, 7 weeks per page.
class HistorySection extends StatelessWidget {
  const HistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final corpus = context.read<Corpus>();
    final history = store.history;
    if (history.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final recent = history
        .where((h) => now.difference(h.cookedAt).inDays <= 7 * 7)
        .take(50)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: context.t('cbRecent'),
            annotation: context.t('tabCookbook'),
          ),
          for (final h in recent.take(6))
            if (corpus.recipe(h.recipeId) != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: StripeThumb(
                  colors: corpus.recipe(h.recipeId)!.stripeColors,
                  size: 40,
                ),
                title: Text(
                  context.recipeName(corpus.recipe(h.recipeId)!),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    color: MC.ink,
                  ),
                ),
                subtitle: Text(
                  _dateLabel(context, h.cookedAt),
                  style: const TextStyle(fontSize: 11, color: MC.inkFaint),
                ),
                onTap: () => openDish(context, corpus.recipe(h.recipeId)!.dishId),
              ),
        ],
      ),
    );
  }

  String _dateLabel(BuildContext context, DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inDays == 0) return context.t('meal.lunch');
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${t.day}.${t.month}.${t.year}';
  }
}
