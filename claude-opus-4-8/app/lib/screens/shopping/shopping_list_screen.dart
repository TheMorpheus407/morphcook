import 'package:flutter/material.dart';

import '../../core/context_ext.dart';
import '../../core/localized.dart';
import '../../logic/shopping_aggregator.dart';
import '../../models/recipe.dart';
import '../../theme/app_theme.dart';
import '../../widgets/decor.dart';
import '../../widgets/paper_background.dart';
import 'insights_screen.dart';

/// The smart shopping list: chosen recipes up top with serving steppers, then
/// every ingredient tidied into aisle groups, deduped and summed. Tick things
/// off as you walk the store.
class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.scope;
    final shopping = scope.services.shopping;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.paper.withValues(alpha: 0.9),
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: Text(
          context.tr('shop.title'),
          style: const TextStyle(
            fontFamily: Fonts.display,
            fontStyle: FontStyle.italic,
            fontSize: 24,
            color: AppColors.ink,
          ),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('shop.insights'),
            icon: const Icon(Icons.insights_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InsightsScreen()),
            ),
          ),
          ListenableBuilder(
            listenable: shopping,
            builder: (context, _) {
              if (shopping.selections().isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: context.tr('common.clear'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmClear(context),
              );
            },
          ),
        ],
      ),
      body: PaperBackground(
        child: ListenableBuilder(
          listenable: shopping,
          builder: (context, _) {
            final selections = shopping.selections();
            if (selections.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: HandNote(context.tr('shop.empty'), size: 22),
                ),
              );
            }

            final corpus = scope.corpus;
            final requests = <ShoppingRequest>[];
            for (final s in selections) {
              final r = corpus.recipe(s.recipeId);
              if (r != null) requests.add(ShoppingRequest(r, s.servings));
            }
            final agg = ShoppingAggregator(corpus.ingredients);
            final groups = agg.aggregate(requests, context.lang);
            final checked = shopping.checkedIngredientIds();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _RecipePanel(),
                const SizedBox(height: 16),
                for (final group in groups) ...[
                  _AisleHeader(label: context.loc(group.label)),
                  for (final line in group.lines)
                    _LineRow(
                      line: line,
                      checked: checked.contains(line.ingredientId),
                      onToggle: () => shopping.toggleChecked(line.ingredientId),
                    ),
                  const SizedBox(height: 18),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text(
          context.tr('common.clear'),
          style: const TextStyle(
            fontFamily: Fonts.display,
            fontStyle: FontStyle.italic,
            color: AppColors.ink,
          ),
        ),
        content: Text(
          context.lang == AppLang.de
              ? 'Die ganze Einkaufsliste leeren?'
              : 'Empty the whole shopping list?',
          style: const TextStyle(fontFamily: Fonts.mono, fontSize: 13, color: AppColors.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr('common.cancel'),
                style: const TextStyle(fontFamily: Fonts.mono, color: AppColors.inkSoft)),
          ),
          TextButton(
            onPressed: () {
              context.scope.services.shopping.clear();
              Navigator.of(dialogContext).pop();
            },
            child: Text(context.tr('common.clear'),
                style: const TextStyle(fontFamily: Fonts.mono, color: AppColors.clay)),
          ),
        ],
      ),
    );
  }
}

class _RecipePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scope = context.scope;
    final shopping = scope.services.shopping;
    final selections = shopping.selections();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MonoLabel(
            '${selections.length} ${context.tr('shop.recipes_in_list')}',
            color: AppColors.terracotta,
          ),
        ),
        for (final s in selections)
          Builder(builder: (context) {
            final recipe = scope.corpus.recipe(s.recipeId);
            return _SelectionRow(
              recipe: recipe,
              recipeId: s.recipeId,
              servings: s.servings,
            );
          }),
        const SizedBox(height: 12),
        DashedRule(withAmpersand: true),
      ],
    );
  }
}

class _SelectionRow extends StatelessWidget {
  const _SelectionRow({
    required this.recipe,
    required this.recipeId,
    required this.servings,
  });
  final Recipe? recipe;
  final String recipeId;
  final int servings;

  @override
  Widget build(BuildContext context) {
    final shopping = context.scope.services.shopping;
    final name = recipe != null
        ? context.loc(recipe!.name)
        : (context.lang == AppLang.de ? 'unbekanntes Rezept' : 'unknown recipe');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: Fonts.display,
                fontStyle: FontStyle.italic,
                fontSize: 17,
                color: AppColors.ink,
              ),
            ),
          ),
          _StepIcon(
            icon: Icons.remove,
            onTap: servings > 1
                ? () => shopping.setServings(recipeId, servings - 1)
                : null,
          ),
          SizedBox(
            width: 36,
            child: Center(
              child: Text(
                '$servings',
                style: const TextStyle(
                  fontFamily: Fonts.mono,
                  fontSize: 14,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          _StepIcon(
            icon: Icons.add,
            onTap: () => shopping.setServings(recipeId, servings + 1),
          ),
          const SizedBox(width: 4),
          _StepIcon(
            icon: Icons.close,
            color: AppColors.clay,
            onTap: () => shopping.removeRecipe(recipeId),
          ),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.icon, this.onTap, this.color});
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      color: color ?? AppColors.inkSoft,
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
    );
  }
}

class _AisleHeader extends StatelessWidget {
  const _AisleHeader({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(label, color: AppColors.inkSoft),
          const SizedBox(height: 6),
          DashedRule(),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.checked,
    required this.onToggle,
  });
  final ShoppingLine line;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final inkColor = checked ? AppColors.inkFaint : AppColors.ink;
    final decoration = checked ? TextDecoration.lineThrough : TextDecoration.none;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                checked ? Icons.check_box_outlined : Icons.check_box_outline_blank,
                size: 20,
                color: checked ? AppColors.sage : AppColors.inkFaint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.loc(line.name),
                    style: TextStyle(
                      fontFamily: Fonts.display,
                      fontStyle: FontStyle.italic,
                      fontSize: 18,
                      color: inkColor,
                      decoration: decoration,
                      decorationColor: AppColors.inkFaint,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${context.tr('shop.from_recipes')} ${line.recipeNames.length}',
                    style: TextStyle(
                      fontFamily: Fonts.mono,
                      fontSize: 10,
                      letterSpacing: 0.8,
                      color: AppColors.inkFaint,
                      decoration: decoration,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              line.quantityLabel(),
              style: TextStyle(
                fontFamily: Fonts.mono,
                fontSize: 12,
                color: checked ? AppColors.inkFaint : AppColors.inkSoft,
                decoration: decoration,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
