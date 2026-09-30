import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/nav_requests.dart';
import '../../app/routes.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/pagination/pagination_controller.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/corpus.dart';
import '../../data/models/dish.dart';
import '../../data/models/history_entry.dart';
import '../../data/models/recipe.dart';
import '../../state/catalog.dart';
import '../../state/controllers/history_controller.dart';
import '../../widgets/paginated_list.dart';
import '../../widgets/paper_controls.dart';
import '../../widgets/recipe_row.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/state_views.dart';

class HistoryItem {
  const HistoryItem(this.entry, this.recipe, this.dish);
  final HistoryEntry entry;
  final Recipe? recipe;
  final Dish? dish;
}

/// Cooking history: seven weeks per page, newest first, grouped under week
/// headings. The next page loads when the reader is within one week of the end.
class HistoryList extends StatefulWidget {
  const HistoryList({super.key});

  @override
  State<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<HistoryList> {
  /// Height of the week heading at the default text size.
  static const double _baseHeaderExtent = 50;

  late final HistoryController _history = context.read<HistoryController>();
  late final Corpus _corpus = context.read<Corpus>();
  late final Catalog _catalog = context.read<Catalog>();

  late final PaginationController<HistoryItem> _pages = PaginationController<HistoryItem>.time(
    groupOf: (item) => weekOrdinal(item.entry.cookedAt),
    loader: (pageIndex, weeks) async {
      final page = _history.pageOfWeeks(pageIndex, weeks, _catalog.clock());
      final items = <HistoryItem>[];
      for (final entry in page.items) {
        final recipe = await _corpus.loadRecipe(entry.recipeId);
        items.add(HistoryItem(entry, recipe, _corpus.dishOfRecipe(entry.recipeId)));
      }
      return TimePage<HistoryItem>(items, hasMore: page.hasMore);
    },
  );

  @override
  void initState() {
    super.initState();
    _pages.refresh();
    _history.addListener(_pages.refresh);
  }

  @override
  void dispose() {
    _history.removeListener(_pages.refresh);
    _pages.dispose();
    super.dispose();
  }

  bool _startsWeek(int index, List<HistoryItem> items) =>
      index == 0 || weekOrdinal(items[index - 1].entry.cookedAt) != weekOrdinal(items[index].entry.cookedAt);

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final thisWeek = weekOrdinal(_catalog.clock());
    final rowExtent = RecipeRowMetrics.of(context).extent;
    // The heading is handwriting at 26 pt with 8 pt below it, and grows with the text size.
    final headerExtent = math.max(
      _baseHeaderExtent,
      (MediaQuery.textScalerOf(context).scale(26) * 1.1 + 8 + 12).ceilToDouble(),
    );
    return PaginatedList<HistoryItem>(
      controller: _pages,
      itemExtent: (index, items) => rowExtent + (_startsWeek(index, items) ? headerExtent : 0),
      padding: const EdgeInsets.only(bottom: 24),
      skeletonBuilder: (_) => const SingleChildScrollView(child: SkeletonList(count: 6)),
      emptyBuilder: (context) => EmptyState(
        title: s('history.empty.title'),
        body: s('history.empty.body'),
        action: s('cookbook.empty.action'),
        onAction: () => context.read<NavRequests>().showTab(0),
      ),
      errorBuilder: (context, retry) => ErrorState(onRetry: retry),
      itemBuilder: (context, item, index) {
        final recipe = item.recipe;
        final dish = item.dish;
        final week = weekOrdinal(item.entry.cookedAt);
        final row = recipe == null || dish == null
            ? SizedBox(
                height: rowExtent,
                child: Center(
                  child: Text(s('cookbook.gone'), style: AppText.serifItalic(color: Palette.inkSoft)),
                ),
              )
            : RecipeRow(
                seed: dish.id,
                title: recipe.title.resolve(s.lang),
                meta: s('history.cooked', {'date': s.shortDate(item.entry.cookedAt), 'n': item.entry.servings.round()}),
                stripe: Palette.fromHex(dish.stripe),
                onTap: () => openDish(context, dish.id, recipeId: recipe.id),
                trailing: PaperIconButton(
                  icon: Icons.replay,
                  tooltip: s('history.again'),
                  onPressed: () => openDish(context, dish.id, recipeId: recipe.id),
                ),
              );
        if (!_startsWeek(index, _pages.items)) return row;
        final monday = item.entry.cookedAt.subtract(Duration(days: item.entry.cookedAt.weekday - 1));
        return Column(
          children: [
            SizedBox(
              height: headerExtent,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    week == thisWeek
                        ? s('history.thisWeek')
                        : week == thisWeek - 1
                        ? s('history.lastWeek')
                        : s('history.weekOf', {'date': s.shortDate(monday)}),
                    style: AppText.hand(size: 26, color: Palette.coralDeep),
                  ),
                ),
              ),
            ),
            row,
          ],
        );
      },
    );
  }
}
