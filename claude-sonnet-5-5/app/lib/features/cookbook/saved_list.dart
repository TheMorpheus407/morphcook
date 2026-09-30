import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/nav_requests.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/labels.dart';
import '../../core/pagination/pagination_controller.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/corpus.dart';
import '../../data/models/dish.dart';
import '../../data/models/recipe.dart';
import '../../state/controllers/cookbook_controller.dart';
import '../../state/controllers/profile_controller.dart';
import '../../widgets/paginated_list.dart';
import '../../widgets/paper_controls.dart';
import '../../widgets/recipe_row.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/state_views.dart';

/// A saved variant with its recipe and dish resolved.
class SavedItem {
  const SavedItem(this.saved, this.recipe, this.dish);
  final SavedRecipe saved;
  final Recipe? recipe;
  final Dish? dish;
}

/// The cookbook: saved variants, newest first, offset-paginated (30 per page).
/// Used by the cookbook tab and by the meal-plan recipe picker.
class SavedList extends StatefulWidget {
  const SavedList({super.key, required this.onOpen, this.showUnsave = true, this.emptyAction});

  /// Called with the tapped recipe.
  final void Function(BuildContext context, Recipe recipe, Dish dish) onOpen;

  /// The trailing bookmark that removes a recipe from the cookbook.
  final bool showUnsave;

  /// Overrides the empty-state button (defaults to opening the today tab).
  final VoidCallback? emptyAction;

  @override
  State<SavedList> createState() => _SavedListState();
}

class _SavedListState extends State<SavedList> {
  late final CookbookController _cookbook = context.read<CookbookController>();
  late final Corpus _corpus = context.read<Corpus>();

  late final PaginationController<SavedItem> _pages = PaginationController<SavedItem>.offset(
    loader: (offset, limit) async {
      final page = _cookbook.page(offset, limit);
      final items = <SavedItem>[];
      for (final saved in page.items) {
        final recipe = await _corpus.loadRecipe(saved.recipeId);
        items.add(SavedItem(saved, recipe, _corpus.dishOfRecipe(saved.recipeId)));
      }
      return OffsetPage<SavedItem>(items, total: page.total);
    },
  );

  @override
  void initState() {
    super.initState();
    _pages.refresh();
    _cookbook.addListener(_pages.refresh);
  }

  @override
  void dispose() {
    _cookbook.removeListener(_pages.refresh);
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final filter = context.watch<ProfileController>().filter;
    final ontology = _corpus.ontology;
    final showTags = context.select<ProfileController, bool>((p) => p.profile.showVariantTags);
    final rowExtent = RecipeRowMetrics.of(context).extent;
    return PaginatedList<SavedItem>(
      controller: _pages,
      itemExtent: (_, _) => rowExtent,
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      skeletonBuilder: (_) => const SingleChildScrollView(child: SkeletonList(count: 6)),
      emptyBuilder: (context) => EmptyState(
        title: s('cookbook.empty.title'),
        body: s('cookbook.empty.body'),
        action: s('cookbook.empty.action'),
        onAction: widget.emptyAction ?? () => context.read<NavRequests>().showTab(0),
      ),
      errorBuilder: (context, retry) => ErrorState(onRetry: retry),
      itemBuilder: (context, item, index) {
        final recipe = item.recipe;
        final dish = item.dish;
        if (recipe == null || dish == null) {
          return SizedBox(
            height: rowExtent,
            child: Center(
              child: Text(s('cookbook.gone'), style: AppText.serifItalic(color: Palette.inkSoft)),
            ),
          );
        }
        // A saved recipe that no longer fits an allergy stays in the cookbook, flagged.
        final match = filter.evaluate(recipe, ignoreCalories: true);
        final unsafe = !filter.isSafe(recipe);
        final reasons = match.clashLabels(recipe, ontology, _corpus.ingredients, s.lang);
        return RecipeRow(
          seed: dish.id,
          title: recipe.title.resolve(s.lang),
          meta: recipeMeta(s, ontology, recipe, showDiet: showTags),
          stripe: Palette.fromHex(dish.stripe),
          note: s('cookbook.savedOn', {'date': s.shortDate(item.saved.savedAt)}),
          warning: unsafe ? s('cookbook.warning', {'items': reasons.take(3).join(', ')}) : null,
          onTap: () => widget.onOpen(context, recipe, dish),
          trailing: widget.showUnsave
              ? PaperIconButton(
                  icon: Icons.bookmark,
                  color: Palette.coralDeep,
                  tooltip: s('dish.unsave'),
                  onPressed: () => _unsave(context, item),
                )
              : null,
        );
      },
    );
  }

  Future<void> _unsave(BuildContext context, SavedItem item) async {
    final s = context.sRead;
    final messenger = ScaffoldMessenger.of(context);
    await _cookbook.remove(item.saved.recipeId);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(s('dish.removed')),
          action: SnackBarAction(
            label: s('common.undo'),
            textColor: Palette.mustard,
            onPressed: () => _cookbook.save(item.saved.recipeId, at: item.saved.savedAt),
          ),
        ),
      );
  }
}
